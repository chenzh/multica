#!/usr/bin/env bash
# Dispatch portfolio tickets through Multica L1 queue (daemon runtime).
# GitHub Issue remains spec mirror during pilot; assign + run history live in Multica.
# shellcheck shell=bash

_MDCA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agent-queue.sh
source "$_MDCA_LIB_DIR/agent-queue.sh"
# shellcheck source=site-factory-runtime.sh
source "$_MDCA_LIB_DIR/site-factory-runtime.sh"

registry_multica_agent_id_for_project() {
  local registry="${1:?}" project_id="${2:?}"
  python3 - "$registry" "$project_id" <<'PY'
import sys
from pathlib import Path

registry = Path(sys.argv[1])
project_id = sys.argv[2]
current_id = ""
agent_id = ""
for line in registry.read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if stripped.startswith("- id:"):
        current_id = stripped.split(":", 1)[1].strip()
        agent_id = ""
        continue
    if stripped.startswith("multica_agent_id:") and current_id == project_id:
        agent_id = stripped.split(":", 1)[1].strip()
        if agent_id and agent_id.lower() not in ("null", "~"):
            print(agent_id)
        raise SystemExit(0)
print("")
PY
}

multica_dispatch_resolve_agent() {
  local registry="${1:-}" project_id="${2:-}" from_registry=""
  if [ -n "$registry" ] && [ -n "$project_id" ]; then
    from_registry="$(registry_multica_agent_id_for_project "$registry" "$project_id")"
    if [ -n "$from_registry" ]; then
      echo "$from_registry"
      return 0
    fi
  fi
  if [ -n "${PORTFOLIO_MULTICA_AGENT_ID:-}" ]; then
    echo "$PORTFOLIO_MULTICA_AGENT_ID"
    return 0
  fi
  if [ -n "${SITE_FACTORY_MULTICA_AGENT_ID:-}" ]; then
    echo "$SITE_FACTORY_MULTICA_AGENT_ID"
    return 0
  fi
  if [ -n "${MULTICA_DEV_AGENT_ID:-}" ]; then
    echo "$MULTICA_DEV_AGENT_ID"
    return 0
  fi
  if [ -n "$project_id" ]; then
    echo "multica dispatch: no multica_agent_id for project $project_id (set in project-registry.yaml or PORTFOLIO_MULTICA_AGENT_ID)" >&2
    return 1
  fi
  multica agent list --output json 2>/dev/null | python3 -c "
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(1)
agents = json.loads(raw)
candidates = []
for row in agents:
    if row.get('archived_at'):
        continue
    if row.get('runtime_bound') and row.get('runtime_mode') == 'local':
        candidates.append(row)
if not candidates:
    candidates = [r for r in agents if not r.get('archived_at')]
if not candidates:
    sys.exit(1)
candidates.sort(key=lambda r: (r.get('status') != 'idle', r.get('name') or ''))
print(candidates[0]['id'])
"
}

multica_dispatch_json_field() {
  local json="$1" field="$2"
  python3 - "$json" "$field" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
print(data.get(sys.argv[2], ""))
PY
}

registry_dispatch_mode_for_repo() {
  local registry="${1:?}" repo="${2:?}"
  python3 - "$registry" "$repo" <<'PY'
import sys
from pathlib import Path

registry = Path(sys.argv[1])
repo = sys.argv[2].replace("github.com/", "").replace("https://github.com/", "")
current_repo = ""
mode = ""
for line in registry.read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if stripped.startswith("repo:"):
        current_repo = stripped.split(":", 1)[1].strip()
        current_repo = current_repo.replace("github.com/", "").replace("https://github.com/", "")
        mode = ""
        continue
    if stripped.startswith("dispatch_mode:") and current_repo == repo:
        print(stripped.split(":", 1)[1].strip())
        raise SystemExit(0)
print("")
PY
}

multica_dispatch_github_needle() {
  local repo="$1" num="$2"
  echo "github.com/${repo}/issues/${num}"
}

multica_dispatch_find_mirror_issue_id() {
  local repo="$1" num="$2"
  local needle
  needle="$(multica_dispatch_github_needle "$repo" "$num")"
  multica issue list --output json --limit 100 2>/dev/null | python3 -c "
import json, sys
needle = sys.argv[1]
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
data = json.loads(raw)
rows = data.get('issues', data) if isinstance(data, dict) else data
for row in rows:
    desc = row.get('description') or ''
    if needle not in desc:
        continue
    if row.get('status_category') in ('done', 'cancelled'):
        continue
    print(row.get('id', ''))
    break
" "$needle"
}

multica_dispatch_issue_id_active() {
  local id="${1:?}"
  local category
  category="$(multica issue get "$id" --output json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('status_category',''))" 2>/dev/null || true)"
  case "$category" in
    done | cancelled | "") return 1 ;;
    *) return 0 ;;
  esac
}

issue_multica_mirror_active() {
  local repo="${1:?}" num="${2:?}"
  local mid
  mid="$(multica_dispatch_find_mirror_issue_id "$repo" "$num")"
  [ -n "$mid" ] || return 1
  multica_dispatch_issue_id_active "$mid"
}

# True only while a Multica task is actually running/queued for this GitHub issue.
# in_review after a completed run must NOT block agent-done / new portfolio slots.
multica_dispatch_mirror_has_live_run() {
  local repo="${1:?}" num="${2:?}"
  local mid
  mid="$(multica_dispatch_find_mirror_issue_id "$repo" "$num")"
  [ -n "$mid" ] || return 1
  multica issue runs "$mid" --output json 2>/dev/null | python3 -c "
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    raise SystemExit(1)
runs = json.loads(raw)
if not isinstance(runs, list):
    runs = runs.get('runs') or runs.get('items') or []
for r in runs:
    if (r.get('status') or '').lower() in ('running', 'queued', 'pending', 'dispatched', 'preparing'):
        raise SystemExit(0)
raise SystemExit(1)
" 2>/dev/null
}

# When GitHub issue is CLOSED (merged/done) but Multica mirror still open
# (in_review/todo), mark Multica done so reconcile can strip agent labels.
multica_dispatch_close_mirror_if_github_closed() {
  local repo="${1:?}" num="${2:?}" dry="${3:-0}"
  local mid gh_state
  gh_state="$(gh issue view "$num" -R "$repo" --json state -q .state 2>/dev/null || true)"
  [ "$gh_state" = "CLOSED" ] || return 1
  mid="$(multica_dispatch_find_mirror_issue_id "$repo" "$num")"
  [ -n "$mid" ] || return 1
  if [ "$dry" = "1" ]; then
    echo "would Multica done: mirror $mid for $repo#$num (GitHub CLOSED)"
    return 0
  fi
  if multica issue status "$mid" done >>/dev/null 2>&1; then
    echo "multica reconcile: $mid → done (GitHub $repo#$num CLOSED)"
    return 0
  fi
  return 1
}

multica_dispatch_busy_count() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  bash "$script_dir/multica-runtime-status.sh" --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(int(d.get('working_agents_total_running') or 0))" 2>/dev/null || echo 0
}

# Pick lowest-numbered eligible GitHub issue (spec mirror).
pick_next_agent_safe_issue() {
  local repo="$1"
  gh issue list -R "$repo" \
    --label "agent-safe" \
    --state open \
    --json number,labels \
    --jq '.[] | select([.labels[].name] | (index("agent-running") | not) and (index("agent-blocked") | not) and (index("agent-done") | not)) | .number' \
    | head -n 1
}

pick_next_agent_safe_issue_for_multica() {
  local repo="$1" num
  while read -r num; do
    [ -z "$num" ] && continue
    if issue_multica_mirror_active "$repo" "$num"; then
      continue
    fi
    echo "$num"
    return 0
  done < <(
    gh issue list -R "$repo" \
      --label "agent-safe" \
      --state open \
      --json number,labels \
      --jq '.[] | select([.labels[].name] | (index("agent-running") | not) and (index("agent-blocked") | not) and (index("agent-done") | not)) | .number' \
      | sort -n
  )
  return 0
}

multica_dispatch_sync_github_running_label() {
  local repo="$1" issue="$2"
  gh issue edit "$issue" -R "$repo" --add-label "agent-running" --remove-label "agent-safe" 2>/dev/null || \
    gh issue edit "$issue" -R "$repo" --add-label "agent-running" 2>/dev/null || true
}

multica_dispatch_ensure_mirror() {
  local repo="$1" issue="$2" root="$3" slug="$4" agent_id="$5" log_file="$6"
  local issue_json title body url child_id child_json create_err
  create_err="$(mktemp)"

  issue_json="$(gh issue view "$issue" -R "$repo" --json title,body,url 2>/dev/null || echo '{}')"
  title="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('title',''))" "$issue_json")"
  url="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('url',''))" "$issue_json")"
  body="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('body') or '')" "$issue_json")"

  child_id="$(multica_dispatch_find_mirror_issue_id "$repo" "$issue")"
  if [ -z "$child_id" ]; then
    child_json="$(multica issue create \
      --title "$title" \
      --description "GitHub spec mirror: $url

Repo path: $root
Delivery: .delivery/$slug/
Read brief.md and accept_cases.md before coding.
Follow orchestrator pipeline (Planner→Implementer→Verifier).

---
$body" \
      --status todo \
      --output json 2>"$create_err")" || child_json=""
    if [ -z "$child_json" ]; then
      if grep -q 'Active duplicate issue exists' "$create_err" 2>/dev/null; then
        child_id="$(multica_dispatch_find_mirror_issue_id "$repo" "$issue")"
        echo "multica dispatch: reuse duplicate mirror $child_id for github #$issue" >>"$log_file"
      else
        cat "$create_err" >>"$log_file" 2>/dev/null || true
        rm -f "$create_err"
        return 1
      fi
    else
      child_id="$(multica_dispatch_json_field "$child_json" id)"
    fi
  else
    echo "multica dispatch: reuse existing mirror $child_id for github #$issue" >>"$log_file"
  fi
  rm -f "$create_err"
  [ -n "$child_id" ] || return 1

  if ! multica issue assign "$child_id" --to-id "$agent_id" >>"$log_file" 2>&1; then
    echo "multica dispatch: assign failed for $child_id" >>"$log_file"
    return 1
  fi

  multica_dispatch_sync_github_running_label "$repo" "$issue"
  if ! gh issue view "$issue" -R "$repo" --json comments -q '.comments[-1].body // ""' 2>/dev/null | grep -q 'Multica L1 queue'; then
    gh issue comment "$issue" -R "$repo" --body "🤖 Dispatched via **Multica L1 queue** (issue \`$child_id\`, agent \`$agent_id\`).

View: ${MULTICA_FRONTEND_URL:-http://localhost:3000}/local/issues" 2>/dev/null || true
  fi

  echo "multica dispatch: github #$issue → multica $child_id (agent $agent_id)" >>"$log_file"
  echo "  multica dispatch $repo#$issue → $child_id (agent $agent_id)"
  return 0
}

# Dispatch up to $cap GitHub spec mirrors via Multica assign (no cursor-agent CLI spawn).
# Returns 0 when at least one issue was assigned.
portfolio_dispatch_via_multica() {
  local repo="$1" root="$2" slug="$3" cap="$4" log_file="$5" dry_run="${6:-0}" registry="${7:-}" project_id="${8:-}"

  if [ "$dry_run" = "1" ]; then
    local preview=0 n issue
    for ((n = 0; n < cap; n++)); do
      issue="$(pick_next_agent_safe_issue_for_multica "$repo")"
      [ -z "$issue" ] && break
      echo "  [dry-run] multica assign: $repo#$issue → daemon (slug=$slug root=$root)"
      preview=$((preview + 1))
    done
    [ "$preview" -gt 0 ]
    return $?
  fi

  if ! site_factory_daemon_running; then
    echo "multica dispatch: daemon not running — start: multica daemon start" >>"$log_file"
    echo "multica dispatch: daemon not running" >&2
    return 1
  fi
  if ! site_factory_runtime_ready; then
    echo "multica dispatch: Multica API not ready" >>"$log_file"
    echo "multica dispatch: Multica API not ready" >&2
    return 1
  fi

  local agent_id
  agent_id="$(multica_dispatch_resolve_agent "$registry" "$project_id")" || {
    echo "multica dispatch: no agent id (set multica_agent_id in registry for $project_id or PORTFOLIO_MULTICA_AGENT_ID)" >>"$log_file"
    echo "multica dispatch: no agent id" >&2
    return 1
  }

  local count=0 issue
  while [ "$count" -lt "$cap" ]; do
    issue="$(pick_next_agent_safe_issue_for_multica "$repo" || true)"
    [ -z "$issue" ] && break

    if issue_multica_mirror_active "$repo" "$issue"; then
      multica_dispatch_ensure_mirror "$repo" "$issue" "$root" "$slug" "$agent_id" "$log_file" || true
      echo "  multica dispatch: already active for github #$issue"
      echo "multica dispatch: already active for github #$issue" >>"$log_file"
      return 0
    fi

    if multica_dispatch_ensure_mirror "$repo" "$issue" "$root" "$slug" "$agent_id" "$log_file"; then
      count=$((count + 1))
    fi
  done

  if [ "$count" -eq 0 ]; then
    local safe_num
    safe_num="$(pick_next_agent_safe_issue "$repo" || true)"
    if [ -n "$safe_num" ] && issue_multica_mirror_active "$repo" "$safe_num"; then
      multica_dispatch_ensure_mirror "$repo" "$safe_num" "$root" "$slug" "$agent_id" "$log_file" || true
      echo "multica dispatch: queue covered by active Multica mirror (github #$safe_num)" >>"$log_file"
      echo "  multica dispatch: already active for github #$safe_num"
      return 0
    fi
    echo "multica dispatch: no issues assigned" >>"$log_file"
    return 1
  fi
  echo "multica dispatch: assigned $count issue(s) on agent $agent_id" >>"$log_file"
  return 0
}
