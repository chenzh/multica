#!/usr/bin/env bash
# Shared agent issue label + local dispatch helpers for hands-off scripts.
# shellcheck shell=bash

local_dispatch_running_count() {
  local n=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Ignore shell wrappers that embed the dispatch script in -c (double-count).
    if [[ "$line" == *"/bin/zsh"* ]] || [[ "$line" == *" zsh -c"* ]]; then
      continue
    fi
    if [[ "$line" == *"dispatch-cursor-agent-cli.sh"* ]] || [[ "$line" == *"cursor-agent -p"* ]]; then
      n=$((n + 1))
    fi
  done < <(pgrep -fl 'dispatch-cursor-agent-cli\.sh|cursor-agent -p' 2>/dev/null || true)
  echo "${n:-0}"
}

cleanup_stale_local_dispatches() {
  local quiet="${1:-0}"
  local killed=0
  local line pid issue repo repo_root state

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ ! "$line" =~ dispatch-cursor-agent-cli\.sh[[:space:]]+([0-9]+) ]]; then
      continue
    fi
    pid="${line%% *}"
    issue="${BASH_REMATCH[1]}"
    repo_root=""
    if [[ "$line" =~ REPO_ROOT=([^[:space:]]+) ]]; then
      repo_root="${BASH_REMATCH[1]}"
    fi
    repo=""
    if [ -z "$repo_root" ]; then
      repo_root="$(lsof -p "$pid" 2>/dev/null | awk '/cwd/ {print $NF; exit}' || true)"
    fi
    if [ -n "$repo_root" ] && [ -d "$repo_root" ]; then
      repo="$(gh repo view "$repo_root" --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
    fi
    if [ -z "$repo" ]; then
      continue
    fi
    state="$(gh issue view "$issue" -R "$repo" --json state -q .state 2>/dev/null || echo OPEN)"
    if [ "$state" = "CLOSED" ]; then
      if [ "$quiet" -eq 0 ]; then
        echo "cleanup: kill stale dispatch pid=$pid ($repo#$issue closed)"
      fi
      kill "$pid" 2>/dev/null || true
      killed=$((killed + 1))
      continue
    fi
    if ! pgrep -P "$pid" >/dev/null 2>&1 && ! pgrep -fl "cursor-agent -p.*cursor-issue-${issue}" >/dev/null 2>&1; then
      lock="${repo_root}/.delivery/.agent-runs/.dispatch-issue-${issue}.lock"
      if [ -f "$lock" ]; then
        lock_pid="$(cat "$lock" 2>/dev/null || true)"
        if [ "$lock_pid" = "$pid" ] && ! pgrep -fl "cursor-agent -p" >/dev/null 2>&1; then
          if [ "$quiet" -eq 0 ]; then
            echo "cleanup: kill stuck dispatch pid=$pid ($repo#$issue no agent child)"
          fi
          kill "$pid" 2>/dev/null || true
          rm -f "$lock"
          killed=$((killed + 1))
        fi
      fi
    fi
  done < <(pgrep -fl 'dispatch-cursor-agent-cli\.sh' 2>/dev/null || true)

  # Zsh wrappers left after manual test runs.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ "$line" == *"dispatch-cursor-agent-cli.sh"* ]]; then
      pid="${line%% *}"
      if [ "$quiet" -eq 0 ]; then
        echo "cleanup: kill wrapper pid=$pid"
      fi
      kill "$pid" 2>/dev/null || true
      killed=$((killed + 1))
    fi
  done < <(pgrep -fl '/bin/zsh.*dispatch-cursor-agent-cli\.sh' 2>/dev/null || true)

  # Stale lock files (dead pid).
  while IFS= read -r lock; do
    [ -f "$lock" ] || continue
    lock_pid="$(cat "$lock" 2>/dev/null || true)"
    if [ -z "$lock_pid" ] || ! kill -0 "$lock_pid" 2>/dev/null; then
      if [ "$quiet" -eq 0 ]; then
        echo "cleanup: remove stale lock $lock"
      fi
      rm -f "$lock"
    fi
  done < <(find "$HOME/Projects" -path '*/.delivery/.agent-runs/.dispatch-issue-*.lock' 2>/dev/null || true)

  echo "$killed"
}

issue_dispatch_active() {
  local num="${1:?}"
  local repo_root="${2:-}"
  if pgrep -fl "dispatch-cursor-agent-cli.sh ${num}( |$)" >/dev/null 2>&1; then
    return 0
  fi
  if [ -n "$repo_root" ] && [ -f "$repo_root/.delivery/.agent-runs/.dispatch-issue-${num}.lock" ]; then
    local pid
    pid="$(cat "$repo_root/.delivery/.agent-runs/.dispatch-issue-${num}.lock" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  if pgrep -fl "cursor-issue-${num}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

strip_agent_labels() {
  local repo="${1:?}"
  local num="${2:?}"
  local label
  for label in agent-done agent-running agent-blocked; do
    gh issue edit "$num" -R "$repo" --remove-label "$label" 2>/dev/null || true
  done
}
