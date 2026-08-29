#!/usr/bin/env bash
# .touchstone/checker/standalone/render-on-write.sh — PostToolUse(Write|Edit) hook:
# re-render <epic-dir>/dossier.html whenever a .yaml/.yml artifact under
# .touchstone/epics/<epic>/ (or .touchstone/archive/epics/<epic>/) is written.
# SAFETY CONTRACT: never blocks a write. Every path — no match, missing
# jq/git/renderer, or a render failure — exits 0. On a render failure the
# previous dossier.html is left untouched (dossier-render.sh only writes it
# once, at the very end, after all parsing — a parse failure exits before that
# write, verified against scripts/dossier-render.sh:1492 and the
# "malformed spec.yaml is fatal" case in scripts/tests-smoke/run-smoke.sh).
#
# PostToolUse stdout on exit 0 is written to the debug log only, not shown to
# the session (Claude Code hooks reference, "Hook output" / per-event table:
# PostToolUse is not among the events whose plain stdout is added as visible
# context). To surface the one-line failure message to the session, this
# script emits it as JSON `{"systemMessage": "..."}` on stdout instead of
# plain text — the doc-named form that actually surfaces.
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

# Must land under <root>/.touchstone/epics/<epic>/... or the archive mirror;
# the epic dir is the first path component below "epics/".
rel=""
case "$abs" in
  "$root"/.touchstone/epics/*)         base="$root/.touchstone/epics";         rel="${abs#"$base"/}" ;;
  "$root"/.touchstone/archive/epics/*) base="$root/.touchstone/archive/epics"; rel="${abs#"$base"/}" ;;
  *) exit 0 ;;
esac

epic="${rel%%/*}"
[ -n "$epic" ] && [ "$epic" != "$rel" ] || exit 0   # no subpath below the epic name → not "under" an epic dir
case "$epic" in .|..) exit 0 ;; esac                # a relative component is never an epic name
epic_dir="$base/$epic"
[ -d "$epic_dir" ] || exit 0

renderer="$root/scripts/dossier-render.sh"
[ -f "$renderer" ] || exit 0

out="$(bash "$renderer" "$epic_dir" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  first_line="$(printf '%s\n' "$out" | head -1)"
  jq -nc --arg msg "dossier-render failed: $first_line" '{systemMessage: $msg}' 2>/dev/null \
    || printf '{"systemMessage":"dossier-render failed"}\n'
fi
exit 0
