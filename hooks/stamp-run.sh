#!/usr/bin/env bash
# stamp-run.sh — hook handler that records the START of an auto-run gate skill
# (design-spec | design-review | anvil) as a run-manifest, so the on-demand metrics
# reporter can bound a burst-window and attribute token/cost/time to that run.
#
# TWO invocation paths, one handler (the gate name is DERIVED from the payload, not passed):
#   * UserPromptSubmit — the user TYPES the gate as a leading slash command (`/anvil`,
#     `/touchstone:design-spec …`). We read `.prompt`, take its FIRST line, and anchor-match a
#     leading `/[touchstone:]<gate>`. Fires on every prompt, so a gate merely mentioned in prose —
#     mid-sentence, OR at the start of a later line of a multi-line prompt — is correctly ignored.
#   * PreToolUse (matcher Skill) — the assistant AUTO-INVOKES the gate via the Skill tool
#     (e.g. crucible calls design-spec/design-review internally). We read `.tool_input.skill`
#     (`touchstone:<gate>`). This is the ONLY path that catches a nested auto-invoked gate.
# The two paths are mutually exclusive per run (typed ⇒ no Skill tool; auto ⇒ no user prompt),
# so there is no double-stamp.
#
# SAFETY CONTRACT: observability must never break the workflow it observes. Every failure path
# is a silent `exit 0` — a missing jq, malformed payload, non-gate prompt, or unwritable dir must
# NOT block the user's command. This hook never exits non-zero.
#
# Storage: run-manifests are machine-local observability, not repo artifacts — they live under
# ${TOUCHSTONE_METRICS_DIR:-$HOME/.touchstone-metrics}/runs, off the project tree but DURABLE
# (a /tmp default was dropped: reboot-cleared observation data reads as fake observability —
# windows silently vanish). The cost data itself also lives elsewhere (~/.codex/sessions + the
# OTel export); the manifest carries the START/END markers.
#
# Scope limit (documented in README + metrics-report.sh): Codex attribution is cwd+window-keyed,
# so it is reliable only when at most ONE active session runs per literal cwd at a time. Separate
# git worktrees (distinct cwd) are fine; two concurrent sessions in the SAME directory path are
# out of scope.
#
# Accuracy limit — a stamp marks a gate INVOCATION, not a guaranteed completion. The UserPromptSubmit
# path fires when the user TYPES a leading `/<gate>` command; if that run is abandoned or retried, its
# window (cost until the next gate START) is spurious or misattributed. The match is anchored to a
# LEADING slash command, so merely discussing a gate in prose never stamps — only an actual command
# does. The auto-invoke (PreToolUse/Skill) path is completion-faithful (the assistant only calls the
# Skill tool to run it). Plausibility-filtering of abandoned windows is a reader/insight-layer concern.
set -u

# Single source of the auto-run gate set (space-delimited; also used to gate-filter both paths).
# epic-driven-roadmap covers scaffold AND close invocations (one gate name, arg-agnostic).
GATES="anvil design-spec design-review insight code-review epic-driven-roadmap"

command -v jq >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

ev="$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"

# Derive the gate name from whichever path this is; leave empty (→ exit 0) if not a gate.
skill=""
case "$ev" in
  UserPromptSubmit)
    prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
    # FIRST line only. A slash command is the leading token of the prompt; matching the whole
    # multi-line string (e.g. via `grep`, whose `^` anchors every line) would false-stamp a gate
    # merely mentioned at the start of line 2+. Strip from the first newline, then anchor-match.
    first="${prompt%%$'\n'*}"
    for g in $GATES; do
      # leading `/`, optional `touchstone:` namespace, the gate name, then a word boundary
      # (whitespace or end) — so `/anvil`, `/touchstone:anvil path` match but `/anvilx` does not.
      if [[ "$first" =~ ^/(touchstone:)?${g}([[:space:]]|$) ]]; then
        skill="$g"; break
      fi
    done
    ;;
  PreToolUse)
    raw="$(printf '%s' "$payload" | jq -r '.tool_input.skill // empty' 2>/dev/null || true)"
    cand="${raw#touchstone:}"   # strip our namespace; a foreign-plugin skill won't match the gate set
    for g in $GATES; do
      [ "$cand" = "$g" ] && { skill="$g"; break; }
    done
    ;;
esac
[ -n "$skill" ] || exit 0

session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$cwd" ] || cwd="$PWD"

base="${TOUCHSTONE_METRICS_DIR:-$HOME/.touchstone-metrics}"
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

# epic attribution is declared, nullable: $TOUCHSTONE_EPIC_SLUG (set it in the
# CC process env for an epic-focused session) — never guessed from repo state.
epic_slug="${TOUCHSTONE_EPIC_SLUG:-}"

# Build with jq so a quoted/odd cwd or session_id can never emit invalid JSON.
# ended_at starts null; scripts/metrics/stamp-end.sh fills it at a gate's
# terminal step, and the reporter prefers it over the next-START heuristic.
jq -nc \
  --arg schema "run-manifest/v1" \
  --arg run_id "$run_id" \
  --arg skill "$skill" \
  --arg session_id "$session_id" \
  --arg cwd "$cwd" \
  --arg started_at "$started_at" \
  --arg epic_slug "$epic_slug" \
  '{schema:$schema, run_id:$run_id, skill:$skill, session_id:$session_id, cwd:$cwd,
    started_at:$started_at, ended_at:null,
    epic_slug:(if $epic_slug == "" then null else $epic_slug end)}' \
  > "$runs_dir/$run_id.json" 2>/dev/null || exit 0

exit 0
