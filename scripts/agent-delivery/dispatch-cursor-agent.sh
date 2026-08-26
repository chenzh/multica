#!/usr/bin/env bash
# Dispatch one Cloud Agent for a GitHub issue. Requires CURSOR_API_KEY.
set -euo pipefail

ISSUE_NUMBER="${1:?usage: dispatch-cursor-agent.sh <issue_number>}"
REPO="${GITHUB_REPOSITORY:-multica-ai/multica}"
REPO_URL="https://github.com/${REPO}"
API_KEY="${CURSOR_API_KEY:?CURSOR_API_KEY is required}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh issue view "$ISSUE_NUMBER" --json title,body,url,number >"$TMP/issue.json"
PROMPT="$TMP/prompt.txt"
bash "$ROOT/scripts/agent-delivery/build-prompt.sh" "$TMP/issue.json" >"$PROMPT"

PAYLOAD="$TMP/payload.json"
jq -n \
  --arg text "$(cat "$PROMPT")" \
  --arg repo "$REPO_URL" \
  --argjson num "$ISSUE_NUMBER" \
  '{
    prompt: { text: $text },
    repos: [{ url: $repo, startingRef: "main" }],
    autoCreatePR: true,
    name: ("multica-issue-" + ($num | tostring))
  }' >"$PAYLOAD"

RESPONSE="$TMP/response.json"
HTTP_CODE="$(curl -sS -w '%{http_code}' -o "$RESPONSE" \
  -X POST "https://api.cursor.com/v1/agents" \
  -u "${API_KEY}:" \
  -H "Content-Type: application/json" \
  -d @"$PAYLOAD")"

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "Cursor API error HTTP $HTTP_CODE" >&2
  cat "$RESPONSE" >&2
  exit 1
fi

AGENT_ID="$(jq -r '.agent.id // .agentId // empty' "$RESPONSE")"
RUN_ID="$(jq -r '.run.id // .latestRunId // empty' "$RESPONSE")"

echo "agent_id=$AGENT_ID"
echo "run_id=$RUN_ID"
echo "agents_url=https://cursor.com/agents?id=${AGENT_ID}"

# Label issue as running
gh issue edit "$ISSUE_NUMBER" --add-label "agent-running" --remove-label "agent-blocked" 2>/dev/null || true

COMMENT="🤖 Cloud Agent dispatched for this issue.

- Agent: \`${AGENT_ID}\`
- Run: \`${RUN_ID}\`
- [Open in Cursor](https://cursor.com/agents?id=${AGENT_ID})

Verifier must pass \`make check\` (or listed acceptance commands) before merge."

gh issue comment "$ISSUE_NUMBER" --body "$COMMENT"
