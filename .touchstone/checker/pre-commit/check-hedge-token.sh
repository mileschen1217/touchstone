#!/usr/bin/env bash
# check-hedge-token.sh — Tier B trigger for hedge tokens in instruction prose:
# the authoring template bans hedging in imperatives ("typically", "consider",
# "may want to" and kin) — an instruction is unconditional or it is steering
# with the trade-off named. This trigger surfaces candidate hedges; whether a
# hit is a real hedge or legitimate steering is a human/LLM disposition.
# WARN-ONLY: hits are printed, exit is ALWAYS 0.
# Scan surface: skills/**/*.md, agents/**/*.md, docs/skill-authoring-template.md,
# CLAUDE.md (tests/ paths and fenced blocks excluded).
# Token list is a project-local binding (fixture-calibrated); the template's own
# banned-word quotation is a known accepted hit.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

files=()
while IFS= read -r f; do files+=("$f"); done < <(
  {
    find "$root/skills" "$root/agents" -type f -name '*.md' ! -path '*/tests/*' 2>/dev/null
    for f in "$root/docs/skill-authoring-template.md" "$root/CLAUDE.md"; do
      [ -f "$f" ] && printf '%s\n' "$f"
    done
  } | sort -u
)
[ "${#files[@]}" -ge 1 ] || exit 0

awk '
  BEGIN {
    nt = split("typically|considering|usually|generally|may want to|might want to|where appropriate|if possible|as needed|consider", toks, "|")
  }
  FNR == 1 { infence = 0 }
  {
    l = $0
    if (!infence && l ~ /^ *(```|~~~)/) { infence = 1; fmark = (l ~ /^ *```/) ? "b" : "t"; next }
    if (infence) {
      if ((fmark == "b" && l ~ /^ *```/) || (fmark == "t" && l ~ /^ *~~~/)) infence = 0
      next
    }
    norm = tolower(l)
    gsub(/[^a-z0-9]+/, " ", norm)
    norm = " " norm " "
    for (i = 1; i <= nt; i++) {
      if (index(norm, " " toks[i] " ") > 0) {
        show = l
        gsub(/^[ \t]+|[ \t]+$/, "", show)
        printf "WARN [check-hedge-token] %s:%d: \"%s\": %.100s\n", FILENAME, FNR, toks[i], show
      }
    }
  }
' "${files[@]}"
exit 0
