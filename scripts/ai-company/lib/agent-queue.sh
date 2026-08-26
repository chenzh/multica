#!/usr/bin/env bash
# Shared agent issue label + local dispatch helpers for hands-off scripts.
# shellcheck shell=bash

issue_dispatch_active() {
  local num="${1:?}"
  if pgrep -fl "dispatch-cursor-agent-cli.sh ${num}" >/dev/null 2>&1; then
    return 0
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
