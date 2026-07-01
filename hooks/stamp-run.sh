#!/usr/bin/env bash
# stamp-run.sh — UserPromptExpansion hook handler: record the START of an auto-run
# gate skill (design-spec | design-review | anvil) as a run-manifest, so the on-demand
# metrics reporter can bound a burst-window and attribute token/cost/time to that run.
#
# Usage (from hooks/hooks.json): stamp-run.sh <skill>
#   <skill> is passed literally per matcher entry (anvil | design-spec | design-review).
#   The hook JSON payload arrives on stdin (session_id, cwd, ... common fields).
#
# SAFETY CONTRACT: observability must never break the workflow it observes. Every
# failure path is a silent `exit 0` — a missing jq, malformed payload, or unwritable
# dir must NOT block the user's gate command. This hook never exits non-zero.
#
# Storage: run-manifests are TRANSIENT machine-local observability, not repo artifacts —
# they live under ${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}/runs, off the project
# tree. /tmp is cleared on reboot and macOS purges files untouched for ~3 days, so this is
# for dogfooding-the-current-work, NOT long-term per-epic accumulation. The cost data
# itself is durable elsewhere (~/.codex/sessions + the OTel export); the manifest is only
# the START marker. For durable accumulation, promote the aggregated report explicitly.
#
# Scope limit (documented in README + metrics-report.sh): Codex attribution is
# cwd+window-keyed, so it is reliable only when at most ONE active session runs per
# literal cwd at a time. Separate git worktrees (distinct cwd) are fine; two concurrent
# sessions in the SAME directory path are out of scope.
set -u

skill="${1:-}"
[ -n "$skill" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$cwd" ] || cwd="$PWD"

base="${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}"
runs_dir="$base/runs"
# Never write THROUGH a pre-existing symlink (classic /tmp symlink attack): if the base or the runs
# dir is a symlink, bail. Observability must never become a write-primitive to an arbitrary path.
[ -L "$base" ] && exit 0
[ -L "$runs_dir" ] && exit 0
mkdir -p "$runs_dir" 2>/dev/null || exit 0
[ -L "$runs_dir" ] && exit 0

# run_id: %s%N first (Linux); $RANDOM$RANDOM (30 bits) hardens collision-resistance on
# BSD/macOS date, which lacks %N and emits a literal "N".
run_id="$(date +%s%N 2>/dev/null)-$$-${RANDOM}${RANDOM}"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"

# Build with jq so a quoted/odd cwd or session_id can never emit invalid JSON.
jq -nc \
  --arg schema "run-manifest/v1" \
  --arg run_id "$run_id" \
  --arg skill "$skill" \
  --arg session_id "$session_id" \
  --arg cwd "$cwd" \
  --arg started_at "$started_at" \
  '{schema:$schema, run_id:$run_id, skill:$skill, session_id:$session_id, cwd:$cwd, started_at:$started_at}' \
  > "$runs_dir/$run_id.json" 2>/dev/null || exit 0

exit 0
