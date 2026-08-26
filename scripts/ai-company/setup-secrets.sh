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

PORTFOLIO_REPO="${PORTFOLIO_REPO:-$ORG/multica}"
if [ -n "${PORTFOLIO_GH_TOKEN:-}" ]; then
  echo "Setting PORTFOLIO_GH_TOKEN on $PORTFOLIO_REPO ..."
  printf '%s' "$PORTFOLIO_GH_TOKEN" | gh secret set PORTFOLIO_GH_TOKEN -R "$PORTFOLIO_REPO"
fi

echo "Done. Trial dispatch:"
echo "  gh workflow run agent-delivery-dispatch.yml -R $ORG/MusicSaas -f max_tasks=1"
