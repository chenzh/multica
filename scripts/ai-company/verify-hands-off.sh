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
if crontab -l 2>/dev/null | grep -q multica-ai-company-nightly; then
  pass "21:00 ceo-nightly crontab 已安装"
  crontab -l 2>/dev/null | grep -A1 multica-ai-company-nightly | sed 's/^/     /'
else
  bad "未安装 cron — bash scripts/ai-company/install-nightly-cron.sh --install"
fi

echo ""
echo "3. 飞书推送"
if [ -n "${FEISHU_WEBHOOK_URL:-}" ]; then
  pass "FEISHU_WEBHOOK_URL 已配置"
else
  bad "未配置飞书 webhook — bash scripts/ai-company/setup-feishu-notify.sh '<url>'"
fi

echo ""
echo "4. 组合状态"
if bash "$SCRIPT_DIR/ceo-dashboard.sh" --json 2>/dev/null | head -4; then
  :
else
  bad "ceo-dashboard 失败"
fi

echo ""
echo "5. 试跑 nightly（不派单）"
if bash "$SCRIPT_DIR/ceo-nightly.sh" --no-dispatch >>/tmp/verify-hands-off-nightly.log 2>&1; then
  pass "ceo-nightly --no-dispatch 成功（见 /tmp/verify-hands-off-nightly.log）"
  grep -E '^(notify:|brief:)' /tmp/verify-hands-off-nightly.log 2>/dev/null | sed 's/^/     /' || true
else
  bad "ceo-nightly 失败 — 见 /tmp/verify-hands-off-nightly.log"
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
