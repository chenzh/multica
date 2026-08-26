# AI 公司上线清单 — 已完成（2026-08-26）

## 已落地

| 项 | 状态 | 证据 |
| --- | --- | --- |
| `.ai-company/` 文档 + 模板 + runbook | ✅ | `multica/.ai-company/` |
| Harness 安装脚本 | ✅ | `.ai-company/harness/install.sh` |
| `scripts/ai-company/*` | ✅ | ceo-dashboard、portfolio-dispatch、sync-backlog |
| **beatscape** 注册表 | ✅ | `project-registry.yaml` → `chenzh/MusicSaas` |
| MusicSaas harness 已 push `main` | ✅ | commit `baa6520` |
| GitHub Issues B01–B04 | ✅ | #6 #8 #9 #11 |
| 首次 dispatch（本地 CLI） | ✅ | issue #6 → PR [#12](https://github.com/chenzh/MusicSaas/pull/12) |
| PR #12 CI 全绿 | ✅ | evaluate / unit / build / integration |
| Issue #6 `agent-done` | ✅ | Play 页 SEO（TICKET-B01） |
| `PORTFOLIO_GH_TOKEN` | ✅ | `chenzh/multica` Secrets |
| `portfolio-agent-dispatch.yml` | ✅ | `chenzh/multica` main，cron + manual |
| multica harness fork | ✅ | `chenzh/multica` PR #1 #2 已合并 |
| 本地派单脚本 | ✅ | `dispatch-cursor-agent-cli.sh` + `--local` portfolio |
| `saas-stripe-mvp` 仓库 | ✅ | `chenzh/saas-stripe-mvp`，issues #1–#4 |
| `local.env` | ✅ | `.ai-company/config/local.env` |

## 派单方式（二选一）

### A. 本地 CLI（推荐，已验证）

```bash
# 派 beatscape 一单
GITHUB_REPOSITORY=chenzh/MusicSaas \
REPO_ROOT=/Users/zhenhuachen/Desktop/MusicSaas \
bash ~/Projects/multica/scripts/agent-delivery/dispatch-cursor-agent-cli.sh <issue#>

# portfolio 本地批量派单
bash ~/Projects/multica/scripts/ai-company/portfolio-dispatch.sh --local --max-total 1

# CEO 仪表盘（已登录 cursor-agent 时自动 --local）
bash ~/Projects/multica/scripts/ai-company/ceo-dashboard.sh --dispatch
```

### B. GitHub Actions 云端（需 `CURSOR_API_KEY`）

各产品仓 Secrets 尚未配置 `CURSOR_API_KEY`（GHA dispatch 会失败）。配置后：

```bash
export CURSOR_API_KEY=crsr_...
bash ~/Projects/multica/scripts/ai-company/setup-secrets.sh

# 单仓派单
gh workflow run agent-delivery-dispatch.yml -R chenzh/MusicSaas -f max_tasks=1

# 总部 portfolio 派单（需 PORTFOLIO_GH_TOKEN，已配置）
gh workflow run portfolio-agent-dispatch.yml -R chenzh/multica -f max_total=1
```

## 日常 CEO 命令

```bash
bash ~/Projects/multica/scripts/ai-company/ceo-dashboard.sh
bash ~/Projects/multica/scripts/ai-company/ceo-dashboard.sh --dispatch
```

## 队列现状

- **beatscape**: issue #6 done（PR #12 待 merge）；#8 #9 #11 仍在队
- **landing-tool-a**: 4 单 agent-safe
- **music-game-sea**: paused
- **saas-stripe-mvp**: issues #1–#4 在队

## 可选后续

- Merge [PR #12](https://github.com/chenzh/MusicSaas/pull/12)（TICKET-B01）
- 配置 `CURSOR_API_KEY` 启用无人值守 GHA 派单
- MusicSaas 本地 WIP：`preview/beatscape-try` 上 `git stash pop`（stash: `wip-all`）
