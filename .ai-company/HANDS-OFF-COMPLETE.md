# 脱手运行 — 完成清单（2026-08-26）

## 已自动化（无需盯盘）

| 能力 | 命令 / 证据 |
|------|-------------|
| 夜间全流程 | `ceo-nightly.sh`：reconcile → merge → reconcile → **sync backlog** → 后台派单 → 飞书日报 |
| Cron | `install-nightly-cron.sh --install` → 21:00 |
| 飞书日报 | `setup-feishu-bot-notify.sh` |
| 队列修复 | `ceo-reconcile-queue.sh`（含 PR 冲突 → BLOCKED） |
| 自动 merge | `ceo-auto-merge.sh` |
| 补票 | `sync-portfolio-backlogs.sh`（`--skip-existing`） |
| 验收 | `verify-hands-off.sh` → 应全绿 |
| Multica 并发 | `multica-runtime-status.sh`、工作台 `:9477` |
| 飞书审批（可选） | `setup-feishu-approval.sh` + `CEO_FEISHU_APPROVAL_PUSH=1` + `ceo-feishu-cloudflare-tunnel.sh quick-install` |
| 飞书 inbound 最后一步 | `setup-feishu-approval-token.sh` → `feishu-approval.env` → `print-feishu-inbound-setup.sh` |

## 一次性配置（若尚未做）

```bash
bash scripts/ai-company/verify-hands-off.sh
bash scripts/ai-company/setup-feishu-bot-notify.sh
bash scripts/ai-company/install-nightly-cron.sh --install
# 可选：飞书卡片审批
bash scripts/ai-company/setup-feishu-approval.sh --test
bash scripts/ai-company/ceo-feishu-approval-service.sh install
# 飞书开放平台 Request URL: https://<公网>/feishu/event（需内网穿透）
```

`local.env` 建议：

```bash
export CEO_NIGHTLY_DISPATCH=1
export CEO_AUTO_MERGE=1
export CEO_SYNC_BACKLOG=1
export CEO_FEISHU_APPROVAL_PUSH=1
```

## 仍需你偶尔介入的边界

- **BLOCKED** 需求澄清（或配置飞书审批卡）
- **backlog 新票**：在 `examples/<slug>/backlog.md` 加 `TICKET-007+`；nightly 会自动 `skip-existing` 同步
- **paused 项目**（如 `music-game-sea`）不会派单 — 取消 `paused` 才会消化
- **Mac 21:00 勿睡眠**（或 cron 跑在常开机器）

## 日常只看飞书

无 BLOCKED → 不回复。有 BLOCKED → 飞书回一句或点审批卡。

工作台：http://127.0.0.1:9477  
日志：`~/.multica/ceo-nightly.log`、`~/.multica/ceo-nightly-dispatch.log`
