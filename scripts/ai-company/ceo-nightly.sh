#!/usr/bin/env bash
# Nightly CEO routine: optional dispatch, then daily brief + notify (21:00 cron).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib/source-local-env.sh
source "$SCRIPT_DIR/lib/source-local-env.sh"

REGISTRY="${REGISTRY:-$MULTICA_ROOT/.ai-company/templates/project-registry.yaml}"
GITHUB_ORG="${GITHUB_ORG:-chenzh}"
MAX_TOTAL="${MAX_TOTAL:-5}"
DISPATCH="${CEO_NIGHTLY_DISPATCH:-1}"
AUTO_MERGE="${CEO_AUTO_MERGE:-1}"
BRIEF=1
SINCE="${SINCE:-@yesterday}"

usage() {
  cat <<'EOF'
Usage: ceo-nightly.sh [options]

Typical cron (21:00 Asia/Shanghai):
  0 21 * * * cd ~/Projects/multica && bash scripts/ai-company/ceo-nightly.sh >> ~/.multica/ceo-nightly.log 2>&1

Options:
  --dispatch          Force portfolio dispatch before brief
  --no-dispatch       Brief only
  --brief-only        Alias for --no-dispatch
  --max-total N       Dispatch cap (default: 5)
  --registry PATH
  --org ORG
  -h, --help

Environment:
  CEO_NIGHTLY_DISPATCH=1|0   default 1
  CEO_AUTO_MERGE=1|0         default 1 — merge green open PRs before dispatch
  SLACK_WEBHOOK_URL / FEISHU_WEBHOOK_URL in local.env
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dispatch) DISPATCH=1; shift ;;
    --no-dispatch|--brief-only) DISPATCH=0; shift ;;
    --max-total) MAX_TOTAL="${2:?}"; shift 2 ;;
    --registry) REGISTRY="${2:?}"; shift 2 ;;
    --org) GITHUB_ORG="${2:?}"; shift 2 ;;
    --since) SINCE="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "=== ceo-nightly $(date -Iseconds) ==="

if [ "$AUTO_MERGE" -eq 1 ]; then
  echo ">> auto-merge green PRs"
  bash "$SCRIPT_DIR/ceo-auto-merge.sh" \
    --registry "$REGISTRY" \
    --org "$GITHUB_ORG" || {
    echo "warn: auto-merge failed (continuing)" >&2
  }
fi

if [ "$DISPATCH" -eq 1 ]; then
  echo ">> dispatch (max_total=$MAX_TOTAL)"
  bash "$SCRIPT_DIR/ceo-dashboard.sh" \
    --registry "$REGISTRY" \
    --org "$GITHUB_ORG" \
    --dispatch \
    --max-total "$MAX_TOTAL" || {
    echo "warn: dispatch failed (continuing to brief)" >&2
  }
fi

if [ "$BRIEF" -eq 1 ]; then
  echo ">> daily brief"
  bash "$SCRIPT_DIR/ceo-daily-brief.sh" \
    --registry "$REGISTRY" \
    --org "$GITHUB_ORG" \
    --since "$SINCE" \
    --quiet
fi

echo "=== done ==="
