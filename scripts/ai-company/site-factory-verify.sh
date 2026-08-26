#!/usr/bin/env bash
# Verify site-factory prerequisites and smoke-test Cloudflare scaffold (no agent quota).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib/site-factory-runtime.sh
source "$SCRIPT_DIR/lib/site-factory-runtime.sh"

ok=0
warn=0
fail=0

pass() { echo "  ✅ $1"; ok=$((ok + 1)); }
note() { echo "  ⚠️  $1"; warn=$((warn + 1)); }
bad() { echo "  ❌ $1"; fail=$((fail + 1)); }

echo "Site Factory 验收 — $(date '+%Y-%m-%d %H:%M')"
echo ""

echo "1. 脚本与模板"
for f in site-factory.sh scaffold-cloudflare.sh lib/site-factory-runtime.sh; do
  if [ -x "$SCRIPT_DIR/$f" ] || [ -f "$SCRIPT_DIR/$f" ]; then
    pass "$f"
  else
    bad "missing $f"
  fi
done
if [ -f "$MULTICA_ROOT/.ai-company/templates/site-factory/research-prompt.md" ]; then
  pass "research/mvp 模板"
else
  bad "site-factory 模板缺失"
fi

echo ""
echo "2. 解析 / dry-run"
if bash "$SCRIPT_DIR/site-factory.sh" --intake "做一个 JSON 格式化网站" --dry-run >/tmp/site-factory-dry-run.log 2>&1; then
  pass "site-factory --dry-run"
  grep -q 'slug:.*json-site' /tmp/site-factory-dry-run.log && pass "slug 解析 json-site" || note "slug 解析非常规"
else
  bad "site-factory --dry-run 失败"
fi

echo ""
echo "3. Multica 运行服务（部分能力由运行中的 self-host + daemon 提供）"
api="$(site_factory_multica_api)"
api="${api:-${MULTICA_SERVER_URL:-http://localhost:8081}}"
if site_factory_runtime_ready "$api"; then
  pass "Multica API ready ($api)"
else
  note "Multica API 未就绪 — bash scripts/local-selfhost-autostart.sh 或 make selfhost"
fi
if site_factory_daemon_running; then
  pass "multica daemon running"
else
  note "daemon 未运行 — multica daemon start"
fi
slots="$(site_factory_dispatch_slots 2)"
pass "dispatch slots (max 2): $slots"

echo ""
echo "4. Cloudflare 脚手架 smoke"
SMOKE="$(mktemp -d)/cf-smoke"
if bash "$SCRIPT_DIR/scaffold-cloudflare.sh" "$SMOKE" cf-smoke "Smoke" >>/tmp/site-factory-scaffold.log 2>&1; then
  pass "scaffold-cloudflare.sh"
else
  bad "scaffold 失败 — /tmp/site-factory-scaffold.log"
fi
if [ -f "$SMOKE/wrangler.toml" ] && [ -f "$SMOKE/.github/workflows/cloudflare-pages-check.yml" ]; then
  pass "wrangler.toml + Pages CI workflow"
else
  bad "CF 产物不完整"
fi
if (cd "$SMOKE" && pnpm install >>/tmp/site-factory-pnpm.log 2>&1 && make check >>/tmp/site-factory-check.log 2>&1); then
  pass "pnpm install + make check"
else
  bad "make check 失败 — /tmp/site-factory-check.log"
fi

echo ""
echo "5. 飞书桥接"
if [ -f "$HOME/Projects/feishu-cursor-claw/server.ts" ] && grep -q matchSiteFactoryIntent "$HOME/Projects/feishu-cursor-claw/server.ts"; then
  pass "feishu-cursor-claw 建站意图已接线"
else
  note "feishu-cursor-claw 未更新或未安装"
fi

echo ""
echo "6. CEO 工作台 API"
if curl -fsS --max-time 2 "http://127.0.0.1:9477/api/site-factory" >/dev/null 2>&1; then
  pass "workbench /api/site-factory 在线"
else
  note "workbench 未运行 — bash scripts/ai-company/ceo-workbench.sh"
fi

echo ""
printf "结果: %s 通过 · %s 警告 · %s 失败\n" "$ok" "$warn" "$fail"
rm -rf "$(dirname "$SMOKE")" 2>/dev/null || true
[ "$fail" -eq 0 ]
