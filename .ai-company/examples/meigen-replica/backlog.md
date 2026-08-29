# Backlog — meigen-replica (chenzh/meigen-replica)

> Visual replica of meigen.ai gallery + studio. DoD = `accept_cases.md` + `make visual-check`.  
> TICKET-001 已 merge；002–003 在 GitHub 进行中。续票供 Work-Finder / nightly sync。

### TICKET-001 [agent-safe] Harness + agent-delivery CI

- **What:** Install company harness (workflows, agent-delivery scripts, labels)
- **DoD:** `make check` + `make visual-check` green in CI
- **Status:** merged (PR #4)

### TICKET-002 [agent-safe] Visual gate baseline sign-off (desktop + mobile)

- **What:** Confirm `@visual` baselines; check AC-V1 / AC-V2 in accept_cases.md
- **DoD:** `make visual-check` exit 0; AC-V1/V2 checked

### TICKET-003 [agent-safe] Visual break-guard regression

- **What:** Ensure intentional H1 break fails visual-check (AC-V3 documented)
- **DoD:** `make visual-check` fails on break, passes after restore

### TICKET-004 [agent-safe] Gallery card detail overlay polish

- **Owner:** Implementer
- **What:** 卡片点击打开 detail overlay（标题、模型标签、关闭）；375 宽可用
- **AC / DoD:** AC 可手测；`make visual-check` exit 0
- **Source:** backlog seed 2026-08-29

### TICKET-005 [agent-safe] Locale persistence (zh/en)

- **Owner:** Implementer
- **What:** `localStorage` 记住语言选择；刷新后保持
- **AC / DoD:** `make check` exit 0；切换流程手测通过
- **Source:** backlog seed 2026-08-29

### TICKET-006 [agent-safe] Skills wizard keyboard / a11y

- **Owner:** Implementer
- **What:** Skills 步骤控件补 `aria-label`；Esc 关闭 overlay
- **AC / DoD:** `make check` exit 0
- **Source:** backlog seed 2026-08-29

### TICKET-007 [agent-safe] Studio mobile 375 layout

- **Owner:** Implementer
- **What:** `/#studio` 在 375 宽下单列可用（dock 不溢出）
- **AC / DoD:** `make visual-check` exit 0（补 mobile studio 快照若需要）
- **Source:** backlog seed 2026-08-29

### TICKET-008 [agent-safe] OG / Twitter meta (gallery home)

- **Owner:** Implementer
- **What:** `index.html` 补 title、description、openGraph/twitter 占位
- **AC / DoD:** `make check` exit 0
- **Source:** backlog seed 2026-08-29

### TICKET-009 [agent-safe] P0 Gallery image resilience (CDN fail)

- **Priority:** P0
- **Owner:** Implementer
- **What:** 画廊/预览依赖 `files.bestcrm4startups.com` 时整页裂图（本地手测 16/16 `naturalWidth=0`）。为每张图提供本地占位（`public/assets/placeholders/` 或 SVG data-URI），`img.onerror` 回退；优先热路径前 N 张可离线展示。
- **AC / DoD:**
  - 断外网或 CDN 不可达时，首页画廊卡片仍可见非空占位（无裂图图标堆）
  - `make check` exit 0
  - `pnpm exec playwright test --grep @gallery` exit 0（若需可加「至少 1 张图 naturalWidth>0 或 placeholder data-attr」断言）
- **Source:** CEO smoke 2026-08-29 `:4173`

### TICKET-010 [agent-safe] P0 Mobile category filters reachable

- **Priority:** P0
- **Owner:** Implementer
- **What:** `@media (max-width:980px)` 把 `.sidebar` 设为 `display:none`，375 宽无法选分类（Playwright 点 `.side-item` 超时 invisible）。补移动端分类入口（顶栏 chips / 抽屉 / 画廊上方横向滚动），与桌面 `state.cat` 同源。
- **AC / DoD:**
  - 375 宽可切换至少「Food / All」并改变 `#gallery` 卡片集合
  - `make check` exit 0
  - `pnpm exec playwright test --grep @gallery` 增加或扩展 375 分类用例 exit 0
- **Source:** CEO smoke 2026-08-29

### TICKET-011 [agent-safe] P0 Restore visual + locale CI green

- **Priority:** P0
- **Owner:** Implementer
- **What:** 本机 `playwright` `@visual`/`@locale`/`@gallery` 375 共 7 fail（截图像素差 + locale/overlay），与裂图/布局漂移相关。修到 `make visual-check` 与 locale/gallery 相关用例绿；必要时 `--update-snapshots` 仅在占位图稳定后更新基线并写 `visual-smoke-log.md`。
- **AC / DoD:**
  - `make check` exit 0
  - `make visual-check` exit 0
  - `pnpm exec playwright test --grep @locale` exit 0
  - `pnpm exec playwright test --grep @gallery` exit 0
- **Source:** CEO smoke 2026-08-29（7 failed / 3 passed）

### TICKET-012 [agent-safe] P0 Auth CTA honesty (Sign In / Get Started)

- **Priority:** P0
- **Owner:** Implementer
- **What:** `#signInBtn` / `#startBtn` / `#ctaStart` 当前直接 `goStudio()`，用户以为能登录/开账号。改为：演示态 toast/横幅说明「复刻演示无账号」并滚到画廊或打开 Studio 时带明确 demo 文案；不实现真登录（见 `wont_do`）。
- **AC / DoD:**
  - 点击 Sign In 不静默进 Studio 冒充登录；有可见说明（中/EN i18n）
  - `make check` exit 0
  - 可选：`playwright` 断言点击后出现 demo notice
- **Source:** CEO smoke 2026-08-29
