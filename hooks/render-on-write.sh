#!/usr/bin/env bash
# hooks/render-on-write.sh — shipped PostToolUse(Write|Edit) hook: re-render
# <epic-dir>/dossier.html whenever a .yaml/.yml artifact under the resolved
# epics dir W/epics/<epic>/ (or the epic archive W/archive/epics/<epic>/) is
# written. W = workspace_root from <root>/.claude/touchstone.yaml (default
# .touchstone) — the same key config-resolver.md reads, parsed here with
# grep/sed (no python3 dependency for this early gate). The archive path here
# is the epic archive shared with dossier-render.sh, NOT config-resolver's
# bundle.archive (= W/archive/specs).
#
# SAFETY CONTRACT (INV-6): never blocks a write. Every path — no match,
# missing jq/git/python3/renderer, or a render failure — exits 0, and never
# prints more than one line. On a render failure the previous dossier.html is
# left untouched (dossier-render.sh only writes it once, at the very end,
# after all parsing — a parse failure exits before that write, verified
# against scripts/dossier-render.sh and the "malformed spec.yaml is fatal"
# case in scripts/tests-smoke/run-smoke.sh).
#
# The renderer invoked is THIS PLUGIN'S OWN scripts/dossier-render.sh
# (plugin-root = the directory above this script's own directory) — never
# <root>/scripts/, which may not exist or may be a different version in a
# consumer project.
#
# PostToolUse stdout on exit 0 is written to the debug log only, not shown to
# the session (Claude Code hooks reference, "Hook output" / per-event table:
# PostToolUse is not among the events whose plain stdout is added as visible
# context). To surface the one-line message to the session, this script
# emits it as JSON `{"systemMessage": "..."}` on stdout instead of plain
# text — the doc-named form that actually surfaces.
set -u

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0

# Cheap extension gate first — avoids the git subprocess below for the
# overwhelmingly common non-yaml write, keeping a no-match payload fast.
case "$file_path" in
  *.yaml|*.yml) ;;
  *) exit 0 ;;
esac

pcwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$pcwd" ] || pcwd="$PWD"

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  command -v git >/dev/null 2>&1 || exit 0
  root="$(git -C "$pcwd" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$root" ] && [ -d "$root" ] || exit 0
# Canonicalize both sides before the prefix match — `epics/../../x.yaml` and a
# symlinked root would otherwise compare as if they were under an epic dir.
# After the extension gate, so the common non-yaml write still pays nothing.
root="$(cd "$root" 2>/dev/null && pwd -P)" || exit 0
[ -n "$root" ] || exit 0

case "$file_path" in
  /*) abs="$file_path" ;;
  *)  abs="$pcwd/$file_path" ;;
esac
abs_dir="$(cd "$(dirname "$abs")" 2>/dev/null && pwd -P)" || exit 0
[ -n "$abs_dir" ] || exit 0
abs="$abs_dir/$(basename "$abs")"

# Resolve W = workspace_root from <root>/.claude/touchstone.yaml (default
# .touchstone when the file or key is absent). Deliberately not a YAML parse
# (no python3 dependency for this gate) — grep the first line matching
# `^workspace_root:`, strip an inline comment, trim, strip surrounding quotes.
w=""
wcfg="$root/.claude/touchstone.yaml"
if [ -f "$wcfg" ]; then
  w="$(grep -m1 -E '^[[:space:]]*workspace_root:' "$wcfg" 2>/dev/null | sed -E 's/^[[:space:]]*workspace_root:[[:space:]]*//')"
  case "$w" in
    \"*) w="${w#\"}"; w="${w%%\"*}" ;;          # double-quoted value: everything up to the closing quote
    \'*) w="${w#\'}"; w="${w%%\'*}" ;;          # single-quoted value
    *)   w="${w%%#*}"; w="$(printf '%s' "$w" | sed 's/[[:space:]]*$//')" ;;   # bare value: strip a trailing comment
  esac
fi
[ -n "$w" ] || w=".touchstone"
case "$w" in
  /*) wroot="$w" ;;
  *)  wroot="$root/$w" ;;
esac

# Must land under <wroot>/epics/<epic>/... or <wroot>/archive/epics/<epic>/...
# (the epic archive — NOT config-resolver's bundle.archive = W/archive/specs);
# the epic dir is the first path component below "epics/".
rel=""
case "$abs" in
  "$wroot"/epics/*)         base="$wroot/epics";         rel="${abs#"$base"/}" ;;
  "$wroot"/archive/epics/*) base="$wroot/archive/epics"; rel="${abs#"$base"/}" ;;
  *) exit 0 ;;
esac

epic="${rel%%/*}"
[ -n "$epic" ] && [ "$epic" != "$rel" ] || exit 0   # no subpath below the epic name → not "under" an epic dir
case "$epic" in .|..) exit 0 ;; esac                # a relative component is never an epic name
epic_dir="$base/$epic"
[ -d "$epic_dir" ] || exit 0

# Plugin-root's own renderer — the directory above this script's own
# directory, resolved from $0 (never <root>/scripts/).
plugin_root="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd -P)" || exit 0
[ -n "$plugin_root" ] || exit 0
renderer="$plugin_root/scripts/dossier-render.sh"
[ -f "$renderer" ] || exit 0

# No python3 on PATH -> skip silently (one line), touch no dossier.
if ! command -v python3 >/dev/null 2>&1; then
  jq -nc '{systemMessage:"dossier-render skipped: python3 not found"}' 2>/dev/null \
    || printf '{"systemMessage":"dossier-render skipped: python3 not found"}\n'
  exit 0
fi

out="$(bash "$renderer" "$epic_dir" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  first_line="$(printf '%s\n' "$out" | head -1)"
  jq -nc --arg msg "dossier-render failed: $first_line" '{systemMessage: $msg}' 2>/dev/null \
    || printf '{"systemMessage":"dossier-render failed"}\n'
fi
exit 0
