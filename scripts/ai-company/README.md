# AI Company scripts

Utilities for the `.ai-company/` operating system.

## install-harness.sh

Copy delivery harness into any git repository.

```bash
bash scripts/ai-company/install-harness.sh /path/to/target-repo
bash scripts/ai-company/install-harness.sh --dry-run ../my-site
```

Delegates to `.ai-company/harness/install.sh`.

## bootstrap-project.sh

One-shot: harness, `gh` labels, optional repo create/push, backlog → issues.

```bash
bash scripts/ai-company/bootstrap-project.sh ../music-game-sea \
  --repo your-org/music-game-sea \
  --create-repo --push \
  --sync-backlog --from TICKET-002 --to TICKET-007
```

## scaffold-landing.sh

Second product line — minimal Next.js landing + tool (no backend):

```bash
bash scripts/ai-company/scaffold-landing.sh ../landing-tool-a
bash scripts/ai-company/bootstrap-project.sh ../landing-tool-a \
  --repo your-org/landing-tool-a --create-repo --push --sync-backlog
```

## ensure-github-labels.sh

```bash
bash scripts/ai-company/ensure-github-labels.sh your-org/music-game-sea
```

## ceo-dashboard.sh

One-command portfolio summary:

```bash
bash scripts/ai-company/ceo-dashboard.sh
bash scripts/ai-company/ceo-dashboard.sh --dispatch --max-total 3
```

## ceo-workbench.sh

Local browser workbench — queue view, per-issue dispatch, portfolio dispatch:

```bash
bash scripts/ai-company/ceo-workbench.sh
# http://127.0.0.1:9477
```

Requires: `python3`, `gh`, logged-in `cursor-agent` for local dispatch.

Local checkout paths are machine-specific — configure in `.ai-company/config/local.env`
(`MUSIC_SAAS_PATH` or `AI_REPO_PATH_<id>`), or let `resolve-repo-path.sh` auto-discover
under `~/Projects` / `~/Desktop`.

## portfolio-dispatch.sh

Multi-repo nightly dispatch from `project-registry.yaml` (run on company HQ / multica repo):

```bash
bash scripts/ai-company/portfolio-dispatch.sh --dry-run
bash scripts/ai-company/portfolio-dispatch.sh --max-total 5
```

Enabled via `.github/workflows/portfolio-agent-dispatch.yml` (cron + manual).

## print-multica-autopilot-commands.sh

```bash
export MULTICA_DEV_AGENT_ID=<uuid>
bash scripts/ai-company/print-multica-autopilot-commands.sh
```

## scaffold-saas.sh

Third product line — SaaS shell; **payment paths human-only**:

```bash
bash scripts/ai-company/scaffold-saas.sh ../saas-stripe-mvp
```

## sync-backlog-to-issues.sh

Create GitHub Issues from a `backlog.md` file (e.g. `examples/music-game-sea/backlog.md`).

```bash
# Preview TICKET-001..003
bash scripts/ai-company/sync-backlog-to-issues.sh \
  --backlog .ai-company/examples/music-game-sea/backlog.md \
  --repo your-org/music-game-sea \
  --from TICKET-001 --to TICKET-003 \
  --dry-run

# Create all agent-safe tickets (after labels exist on repo)
bash scripts/ai-company/sync-backlog-to-issues.sh \
  --backlog ../music-game-sea/.delivery/music-game-sea/backlog.md \
  --repo your-org/music-game-sea
```

**Prerequisites:**

- `gh` CLI authenticated
- Repo labels: `agent-safe`, `agent-assisted`, `human-only` (+ runtime labels from `.delivery/README.md`)

Parses lines like:

```markdown
### TICKET-004 [agent-safe] 营销落地页 `/`
```

Human-only lines (`PAY-001`, etc.) are only parsed if they use the same `### ID [grade] title` format.
