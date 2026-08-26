#!/usr/bin/env bash
# Dispatch one issue via local cursor-agent CLI (session auth — no CURSOR_API_KEY).
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

if [ -z "$REPO" ]; then
  REPO="$(gh repo view "$REPO_ROOT" --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "$REPO" ]; then
  echo "error: set GITHUB_REPOSITORY or run inside a gh-linked repo" >&2
  exit 1
fi

if ! command -v "$CURSOR_AGENT_BIN" &>/dev/null; then
  echo "error: $CURSOR_AGENT_BIN not found on PATH" >&2
  exit 1
fi

if ! "$CURSOR_AGENT_BIN" status &>/dev/null; then
  echo "error: cursor-agent not logged in — run: cursor-agent login" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/issue-${ISSUE_NUMBER}-${TS}.log"

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

WORKTREE_BASE_REF="$WORKTREE_BASE"
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  git -C "$REPO_ROOT" fetch origin "$WORKTREE_BASE" --quiet 2>/dev/null || true
  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$WORKTREE_BASE"; then
    WORKTREE_BASE_REF="origin/$WORKTREE_BASE"
  fi
fi

set +e
(
  cd "$REPO_ROOT"
  if [ "$USE_WORKTREE" = "1" ]; then
    cat "$PROMPT" | "$CURSOR_AGENT_BIN" -p --force --trust \
      --worktree "$WORKTREE_NAME" \
      --worktree-base "$WORKTREE_BASE_REF" \
      --output-format stream-json \
      2>&1 | tee "$LOG_FILE"
  else
    git checkout -B "$WORKTREE_NAME" "$WORKTREE_BASE" 2>/dev/null || git checkout "$WORKTREE_NAME" 2>/dev/null
    cat "$PROMPT" | "$CURSOR_AGENT_BIN" -p --force --trust \
      --output-format stream-json \
      2>&1 | tee "$LOG_FILE"
  fi
)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  gh issue edit "$ISSUE_NUMBER" --remove-label "agent-running" --add-label "agent-done" 2>/dev/null || true
  gh issue comment "$ISSUE_NUMBER" --body "$(cat <<EOF
✅ Local cursor-agent finished (exit 0). Check worktree \`${WORKTREE_NAME}\` and open PR if not auto-created.
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
