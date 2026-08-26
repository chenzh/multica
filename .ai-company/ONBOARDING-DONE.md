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

## 队列现状（2026-08-26 晚）

- **beatscape**: agent-safe 队列已清空（B01–B04 已交付）
- **landing-tool-a**: `~/Projects/landing-tool-a`，4 条 agent-safe + 1 running
- **saas-stripe-mvp**: `~/Projects/saas-stripe-mvp`，4 条 agent-safe
- **music-game-sea**: paused

## Git：只推 fork，别推 origin

本机 `main` 跟踪 **`fork/main`**（`chenzh/multica`）。推上游 `multica-ai/multica` 会 **403**。

```bash
# 推荐
bash scripts/ai-company/push-fork.sh

# 或
git push fork main
```

`origin` 仅用于拉上游更新：`git fetch origin`。

## 还差一步（webhook）

```bash
bash scripts/ai-company/setup-feishu-notify.sh 'https://open.feishu.cn/open-apis/bot/v2/hook/你的token'
```

飞书群 → 设置 → 群机器人 → 自定义机器人 → 复制 webhook URL。

## 可选后续

- MusicSaas 本地 WIP：`preview/beatscape-try` 上 `git stash pop`（stash: `wip-all`）
