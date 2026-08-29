# 24 — 自媒体运营（Content line）

> 远程 Hermes 机执行 · CEO 本机指挥 · GitHub Issue 为队列真相源  
> 更新：2026-08-29

## 定位

| 层 | 载体 | 自媒体 |
|----|------|--------|
| 经营 | SecondBrain OPC | 本周是否起号、杀线 |
| 指挥 | `.ai-company/` + `:9477` + `ceo-nightly` | portfolio 派单、飞书 BLOCKED |
| 队列 | GitHub Issues（内容仓） | `agent-safe` 草稿任务 |
| 执行 | **远程机** Hermes | `dispatch-hermes-cli.sh` |
| 发布 | **CEO human-only** | 除非 Issue 显式 `publish-ok` |

Hermes **只做 Worker**，不顶层调度。流程决策在 `portfolio-dispatch.sh` / `pull-dispatch.sh`。

---

## 仓库结构（内容仓）

```text
content-<channel>/
  brand/voice.md
  drafts/YYYY-MM-DD-topic/
  calendar/YYYY-MM.yaml
  .delivery/prompts/orchestrator-kickoff.md
  scripts/content-delivery/
  .github/workflows/content-delivery-dispatch.yml
```

安装：

```bash
# 在 multica 仓执行，目标可以是新 clone 的内容仓
bash scripts/ai-company/install-content-harness.sh /path/to/content-youtube-sea
```

---

## project-registry 字段

见 [templates/project-registry.yaml](../templates/project-registry.yaml) 注释。最小示例：

```yaml
- id: content-youtube-sea
  kind: content
  repo: github.com/chenzh/content-youtube-sea
  dispatch_mode: gha          # 或 remote-pull
  workflow: content-delivery-dispatch.yml
  max_nightly_tickets: 1
  paused: true
  publish_policy: ceo-approve
```

| `dispatch_mode` | CEO 本机行为 | 远程机行为 |
|-----------------|--------------|------------|
| `gha` | `portfolio-dispatch` → `gh workflow run` | self-hosted runner 跑 Hermes |
| `remote-pull` | 只统计，不派单 | cron: `pull-dispatch.sh --max-tasks 1` |
| `local` | **不支持** content（会 skip） | — |

**不要**在 CEO 机配置 `AI_REPO_PATH_content_*`。

---

## 接线步骤

### A. 远程 Hermes 机（自媒体团队电脑）

1. `git clone` 内容仓，`install-content-harness.sh`
2. `hermes setup --portal`（或既有登录）
3. `gh auth login`
4. GitHub → Settings → Actions → self-hosted runner，标签：`self-hosted`, `content-hermes`
5. 试跑：

```bash
cd ~/content-youtube-sea
bash scripts/content-delivery/pull-dispatch.sh --max-tasks 1 --dry-run
bash scripts/content-delivery/dispatch-hermes-cli.sh <issue#> --dry-run
```

**可选 cron（`dispatch_mode: remote-pull` 时）：**

```cron
0 22 * * * cd ~/content-youtube-sea && bash scripts/content-delivery/pull-dispatch.sh --max-tasks 1 >> ~/.multica/content-pull-dispatch.log 2>&1
```

### B. CEO 本机（总部）

1. `project-registry.yaml` 登记 `kind: content`，起号前 `paused: true`
2. 夜间已跑 `ceo-nightly` → 自动 `portfolio-dispatch`（GHA 模式触发远程 workflow）
3. 飞书仍只推 BLOCKED；内容「待发布」在 GitHub Issue / PR 审

```bash
# 手动试 HQ 派单（不跑 local cursor）
bash scripts/ai-company/portfolio-dispatch.sh --dry-run --max-total 2
bash scripts/ai-company/portfolio-dispatch.sh --max-total 1
```

### C. 可选 — Multica 远程 runtime

自媒体机可额外：

```bash
export MULTICA_SERVER_URL=https://multica.<tailnet>.ts.net
multica login && multica daemon start
```

用于在 Multica UI 看 Hermes runtime 在线；**Issue 真相源仍建议 GitHub**。

---

## 任务分级（内容）

在 [06-task-grading.md](./06-task-grading.md) 基础上：

| 分级 | 自媒体示例 |
|------|------------|
| `agent-safe` | 调研摘要、标题库、草稿、日历提案 |
| `agent-assisted` | 成稿、多平台改写 → CEO 审后排期 |
| `human-only` | 发帖、投流、账号绑定、带 `publish-ok` 仍建议人点发送 |

Issue 模板：`content_agent_safe_task.yml`（harness 安装）。

---

## 与网站线共存

- **工程** `kind: product` → `portfolio-dispatch --local` 或 `agent-delivery-dispatch.yml`
- **内容** `kind: content` → `content-delivery-dispatch.yml` 或 `remote-pull`
- OPC 每周只开一条全力主线，用 `paused` + `priority` 控带宽

---

## 脚本索引

| 脚本 | 位置 |
|------|------|
| `install-content-harness.sh` | `scripts/ai-company/` |
| `dispatch-hermes-cli.sh` | `scripts/content-delivery/` |
| `pull-dispatch.sh` | 同上（远程 cron） |
| `content-verify.sh` | 轻量 merge 前检查 |
| `portfolio-dispatch.sh` | 读 registry `kind` / `dispatch_mode` |

---

## 相关

- [08-multi-project-portfolio.md](./08-multi-project-portfolio.md)
- [13-opc-bridge.md](./13-opc-bridge.md)
- [15-feishu-site-factory.md](./15-feishu-site-factory.md)（网站线对称能力）
- [23-local-agent-environment.md](./23-local-agent-environment.md)（仅工程本机）
