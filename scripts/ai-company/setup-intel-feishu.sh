#!/usr/bin/env bash
# Feishu ops for 产品情报站: lark-cli group + Multica agent bind QR URLs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${INTEL_FEISHU_STATE:-$HOME/.multica/intel-lounge-feishu.json}"
WEBHOOK_FILE="${INTEL_FEISHU_WEBHOOK_FILE:-$HOME/.multica/intel-lounge-feishu-webhook.url}"
IDS_FILE="${INTEL_LOUNGE_IDS:-$HOME/.multica/intel-lounge.json}"
API="${MULTICA_API_URL:-http://localhost:8081}"
WSID="${MULTICA_WORKSPACE_ID:-98f1c3f7-fc74-4ef5-8ea2-f4a5c7f395ab}"
GROUP_NAME="${INTEL_FEISHU_GROUP_NAME:-产品情报站}"
WEBHOOK_URL="${INTEL_FEISHU_WEBHOOK_URL:-}"
DRY_RUN=0
OPEN_QR=0
SKIP_GROUP=0
SKIP_WEBHOOK=0

usage() {
  cat <<'EOF'
Usage: setup-intel-feishu.sh [options]

Requires: lark-cli (npm i -g @larksuite/cli), multica login, feishu-bot-notify.env

Steps:
  1. Configure lark-cli from .ai-company/config/feishu-bot-notify.env (CEO notify bot)
  2. Create Feishu group (or reuse from state file)
  3. Post pinned group rules
  4. Print Multica Lark bind QR URLs for intel-scout / product-analyst / intel-moderator
  5. Optional: wire group webhook into agent env (proactive 09:00/14:00 cards)

Options:
  --dry-run         Print actions only
  --open-qr         macOS: open each bind URL in browser
  --skip-group      Only print Multica bind URLs
  --webhook-url U   Group custom-bot webhook (or save to $WEBHOOK_FILE)
  --skip-webhook    Do not set agent env even if webhook file exists
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --open-qr) OPEN_QR=1 ;;
    --skip-group) SKIP_GROUP=1 ;;
    --skip-webhook) SKIP_WEBHOOK=1 ;;
    --webhook-url)
      shift
      WEBHOOK_URL="${1:-}"
      [ -n "$WEBHOOK_URL" ] || { echo "error: --webhook-url requires a URL" >&2; exit 1; }
      shift
      continue
      ;;
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

resolve_webhook_url() {
  if [ -n "$WEBHOOK_URL" ]; then
    echo "$WEBHOOK_URL"
    return
  fi
  if [ -f "$WEBHOOK_FILE" ]; then
    sed -n '1p' "$WEBHOOK_FILE" | tr -d '[:space:]'
  fi
}

save_webhook_url() {
  local url="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] save webhook to $WEBHOOK_FILE"
    return
  fi
  mkdir -p "$(dirname "$WEBHOOK_FILE")"
  printf '%s\n' "$url" >"$WEBHOOK_FILE"
  chmod 600 "$WEBHOOK_FILE"
  log "saved webhook to $WEBHOOK_FILE"
}

wire_agent_group_env() {
  [ -f "$IDS_FILE" ] || { log "skip agent env: $IDS_FILE missing (run setup-product-intel-lounge.sh)"; return; }

  local webhook chat_id post_script
  webhook=""
  if [ "$SKIP_WEBHOOK" -eq 0 ]; then
    webhook="$(resolve_webhook_url)"
  fi
  chat_id=""
  if [ -f "$STATE_FILE" ]; then
    chat_id="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('chat_id',''))" 2>/dev/null || true)"
  fi
  post_script="$MULTICA_ROOT/scripts/ai-company/intel-lounge-post.sh"

  if [ -n "$webhook" ]; then
    if [[ "$webhook" != https://open.feishu.cn/* ]] && [[ "$webhook" != https://open.larksuite.com/* ]]; then
      echo "error: webhook must be a Feishu open-apis hook URL" >&2
      exit 1
    fi
    if [ -n "$WEBHOOK_URL" ]; then
      save_webhook_url "$webhook"
    fi
  else
    log "no group webhook — agents will use intel-lounge-post.sh (CEO notify bot → group)"
    log "optional: add custom bot webhook → rerun with --webhook-url"
  fi

  local env_json
  env_json="$(python3 - "$webhook" "$chat_id" "$post_script" <<'PY'
import json, sys
webhook, chat_id, post_script = sys.argv[1], sys.argv[2], sys.argv[3]
env = {"INTEL_LOUNGE_POST_SCRIPT": post_script}
if chat_id:
    env["INTEL_FEISHU_CHAT_ID"] = chat_id
if webhook:
    env["FEISHU_WEBHOOK_URL"] = webhook
print(json.dumps(env, ensure_ascii=False))
PY
)"
  while IFS=$'\t' read -r role aid; do
    [ -n "$aid" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] multica agent env set $role ($aid)"
      continue
    fi
    multica agent env set "$aid" --custom-env "$env_json" >/dev/null
    log "agent env wired: $role ($aid)"
  done < <(agent_ids)
}

sync_agent_instructions() {
  local tpl="$MULTICA_ROOT/.ai-company/templates/intel-lounge/agents"
  while IFS=$'\t' read -r role aid; do
    [ -n "$aid" ] || continue
    local file="$tpl/$role.md"
    [ -f "$file" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] multica agent update instructions $role"
      continue
    fi
    multica agent update "$aid" --instructions "$(cat "$file")" >/dev/null
    log "agent instructions synced: $role"
  done < <(agent_ids)
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
  wire_agent_group_env
  sync_agent_instructions
  if [ -f "$STATE_FILE" ]; then
    log "group state: $STATE_FILE"
    python3 -m json.tool "$STATE_FILE" >&2
  fi
  cat <<'EOF'

下一步（CEO）：
1. 用手机飞书扫上面 3 个链接，分别绑定 intel-scout / product-analyst / intel-moderator
2. 在开放平台把 3 个新 Bot 拉进「产品情报站」群
3. （推荐）群设置 → 群机器人 → 自定义机器人 → 复制 webhook：
   bash scripts/ai-company/setup-intel-feishu.sh --skip-group --webhook-url 'https://open.feishu.cn/open-apis/bot/v2/hook/...'
   未配 webhook 时，Agent 会用 intel-lounge-post.sh 经 CEO Bot 发到群
4. 群里 @intel-moderator 忽略 — 测主持 Bot（绑定完成后）

EOF
}

main "$@"
