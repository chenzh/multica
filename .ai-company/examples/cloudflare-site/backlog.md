# Backlog — cloudflare-site

### TICKET-001 [agent-safe] Vite 空壳与 harness 验证

- **What:** `apps/web` + `pnpm typecheck` + vitest 占位 + `wrangler.toml`  
- **AC:** `make check` exit 0  

### TICKET-002 [agent-safe] 落地页 SEO metadata

- **What:** `index.html` / root layout title、description、OG tags  
- **AC:** AC-1 相关 metadata 存在  

### TICKET-003 [agent-safe] 核心工具或落地页 UI

- **What:** 按 brief 实现主功能（textarea + 交互或 hero + CTA）  
- **AC:** AC-1、AC-2  

### TICKET-004 [agent-safe] Privacy / Terms 静态页

- **AC:** AC-3  

### TICKET-005 [agent-safe] Cloudflare Pages 构建与 wrangler 校验

- **What:** `pnpm build` 产出 `apps/web/dist`；CI 跑 typecheck + test  
- **AC:** AC-4  
