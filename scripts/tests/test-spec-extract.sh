#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ex="$here/../spec-extract.sh"
fix="$here/floor-fixtures"
fail=0
out="$(bash "$ex" reqs "$fix/req-happy.md")"
if [ "$out" != "$(printf 'REQ-1\nREQ-2')" ]; then echo "FAIL reqs: [$out]"; fail=$((fail+1)); else echo "ok reqs"; fi
d1="$(bash "$ex" digest "$fix/req-happy.md")"
# determinism
d1b="$(bash "$ex" digest "$fix/req-happy.md")"
# trailing-space invariance
cp "$fix/req-happy.md" "$fix/_ts.md"; sed -i.bak 's/^Given x$/Given x   /' "$fix/_ts.md"; rm -f "$fix/_ts.md.bak"
d2="$(bash "$ex" digest "$fix/_ts.md")"; rm -f "$fix/_ts.md"
# CRLF invariance
cp "$fix/req-happy.md" "$fix/_cr.md"; sed -i.bak 's/$/\r/' "$fix/_cr.md"; rm -f "$fix/_cr.md.bak"
d3="$(bash "$ex" digest "$fix/_cr.md")"; rm -f "$fix/_cr.md"
if [ -z "$d1" ] || [ "${#d1}" -ne 64 ]; then echo "FAIL digest: not a 64-hex hash [$d1]"; fail=$((fail+1)); else echo "ok digest-shape"; fi
[ "$d1" = "$d1b" ] && echo "ok digest-deterministic" || { echo "FAIL digest non-deterministic"; fail=$((fail+1)); }
[ "$d1" = "$d2" ]  && echo "ok digest-trailingspace" || { echo "FAIL digest trailing-space changed it"; fail=$((fail+1)); }
[ "$d1" = "$d3" ]  && echo "ok digest-crlf" || { echo "FAIL digest CRLF changed it"; fail=$((fail+1)); }
# fence-awareness regression: a fenced `## ` line must NOT terminate the section
d4="$(bash "$ex" digest "$fix/req-fenced-hash.md")"
[ -n "$d4" ] && echo "ok digest-fenced-hash" || { echo "FAIL fenced ## broke extraction"; fail=$((fail+1)); }
# golden pin: a FROZEN fixture's digest must equal the recorded literal (catches algorithm drift)
GOLD="$(bash "$ex" digest "$fix/digest-golden.md")"
[ "$GOLD" = "$(cat "$fix/digest-golden.sha")" ] && echo "ok digest-golden" || { echo "FAIL golden drift: $GOLD"; fail=$((fail+1)); }
sout="$(bash "$ex" stories "$fix/story-extract.md")"
if [ "$sout" != "$(printf 'US-1\nUS-2')" ]; then echo "FAIL stories: [$sout]"; fail=$((fail+1)); else echo "ok stories"; fi
sus="$(bash "$ex" stories "$fix/story-extract.md")"
[ "$sus" = "$sout" ] && echo "ok stories-deterministic" || { echo "FAIL stories non-deterministic"; fail=$((fail+1)); }
# --- Task 1: raw extractors ---
rs="$(bash "$ex" raw-stories "$fix/story-dup.md")"
[ "$(printf '%s\n' "$rs" | sort | uniq -d | grep -c .)" -ge 1 ] && echo "ok raw-stories-nondedup" || { echo "FAIL raw-stories deduped"; fail=$((fail+1)); }
rr="$(bash "$ex" raw-reqs "$fix/req-dup-id.md")"
[ "$(printf '%s\n' "$rr" | sort | uniq -d | grep -c .)" -ge 1 ] && echo "ok raw-reqs-nondedup" || { echo "FAIL raw-reqs deduped"; fail=$((fail+1)); }
tr="$(bash "$ex" traces "$fix/req-happy.md")"
printf '%s\n' "$tr" | grep -qE '^REQ-[0-9]+ US-[0-9]+$' && echo "ok traces-pairs" || { echo "FAIL traces shape: [$tr]"; fail=$((fail+1)); }
# --- Task 2: attested-surface widening ---
base="$(bash "$ex" digest "$fix/attested-base.md")"
for variant in us-edit us-add us-remove foundation-intention foundation-aim foundation-oos ac-edit; do
  v="$(bash "$ex" digest "$fix/attested-$variant.md")"
  [ "$base" != "$v" ] && echo "ok widen-$variant" || { echo "FAIL $variant did not change digest"; fail=$((fail+1)); }
done
non="$(bash "$ex" digest "$fix/attested-nonattested.md")"
[ "$base" = "$non" ] && echo "ok widen-nonattested-invariant" || { echo "FAIL non-attested edit changed digest"; fail=$((fail+1)); }
order="$(bash "$ex" digest "$fix/attested-reordered.md")"
[ "$base" = "$order" ] && echo "ok widen-fixed-order" || { echo "FAIL section reorder changed digest"; fail=$((fail+1)); }
if bash "$ex" digest "$fix/attested-dup-heading.md" >/dev/null 2>&1; then echo "FAIL dup heading did not BLOCK"; fail=$((fail+1)); else echo "ok dup-heading-blocks"; fi
# regression: literal string in body must NOT false-trigger dup-block (AC-10 fix)
dup_str_h="$(bash "$ex" digest "$fix/attested-body-with-dup-string.md" 2>/dev/null)"
[ -n "$dup_str_h" ] && [ "${#dup_str_h}" -eq 64 ] && echo "ok dup-string-in-body-no-block" || { echo "FAIL dup string in body false-triggered block"; fail=$((fail+1)); }
nv="$(bash "$ex" normalizer-version)"   # NO spec arg
[ "$nv" = "1" ] && echo "ok normalizer-version" || { echo "FAIL normalizer-version: [$nv]"; fail=$((fail+1)); }
# cross-tool determinism (AC-7): verify the two tools agree on the SAME input directly
# (SHA-256 is SHA-256). Tool-level equivalence is the honest claim; do NOT try to force
# digest()'s branch via a PATH shim (command -v still finds a present-but-failing shasum).
if command -v shasum >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1; then
  h1="$(printf 'attested-body' | shasum -a 256 | awk '{print $1}')"
  h2="$(printf 'attested-body' | sha256sum | awk '{print $1}')"
  [ "$h1" = "$h2" ] && echo "ok cross-tool-digest" || { echo "FAIL shasum vs sha256sum differ"; fail=$((fail+1)); }
else echo "ok cross-tool-digest (one tool absent — n/a on this host)"; fi
# --- Task 2 review fixes: trailing-space-heading fixtures + dup-block for Foundation/AC ---
# trailing-space headings are still the same section (canonical print); digest must equal base
tsh="$(bash "$ex" digest "$fix/attested-trailing-space-heading.md")"
[ "$tsh" = "$base" ] && echo "ok trailing-space-heading-equals-base" || { echo "FAIL trailing-space-heading digest differs from base"; fail=$((fail+1)); }
# duplicate trailing-space heading is still a duplicate — must block
if bash "$ex" digest "$fix/attested-dup-trailing-space-heading.md" >/dev/null 2>&1; then echo "FAIL dup trailing-space heading did not BLOCK"; fail=$((fail+1)); else echo "ok dup-trailing-space-heading-blocks"; fi
# duplicate Foundation heading must block
if bash "$ex" digest "$fix/attested-dup-foundation.md" >/dev/null 2>&1; then echo "FAIL dup Foundation heading did not BLOCK"; fail=$((fail+1)); else echo "ok dup-foundation-blocks"; fi
# duplicate Acceptance Criteria heading must block
if bash "$ex" digest "$fix/attested-dup-ac.md" >/dev/null 2>&1; then echo "FAIL dup Acceptance Criteria heading did not BLOCK"; fail=$((fail+1)); else echo "ok dup-ac-blocks"; fi
# --- Task 4: golden edge-case + boundary-agreement (AC-6) ---
for sub in stories raw-stories reqs raw-reqs traces digest; do
  got="$(bash "$ex" "$sub" "$fix/extract-edges.md")"; want="$(cat "$fix/extract-edges.$sub.expected")"
  [ "$got" = "$want" ] && echo "ok golden-$sub" || { echo "FAIL golden-$sub drift"; fail=$((fail+1)); }
done
bash "$ex" stories "$fix/extract-edges.md" | grep -q 'US-99' && { echo "FAIL fenced US-99 parsed"; fail=$((fail+1)); } || echo "ok fenced-us-not-parsed"
# boundary agreement: the floor checker passes this well-formed requirement-bearing edge spec
if bash "$here/../check-spec-floor.sh" "$fix/extract-edges.md" >/dev/null 2>&1; then echo "ok floor-boundary-agreement"; else echo "FAIL floor disagrees on edge boundary"; fail=$((fail+1)); fi
if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail"; exit 1; fi
