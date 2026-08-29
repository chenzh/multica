#!/usr/bin/env bash
# Feishu ops for 产品情报站: lark-cli group + Multica agent bind QR URLs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${INTEL_FEISHU_STATE:-$HOME/.multica/intel-lounge-feishu.json}"
IDS_FILE="${INTEL_LOUNGE_IDS:-$HOME/.multica/intel-lounge.json}"
API="${MULTICA_API_URL:-http://localhost:8081}"
WSID="${MULTICA_WORKSPACE_ID:-98f1c3f7-fc74-4ef5-8ea2-f4a5c7f395ab}"
GROUP_NAME="${INTEL_FEISHU_GROUP_NAME:-产品情报站}"
DRY_RUN=0
OPEN_QR=0
SKIP_GROUP=0

usage() {
  cat <<'EOF'
Usage: setup-intel-feishu.sh [options]

Requires: lark-cli (npm i -g @larksuite/cli), multica login, feishu-bot-notify.env

Steps:
  1. Configure lark-cli from .ai-company/config/feishu-bot-notify.env (CEO notify bot)
  2. Create Feishu group (or reuse from state file)
  3. Post pinned group rules
  4. Print Multica Lark bind QR URLs for intel-scout / product-analyst / intel-moderator

Options:
  --dry-run      Print actions only
  --open-qr      macOS: open each bind URL in browser
  --skip-group   Only print Multica bind URLs
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --open-qr) OPEN_QR=1 ;;
    --skip-group) SKIP_GROUP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

log() { echo "intel-feishu: $*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "error: missing $1" >&2; exit 1; }
}

load_feishu_env() {
  local env_file="$MULTICA_ROOT/.ai-company/config/feishu-bot-notify.env"
  if [ ! -f "$env_file" ]; then
    echo "error: $env_file not found — run setup-feishu-bot-notify.sh first" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$env_file"
  if [ -z "${FEISHU_BOT_APP_ID:-}" ] || [ -z "${FEISHU_BOT_APP_SECRET:-}" ]; then
    echo "error: FEISHU_BOT_APP_ID/SECRET missing in $env_file" >&2
    exit 1
  fi
}

ensure_lark_cli() {
  if ! command -v lark-cli >/dev/null 2>&1; then
    log "installing @larksuite/cli..."
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] npx @larksuite/cli@latest install"
      return
    fi
    npx @larksuite/cli@latest install
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] lark-cli config init --app-id $FEISHU_BOT_APP_ID"
    return
  fi
  if ! lark-cli config show 2>/dev/null | grep -q "\"appId\": \"$FEISHU_BOT_APP_ID\""; then
    printf '%s' "$FEISHU_BOT_APP_SECRET" | lark-cli config init \
      --app-id "$FEISHU_BOT_APP_ID" --app-secret-stdin --brand feishu
  fi
}

ensure_group() {
  if [ "$SKIP_GROUP" -eq 1 ]; then
    return
  fi
  if [ -f "$STATE_FILE" ]; then
    local existing
    existing="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('chat_id',''))" 2>/dev/null || true)"
    if [ -n "$existing" ]; then
      log "reuse group chat_id=$existing"
      return
    fi
  fi
  local ceo_open="${FEISHU_BOT_NOTIFY_OPEN_ID:-}"
  if [ -z "$ceo_open" ]; then
    echo "error: FEISHU_BOT_NOTIFY_OPEN_ID missing" >&2
    exit 1
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] lark-cli im +chat-create --name $GROUP_NAME"
    return
  fi
  local out
  out="$(lark-cli im +chat-create --as bot \
    --name "$GROUP_NAME" \
    --description "Multica 产品情报站" \
    --type private \
    --users "$ceo_open" \
    --set-bot-manager)"
  python3 - "$STATE_FILE" "$out" <<'PY'
import json, sys, datetime
path, raw = sys.argv[1], sys.argv[2]
data = json.loads(raw)
chat = data.get("data") or {}
state = {
    "group_name": chat.get("name") or "产品情报站",
    "chat_id": chat.get("chat_id"),
    "chat_app_link": chat.get("chat_app_link"),
    "share_link": chat.get("share_link"),
    "created_at": datetime.datetime.utcnow().isoformat() + "Z",
}
with open(path, "w") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
print(state["chat_id"])
PY
}

post_group_rules() {
  if [ "$SKIP_GROUP" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
    return
  fi
  local chat_id
  chat_id="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('chat_id',''))")"
  [ -n "$chat_id" ] || return
  local pin="$MULTICA_ROOT/.ai-company/templates/intel-lounge/feishu-group-pin.txt"
  lark-cli im +messages-send --as bot --chat-id "$chat_id" --text "$(cat "$pin")" >/dev/null
  log "posted group rules to $chat_id"
}

multica_token() {
  python3 -c "import json; print(json.load(open('$HOME/.multica/config.json'))['token'])"
}

agent_ids() {
  python3 - "$IDS_FILE" <<'PY'
import json, sys
ids = json.load(open(sys.argv[1])).get("agents", {})
for role in ("intel-scout", "product-analyst", "intel-moderator"):
    if role in ids:
        print(f"{role}\t{ids[role]}")
PY
}

print_bind_qrs() {
  require_cmd curl
  local pat token
  token="$(multica_token)"
  log "Multica Lark bind — scan each URL in Feishu mobile (creates one bot per agent):"
  while IFS=$'\t' read -r role aid; do
    [ -n "$aid" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] begin lark install agent=$role ($aid)"
      continue
    fi
    local resp
    resp="$(curl -fsS -X POST \
      "$API/api/workspaces/$WSID/lark/install/begin?agent_id=$aid&region=feishu" \
      -H "Authorization: Bearer $token" \
      -H "X-Workspace-Slug: local" \
      -H "X-Workspace-ID: $WSID")"
    python3 - "$role" "$resp" "$OPEN_QR" <<'PY'
import json, sys, subprocess
role, data, open_qr = sys.argv[1], json.loads(sys.argv[2]), sys.argv[3] == "1"
url = data.get("qr_code_url", "")
code = ""
if "user_code=" in url:
    code = url.split("user_code=")[-1]
print(f"\n=== {role} ===")
print(f"user_code: {code}")
print(url)
if open_qr and url:
    subprocess.run(["open", url], check=False)
PY
  done < <(agent_ids)
}

main() {
  require_cmd multica
  require_cmd python3
  load_feishu_env
  ensure_lark_cli
  ensure_group
  post_group_rules
  print_bind_qrs
  if [ -f "$STATE_FILE" ]; then
    log "group state: $STATE_FILE"
    python3 -m json.tool "$STATE_FILE" >&2
  fi
  cat <<'EOF'

下一步（CEO）：
1. 用手机飞书扫上面 3 个链接，分别绑定 intel-scout / product-analyst / intel-moderator
2. 在开放平台把 3 个新 Bot 拉进「产品情报站」群
3. 群里回「忽略」测主持 Bot（绑定完成后）

EOF
}

main "$@"
