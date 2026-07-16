#!/usr/bin/env bash
# check-dup-block.sh — verbatim duplication of >= K consecutive words, cross-file
# or non-overlapping intra-file, over the md scan surface: skills/**/*.md,
# agents/**/*.md, docs/skill-authoring-template.md, CLAUDE.md.
# Mechanizes fat classes F5 (verbatim duplication across files) and the verbatim
# subset of F2 (repeated discipline) — docs/skill-authoring-template.md is the rule home.
# Tier A: blocking (nonzero exit fails the commit via the checker rail).
# Fenced code blocks are skipped: parsed contract strings are incompressible content.
# tests/ paths are skipped: test fixtures are synthetic data, not governed prose.
# Pre-existing accepted/deferred duplication is ratcheted via the baseline file
# (.touchstone/checker/baselines/dup-block-baseline.txt — one fingerprint per line,
# the first K normalized words of the run; populated only through calibration review):
# baselined runs stay silent, NEW duplication blocks.
# KNOWN LIMITATION: tokenization is A-Za-z0-9 word-based; CJK prose is invisible
# to this check (the governed form rules are English-form text).
# K is a project-local binding (fixture-calibrated); override: DUP_BLOCK_MIN_WORDS.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
K="${DUP_BLOCK_MIN_WORDS:-12}"

baseline="$root/.touchstone/checker/baselines/dup-block-baseline.txt"
[ -f "$baseline" ] || baseline=/dev/null

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

# Baseline maintenance: DUP_BLOCK_FP=1 prints each run as "<fingerprint>  # site"
# (paste reviewed lines into the baseline file); normal runs print human-readable hits.
hits="$(awk -v K="$K" -v baseline="$baseline" -v FPMODE="${DUP_BLOCK_FP:-0}" '
  BEGIN {
    while ((getline bl < baseline) > 0) {
      sub(/#.*/, "", bl); gsub(/^[ \t]+|[ \t]+$/, "", bl)
      if (bl != "") base[bl] = 1
    }
    close(baseline)
  }
  FNR == 1 { fi++; fname[fi] = FILENAME; infence = 0 }
  {
    l = $0
    if (l ~ /^ *(```|~~~)/) { infence = !infence; next }
    if (infence) next
    gsub(/[^A-Za-z0-9]+/, " ", l)
    l = tolower(l)
    n = split(l, w, " ")
    for (i = 1; i <= n; i++) if (w[i] != "") {
      wc = ++wcount[fi]
      word[fi, wc]  = w[i]
      wline[fi, wc] = FNR
    }
  }
  END {
    for (f = 1; f <= fi; f++) {
      for (p = 1; p + K - 1 <= wcount[f]; p++) {
        key = word[f, p]
        for (j = 1; j < K; j++) key = key " " word[f, p + j]
        if (!(key in occn)) keyid[++nk] = key
        c = ++occn[key]
        occf[key, c] = f; occp[key, c] = p
      }
    }
    for (ki = 1; ki <= nk; ki++) {
      key = keyid[ki]; c = occn[key]
      if (c < 2) continue
      qual = 0
      for (a = 1; a <= c && !qual; a++)
        for (b = a + 1; b <= c && !qual; b++) {
          if (occf[key, a] != occf[key, b]) qual = 1
          else { d = occp[key, b] - occp[key, a]; if (d < 0) d = -d; if (d >= K) qual = 1 }
        }
      if (!qual) continue
      for (a = 1; a <= c; a++) {
        f = occf[key, a]; p = occp[key, a]
        for (j = 0; j < K; j++) matched[f, p + j] = 1
      }
    }
    for (f = 1; f <= fi; f++) {
      p = 1
      while (p <= wcount[f]) {
        if (matched[f, p]) {
          s = p
          while (p <= wcount[f] && matched[f, p]) p++
          e = p - 1
          fp = word[f, s]
          for (j = 1; j < K && s + j <= e; j++) fp = fp " " word[f, s + j]
          if (FPMODE) { printf "%s  # %s:%d-%d (%d words)\n", fp, fname[f], wline[f, s], wline[f, e], e - s + 1; p++; continue }
          if (fp in base) continue
          lim = (e - s + 1 < 10) ? e - s + 1 : 10
          snip = word[f, s]
          for (j = 1; j < lim; j++) snip = snip " " word[f, s + j]
          printf "%s:%d-%d: \"%s…\" (%d words)\n", fname[f], wline[f, s], wline[f, e], snip, e - s + 1
        } else p++
      }
    }
  }
' "${files[@]}")"

[ -z "$hits" ] && exit 0
echo "[check-dup-block] verbatim duplication >= $K words (one home per rule — point, do not restate):"
echo "$hits"
exit 1
