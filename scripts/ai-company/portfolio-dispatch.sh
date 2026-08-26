#!/usr/bin/env bash
# Dispatch agent-delivery workflow across all active projects in project-registry.yaml.
# Run from multica repo (company HQ) or set REGISTRY path.
set -euo pipefail

MULTICA_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib/source-local-env.sh
source "$(dirname "$0")/lib/source-local-env.sh"
# shellcheck source=lib/agent-queue.sh
source "$(dirname "$0")/lib/agent-queue.sh"
REGISTRY="${REGISTRY:-$MULTICA_ROOT/.ai-company/templates/project-registry.yaml}"
MAX_TOTAL="${MAX_TOTAL:-5}"
DRY_RUN=0
LOCAL=0
WORKFLOW="${WORKFLOW:-agent-delivery-dispatch.yml}"
GITHUB_ORG="${GITHUB_ORG:-chenzh}"

usage() {
  cat <<'EOF'
Usage: portfolio-dispatch.sh [options]

Reads .ai-company/templates/project-registry.yaml and triggers
agent-delivery-dispatch on each repo (fair share per max_nightly_tickets).

Options:
  --registry PATH   project-registry.yaml
  --max-total N     Cap total dispatches this run (default: 5)
  --workflow NAME   Workflow file name (default: agent-delivery-dispatch.yml)
  --local           Dispatch via local cursor-agent CLI (no GHA / no CURSOR_API_KEY)
  --dry-run         Print commands only
  -h, --help

Requires: gh CLI, authenticated for all repos in registry.

Example:
  bash scripts/ai-company/portfolio-dispatch.sh --dry-run
  bash scripts/ai-company/portfolio-dispatch.sh --max-total 3
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --registry) REGISTRY="${2:?}"; shift 2 ;;
    --max-total) MAX_TOTAL="${2:?}"; shift 2 ;;
    --workflow) WORKFLOW="${2:?}"; shift 2 ;;
    --local) LOCAL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ ! -f "$REGISTRY" ]; then
  echo "error: registry not found: $REGISTRY" >&2
  exit 1
fi

# Parse YAML projects block (line-oriented; matches our template shape).
declare -a IDS=() REPOS=() PRIORITIES=() CAPS=() PAUSED=()

current_id="" current_repo="" current_priority="0" current_cap="1" current_paused="false"

flush_project() {
  if [ -z "$current_id" ] || [ -z "$current_repo" ]; then
    return 0
  fi
  IDS+=("$current_id")
  REPOS+=("$current_repo")
  PRIORITIES+=("$current_priority")
  CAPS+=("$current_cap")
  PAUSED+=("$current_paused")
  current_id=""
  current_repo=""
  current_priority="0"
  current_cap="1"
  current_paused="false"
}

while IFS= read -r line; do
  line="${line%%#*}"
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  if [[ "$line" =~ ^-\ id:\ (.+)$ ]]; then
    flush_project
    current_id="${BASH_REMATCH[1]}"
    continue
  fi
  if [[ "$line" =~ ^repo:\ (.+)$ ]]; then
    current_repo="${BASH_REMATCH[1]}"
    current_repo="${current_repo#github.com/}"
    current_repo="${current_repo#https://github.com/}"
    if [[ "$current_repo" == your-org/* ]]; then
      current_repo="${current_repo/your-org/$GITHUB_ORG}"
    fi
    continue
  fi
  if [[ "$line" =~ ^priority:\ (.+)$ ]]; then
    current_priority="${BASH_REMATCH[1]}"
    continue
  fi
  if [[ "$line" =~ ^max_nightly_tickets:\ (.+)$ ]]; then
    current_cap="${BASH_REMATCH[1]}"
    continue
  fi
  if [[ "$line" =~ ^paused:\ (.+)$ ]]; then
    current_paused="${BASH_REMATCH[1]}"
    continue
  fi
done <"$REGISTRY"
flush_project

if [ "${#IDS[@]}" -eq 0 ]; then
  echo "No projects in registry."
  exit 0
fi

# Sort indices by priority desc (simple bubble via ordered list)
declare -a ORDER=()
for i in "${!IDS[@]}"; do ORDER+=("$i"); done
for ((a=0; a<${#ORDER[@]}; a++)); do
  for ((b=a+1; b<${#ORDER[@]}; b++)); do
    ia=${ORDER[$a]} ib=${ORDER[$b]}
    if [ "${PRIORITIES[$ia]}" -lt "${PRIORITIES[$ib]}" ]; then
      tmp=${ORDER[$a]}; ORDER[$a]=${ORDER[$b]}; ORDER[$b]=$tmp
    fi
  done
done

remaining="$MAX_TOTAL"
total_dispatched=0

pick_next_issue() {
  local repo="$1"
  gh issue list -R "$repo" \
    --label "agent-safe" \
    --state open \
    --json number,labels \
    --jq '.[] | select([.labels[].name] | (index("agent-running") | not) and (index("agent-blocked") | not) and (index("agent-done") | not)) | .number' \
    | head -n 1
}

echo "Portfolio dispatch (max_total=$MAX_TOTAL mode=$([ "$LOCAL" -eq 1 ] && echo local-cli || echo gha))"
echo "Registry: $REGISTRY"
echo ""

for idx in "${ORDER[@]}"; do
  [ "$remaining" -le 0 ] && break
  if [ "${PAUSED[$idx]}" = "true" ]; then
    echo "skip (paused): ${IDS[$idx]} (${REPOS[$idx]})"
    continue
  fi
  cap="${CAPS[$idx]}"
  if [ "$cap" -gt "$remaining" ]; then
    cap="$remaining"
  fi
  repo="${REPOS[$idx]}"
  echo "→ ${IDS[$idx]} ($repo) max_tasks=$cap priority=${PRIORITIES[$idx]}"

  if [ "$LOCAL" -eq 1 ]; then
    root="$(bash "$MULTICA_ROOT/scripts/ai-company/resolve-repo-path.sh" --id "${IDS[$idx]}" --repo "$repo" --quiet 2>/dev/null || true)"
    if [ -z "$root" ] || [ ! -d "$root" ]; then
      echo "  warning: no local checkout for ${IDS[$idx]} ($repo) — set AI_REPO_PATH_${IDS[$idx]} in local.env" >&2
      continue
    fi
    for ((n=0; n<cap; n++)); do
      issue="$(pick_next_issue "$repo")"
      if [ -z "$issue" ]; then
        echo "  no eligible agent-safe issues in $repo"
        break
      fi
      if issue_dispatch_active "$issue"; then
        echo "  skip $repo#$issue (dispatch already in progress)"
        break
      fi
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "  GITHUB_REPOSITORY=$repo REPO_ROOT=$root dispatch-cursor-agent-cli.sh $issue"
      else
        GITHUB_REPOSITORY="$repo" REPO_ROOT="$root" \
          bash "$MULTICA_ROOT/scripts/agent-delivery/dispatch-cursor-agent-cli.sh" "$issue" || {
          echo "  warning: local dispatch failed for $repo#$issue" >&2
          continue
        }
      fi
      total_dispatched=$((total_dispatched + 1))
      remaining=$((remaining - 1))
      [ "$remaining" -le 0 ] && break
    done
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  gh workflow run $WORKFLOW -R $repo -f max_tasks=$cap"
  else
    if ! gh repo view "$repo" &>/dev/null; then
      echo "  warning: cannot access repo $repo — skip" >&2
      continue
    fi
    default_branch="$(gh repo view "$repo" --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || echo main)"
    workflow_id="$(
      gh api "repos/$repo/actions/workflows" \
        --jq ".workflows[] | select(.path == \".github/workflows/$WORKFLOW\") | .id" 2>/dev/null || true
    )"
    if [ -n "$workflow_id" ]; then
      if gh workflow run "$workflow_id" -R "$repo" --ref "$default_branch" -f "max_tasks=$cap"; then
        total_dispatched=$((total_dispatched + cap))
        remaining=$((remaining - cap))
        continue
      fi
      echo "  warning: workflow dispatch failed for $repo — trying local CLI" >&2
    else
      echo "  workflow $WORKFLOW not registered on $repo — falling back to local CLI" >&2
    fi
    root="$(bash "$MULTICA_ROOT/scripts/ai-company/resolve-repo-path.sh" --id "${IDS[$idx]}" --repo "$repo" --quiet 2>/dev/null || true)"
    if [ -z "$root" ] || [ ! -d "$root" ]; then
      echo "  warning: no local checkout for ${IDS[$idx]} — set AI_REPO_PATH_* in local.env" >&2
      continue
    fi
    for ((n=0; n<cap; n++)); do
      issue="$(pick_next_issue "$repo")"
      if [ -z "$issue" ]; then
        echo "  no eligible agent-safe issues in $repo"
        break
      fi
      if issue_dispatch_active "$issue"; then
        echo "  skip $repo#$issue (dispatch already in progress)"
        break
      fi
      GITHUB_REPOSITORY="$repo" REPO_ROOT="$root" \
        bash "$MULTICA_ROOT/scripts/agent-delivery/dispatch-cursor-agent-cli.sh" "$issue" || {
        echo "  warning: local dispatch failed for $repo#$issue" >&2
        continue
      }
      total_dispatched=$((total_dispatched + 1))
      remaining=$((remaining - 1))
      [ "$remaining" -le 0 ] && break
    done
  fi
done

echo ""
echo "Planned/dispatched task slots: $total_dispatched"
