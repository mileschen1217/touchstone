#!/usr/bin/env bash
# check-req-headline.sh — REQ-headline discipline for design specs: a
# `### Requirement: REQ-N — …` headline is exactly ONE SHALL sentence.
# Flags: SHALL-clause count != 1, or a second sentence in the headline
# (overflow clauses re-home into the requirement body / ACs).
# Tier A verdict, STANDALONE runner: the scan target (.touchstone/specs/) is
# gitignored, so the pre-commit rail never sees it — run this script directly,
# or via the calibration scan. Legacy flat-AC specs (no `### Requirement:`
# heading) produce no hits by construction.
# Sentence-boundary heuristic (". " + uppercase) is a project-local binding,
# fixture-calibrated.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
dir="$root/.touchstone/specs"
[ -d "$dir" ] || exit 0

rc=0
for f in "$dir"/*.md; do
  [ -e "$f" ] || continue
  out="$(awk '
    /^### Requirement: REQ-[0-9]+/ {
      h = $0
      sub(/^### Requirement: REQ-[0-9]+[[:space:]]*[—-][[:space:]]*/, "", h)
      n = 0
      m = split(h, hw, /[^A-Za-z0-9-]+/)
      for (i = 1; i <= m; i++) if (hw[i] == "SHALL") n++
      if (n != 1)
        printf "FLAG %d: %d SHALL clauses (exactly 1 per headline): %.100s\n", FNR, n, h
      else if (h ~ /\. +[A-Z]/)
        printf "FLAG %d: second sentence in headline (one SHALL sentence; re-home overflow): %.100s\n", FNR, h
    }
  ' "$f")"
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | sed "s|^FLAG |FLAG $f:|"
    rc=1
  fi
done
exit "$rc"
