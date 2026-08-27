#!/usr/bin/env bash
# Source machine-local AI company env (optional).
set -euo pipefail

MULTICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOCAL_ENV="$MULTICA_ROOT/.ai-company/config/local.env"
PROXY_ENV="$MULTICA_ROOT/.ai-company/config/proxy.env"

if [ -f "$PROXY_ENV" ]; then
  # shellcheck disable=SC1090
  source "$PROXY_ENV"
  if [ -n "${https_proxy:-}" ]; then
    proxy_host_port="${https_proxy#*://}"
    proxy_host="${proxy_host_port%%:*}"
    proxy_port="${proxy_host_port##*:}"
    if ! curl -fsS --connect-timeout 1 "http://${proxy_host}:${proxy_port}/" >/dev/null 2>&1; then
      unset https_proxy http_proxy all_proxy
    fi
  fi
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

FEISHU_BOT_NOTIFY_ENV="$MULTICA_ROOT/.ai-company/config/feishu-bot-notify.env"
if [ -f "$FEISHU_BOT_NOTIFY_ENV" ]; then
  # shellcheck disable=SC1090
  source "$FEISHU_BOT_NOTIFY_ENV"
fi

FEISHU_APPROVAL_ENV="$MULTICA_ROOT/.ai-company/config/feishu-approval.env"
if [ -f "$FEISHU_APPROVAL_ENV" ]; then
  # shellcheck disable=SC1090
  source "$FEISHU_APPROVAL_ENV"
fi

SECOND_BRAIN_FEISHU="${SECOND_BRAIN_FEISHU_JSON:-$HOME/Documents/SecondBrain/10-SYSTEM/control-plane-tunnel/feishu.local.json}"
if [ -z "${FEISHU_WEBHOOK_URL:-}" ] && [ -f "$SECOND_BRAIN_FEISHU" ]; then
  FEISHU_WEBHOOK_URL="$(
    python3 - "$SECOND_BRAIN_FEISHU" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    url = str(json.loads(path.read_text(encoding="utf-8")).get("webhookUrl", "")).strip()
except (OSError, json.JSONDecodeError, AttributeError):
    url = ""
if url and "YOUR_TOKEN" not in url:
    print(url)
PY
  )"
  [ -n "$FEISHU_WEBHOOK_URL" ] && export FEISHU_WEBHOOK_URL
fi
