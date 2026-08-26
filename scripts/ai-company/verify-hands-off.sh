#!/usr/bin/env bash
# Verify hands-off AI company setup (cron, proxy, dispatch, notify).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib/source-local-env.sh
source "$SCRIPT_DIR/lib/source-local-env.sh"

ok=0
warn=0
fail=0

pass() { echo "  ✅ $1"; ok=$((ok + 1)); }
note() { echo "  ⚠️  $1"; warn=$((warn + 1)); }
bad() { echo "  ❌ $1"; fail=$((fail + 1)); }

echo "AI 公司脱手验收 — $(date '+%Y-%m-%d %H:%M')"
echo ""

echo "1. 本机环境"
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  pass "gh 已登录"
else
  bad "gh 未登录 — gh auth login"
fi
if command -v cursor-agent &>/dev/null && cursor-agent status 2>&1 | grep -q "Logged in"; then
  pass "cursor-agent 已登录"
else
  bad "cursor-agent 未登录"
fi
if [ -f "$MULTICA_ROOT/.ai-company/config/proxy.env" ]; then
  pass "proxy.env 存在（GitHub 代理）"
else
  note "无 proxy.env — 国内可能 push/gh 失败"
fi

echo ""
echo "2. 夜间 cron"
if crontab -l 2>/dev/null | grep -qE 'multica-ai-company-nightly|ceo-nightly\.sh'; then
  pass "21:00 ceo-nightly crontab 已安装"
  crontab -l 2>/dev/null | grep -E 'multica-ai-company-nightly|ceo-nightly\.sh' | sed 's/^/     /'
else
  bad "未安装 cron — bash scripts/ai-company/install-nightly-cron.sh --install"
fi

echo ""
echo "3. 飞书 / 通知"
# shellcheck source=lib/notify.sh
source "$SCRIPT_DIR/lib/notify.sh"
if has_ceo_notify_channel; then
  if [ -n "${FEISHU_BOT_APP_ID:-}" ]; then
    pass "Feishu Bot 私聊已配置（feishu-bot-notify.env）"
  fi
  if [ -n "${FEISHU_WEBHOOK_URL:-}" ]; then
    pass "FEISHU_WEBHOOK_URL 已配置"
  fi
  if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    pass "SLACK_WEBHOOK_URL 已配置"
  fi
  test_msg="AI 公司验收测试 — $(date '+%H:%M')"
  if notify_ceo_brief "$test_msg"; then
    pass "通知试发成功"
  else
    bad "通知试发失败 — 检查 feishu-bot-notify.env 或 webhook"
  fi
else
  bad "未配置通知 — setup-feishu-notify.sh 或 setup-feishu-bot-notify.sh"
fi

echo ""
echo "4. 组合状态"
dashboard_json="/tmp/verify-hands-off-dashboard.json"
if bash "$SCRIPT_DIR/ceo-dashboard.sh" --json >"$dashboard_json" 2>/dev/null; then
  head -4 "$dashboard_json"
  pass "ceo-dashboard 可读"
else
  bad "ceo-dashboard 失败"
fi

echo ""
echo "4b. Multica 并发可观测"
if bash "$SCRIPT_DIR/multica-runtime-status.sh" --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('api_ok'); print('agents', len(d.get('agents',[])))"; then
  pass "multica-runtime-status API 可读"
else
  note "multica-runtime-status 不可用（Multica 未登录或 daemon 未跑）"
fi

echo ""
echo "4c. 队列 reconcile"
if bash "$SCRIPT_DIR/ceo-reconcile-queue.sh" --dry-run >>/tmp/verify-hands-off-reconcile.log 2>&1; then
  pass "ceo-reconcile-queue --dry-run 成功"
else
  bad "ceo-reconcile-queue 失败 — /tmp/verify-hands-off-reconcile.log"
fi

echo ""
echo "4d. Backlog 自动补票"
if bash "$SCRIPT_DIR/sync-portfolio-backlogs.sh" --dry-run >>/tmp/verify-hands-off-sync.log 2>&1; then
  pass "sync-portfolio-backlogs --dry-run 成功"
else
  bad "sync-portfolio-backlogs 失败 — /tmp/verify-hands-off-sync.log"
fi

echo ""
if bash "$SCRIPT_DIR/ceo-daily-brief.sh" --no-notify --quiet >>/tmp/verify-hands-off-nightly.log 2>&1; then
  pass "ceo-daily-brief --no-notify 成功（见 /tmp/verify-hands-off-nightly.log）"
  grep -E '^brief:' /tmp/verify-hands-off-nightly.log 2>/dev/null | tail -1 | sed 's/^/     /' || true
else
  bad "ceo-daily-brief 失败 — 见 /tmp/verify-hands-off-nightly.log"
fi

echo ""
echo "6. Git fork"
if git -C "$MULTICA_ROOT" rev-parse --abbrev-ref @{upstream} 2>/dev/null | grep -q 'fork/'; then
  pass "main 跟踪 fork/*"
else
  note "main 未跟踪 fork — 用 push-fork.sh"
fi

echo ""
echo "────────────────────────────"
printf "结果: %s 通过 · %s 警告 · %s 失败\n" "$ok" "$warn" "$fail"
if [ "$fail" -eq 0 ]; then
  echo "🎉 脱手链路完整 — 今晚 21:00 可睡"
  exit 0
fi
echo "修复 ❌ 项后重跑: bash scripts/ai-company/verify-hands-off.sh"
exit 1
