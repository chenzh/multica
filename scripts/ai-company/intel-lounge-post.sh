#!/usr/bin/env bash
# Post a plain-text card to the 产品情报站 Feishu group (CEO notify bot via lark-cli).
# Fallback when FEISHU_WEBHOOK_URL is not configured on the intel agents.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${INTEL_FEISHU_STATE:-$HOME/.multica/intel-lounge-feishu.json}"
PREFIX="${INTEL_LOUNGE_POST_PREFIX:-}"

usage() {
  cat <<'EOF'
Usage: intel-lounge-post.sh [--prefix LABEL] <text>

Posts to the intel lounge group chat_id from ~/.multica/intel-lounge-feishu.json.
Requires: lark-cli + .ai-company/config/feishu-bot-notify.env (CEO notify bot).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)
      shift
      PREFIX="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
  shift
done

TEXT="${*:-}"
if [ -z "$TEXT" ]; then
  if [ ! -t 0 ]; then
    TEXT="$(cat)"
  fi
fi
if [ -z "$TEXT" ]; then
  echo "error: message text required" >&2
  usage >&2
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "error: $STATE_FILE missing — run setup-intel-feishu.sh first" >&2
  exit 1
fi

CHAT_ID="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('chat_id',''))")"
if [ -z "$CHAT_ID" ]; then
  echo "error: chat_id missing in $STATE_FILE" >&2
  exit 1
fi

ENV_FILE="$MULTICA_ROOT/.ai-company/config/feishu-bot-notify.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "error: $ENV_FILE missing" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if ! command -v lark-cli >/dev/null 2>&1; then
  echo "error: lark-cli not found (npx @larksuite/cli@latest install)" >&2
  exit 1
fi

if ! lark-cli config show 2>/dev/null | grep -q "\"appId\": \"${FEISHU_BOT_APP_ID}\""; then
  printf '%s' "$FEISHU_BOT_APP_SECRET" | lark-cli config init \
    --app-id "$FEISHU_BOT_APP_ID" --app-secret-stdin --brand feishu
fi

BODY="$TEXT"
if [ -n "$PREFIX" ]; then
  BODY="[$PREFIX] $TEXT"
fi

lark-cli im +messages-send --as bot --chat-id "$CHAT_ID" --text "$BODY" >/dev/null
echo "intel-lounge-post: sent to $CHAT_ID"
