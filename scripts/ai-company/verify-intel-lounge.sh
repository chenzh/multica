#!/usr/bin/env bash
# Smoke checks for 产品情报站 (35-product-intel-lounge).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IDS_FILE="${INTEL_LOUNGE_IDS:-$HOME/.multica/intel-lounge.json}"
FEISHU_STATE="${INTEL_FEISHU_STATE:-$HOME/.multica/intel-lounge-feishu.json}"
WEBHOOK_FILE="${INTEL_FEISHU_WEBHOOK_FILE:-$HOME/.multica/intel-lounge-feishu-webhook.url}"
POST_SCRIPT="$MULTICA_ROOT/scripts/ai-company/intel-lounge-post.sh"

ok=0
warn=0
fail=0

pass() { echo "  ✅ $1"; ok=$((ok + 1)); }
note() { echo "  ⚠️  $1"; warn=$((warn + 1)); }
bad() { echo "  ❌ $1"; fail=$((fail + 1)); }

echo "5. 产品情报站（35-product-intel-lounge）"

if [ ! -f "$IDS_FILE" ]; then
  bad "缺少 $IDS_FILE — bash scripts/ai-company/setup-product-intel-lounge.sh"
  printf "结果: %s 通过 · %s 警告 · %s 失败\n" "$ok" "$warn" "$fail" >&2
  exit 1
fi
pass "intel-lounge.json 存在"

python3 - "$IDS_FILE" <<'PY' || bad "intel-lounge.json 结构不完整"
import json, sys
data = json.load(open(sys.argv[1]))
agents = data.get("agents") or {}
autopilots = data.get("autopilots") or {}
for name in ("intel-scout", "product-analyst", "intel-moderator"):
    assert agents.get(name), f"missing agent {name}"
for title in ("每日产品热点扫描", "热点产品解读", "本周情报周报"):
    assert autopilots.get(title), f"missing autopilot {title}"
PY
if [ "$fail" -eq 0 ]; then
  pass "4 agents + 3 autopilots 已登记"
fi

if [ -f "$FEISHU_STATE" ]; then
  chat_id="$(python3 -c "import json; print(json.load(open('$FEISHU_STATE')).get('chat_id',''))" 2>/dev/null || true)"
  if [ -n "$chat_id" ]; then
    pass "飞书群 chat_id=$chat_id"
  else
    bad "intel-lounge-feishu.json 无 chat_id — setup-intel-feishu.sh"
  fi
else
  note "未建飞书群状态 — bash scripts/ai-company/setup-intel-feishu.sh"
fi

if [ -x "$POST_SCRIPT" ]; then
  pass "intel-lounge-post.sh 可执行"
else
  bad "缺少 $POST_SCRIPT"
fi

if command -v multica >/dev/null 2>&1; then
  scout_id="$(python3 -c "import json; print(json.load(open('$IDS_FILE'))['agents']['intel-scout'])")"
  if multica agent env get "$scout_id" 2>/dev/null | python3 -c "
import json, sys
env = json.load(sys.stdin).get('custom_env') or {}
assert env.get('INTEL_LOUNGE_POST_SCRIPT'), 'missing INTEL_LOUNGE_POST_SCRIPT'
assert env.get('INTEL_FEISHU_CHAT_ID'), 'missing INTEL_FEISHU_CHAT_ID'
"; then
    pass "intel-scout agent env 已接线（群投递）"
  else
    note "agent env 未接线 — bash scripts/ai-company/setup-intel-feishu.sh --skip-group"
  fi

  ap_id="$(python3 -c "import json; print(json.load(open('$IDS_FILE'))['autopilots']['每日产品热点扫描'])")"
  if multica autopilot get "$ap_id" --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
ap = d.get('autopilot') or {}
assert ap.get('status') == 'active'
triggers = d.get('triggers') or []
assert any(t.get('enabled') and t.get('cron_expression') == '0 9 * * 1-5' for t in triggers)
"; then
    pass "每日扫描 Autopilot active · cron 0 9 * * 1-5"
  else
    bad "每日扫描 Autopilot 未就绪"
  fi
else
  note "multica CLI 不可用 — 跳过 agent/autopilot 检查"
fi

if [ -f "$WEBHOOK_FILE" ] && [ -s "$WEBHOOK_FILE" ]; then
  pass "群 webhook 已配置（intel-lounge-feishu-webhook.url）"
else
  note "无群 webhook — 定时卡走 intel-lounge-post.sh（CEO Bot 身份）"
fi

printf "结果: %s 通过 · %s 警告 · %s 失败\n" "$ok" "$warn" "$fail" >&2
[ "$fail" -eq 0 ]
