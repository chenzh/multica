# Agent delivery scripts

See [.delivery/README.md](../../.delivery/README.md) for the full setup guide.

## Requirements

- `gh` CLI authenticated
- `jq`, `curl`
- `CURSOR_API_KEY` from [Cursor Dashboard](https://cursor.com/dashboard/api)

## Examples

```bash
# Build prompt from issue #123 (stdout)
gh issue view 123 --json title,body,url,number > /tmp/issue.json
bash scripts/agent-delivery/build-prompt.sh /tmp/issue.json

# Dispatch Cloud Agent
export CURSOR_API_KEY=crsr_...
bash scripts/agent-delivery/dispatch-cursor-agent.sh 123

# Poll until done (optional; dispatch workflow does not wait by default)
bash scripts/agent-delivery/poll-agent-run.sh <agent_id> <run_id>

# Check auto-merge eligibility for PR
bash scripts/agent-delivery/check-merge-eligible.sh 456
```

Make scripts executable locally:

```bash
chmod +x scripts/agent-delivery/*.sh
```
