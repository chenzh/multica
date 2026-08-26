# Acceptance Cases — <project-slug>

<!-- Verifier 按此执行；exit code 必须 0。CEO 交付前勾选。 -->

## Verification commands

最低栏（按项目裁剪）：

```bash
# 示例 — 替换为本项目真实命令
pnpm test --filter <package>
make test
# PR 前全量（env 允许时）：
make check
```

## Functional criteria

- [ ] AC-1: 
- [ ] AC-2: 
- [ ] AC-3: 

## Non-functional（若适用）

- [ ] 无新增 lint error
- [ ] OpenAPI lint 通过（`vacuum lint api/openapi.yaml`）
- [ ] 无 breaking API change（`oasdiff`）
- [ ] E2E smoke: （列 Playwright 用例名或路径）

## Evidence（Verifier 填写）

| Command | Exit code | Last run (UTC) |
|---------|-----------|----------------|
| | | |

## CEO sign-off

- [ ] 我已对照上述条目验收（可抽检 CI + AC，不必读全 diff）

签名 / 日期：
