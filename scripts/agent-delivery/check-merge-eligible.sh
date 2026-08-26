#!/usr/bin/env bash
# Check whether changed files in a PR are eligible for auto-merge per merge-policy.json.
set -euo pipefail

PR_NUMBER="${1:?usage: check-merge-eligible.sh <pr_number>}"
REPO="${GITHUB_REPOSITORY:-multica-ai/multica}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POLICY="$ROOT/.delivery/config/merge-policy.json"

if [ ! -f "$POLICY" ]; then
  echo "merge_eligible=false reason=policy_missing"
  exit 1
fi

ENABLED="$(jq -r '.autoMergeEnabled' "$POLICY")"
if [ "$ENABLED" != "true" ]; then
  echo "merge_eligible=false reason=auto_merge_disabled"
  exit 0
fi

BASE="$(gh pr view "$PR_NUMBER" --json baseRefName -q .baseRefName)"
HEAD="$(gh pr view "$PR_NUMBER" --json headRefName -q .headRefName)"
BRANCH_PREFIX="$(jq -r '.branchNamePrefix // "cursor/"' "$POLICY")"

if [[ "$HEAD" != ${BRANCH_PREFIX}* ]]; then
  echo "merge_eligible=false reason=branch_prefix"
  exit 0
fi

mapfile -t FILES < <(gh pr diff "$PR_NUMBER" --name-only)

deny_patterns=()
while IFS= read -r line; do
  deny_patterns+=("$line")
done < <(jq -r '.deny[]' "$POLICY")

allow_patterns=()
while IFS= read -r line; do
  allow_patterns+=("$line")
done < <(jq -r '.allow[]' "$POLICY")

matches_glob() {
  local file="$1"
  local pattern="$2"
  case "$pattern" in
    *"**"*)
      local prefix="${pattern%%\*\**}"
      [[ "$file" == "$prefix"* ]]
      ;;
    *"*")
      local base="${pattern%\*}"
      [[ "$file" == "$base"* ]]
      ;;
    *)
      [[ "$file" == "$pattern" ]]
      ;;
  esac
}

for f in "${FILES[@]}"; do
  for d in "${deny_patterns[@]}"; do
    if matches_glob "$f" "$d"; then
      echo "merge_eligible=false reason=deny_path file=$f pattern=$d"
      exit 0
    fi
  done
done

for f in "${FILES[@]}"; do
  allowed=false
  for a in "${allow_patterns[@]}"; do
    if matches_glob "$f" "$a"; then
      allowed=true
      break
    fi
  done
  if [ "$allowed" = false ]; then
    echo "merge_eligible=false reason=not_in_allowlist file=$f"
    exit 0
  fi
done

echo "merge_eligible=true base=$BASE head=$HEAD files=${#FILES[@]}"
exit 0
