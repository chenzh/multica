# 14 — Multica Autopilot 与 Portfolio 夜间调度

公司有两层夜间调度，可 **并存**：

| 层 | 机制 | 管什么 |
|----|------|--------|
| **Portfolio（公司总部）** | multica 仓 `portfolio-agent-dispatch.yml` | 按 `project-registry.yaml` 对每个 **产品 repo** 触发 `agent-delivery-dispatch` |
| **产品 repo** | 各仓 `agent-delivery-dispatch.yml` | 拉本仓 `agent-safe` Issue → Cursor Cloud Agent |
| **Multica Autopilot（可选）** | `multica autopilot` cron/webhook | 在 Multica 看板创建 Issue/任务、留 run 历史 |

```text
CEO 维护 project-registry.yaml
        ↓
portfolio-agent-dispatch (multica 仓 GHA, cron)
        ↓
gh workflow run agent-delivery-dispatch -R org/music-game-sea
gh workflow run agent-delivery-dispatch -R org/landing-tool-a
        ↓
各产品仓 Cursor Agent 执行
```

---

## A. Portfolio 调度（推荐先上）

### 1. 填台账

编辑 [templates/project-registry.yaml](../templates/project-registry.yaml)：

- `repo:` 改为真实 `github.com/YOUR_ORG/...`（脚本会自动剥前缀）
- `priority` / `max_nightly_tickets` / `paused`

### 2. 本地试跑

```bash
bash scripts/ai-company/portfolio-dispatch.sh --dry-run
bash scripts/ai-company/portfolio-dispatch.sh --max-total 3
```

### 3. 启用 multica 仓 workflow

文件：`.github/workflows/portfolio-agent-dispatch.yml`（已含 cron）

**Token 权限：** 若产品 repo 与 multica 同 org，默认 `GITHUB_TOKEN` 可能不够跨 repo 调 workflow。建议：

- 建 PAT 或 GitHub App，secret 名 `PORTFOLIO_GH_TOKEN`，scope：`repo` + `workflow`

### 4. 各产品仓必备

每个产品 repo 仍需：

- `CURSOR_API_KEY` Secret  
- labels + `agent-delivery-dispatch.yml`（harness 已带）

---

## B. Multica Autopilot（看板 + 历史）

适合：你想在 **Multica UI** 看 run、用 webhook 接 GitHub/Linear。

### 创建 Autopilot（CLI）

```bash
# 自托管 Multica 已 login 后
multica autopilot create \
  --title "Portfolio — music-game-sea nightly" \
  --description "Read .delivery/music-game-sea/brief.md and CLAUDE.md. Process issues labeled agent-safe. Verifier must exit 0." \
  --agent <YOUR_RUNTIME_AGENT_UUID> \
  --mode create_issue

multica autopilot trigger-add <AUTOPILOT_ID> \
  --kind schedule \
  --cron "0 2 * * *" \
  --timezone Asia/Shanghai
```

为 **每个产品线** 各建一个 Autopilot，或一个总 Autopilot 其 prompt 指向 `project-registry.yaml`（Agent 读文件决定去哪仓——软逻辑，仅辅助）。

### Webhook 触发（GitHub → Multica）

1. Multica UI → Autopilot → Add **Webhook** trigger  
2. GitHub repo webhook → POST JSON（如 `issue.labeled` 含 `agent-safe`）  
3. 配置 **Event filters** 避免每个 push 都跑  

与 Portfolio GHA **分工**：

- **GHA Portfolio**：硬触发、公平配额、不依赖 LLM  
- **Multica Autopilot**：可视化、人工 `@agent`、run 审计  

### 生成命令脚本

```bash
bash scripts/ai-company/print-multica-autopilot-commands.sh
```

输出各项目的 `multica autopilot create` 命令（需填 agent id）。

---

## C. 推荐组合（躺平 CEO）

| 时段 | 发生什么 |
|------|----------|
| 02:00 | `portfolio-agent-dispatch` 按 registry 分配 5 个 slot |
| 夜间 | 各仓 Cursor Agent 跑子流水线 + CI |
| 早上 | CEO `ceo-daily.md`：两个 repo 的 BLOCKED + merge 勾选 |

**不必** 先上 LangGraph；队列 <10 ticket/天 Portfolio + 产品仓 GHA 足够。

---

## 故障排查

| 现象 | 处理 |
|------|------|
| portfolio workflow 403 | 配置 `PORTFOLIO_GH_TOKEN` |
| 某 repo 从不 dispatch | `paused: true`？repo 路径错？无 agent-safe issue？ |
| 重复 dispatch | 产品仓 `agent-running` label 是否正常打上 |
| Multica 与 GHA 双跑 | 关 Autopilot schedule 或只保留 Portfolio |

---

## 相关

- [08-multi-project-portfolio.md](./08-multi-project-portfolio.md)  
- [config/company-defaults.yaml](../config/company-defaults.yaml)  
- [runbooks/ceo-daily.md](../runbooks/ceo-daily.md)  
