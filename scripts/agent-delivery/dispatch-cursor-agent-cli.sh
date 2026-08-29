#!/usr/bin/env bash
# Dispatch one issue via local cursor-agent CLI (session auth).
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-}"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CURSOR_AGENT_BIN="${CURSOR_AGENT_BIN:-cursor-agent}"
WORKTREE_BASE="${WORKTREE_BASE:-main}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/.delivery/.agent-runs}"
DRY_RUN=0
ISSUE_NUMBER=""

usage() {
  cat <<'EOF'
Usage: dispatch-cursor-agent-cli.sh <issue_number> [--dry-run]

Runs cursor-agent locally against REPO_ROOT using CLI session auth.
Requires: gh, jq, cursor-agent logged in (`cursor-agent status`).

Environment:
  GITHUB_REPOSITORY   owner/name (default: infer from gh)
  REPO_ROOT           Product repo path (default: parent of scripts/agent-delivery)
  CURSOR_AGENT_BIN        Binary (default: cursor-agent)
  WORKTREE_BASE       Base ref for --worktree (default: main)
  LOG_DIR             Where to write run logs
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *)
      if [ -z "$ISSUE_NUMBER" ]; then
        ISSUE_NUMBER="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [ -z "$ISSUE_NUMBER" ]; then
  usage >&2
  exit 1
fi

WORKTREE_NAME="${WORKTREE_NAME:-cursor-issue-${ISSUE_NUMBER}}"
USE_WORKTREE="${USE_WORKTREE:-1}"

mkdir -p "$LOG_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/issue-${ISSUE_NUMBER}-${TS}.log"
{
  echo "=== dispatch-cursor-agent-cli.sh ==="
  echo "started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "issue=#${ISSUE_NUMBER} root=${REPO_ROOT}"
} >>"$LOG_FILE"

if [ -z "$REPO" ]; then
  REPO="$(gh repo view "$REPO_ROOT" --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "$REPO" ]; then
  echo "error: set GITHUB_REPOSITORY or run inside a gh-linked repo" >&2
  echo "error: could not resolve GITHUB_REPOSITORY" >>"$LOG_FILE"
  exit 1
fi
echo "repo=$REPO" >>"$LOG_FILE"

if ! command -v "$CURSOR_AGENT_BIN" &>/dev/null; then
  echo "error: $CURSOR_AGENT_BIN not found on PATH" >&2
  echo "error: $CURSOR_AGENT_BIN not found" >>"$LOG_FILE"
  exit 1
fi

if ! "$CURSOR_AGENT_BIN" status &>/dev/null; then
  echo "error: cursor-agent not logged in — run: cursor-agent login" >&2
  echo "error: cursor-agent not logged in" >>"$LOG_FILE"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export GH_REPO="$REPO"
gh issue view "$ISSUE_NUMBER" --json title,body,url,number >"$TMP/issue.json"
PROMPT="$TMP/prompt.txt"
bash "$(dirname "$0")/build-prompt.sh" "$TMP/issue.json" >"$PROMPT"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "repo=$REPO root=$REPO_ROOT worktree=$WORKTREE_NAME base=$WORKTREE_BASE"
  echo "log=$LOG_FILE"
  head -20 "$PROMPT"
  exit 0
fi

gh issue edit "$ISSUE_NUMBER" --add-label "agent-running" --remove-label "agent-blocked" 2>/dev/null || true

COMMENT="🤖 Local cursor-agent dispatched for this issue.

- Mode: CLI (\`cursor-agent\` session)
- Worktree: \`${WORKTREE_NAME}\` (base \`${WORKTREE_BASE}\`)
- Log: \`${LOG_FILE}\`

Verifier must pass acceptance commands before merge."

gh issue comment "$ISSUE_NUMBER" --body "$COMMENT"

echo "Dispatching issue #$ISSUE_NUMBER in $REPO_ROOT (log: $LOG_FILE)"

# Resolve base ref: explicit WORKTREE_BASE, else origin/HEAD, else main/master.
WORKTREE_BASE_REF="$WORKTREE_BASE"
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  if [ "$WORKTREE_BASE" = "main" ] || [ -z "${WORKTREE_BASE_SET:-}" ]; then
    default_remote="$(git -C "$REPO_ROOT" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [ -n "$default_remote" ]; then
      WORKTREE_BASE="${default_remote#origin/}"
    elif git -C "$REPO_ROOT" show-ref --verify --quiet refs/remotes/origin/master; then
      WORKTREE_BASE="master"
    elif git -C "$REPO_ROOT" show-ref --verify --quiet refs/remotes/origin/main; then
      WORKTREE_BASE="main"
    fi
  fi
  if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$WORKTREE_BASE"; then
    # Best-effort refresh; don't hang the dispatcher on flaky network.
    GIT_TERMINAL_PROMPT=0 git -C "$REPO_ROOT" -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 \
      fetch origin "$WORKTREE_BASE" --quiet 2>/dev/null || true
  fi
  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$WORKTREE_BASE"; then
    WORKTREE_BASE_REF="origin/$WORKTREE_BASE"
  elif git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$WORKTREE_BASE"; then
    WORKTREE_BASE_REF="$WORKTREE_BASE"
  else
    echo "error: cannot resolve worktree base '$WORKTREE_BASE' in $REPO_ROOT" >&2
    gh issue edit "$ISSUE_NUMBER" --remove-label "agent-running" --add-label "agent-blocked" 2>/dev/null || true
    exit 1
  fi
fi
echo "Using worktree base: $WORKTREE_BASE_REF"

set +e
(
  cd "$REPO_ROOT"
  # Keep prompt outside TMP so EXIT trap cannot race stdin; write log directly.
  PROMPT_KEEP="$LOG_DIR/issue-${ISSUE_NUMBER}-${TS}.prompt.txt"
  cp "$PROMPT" "$PROMPT_KEEP"
  if [ "$USE_WORKTREE" = "1" ]; then
    "$CURSOR_AGENT_BIN" -p --force --trust \
      --worktree "$WORKTREE_NAME" \
      --worktree-base "$WORKTREE_BASE_REF" \
      --output-format text \
      <"$PROMPT_KEEP" \
      >"$LOG_FILE" 2>&1
  else
    git checkout -B "$WORKTREE_NAME" "$WORKTREE_BASE" 2>/dev/null || git checkout "$WORKTREE_NAME" 2>/dev/null
    "$CURSOR_AGENT_BIN" -p --force --trust \
      --output-format text \
      <"$PROMPT_KEEP" \
      >"$LOG_FILE" 2>&1
  fi
)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  gh issue edit "$ISSUE_NUMBER" --remove-label "agent-running" --add-label "agent-done" 2>/dev/null || true
  FINALIZE_NOTE=""
  if [ "${AUTO_FINALIZE_MAIN:-0}" = "1" ]; then
    if bash "$(dirname "$0")/finalize-to-main.sh" --issue "$ISSUE_NUMBER"; then
      FINALIZE_NOTE=$'\n\nMerged to `main` and primary checkout is on `main`.'
    else
      FINALIZE_NOTE=$'\n\n⚠️ finalize-to-main failed — merge manually, then `git checkout main`.'
    fi
  fi
  gh issue comment "$ISSUE_NUMBER" --body "$(cat <<EOF
✅ Local cursor-agent finished (exit 0). Check worktree \`${WORKTREE_NAME}\` and open PR if not auto-created.

Next: merge into \`main\`, then return to \`main\`:
\`\`\`bash
bash scripts/agent-delivery/finalize-to-main.sh --issue ${ISSUE_NUMBER}
\`\`\`
Or set \`AUTO_FINALIZE_MAIN=1\` on dispatch to run this automatically.${FINALIZE_NOTE}
EOF
)"
else
  gh issue edit "$ISSUE_NUMBER" --remove-label "agent-running" --add-label "agent-blocked" 2>/dev/null || true
  gh issue comment "$ISSUE_NUMBER" --body "$(cat <<EOF
❌ Local cursor-agent failed (exit $exit_code). See log: \`${LOG_FILE}\`
EOF
)"
  exit "$exit_code"
fi
