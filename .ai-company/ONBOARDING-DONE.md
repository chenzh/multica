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
| 首次 dispatch（本地 CLI） | ✅ | PR [#12](https://github.com/chenzh/MusicSaas/pull/12) [#13](https://github.com/chenzh/MusicSaas/pull/13) [#14](https://github.com/chenzh/MusicSaas/pull/14) 已 merge |
| `PORTFOLIO_GH_TOKEN` | ✅ | `chenzh/multica` Secrets |
| `portfolio-agent-dispatch.yml` | ✅ | `chenzh/multica` main，cron + manual |
| multica harness fork | ✅ | `chenzh/multica` PR #1 #2 已合并 |
| CEO 浏览器工作台 | ✅ | `scripts/ai-company/ceo-workbench.sh` → http://127.0.0.1:9477 |
| 每晚 21:00 派单 + 日报 | ✅ | `ceo-nightly.sh` + `install-nightly-cron.sh --install` |
| 本机路径解析 | ✅ | `resolve-repo-path.sh` + `local.env`（registry 不写路径） |
| 派单方式 | ✅ 本地 CLI | `cursor-agent` 已登录，**无需 `CURSOR_API_KEY`** |
| `saas-stripe-mvp` 仓库 | ✅ | `chenzh/saas-stripe-mvp`，issues #1–#4 |
| `local.env` | ✅ | `.ai-company/config/local.env` |

## 派单（本地 cursor-agent）

```bash
# 浏览器工作台（推荐）
bash ~/Projects/multica/scripts/ai-company/ceo-workbench.sh

# 终端仪表盘
bash ~/Projects/multica/scripts/ai-company/ceo-dashboard.sh --dispatch
```

> GHA 云端派单（`agent-delivery-dispatch.yml`）需各仓 `CURSOR_API_KEY`；当前不走此路径。

## 日常 CEO 命令

```bash
# 自动（cron 21:00）：派单 + 日报 → 飞书/Slack
bash scripts/ai-company/install-nightly-cron.sh --install

# 手动
bash ~/Projects/multica/scripts/ai-company/ceo-dashboard.sh
bash ~/Projects/multica/scripts/ai-company/ceo-dashboard.sh --dispatch
bash ~/Projects/multica/scripts/ai-company/ceo-nightly.sh --no-dispatch
```

## 队列现状

- **beatscape**: agent-safe 队列已清空（B01–B04 已交付）
- **landing-tool-a**: 有 agent 在跑；需本机 clone 或 `AI_REPO_PATH_*` 才能本地派单
- **music-game-sea**: paused
- **saas-stripe-mvp**: 需本机 clone 或 `AI_REPO_PATH_*`

## 可选后续

- Clone `landing-tool-a` / `saas-stripe-mvp` 到 `~/Projects` 或配置 `local.env` 后继续派单
- MusicSaas 本地 WIP：`preview/beatscape-try` 上 `git stash pop`（stash: `wip-all`）
