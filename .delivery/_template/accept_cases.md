# Acceptance cases

<!-- 每条必须可测试。Verifier 和人都对照这份清单。 -->

## Functional

- [ ] <!-- 正常路径 -->

## Error / edge

- [ ] <!-- 参数缺失、权限、边界 -->

## Verification commands

- [ ] `pnpm typecheck` passes (if TS touched)
- [ ] `pnpm test --filter=<package>` passes (name the package)
- [ ] `make test` passes (if Go touched)
- [ ] `make check` passes before opening PR

## Max iterations

If verification still fails after **3** fix loops → mark **BLOCKED** and output `NEED_CLARIFY` or list blockers.
