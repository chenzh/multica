# Acceptance Cases — cloudflare-site

## Verification commands

```bash
pnpm typecheck
pnpm test
pnpm --filter @cloudflare-site/web build
make check
```

## Functional

- [ ] AC-1: `/` 渲染 brief 定义的核心 UI（工具或落地页）
- [ ] AC-2: 非法输入或边界情况有用户可读反馈，不白屏
- [ ] AC-3: `/privacy` `/terms` 可访问（路由或静态页）
- [ ] AC-4: `apps/web/dist` 构建成功，Wrangler/Pages 配置与 brief 栈一致

## Performance & quality

- [ ] AC-5: 首屏无阻塞级 console error（本地 `pnpm dev` 抽检）
- [ ] AC-6: Lighthouse 性能/SEO 基线可接受（CEO 抽检或 CI 占位通过）

## CEO sign-off

- [ ] AC 已勾选或抽检通过
