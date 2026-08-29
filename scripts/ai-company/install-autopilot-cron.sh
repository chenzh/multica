#!/usr/bin/env bash
# Install or show crontab lines for daytime Employee Autopilot dispatch.
set -euo pipefail

MULTICA_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG="${AUTOPILOT_LOG:-$HOME/.multica/autopilot-cron.log}"
INSTALL=0

usage() {
  cat <<EOF
Usage: install-autopilot-cron.sh [--install]

Daytime autopilot (Asia/Shanghai quiet hours 23:00–06:00 are enforced in-script):
  - Weekdays 06:00–22:00: every hour at :15
  - Weekends: every 30 minutes

Before install:
  1. cp .ai-company/config/local.env.example .ai-company/config/local.env
  2. Ensure cursor-agent logged in (\`cursor-agent status\`)

Cron lines (copy/paste or --install):
  15 6-22 * * 1-5 cd ${MULTICA_ROOT} && bash scripts/ai-company/autopilot-dispatch.sh >> ${LOG} 2>&1
  */30 * * * 0,6 cd ${MULTICA_ROOT} && bash scripts/ai-company/autopilot-dispatch.sh >> ${LOG} 2>&1

Manual test:
  bash scripts/ai-company/autopilot-dispatch.sh --dry-run --force
  bash scripts/ai-company/autopilot-dispatch.sh --force
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --install) INSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

WEEKDAY_LINE="15 6-22 * * 1-5 cd ${MULTICA_ROOT} && bash scripts/ai-company/autopilot-dispatch.sh >> ${LOG} 2>&1"
WEEKEND_LINE="*/30 * * * 0,6 cd ${MULTICA_ROOT} && bash scripts/ai-company/autopilot-dispatch.sh >> ${LOG} 2>&1"
MARKER="# multica-ai-company-autopilot"

echo "Suggested crontab entries:"
echo "$WEEKDAY_LINE"
echo "$WEEKEND_LINE"
echo ""
echo "Log: $LOG"

if [ "$INSTALL" -eq 0 ]; then
  exit 0
fi

mkdir -p "$(dirname "$LOG")"
existing="$(crontab -l 2>/dev/null || true)"
if echo "$existing" | grep -q "$MARKER"; then
  echo "crontab: autopilot entry already present (skip)" >&2
  exit 0
fi

{
  echo "$existing"
  echo "$MARKER"
  echo "$WEEKDAY_LINE"
  echo "$WEEKEND_LINE"
} | crontab -

echo "crontab: autopilot installed" >&2
