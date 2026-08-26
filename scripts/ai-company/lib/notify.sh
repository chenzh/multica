#!/usr/bin/env bash
# Push a plain-text CEO brief to Slack or Feishu webhook (optional).
set -euo pipefail

send_slack() {
  local text="$1"
  local webhook="${SLACK_WEBHOOK_URL:-}"
  [ -n "$webhook" ] || return 0
  python3 - "$webhook" "$text" <<'PY'
import json
import sys
import urllib.request

webhook, text = sys.argv[1], sys.argv[2]
body = json.dumps({"text": text}).encode("utf-8")
req = urllib.request.Request(
    webhook,
    data=body,
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=30) as resp:
    resp.read()
PY
}

send_feishu() {
  local text="$1"
  local webhook="${FEISHU_WEBHOOK_URL:-}"
  [ -n "$webhook" ] || return 0
  python3 - "$webhook" "$text" <<'PY'
import json
import sys
import urllib.request

webhook, text = sys.argv[1], sys.argv[2]
body = json.dumps(
    {"msg_type": "text", "content": {"text": text}}
).encode("utf-8")
# Feishu API is domestic; bypass HTTP proxy if set.
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
req = urllib.request.Request(
    webhook,
    data=body,
    headers={"Content-Type": "application/json"},
    method="POST",
)
with opener.open(req, timeout=30) as resp:
    resp.read()
PY
}

notify_ceo_brief() {
  local text="${1:?}"
  local errors=0
  if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    send_slack "$text" || errors=$((errors + 1))
  fi
  if [ -n "${FEISHU_WEBHOOK_URL:-}" ]; then
    send_feishu "$text" || errors=$((errors + 1))
  fi
  return "$errors"
}
