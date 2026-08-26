# 02 — 运营模型（Sleep Mode）

## 核心循环

```text
CEO 投 brief / Issue
    → 调度层（GHA / Multica Autopilot / LangGraph）拉队列
    → Worker（Cursor 为主）执行子流水线
    → 门禁层（Verifier + CI + 契约）只信 exit code
    → 绿：可选 auto-merge 或等 CEO 勾选 AC
    → 红/BLOCKED：告警，停止消耗配额
```

**睡眠模式**：夜间只处理 `agent-safe`；无 BLOCKED 则不 ping CEO。

---

## 三层时钟

| 层级 | 周期 | 执行者 | 产出 |
|------|------|--------|------|
| **战略** | 月/季 | CEO | 产品线优先级、预算调整 |
| **战术** | 周 | CEO + Autopilot | backlog 排序、分级复核 |
| **执行** | 日/夜 | 编排 + Worker | PR、CI 结果、BLOCKED 单 |

---

## 工单生命周期

```text
backlog → triaged → agent-safe 入队 → agent-running
    → PR opened → CI running → CI green
    → [auto-merge | CEO merge] → agent-done
```

异常路径：

```text
NEED_CLARIFY → agent-blocked → CEO 回答 → 重新入队
verify 3 轮失败 → agent-blocked → CEO 降级为 human-only 或拆 ticket
CI failed → 告警 → Worker 重试或 BLOCKED
```

GitHub Labels（与 `.delivery/README.md` 一致）：

| Label | 含义 |
|-------|------|
| `agent-safe` | 允许夜间自主处理 |
| `agent-running` | 已有 Agent 在处理 |
| `agent-blocked` | 需澄清或 verify 耗尽 |
| `agent-done` | PR 已开且 CI 绿 |

---

## 三种调度路径（可并存）

| 路径 | 组件 | 适用 |
|------|------|------|
| **A 手动** | Cursor Cloud + orchestrator prompt | 试跑、日 1～3 ticket |
| **B GHA** | `agent-delivery-dispatch.yml` + Cursor API | 夜间批量、硬调度 |
| **C Multica** | Autopilot cron/webhook + daemon | 看板、多 runtime、历史 |

推荐组合：**B + C** — GitHub 管 merge 门禁，Multica 管队列与 run 历史。

---

## 告警策略（真睡觉的关键）

| 事件 | 告警 | 动作 |
|------|------|------|
| `agent-blocked` | Slack / 邮件 | CEO 按 blocked runbook 处理 |
| Agent PR CI failed | Slack | 附 PR 链接；可自动重试 1 次 |
| auto-merge 被拒（deny 路径） | **不告警** | 预期行为，早上 merge |
| 安全/密钥扫描失败 | 立即 P0 | incident runbook |
| 预算超 80% | 日摘要 | 暂停非 P0 队列 |

---

## CEO 时间预算

| 活动 | 频率 | 时间 |
|------|------|------|
| 每日仪表盘 | 每天 | 15 min |
| 投新 brief / 勾 AC | 按需 | 5 min/ticket |
| BLOCKED 分拣 | 按需 | 10～30 min/条 |
| 每周治理 | 每周 | 30 min |
| 读代码 diff | **默认不做** | 仅安全/架构 ticket |

---

## 相关文档

- [06-task-grading.md](./06-task-grading.md)  
- [12-ceo-dashboard.md](./12-ceo-dashboard.md)  
- [runbooks/ceo-daily.md](../runbooks/ceo-daily.md)  
