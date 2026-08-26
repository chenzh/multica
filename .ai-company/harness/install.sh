#!/usr/bin/env bash
# Install company-harness into a target git repository.
# Run from multica repo: bash .ai-company/harness/install.sh [options] [TARGET_DIR]
set -euo pipefail

DRY_RUN=0
FORCE=0
TARGET=""

usage() {
  cat <<'EOF'
Usage: install.sh [options] [TARGET_DIR]

  TARGET_DIR   Destination repo root (default: current directory)

Options:
  --dry-run    Print actions without copying
  --force      Overwrite existing harness files
  -h, --help   Show this help

Example:
  bash .ai-company/harness/install.sh ../music-game-sea
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)
      if [ -n "$TARGET" ]; then
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      TARGET="$1"
      shift
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -n "${TARGET:-}" ]; then
  mkdir -p "$TARGET"
  TARGET="$(cd "$TARGET" && pwd)"
else
  TARGET="$(pwd)"
fi

if [ ! -d "$SOURCE_ROOT/.delivery" ] || [ ! -d "$SOURCE_ROOT/.cursor/agents" ]; then
  echo "error: SOURCE_ROOT does not look like multica (missing .delivery or .cursor/agents): $SOURCE_ROOT" >&2
  exit 1
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

copy_tree() {
  local src="$1"
  local dst="$2"
  if [ ! -e "$src" ]; then
    echo "warning: missing source $src" >&2
    return 0
  fi
  if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "skip (exists): $dst  (use --force to overwrite)"
    return 0
  fi
  run mkdir -p "$(dirname "$dst")"
  if [ -d "$src" ]; then
    run rm -rf "$dst"
    run cp -R "$src" "$dst"
  else
    run cp "$src" "$dst"
  fi
  echo "installed: $dst"
}

echo "company-harness install"
echo "  source: $SOURCE_ROOT"
echo "  target: $TARGET"
echo ""

# Core delivery tree (exclude feature-specific slugs under .delivery/*)
copy_tree "$SOURCE_ROOT/.delivery/_template" "$TARGET/.delivery/_template"
copy_tree "$SOURCE_ROOT/.delivery/prompts" "$TARGET/.delivery/prompts"
copy_tree "$SOURCE_ROOT/.delivery/config" "$TARGET/.delivery/config"
if [ -f "$SOURCE_ROOT/.delivery/README.md" ]; then
  copy_tree "$SOURCE_ROOT/.delivery/README.md" "$TARGET/.delivery/README.md"
fi

# Generic merge-policy fallback from harness scaffold if target has no policy
if [ ! -f "$TARGET/.delivery/config/merge-policy.json" ] || [ "$FORCE" -eq 1 ]; then
  if [ -f "$SCRIPT_DIR/scaffold/.delivery/config/merge-policy.json" ]; then
    copy_tree "$SCRIPT_DIR/scaffold/.delivery/config/merge-policy.json" \
      "$TARGET/.delivery/config/merge-policy.json"
  fi
fi

copy_tree "$SOURCE_ROOT/.cursor/agents" "$TARGET/.cursor/agents"
copy_tree "$SOURCE_ROOT/scripts/agent-delivery" "$TARGET/scripts/agent-delivery"

for wf in agent-delivery-dispatch.yml agent-delivery-gate.yml; do
  copy_tree "$SOURCE_ROOT/.github/workflows/$wf" "$TARGET/.github/workflows/$wf"
done

# Optional API contract gate from harness scaffold
copy_tree "$SCRIPT_DIR/scaffold/.github/workflows/api-contract-gate.yml" \
  "$TARGET/.github/workflows/api-contract-gate.yml"

# Issue template for agent-safe tasks
copy_tree "$SCRIPT_DIR/scaffold/.github/ISSUE_TEMPLATE/agent_safe_task.yml" \
  "$TARGET/.github/ISSUE_TEMPLATE/agent_safe_task.yml"

# Make scripts executable
if [ "$DRY_RUN" -eq 0 ]; then
  chmod +x "$TARGET/scripts/agent-delivery/"*.sh 2>/dev/null || true
fi

# Pointer to company OS docs (for monorepo installs)
POINTER="$TARGET/.delivery/COMPANY-OS.md"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] write $POINTER"
else
  cat >"$POINTER" <<EOF
# Company OS pointer

AI 公司级文档不在本仓库内复制，请阅读 Multica 仓：

- \`.ai-company/README.md\` — 宪法与索引
- \`.ai-company/runbooks/onboard-new-project.md\` — 接入清单
- \`.ai-company/examples/\` — 产品线示例 brief

本仓库仅保留 **执行 harness**（\`.delivery/\`、agents、workflows、scripts）。
EOF
  echo "installed: $POINTER"
fi

cat <<'EOF'

Next steps:
  1. GitHub Secrets: CURSOR_API_KEY, (optional) SLACK_WEBHOOK_URL
  2. Create labels: agent-safe, agent-running, agent-blocked, agent-done
  3. cp -r <company-os>/.ai-company/examples/music-game-sea .delivery/<your-slug>
     — or copy from .delivery/_template and fill brief.md
  4. gh workflow run agent-delivery-dispatch.yml -f max_tasks=1

See .ai-company/harness/README.md (in multica repo) for details.
EOF
