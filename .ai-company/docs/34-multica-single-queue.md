# 34 — Multica 单队列（L1 迁移 ADR）

> **状态**：已采纳（2026-08-29）  
> **Pilot**：`meigen-replica`（`dispatch_mode: multica`）  
> 配套：[04-architecture.md](./04-architecture.md) · [14-multica-autopilot-portfolio.md](./14-multica-autopilot-portfolio.md) · [33-autonomous-iteration.md](./33-autonomous-iteration.md)

---

## 决策

**Multica Issue/Task 是公司 L1 调度真相源**；GitHub Issue 在迁移期作为 **Spec 镜像**（brief/AC/CI），不再用 `dispatch-cursor-agent-cli.sh` 直接派单（`dispatch_mode: multica` 项目）。

| 层 | 真相源 | 职责 |
|----|--------|------|
| **L1 队列** | Multica（`:3000` / `multica issue`） | 派单、assign、run 历史、编排 API |
| **Spec 镜像** | GitHub Issue（迁移期） | AC、label 状态、PR 链、CI |
| **代码面** | GitHub PR + branch protection | merge、required checks |
| **CEO 聚合** | `:9477` 指挥舱 | 多仓脉搏；读 Multica + GitHub，**不**第二套调度 |

**禁止**：同一 repo 同时 `dispatch_mode: multica` 与 CLI `local` 派单；禁止 Kanban + Issues 双派单（[30](./30-silicon-valley-doc-standards.md)）。

---

## 为何现在做

1. 双队列（GitHub 调度 + Multica 看板空）阻碍后续 LangGraph / 编排。  
2. Multica 是本公司产品 — dogfood L1 与 `04-architecture` 对齐。  
3. Site Factory 已验证 `multica issue assign` + daemon 路径（`site-factory-multica.sh`）。

---

## 实现（P0）

| 工件 | 路径 |
|------|------|
| 派单库 | `scripts/ai-company/lib/multica-dispatch.sh` |
| Portfolio 分支 | `portfolio-dispatch.sh` — `dispatch_mode: multica` |
| 台账 | `templates/project-registry.yaml` — meigen pilot |
| 验收 | `verify-hands-off.sh` — multica 项目需 daemon + API |

### `dispatch_mode` 取值

| 值 | 行为 |
|----|------|
| `local`（默认） | `dispatch-cursor-agent-cli.sh`（legacy） |
| `multica` | `portfolio_dispatch_via_multica` → `multica issue create` + `assign`（需 `multica_agent_id`） |
| `gha` | content 线 workflow |
| `remote-pull` | 仅统计 |

**multica 模式无 CLI 回退** — 失败记 log + BLOCKED 路径，避免双队列。

### 收口（避免 `agent-running` 占坑）

| 规则 | 行为 |
|------|------|
| Multica task **live**（running/queued） | reconcile **不清** `agent-running` |
| Multica **idle**（如 `in_review`）+ 有 open PR | → GitHub `agent-done`，释放并发 |
| merge-policy `branchNamePrefix` | meigen 用 `cursor`（兼容 `cursor/` 与 `cursor-issue*`） |
| Agent 开分支 | 优先 `cursor-issue-<github#>`；`cursor/loca-*` 亦可合 |

---

## Pilot 验收（meigen-replica）

**前置**：`multica_agent_id` 指向职责范围覆盖该 repo 的 Multica agent（勿用 MusicSaas 等单项目 agent，否则会拒单）。

- [x] `project-registry`：`dispatch_mode: multica` + `multica_agent_id`  
- [x] `multica daemon status` → running；`/readyz` 绿  
- [x] `portfolio-dispatch.sh --dry-run` 显示 multica 分支  
- [x] 真实派单：`LOCA-43` ← GitHub `#10`（Multica L1）  
- [x] `:3000/local/issues` 可见 `LOCA-43`  
- [x] meigen **无** 新 `cursor-issue-N` CLI 派单（`dispatch_mode: multica`）  
- [x] PR + `agent-delivery-gate`：`PR #18` merged，`Agent delivery gate` + `Replica CI` 绿（2026-08-29）

---

## 后续阶段（未在本 ADR 实施）

| 阶段 | 内容 |
|------|------|
| P1 | 更多 registry 项目切 `multica`；`multica_agent_id` 按项目配置 |
| P2 | 新票直建 Multica（GitHub 仅 PR）；`sync-backlog-to-multica.sh` |
| P3 | LangGraph 只读 Multica task API；GitHub label 只读镜像 |

---

## 相关

- `scripts/ai-company/lib/multica-dispatch.sh`  
- [17-ceo-cockpit.md](./17-ceo-cockpit.md) — `:3000` 与指挥舱分工更新见该文「界面分工」  
- [runbooks/employee-autopilot.md](../runbooks/employee-autopilot.md)
