# Suggested Backlog — beatscape (MusicSaas)

仅 **agent-safe**；MLX/Gateway 见 MusicSaas `.delivery/beatscape/human-only-queue.md`。

### TICKET-B06 [agent-safe] Library 页 SEO title/description

- **What:** `apps/beatscape/src/pages/Library.tsx` 使用 `pageMeta` 设置 title/description  
- **AC:** `pnpm --filter @beatscape/web typecheck` exit 0；`pageMeta.test.ts` 仍绿  

### TICKET-B07 [agent-safe] Calibration 页 SEO title/description

- **What:** `apps/beatscape/src/pages/Calibration.tsx` 使用 `pageMeta`  
- **AC:** `pnpm --filter @beatscape/web typecheck` exit 0  
