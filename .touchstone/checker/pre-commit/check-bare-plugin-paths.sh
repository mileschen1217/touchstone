#!/usr/bin/env bash
# SC2016: grep patterns search for the literal string ${CLAUDE_PLUGIN_ROOT} in file content
#         (single-quote intentional — no expansion wanted).
# shellcheck disable=SC2016
# check-bare-plugin-paths.sh — no bare relative path in execution/read instructions
# inside shipped skill / command / agent markdown files.
#
# "Bare path" = an explicit execution verb (bash / run / Read / read) immediately
# preceding a path like `scripts/`, `skills/`, `commands/`, or `agents/` that is
# NOT prefixed with ${CLAUDE_PLUGIN_ROOT}/.
#
# Prose attributions — e.g. "Per `skills/...`", "see `scripts/...`", "defined in
# `skills/...`" — are NOT flagged because they contain no execution verb before
# the path.
#
# EXEMPTION: add  <!-- bare-path-ok -->  on the same line as the bare path, or on
# the immediately preceding line, to suppress this check for that specific line.
# Use only for cases where the literal bare path is genuinely correct (e.g. the
# checker file itself, or a prose example that mentions the pattern).
set -uo pipefail

root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

rc=0

while IFS= read -r f; do
  prev_exempt=0
  lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))

    # Determine per-line exemption state
    this_exempt=0
    printf '%s' "$line" | grep -qF '<!-- bare-path-ok -->' && this_exempt=1

    # Skip if current line OR previous line carries the exemption marker
    if [ "$this_exempt" -eq 1 ] || [ "$prev_exempt" -eq 1 ]; then
      prev_exempt=$this_exempt
      continue
    fi
    prev_exempt=$this_exempt

    # --- Pattern A: bash / run + bare path (scripts/ or skills/) ---
    # Matches: bash scripts/foo.sh   bash "scripts/foo.sh"   run skills/bar.sh
    # Does NOT match: bash "${CLAUDE_PLUGIN_ROOT}/scripts/..." ($ follows quote)
    # Does NOT match: dry-run scripts/...   re-run skills/... (word boundary before verb)
    if printf '%s' "$line" | grep -qE '(^|[[:space:]])(bash|run)[[:space:]]+"?(scripts|skills)/'; then
      if ! printf '%s' "$line" | grep -qF '${CLAUDE_PLUGIN_ROOT}'; then
        echo "[check-bare-plugin-paths] $f:$lineno: bare exec path (prefix with \${CLAUDE_PLUGIN_ROOT}/): $line"
        rc=1
      fi
    fi

    # --- Pattern B: Read / read + backtick-quoted bare path ---
    # Matches: Read `skills/foo.md`   read `scripts/bar.sh`   Read `commands/x.md`
    # Does NOT match: Read `${CLAUDE_PLUGIN_ROOT}/skills/...`
    if printf '%s' "$line" | grep -qE '(Read|read)[[:space:]]+`(skills|scripts|commands|agents)/'; then
      if ! printf '%s' "$line" | grep -qF '${CLAUDE_PLUGIN_ROOT}'; then
        echo "[check-bare-plugin-paths] $f:$lineno: bare Read path (prefix with \${CLAUDE_PLUGIN_ROOT}/): $line"
        rc=1
      fi
    fi

  done < "$f"
done < <(find "$root/skills" "$root/commands" "$root/agents" -name '*.md' 2>/dev/null | sort)

exit "$rc"
