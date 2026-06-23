#!/usr/bin/env bash
# Deterministic acceptance check for the Phase-2.8 skill-cleanup (Spec A). Exit 0 = complete.
# Self-contained: the [labels] are this check's own identifiers, not external spec refs.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
fail=0
err() { echo "FAIL: $*" >&2; fail=1; }
SELF='scripts/tests/phase2.8-cleanup-checks.sh'

bodylines() { # $1 = SKILL.md path; prints body line count (frontmatter excluded)
  awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{f=0;b=1;next} b{c++} END{print c+0}' "$1"
}

# --- [ac1-context-deleted]: CONTEXT.md § Design+review control axis fully gone (ALL 5 tokens) ---
for tok in 'Design+review control axis' 'Pillar 1' 'Pillar 2' 'comparator type' 'minimize expected complexity'; do
  n=$(grep -Fc "$tok" CONTEXT.md); n=${n:-0}
  [ "$n" -eq 0 ] || err "[ac1-context-deleted] CONTEXT.md still has '$tok' ($n)"
done

# --- [ac3-no-dangling]: zero pointer to the deleted section in tracked files
#     (excl docs/adr/0018-* = legitimate home; excl scripts/tests/* = they carry the token
#      as grep PATTERNS, not as dangling pointers; the spec is .touchstone/ = untracked) ---
dangle=""
while IFS= read -r -d '' f; do
  case "$f" in
    docs/adr/0018-*|scripts/tests/*) continue ;;
  esac
  if grep -Fq 'Design+review control axis' "$f"; then dangle="$dangle $f"; fi
done < <(git ls-files -z)
[ -z "$dangle" ] || err "[ac3-no-dangling] section pointer still in:$dangle"

# --- [ac5-suite-size]: each skill <=200 body lines OR well-formed keep-long;
#     EXCEPT design-spec + design-review which are HARD <=200 (keep-long forbidden, Phase 2.9 REQ-5) ---
HARDCAP=" skills/design-spec/SKILL.md skills/design-review/SKILL.md "
for f in skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  b=$(bodylines "$f")
  if [[ "$HARDCAP" == *" $f "* ]]; then
    [ "$b" -le 200 ] || err "[ac5-suite-size] $f body=$b > 200 (HARD cap; keep-long forbidden for this skill)"
    grep -Eq 'keep-long:[[:space:]]*[0-9]+' "$f" && err "[ac5-suite-size] $f carries keep-long: — forbidden for design-spec/design-review (REQ-5 no escape hatch)"
  elif [ "$b" -gt 200 ]; then
    grep -Eq 'keep-long:[[:space:]]*[0-9]+([^[:alnum:]]|$)' "$f" \
      || err "[ac5-suite-size] $f body=$b > 200 and no well-formed keep-long: <n> annotation"
  fi
done

# --- [ac8-keystone-selfcontained]: invariant in the SKILL.md BODY (REQ-3, not only references/);
#     SKILL.md has no CONTEXT pointer ---
grep -Fq 'minimize expected complexity' skills/keystone/SKILL.md \
  || err "[ac8-keystone-selfcontained] keystone SKILL.md BODY missing the arch invariant 'minimize expected complexity'"
kp=$(grep -Fc 'Design+review control axis' skills/keystone/SKILL.md); kp=${kp:-0}
[ "$kp" -eq 0 ] || err "[ac8-keystone-selfcontained] keystone/SKILL.md still points to CONTEXT § control axis ($kp)"

[ "$fail" = 0 ] && echo "phase2.8-cleanup-checks: PASS"
exit "$fail"
