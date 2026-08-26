# Backlog — saas-stripe-mvp (agent-safe only)

### TICKET-001 [agent-safe] Monorepo 壳 + merge-policy 含 payment deny

- **AC:** `make check` exit 0；`merge-policy.json` deny `**/payment/**`

### TICKET-002 [agent-safe] 营销页 + Pricing 静态三栏

- **AC:** AC-1  

### TICKET-003 [agent-safe] Dashboard 布局壳

- **AC:** AC-2  

### TICKET-004 [agent-safe] GET /v1/me mock handler

- **AC:** AC-3、AC-N2（Go test）  

### TICKET-005 [agent-safe] GET /health 存活探针

- **What:** `server` 增加 `GET /health` 返回 `{"status":"ok"}`  
- **AC:** Go test 覆盖 handler；`make check` exit 0  

### TICKET-006 [agent-safe] GET /v1/workspaces mock 列表

- **What:** mock handler 返回单条 workspace JSON  
- **AC:** Go test；`make check` exit 0  
