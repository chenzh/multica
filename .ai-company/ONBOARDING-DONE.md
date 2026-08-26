# AI 公司上线清单 — 已完成项（2026-08-26）

## 已落地

| 项 | 状态 | 证据 |
| --- | --- | --- |
| `.ai-company/` 文档 + 模板 + runbook | ✅ | `multica/.ai-company/` |
| Harness 安装脚本 | ✅ | `.ai-company/harness/install.sh` |
| `scripts/ai-company/*` | ✅ | ceo-dashboard、portfolio-dispatch、sync-backlog |
| **beatscape** 注册表 | ✅ | `.ai-company/templates/project-registry.yaml` → `chenzh/MusicSaas` |
| MusicSaas harness 已 push `main` | ✅ | commit `baa6520` |
| GitHub Issues B01–B04 | ✅ | #6 #8 #9 #11（#7 #10 已关重复） |
| `~/Projects/MusicSaas` 重复副本 | ✅ 已删 | — |
| CEO 仪表盘 | ✅ | `bash scripts/ai-company/ceo-dashboard.sh` |
| 首次 dispatch 已触发 | ✅ | [run 32928101929](https://github.com/chenzh/MusicSaas/actions/runs/32928101929) |
| `local.env` | ✅ | `.ai-company/config/local.env` |
| `saas-stripe-mvp` 仓库 | ✅ | `chenzh/saas-stripe-mvp`，issues #1–#4 |
| multica harness 分支 | ✅ push 待合并 | `feat/ai-company-os` → `multica-ai/multica` |

## 仍需你手动完成（约 5 分钟）

### 1. GitHub Secrets — `CURSOR_API_KEY`

在 **每个** 要跑 agent 的仓库设置：

```bash
gh secret set CURSOR_API_KEY -R chenzh/MusicSaas
gh secret set CURSOR_API_KEY -R chenzh/landing-tool-a
```

值来自 [Cursor Dashboard → Integrations → User API Keys](https://cursor.com/settings)。

### 2. 跨仓 portfolio dispatch（可选，睡后自动派单）

在 **multica** 仓库：

```bash
gh secret set PORTFOLIO_GH_TOKEN -R chenzh/multica
# 使用有 repo/workflow 权限的 PAT 或 GitHub App token
```

然后启用 cron：`portfolio-agent-dispatch.yml`（已存在于 multica）。

### 3. 睡后派单

```bash
cd ~/Projects/multica
bash scripts/ai-company/ceo-dashboard.sh --dispatch
# 或
bash scripts/ai-company/portfolio-dispatch.sh --max-total 3
```

### 4. MusicSaas 本地 WIP

你在 `preview/beatscape-try` 上的未提交改动已 `git stash`（`wip-all`）。恢复：

```bash
cd ~/Desktop/MusicSaas
git checkout preview/beatscape-try
git stash pop
```

## 日常 CEO 命令

```bash
# 一眼看全组合
bash scripts/ai-company/ceo-dashboard.sh

# 手动派 1 单 beatscape
gh workflow run agent-delivery-dispatch.yml -R chenzh/MusicSaas -f max_tasks=1
```

## 队列现状（首次仪表盘）

- **beatscape**: 3 单 agent-safe 在队
- **landing-tool-a**: 4 单
- **music-game-sea**: paused（6 单在队但不派）
