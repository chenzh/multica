# Backlog — landing-tool-a

### TICKET-001 [agent-safe] Next 空壳与 harness 验证

- **What:** `apps/web` + `pnpm typecheck` + vitest 占位  
- **AC:** `pnpm typecheck` exit 0  

### TICKET-002 [agent-safe] 落地页 SEO metadata

- **What:** `layout.tsx` title/description、OG tags  
- **AC:** AC-1 相关 metadata 存在  

### TICKET-003 [agent-safe] JSON 格式化工具 UI

- **What:** textarea + format 按钮 + 错误提示  
- **AC:** AC-1、AC-2  

### TICKET-004 [agent-safe] Privacy / Terms 静态页

- **AC:** AC-3  

### TICKET-005 [agent-safe] favicon 与 web manifest

- **What:** `apps/web/public/favicon.ico`、`site.webmanifest`（name/theme_color）  
- **AC:** `pnpm typecheck` exit 0；`/manifest.webmanifest` 或等价路由可访问  

### TICKET-006 [agent-safe] robots.txt 与 sitemap 占位

- **What:** `apps/web/public/robots.txt`；`app/sitemap.ts` 返回最小 sitemap  
- **AC:** `pnpm typecheck` exit 0  
