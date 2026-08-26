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
| 派单方式 | ✅ 本地 CLI | `cursor-agent` 已登录，**无需 `CURSOR_API_KEY`** |
| `saas-stripe-mvp` 仓库 | ✅ | `chenzh/saas-stripe-mvp`，issues #1–#4 |
| `local.env` | ✅ | `.ai-company/config/local.env` |

## 派单（本地 cursor-agent）

```bash
# 派 beatscape 一单
GITHUB_REPOSITORY=chenzh/MusicSaas \
REPO_ROOT=/Users/zhenhuachen/Desktop/MusicSaas \
bash ~/Projects/multica/scripts/agent-delivery/dispatch-cursor-agent-cli.sh <issue#>

# portfolio 本地批量派单
bash ~/Projects/multica/scripts/ai-company/portfolio-dispatch.sh --local --max-total 1

# CEO 仪表盘（自动 --local）
bash ~/Projects/multica/scripts/ai-company/ceo-dashboard.sh --dispatch
```

> GHA 云端派单（`agent-delivery-dispatch.yml`）需各仓 `CURSOR_API_KEY`；当前不走此路径。

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
- MusicSaas 本地 WIP：`preview/beatscape-try` 上 `git stash pop`（stash: `wip-all`）
