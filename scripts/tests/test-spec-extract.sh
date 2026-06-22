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
if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail"; exit 1; fi
