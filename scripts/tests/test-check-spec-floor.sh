#!/usr/bin/env bash
# Fixture-based tests for check-spec-floor.sh (no bats in this repo).
# Each case asserts exit code + a required substring in output.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
checker="$here/../check-spec-floor.sh"
fix="$here/floor-fixtures"
fail=0

# assert <name> <expected-exit> <required-substring> <fixture>
assert() {
  local name="$1" want_rc="$2" want_sub="$3" file="$4"
  local out rc
  out="$(bash "$checker" "$fix/$file" 2>&1)"; rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    echo "FAIL $name: exit want=$want_rc got=$rc"; fail=$((fail+1)); return
  fi
  if ! printf '%s' "$out" | grep -qF "$want_sub"; then
    echo "FAIL $name: output missing '$want_sub' — got: $out"; fail=$((fail+1)); return
  fi
  echo "ok $name"
}

assert happy        0 "pass"              happy.md
assert missing-body 1 "AC-2"              missing-body.md
assert orphan-body  1 "AC-2"              orphan-body.md
assert empty-reason 1 "AC-1"              empty-reason.md
assert no-table     1 "no AC table"       no-table.md
assert draft        0 "skipped: draft"    draft.md
assert dup-index    1 "AC-2"              dup-index.md
assert dup-body     1 "AC-1"              dup-body.md
assert noise        0 "pass"              noise.md

assert req-happy   0 "pass"  req-happy.md
assert req-zero-ac 1 "REQ-2" req-zero-ac.md

assert req-orphan 1 "AC-2"  req-orphan.md
assert req-dup-id 1 "REQ-2" req-dup-id.md
assert req-dup-ac 1 "AC-3"  req-dup-ac.md

assert req-pair-mismatch 1 "AC-3" req-pair-mismatch.md

assert req-marker        1 "clarification" req-marker.md
assert req-marker-on-req 1 "clarification" req-marker-on-req.md
assert req-draft         0 "skipped: draft" req-draft.md
assert req-legacy        0 "pass"           req-legacy.md

assert req-self-trip     0 "pass"           req-self-trip.md

assert story-happy        0 "pass"                    story-happy.md
assert story-dropped      1 "US-2 has no requirement"     story-dropped.md
assert story-dangling     1 "US-9 dangling traces-to"      story-dangling.md
assert story-zerotrace    1 "REQ-2 untraced requirement"   story-zerotrace.md
assert story-zerotrace-e  1 "REQ-2 untraced requirement"   story-zerotrace-empty.md
assert story-multitoken   0 "pass"                     story-multitoken.md
assert story-multiline    0 "pass"                     story-multiline.md
assert story-sep-variants 0 "pass"                     story-sep-variants.md
assert story-empty        1 "User Stories"             story-empty.md
assert story-dup          1 "duplicated"               story-dup.md
assert story-fenced-head  0 "pass"                     story-fenced-heading.md
assert story-fence        0 "pass"                     story-fence.md
assert story-draft        0 "skipped: draft"           story-draft.md
assert story-legacy-trace 0 "pass"                     story-legacy-trace.md
assert story-no-req       1 "untraced story"           story-no-req.md

# stories extractor non-zero -> checker fails closed (not treated as empty set)
tmp="$(mktemp -d)"
cp "$here/../check-spec-floor.sh" "$tmp/"
printf '#!/usr/bin/env bash\ncase "$1" in reqs) echo REQ-1;; stories) exit 1;; *) exit 2;; esac\n' > "$tmp/spec-extract.sh"
chmod +x "$tmp/spec-extract.sh"
cp "$fix/story-happy.md" "$tmp/s.md"
out="$(bash "$tmp/check-spec-floor.sh" "$tmp/s.md" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "stories failed"; then echo "ok story-extract-fail-closed"; else echo "FAIL story-extract-fail-closed: rc=$rc out=$out"; fail=$((fail+1)); fi
rm -rf "$tmp"

# grep for the REMOVED inline awk GRAMMAR, not the variable names (which are kept,
# now holding subcommand output): inus=1 (the rawstories awk) and the traces while-match.
if grep -qE 'inus=1|while \(match\(line,/US-' "$here/../check-spec-floor.sh"; then echo "FAIL floor still inline-parses unit ids"; fail=$((fail+1)); else echo "ok floor-no-inline-unit-reparse"; fi

ctx="$here/../../CONTEXT.md"
for term in "challenge-result" "attested surface"; do grep -q "$term" "$ctx" || { echo "FAIL CONTEXT.md missing: $term"; fail=$((fail+1)); }; done
grep -qiE "freshness.*challenge-pass|challenge-pass sense" "$ctx" && echo "ok ctx-freshness-distinct" || { echo "FAIL ctx missing challenge-pass freshness"; fail=$((fail+1)); }

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail failed"; exit 1; fi
