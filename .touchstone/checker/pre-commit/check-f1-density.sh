#!/usr/bin/env bash
# check-f1-density.sh — Tier B trigger for fat class F1 (enumeration without a
# stated generating principle): a run of >= N consecutive same-shape list items.
# Shape = indent + marker class (bullet / numbered / checkbox) + lead style
# (bold / code / plain). Blank lines and wrapped continuation lines keep a run
# alive; headings, fences, tables, and plain paragraphs break it.
# WARN-ONLY: hits are printed, exit is ALWAYS 0 — whether a flagged run has a
# stated generating rule is a human/LLM disposition, not this trigger's verdict.
# Scan surface: skills/**/*.md, agents/**/*.md, docs/skill-authoring-template.md,
# CLAUDE.md (tests/ paths and fenced blocks excluded; tables out of scope).
# N is a project-local binding (fixture-calibrated); override: F1_DENSITY_MIN_RUN.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
N="${F1_DENSITY_MIN_RUN:-5}"

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

awk -v N="$N" '
  function close_run() {
    if (cnt >= N)
      printf "WARN [check-f1-density] %s:%d-%d: %d same-shape list items (F1: state the generating rule once, keep 1-2 labeled anchor examples)\n", curfile, rstart, rend, cnt
    cnt = 0; sig = ""
  }
  FNR == 1 { close_run(); curfile = FILENAME; infence = 0 }
  {
    l = $0
    if (l ~ /^ *(```|~~~)/) { infence = !infence; close_run(); next }
    if (infence) next
    if (l ~ /^[ \t]*$/) next                     # blank keeps run alive
    ind = l; sub(/[^ ].*$/, "", ind)             # leading spaces
    item = ""
    if      (l ~ /^ *- \[[ xX]\] /)   item = "checkbox"
    else if (l ~ /^ *[-*+] /)         item = "bullet"
    else if (l ~ /^ *[0-9]+[.)] /)    item = "numbered"
    if (item == "") {
      if (length(ind) > runind && cnt > 0) next  # wrapped continuation line
      close_run(); next
    }
    rest = l
    sub(/^ *([-*+]|[0-9]+[.)]) (\[[ xX]\] )?/, "", rest)
    lead = (rest ~ /^\*\*/) ? "bold" : (rest ~ /^`/) ? "code" : "plain"
    s = length(ind) "|" item "|" lead
    if (s == sig) { cnt++; rend = FNR }
    else { close_run(); sig = s; cnt = 1; rstart = FNR; rend = FNR; runind = length(ind) }
  }
  END { close_run() }
' "${files[@]}"
exit 0
