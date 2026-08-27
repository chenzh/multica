#!/usr/bin/env bash
# Guide user to copy Verification Token into feishu-approval.env (not available via API).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT="$MULTICA_ROOT/.ai-company/config/feishu-approval.env"
EXAMPLE="$MULTICA_ROOT/.ai-company/config/feishu-approval.env.example"

# shellcheck source=lib/source-local-env.sh
source "$SCRIPT_DIR/lib/source-local-env.sh"

APP_ID="${FEISHU_BOT_APP_ID:-}"

echo "=== 飞书 Verification Token 配置 ==="
echo ""
echo "Verification Token 只能在开放平台控制台查看，API 无法读取。"
echo ""
if [ -n "$APP_ID" ]; then
  echo "1. 打开: https://open.feishu.cn/app/${APP_ID}/event"
  echo "   （开发配置 → 事件与回调 → 加密策略 → Verification Token）"
else
  echo "1. 打开飞书开放平台 → 你的 Bot 应用 → 事件与回调 → 加密策略"
fi
echo ""
echo "2. 复制 Verification Token，写入:"
echo "   $OUT"
echo ""
if [ -f "$OUT" ]; then
  if grep -q 'YOUR_FEISHU_VERIFICATION_TOKEN' "$OUT" 2>/dev/null; then
    echo "   ⚠️  $OUT 存在但仍是占位符"
  else
    echo "   ✅ $OUT 已存在"
    bash "$SCRIPT_DIR/ceo-feishu-approval-service.sh" install
    bash "$SCRIPT_DIR/print-feishu-inbound-setup.sh"
    exit 0
  fi
else
  cp "$EXAMPLE" "$OUT"
  echo "   已创建 $OUT — 请编辑填入 token"
fi
echo ""
echo "3. 保存后运行:"
echo "   bash $SCRIPT_DIR/ceo-feishu-approval-service.sh install"
echo "   bash $SCRIPT_DIR/print-feishu-inbound-setup.sh"
