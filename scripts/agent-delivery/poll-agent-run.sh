#!/usr/bin/env bash
# Poll Cloud Agent run until terminal state or timeout.
set -euo pipefail

AGENT_ID="${1:?usage: poll-agent-run.sh <agent_id> [run_id]}"
RUN_ID="${2:-}"
API_KEY="${CURSOR_API_KEY:?CURSOR_API_KEY is required}"
TIMEOUT_SEC="${POLL_TIMEOUT_SEC:-7200}"
INTERVAL_SEC="${POLL_INTERVAL_SEC:-60}"

deadline=$((SECONDS + TIMEOUT_SEC))

if [ -z "$RUN_ID" ]; then
  RUN_ID="$(curl -sS -u "${API_KEY}:" "https://api.cursor.com/v1/agents/${AGENT_ID}" \
    | jq -r '.latestRunId // .agent.latestRunId // empty')"
fi

if [ -z "$RUN_ID" ]; then
  echo "Could not resolve run id for agent $AGENT_ID" >&2
  exit 1
fi

echo "Polling agent=$AGENT_ID run=$RUN_ID (timeout ${TIMEOUT_SEC}s)"

while [ "$SECONDS" -lt "$deadline" ]; do
  RUN="$(curl -sS -u "${API_KEY}:" "https://api.cursor.com/v1/agents/${AGENT_ID}/runs/${RUN_ID}")"
  STATUS="$(echo "$RUN" | jq -r '.status // .run.status // "unknown"')"
  echo "status=$STATUS"

  case "$STATUS" in
    completed|succeeded|success|done|finished)
      echo "$RUN" | jq .
      exit 0
      ;;
    failed|error|cancelled|canceled|blocked)
      echo "$RUN" | jq .
      exit 2
      ;;
  esac

  sleep "$INTERVAL_SEC"
done

echo "Timeout waiting for run $RUN_ID" >&2
exit 3
