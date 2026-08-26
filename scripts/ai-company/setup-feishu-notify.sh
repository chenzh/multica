#!/usr/bin/env bash
# Save Feishu bot webhook and send a test CEO brief notification.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$MULTICA_ROOT/.ai-company/config"
WEBHOOK_FILE="$CONFIG_DIR/feishu-webhook.url"
LOCAL_ENV="$CONFIG_DIR/local.env"
URL="${1:-}"

usage() {
  cat <<'EOF'
Usage: setup-feishu-notify.sh <webhook-url>

1. Feishu group → Settings → Bots → Add bot → Custom bot → copy webhook URL
2. Run:
   bash scripts/ai-company/setup-feishu-notify.sh 'https://open.feishu.cn/open-apis/bot/v2/hook/...'

Writes .ai-company/config/feishu-webhook.url (gitignored) and exports FEISHU_WEBHOOK_URL
from ai-company scripts. Sends a one-line test message.
EOF
}

if [ -z "$URL" ] || [ "$URL" = "-h" ] || [ "$URL" = "--help" ]; then
  usage
  exit 0
fi

case "$URL" in
  https://open.feishu.cn/open-apis/bot/v2/hook/*) ;;
  *)
    echo "error: expected Feishu bot webhook URL (open.feishu.cn/.../hook/...)" >&2
    exit 1
    ;;
esac

mkdir -p "$CONFIG_DIR"
printf '%s\n' "$URL" >"$WEBHOOK_FILE"
chmod 600 "$WEBHOOK_FILE"

if [ -f "$LOCAL_ENV" ] && grep -q '^export FEISHU_WEBHOOK_URL=' "$LOCAL_ENV" 2>/dev/null; then
  :
else
  {
    echo ""
    echo "# Feishu CEO brief (also: feishu-webhook.url)"
    echo "export FEISHU_WEBHOOK_URL=$URL"
  } >>"$LOCAL_ENV"
fi

# shellcheck source=lib/source-local-env.sh
source "$SCRIPT_DIR/lib/source-local-env.sh"
# shellcheck source=lib/notify.sh
source "$SCRIPT_DIR/lib/notify.sh"

test_msg="AI 公司日报测试 — $(date '+%Y-%m-%d %H:%M') — nightly cron 已就绪"
if notify_ceo_brief "$test_msg"; then
  echo "ok: test message sent to Feishu"
else
  echo "error: notify failed (check webhook URL and network)" >&2
  exit 1
fi

echo "Saved: $WEBHOOK_FILE"
echo "Nightly: bash scripts/ai-company/ceo-nightly.sh"
