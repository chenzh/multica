#!/usr/bin/env bash
# Set GitHub Actions secrets for AI company repos from env vars (never commit values).
set -euo pipefail

ORG="${GITHUB_ORG:-chenzh}"
REPOS=(
  "$ORG/MusicSaas"
  "$ORG/landing-tool-a"
  "$ORG/saas-stripe-mvp"
)

if [ -z "${CURSOR_API_KEY:-}" ]; then
  echo "error: export CURSOR_API_KEY=crsr_... first" >&2
  echo "  https://cursor.com/settings → Integrations → User API Keys" >&2
  exit 1
fi

for repo in "${REPOS[@]}"; do
  echo "Setting CURSOR_API_KEY on $repo ..."
  printf '%s' "$CURSOR_API_KEY" | gh secret set CURSOR_API_KEY -R "$repo"
done

if [ -n "${PORTFOLIO_GH_TOKEN:-}" ]; then
  if gh secret set PORTFOLIO_GH_TOKEN -R multica-ai/multica <<<"$PORTFOLIO_GH_TOKEN" 2>/dev/null; then
    echo "PORTFOLIO_GH_TOKEN set on multica-ai/multica"
  else
    echo "warn: could not set PORTFOLIO_GH_TOKEN on multica-ai/multica (need admin)" >&2
  fi
fi

echo "Done. Trial dispatch:"
echo "  gh workflow run agent-delivery-dispatch.yml -R $ORG/MusicSaas -f max_tasks=1"
