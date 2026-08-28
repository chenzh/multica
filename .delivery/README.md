# Agent 自主交付流水线（Sleep Mode）

让 Agent 团队按 ticket 自主实现、验证、开 PR；你只投队列、看告警、对验收用例点勾。**CI 不绿不算交付。**

本目录是这套流水线的**唯一业务真相源**（对话不是）。架构约束仍以仓库根目录 `CLAUDE.md` / `AGENTS.md` 为准。

---

## 架构一览

```text
┌─────────────────────────────────────────────────────────────────┐
│  你（5 分钟/ ticket）                                            │
│  创建 GitHub Issue（agent-safe 模板）或 .delivery/<slug>/ 文件   │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  调度层（硬逻辑，不靠 Prompt 自觉）                               │
│  · GitHub Actions: agent-delivery-dispatch（定时 / 手动）         │
│  · 或 Cursor Automations（Linear / cron / webhook）              │
│  · 或 Multica Autopilot（dogfood，见下文「路径 C」）            │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  执行层：Cursor Cloud Agent（一 ticket 一 VM 一 branch）          │
│  读 CLAUDE.md + .delivery/* + Issue 正文                         │
│  子角色：.cursor/agents/{planner,implementer,verifier,reviewer}  │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  门禁层（只信 exit code）                                         │
│  1. Verifier 跑 make check / 范围更窄的 pnpm test + make test     │
│     · 复刻/落地页另跑 make visual-check（Playwright @visual）     │
│     · 需 competitor_inventory.md + wont_do.md（见 Visual Replica）│
│  2. GitHub CI（现有 ci.yml / cloudflare-pages-check）             │
│  3. agent-delivery-gate：路径白名单 → 可选 auto-merge            │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  你睡觉时：Slack/邮件 仅在 BLOCKED / CI 挂 / 需澄清 时 ping       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三种落地路径

| 路径 | 适合 | 你需要做什么 |
|------|------|--------------|
| **A. 纯 Cursor（手动队列）** | 先试跑、每天 1～3 个 ticket | 复制 Orchestrator prompt，手动开 Cloud Agent |
| **B. GitHub Actions + Cloud API（推荐睡觉模式）** | 夜间批量、硬门禁 | 配 Secrets，开 workflow |
| **C. Multica Autopilot（dogfood）** | 用自家产品管队列 | `multica autopilot create` + cron |

可以 **B + C 并存**：GitHub 管 merge 门禁，Multica 管 issue 队列与 run 历史。

---

## 第 0 步：前置条件

### Cursor 账号

- Cursor **Pro / Business**（Cloud Agent + API）
- [Dashboard → API Keys](https://cursor.com/dashboard/api) 生成 API Key
- Cloud Agent 已连接 GitHub 仓库 `multica-ai/multica`

### GitHub 仓库

1. **Settings → Secrets → Actions** 添加：

   | Secret | 用途 |
   |--------|------|
   | `CURSOR_API_KEY` | 调用 Cloud Agents API |
   | `SLACK_WEBHOOK_URL` | （可选）BLOCKED / 失败告警 |

2. **Labels**（Settings → Labels）创建：

   | Label | 含义 |
   |-------|------|
   | `agent-safe` | 允许进夜间队列 |
   | `agent-running` | 已有 Agent 在处理 |
   | `agent-blocked` | NEED_CLARIFY 或 3 轮 verify 失败 |
   | `agent-done` | PR 已开且 CI 绿（人工或 bot 打） |

3. **Branch protection（main）**  
   保持现有 required checks（`frontend` / `backend`）。auto-merge **仅**对白名单路径开启（见 `config/merge-policy.json`）。

---

## 第 1 步：任务分级（决定能不能睡觉）

### ✅ 允许 `agent-safe`

- 有**可勾选验收标准**（Issue 模板或 `accept_cases.md`）
- 改动范围 ≤ 3 个模块，**无** DB migration
- 不碰 auth/支付/权限模型
- 有现成测试模式可抄

### ❌ 禁止进队列

- 新 API 语义 / Breaking change
- `server/migrations/**` 变更
- 「用户可能会喜欢…」类产品判断
- 跨 5+ 包的 refactor

违反分级 = 醒来收尸，不是 Agent 的锅。

---

## 第 2 步：创建任务

### 方式 1：GitHub Issue（推荐）

使用模板 **Agent-safe task**，填：

- What & why（3 句以内）
- Acceptance criteria（`- [ ]` 列表）
- Out of scope（禁止改的路径）

打 label **`agent-safe`**。

### 方式 2：本地 delivery 包

```bash
cp -r .delivery/_template .delivery/my-feature
# 编辑 brief.md、accept_cases.md
```

大功能先在 `.delivery/<slug>/plan.md` 里过一遍（Planner subagent 也会写这个）。

---

## 第 3 步：Subagent 角色（已配置）

文件在 `.cursor/agents/`：

| 文件 | 角色 |
|------|------|
| `orchestrator.md` | 总调度，禁止跳阶段 |
| `planner.md` | 出 plan + 补全 accept_cases |
| `implementer.md` | 写代码 + 单测 |
| `verifier.md` | **只跑测试**，输出 PASSED/BLOCKED |
| `reviewer.md` | 对照 CLAUDE.md 审查 |

Cloud Agent clone 仓库后会自动读取项目 subagent 定义。

---

## 第 4 步：路径 A — 手动试跑（今天就能用）

1. 新建 **Agent 会话**（Cloud Agent 模式），仓库选 `multica-ai/multica`。
2. 粘贴 `.delivery/prompts/orchestrator-kickoff.md` 全文。
3. 附上 Issue 链接或 `@.delivery/my-feature/`。
4. 等 PR；**不要逐行读代码**，对照 Issue 验收标准 + CI 绿。

---

## 第 5 步：路径 B — 夜间自动调度

### 启用手动 dispatch

```bash
# GitHub UI: Actions → Agent delivery dispatch → Run workflow
# 或 CLI:
gh workflow run agent-delivery-dispatch.yml -f max_tasks=2
```

Workflow 会：

1. 拉取 open issues：`label:agent-safe -label:agent-running -label:agent-blocked`
2. 对每个 issue 调 `scripts/agent-delivery/dispatch-cursor-agent.sh`
3. 打 label `agent-running`，在 issue 评论里贴 Cloud Agent 链接
4. 失败 → `agent-blocked` + Slack（若配置）

### 开启 cron（默认关闭）

编辑 `.github/workflows/agent-delivery-dispatch.yml`，取消 `schedule` 注释：

```yaml
schedule:
  - cron: "0 18 * * 1-5"  # UTC 18:00 = 北京时间次日 02:00
```

### Auto-merge 门禁

PR 来自 `cursor/**` 分支且 CI 全绿时，`agent-delivery-gate.yml` 读取 `config/merge-policy.json`：

- **allow**：docs、纯测试、小范围 fix → 可 auto-merge
- **deny**：`server/migrations/**`、`packages/core/api/**` 等 → 只开 PR，人早上 merge

---

## 第 6 步：路径 C — Multica Autopilot（dogfood）

在你自己的 Multica workspace 里：

```bash
multica autopilot create \
  --title "Nightly agent-safe backlog" \
  --description "Process GitHub issues labeled agent-safe. Read CLAUDE.md and .delivery/README.md. Follow verifier gate." \
  --agent <your-dev-agent> \
  --mode create_issue

multica autopilot trigger-add <id> --kind schedule --cron "0 2 * * *" --timezone Asia/Shanghai
```

Autopilot 创建 issue → 你的 runtime Agent 执行 → 结果写在 issue comment。  
与路径 B 配合：Autopilot 负责**队列与可追溯 run**，GitHub Actions 负责 **API dispatch + merge 策略**。

---

## 第 7 步：告警（真睡觉的关键）

仅以下情况应叫醒你：

| 事件 | 动作 |
|------|------|
| `agent-blocked` | Slack：需澄清或 verify 3 轮失败 |
| CI failed on agent PR | Slack：附 PR 链接 |
| auto-merge 被拒绝（路径 deny） | **不告警**（预期行为，早上处理） |

未配置 `SLACK_WEBHOOK_URL` 时，workflow 只写 GitHub issue comment。

---

## 第 8 步：Orchestrator 硬规则（给 Cloud Agent 的 prompt 摘要）

完整版：`.delivery/prompts/orchestrator-kickoff.md`

核心：

1. 顺序：Planner → Implementer → Verifier → Reviewer → PR  
2. Verifier 必须跑 `make check`（或大改动前的分步 test）；exit ≠ 0 → BLOCKED，最多 3 轮  
3. 歧义 → 输出 `NEED_CLARIFY`，停止，不打 `agent-done`  
4. 禁止改 `CLAUDE.md` 未授权的包边界  
5. 禁止口头「应该没问题」

---

## 验证清单（搭建完成自检）

- [ ] `.cursor/agents/*.md` 已提交
- [ ] GitHub label 四个已创建
- [ ] `CURSOR_API_KEY` 已写入 Secrets
- [ ] 手动 `gh workflow run agent-delivery-dispatch.yml -f max_tasks=1` 成功起 Agent
- [ ] 用一个 trivial ticket（如补测试）跑通：Issue → PR → CI 绿
- [ ] `agent-delivery-gate` 对 docs-only PR 行为符合 `merge-policy.json`
- [ ] Slack 测试消息收到（若启用）

---

## 常见问题

**Q: Agent 跳过测试怎么办？**  
A: 不靠 Prompt。Verifier subagent + CI required checks；dispatch script 在 prompt 里写死「PR 描述必须贴 make check 输出」。

**Q: 能否 100% 脱手？**  
A: 不能。你仍负责分级、AC 质量、BLOCKED 处理。睡觉 = 无 BLOCKED 时不叫醒。

**Q: LangGraph 还要吗？**  
A: 队列 <10 ticket/天 不需要。CI + Actions 已是硬 DAG。

**Q: 和 Vibe-coding 单会话的区别？**  
A: 单会话 = 上下文漂移 + 你逐行改。本方案 = 文件真相源 + 子 Agent 隔离 + exit code 门禁。

---

## 目录结构

```text
.delivery/
  README.md                 ← 本文件
  _template/                ← 复制新建 feature
  config/merge-policy.json  ← auto-merge 白名单
  prompts/                  ← 粘贴即用 prompt
.cursor/agents/             ← Subagent 定义
.github/workflows/
  agent-delivery-dispatch.yml
  agent-delivery-gate.yml
.github/ISSUE_TEMPLATE/
  agent_safe_task.yml
scripts/agent-delivery/     ← dispatch / poll 脚本
```
