#!/usr/bin/env bash
# Source machine-local AI company env (optional).
set -euo pipefail

MULTICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOCAL_ENV="$MULTICA_ROOT/.ai-company/config/local.env"
PROXY_ENV="$MULTICA_ROOT/.ai-company/config/proxy.env"

if [ -f "$PROXY_ENV" ]; then
  # shellcheck disable=SC1090
  source "$PROXY_ENV"
fi

if [ -f "$LOCAL_ENV" ]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi

WEBHOOK_FILE="$MULTICA_ROOT/.ai-company/config/feishu-webhook.url"
if [ -z "${FEISHU_WEBHOOK_URL:-}" ] && [ -f "$WEBHOOK_FILE" ]; then
  FEISHU_WEBHOOK_URL="$(sed -n '1p' "$WEBHOOK_FILE" | tr -d '[:space:]')"
  export FEISHU_WEBHOOK_URL
fi
