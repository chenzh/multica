#!/usr/bin/env bash
# @vitest-environment node — shell unit tests for multica-dispatch helpers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/source-local-env.sh
source "$SCRIPT_DIR/lib/source-local-env.sh"
# shellcheck source=lib/multica-dispatch.sh
source "$SCRIPT_DIR/lib/multica-dispatch.sh"

fail=0
assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [ "$got" != "$want" ]; then
    echo "FAIL: $msg (got=$got want=$want)" >&2
    fail=1
  fi
}

json='{"id":"abc-123","title":"T"}'
assert_eq "$(multica_dispatch_json_field "$json" id)" "abc-123" "json id field"
assert_eq "$(multica_dispatch_json_field "$json" title)" "T" "json title field"

if bash -n "$SCRIPT_DIR/lib/multica-dispatch.sh" && bash -n "$SCRIPT_DIR/portfolio-dispatch.sh"; then
  echo "OK: bash -n syntax"
else
  echo "FAIL: bash -n syntax" >&2
  fail=1
fi

# After pilot close: GitHub #10 mirror is done → no longer "active".
if issue_multica_mirror_active "chenzh/meigen-replica" "10"; then
  echo "FAIL: meigen #10 Multica mirror should be inactive after done" >&2
  fail=1
else
  echo "OK: meigen github#10 Multica mirror inactive (done)"
fi

# find_mirror skips done/cancelled — empty is correct after LOCA-43 done.
if mid="$(multica_dispatch_find_mirror_issue_id "chenzh/meigen-replica" "10")"; [ -z "$mid" ]; then
  echo "OK: find_mirror skips done mirror for #10"
else
  echo "FAIL: find_mirror should skip done (got=$mid)" >&2
  fail=1
fi

assert_eq "$(registry_multica_agent_id_for_project "$SCRIPT_DIR/../../.ai-company/templates/project-registry.yaml" meigen-replica)" "675dcb2c-8198-4ce0-bed5-032793368a2a" "registry multica_agent_id"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "multica-dispatch.test.sh: all passed"
