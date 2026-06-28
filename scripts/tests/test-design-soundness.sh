#!/usr/bin/env bash
# Deterministic tests for the code-facing-design-quality (cfdq) wiring.
# Covers: AC-1/2/3/6/7/9/10/13/14/15 (deterministic ACs).
# Live-bearing ACs (AC-4/5/8/11/12) are discharged by test-design-soundness-live.sh.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FRAGMENT="$REPO_ROOT/skills/_shared/inject/design-soundness-honor-check.md"
TEMPLATE="$REPO_ROOT/skills/design-spec/template.md"
FLOOR="$REPO_ROOT/scripts/check-design-soundness-refs.sh"
FIX_DIR="$REPO_ROOT/scripts/tests/fixtures/cfdq"
ANVIL="$REPO_ROOT/skills/anvil/SKILL.md"
BATCH="$REPO_ROOT/skills/code-review/references/batch-mode.md"
DREV="$REPO_ROOT/skills/design-review/SKILL.md"
CONTEXT="$REPO_ROOT/CONTEXT.md"

pass=0; fail=0

ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }

# ---------------------------------------------------------------------------
# Task 1 / AC-15: inject fragment exists and contains required sentinel phrases
# ---------------------------------------------------------------------------

if [ -f "$FRAGMENT" ]; then
  ok "AC-15 fragment exists"
else
  fail "AC-15 fragment exists at $FRAGMENT"
fi

# element-1: structural commitment definition
if grep -qF "structural commitment" "$FRAGMENT" 2>/dev/null; then
  ok "AC-15 element-1: structural commitment"
else
  fail "AC-15 element-1: 'structural commitment' not in fragment"
fi

# element-2: honor judgment + ## Architecture
if grep -qF "honor" "$FRAGMENT" 2>/dev/null && grep -qF "## Architecture" "$FRAGMENT" 2>/dev/null; then
  ok "AC-15 element-2: honor + ## Architecture"
else
  fail "AC-15 element-2: 'honor' and '## Architecture' not both in fragment"
fi

# element-3: FF duty — depth-stakes + descriptive-only
if grep -qF "depth-stakes" "$FRAGMENT" 2>/dev/null && grep -qF "descriptive-only" "$FRAGMENT" 2>/dev/null; then
  ok "AC-15 element-3: depth-stakes + descriptive-only"
else
  fail "AC-15 element-3: 'depth-stakes' and 'descriptive-only' not both in fragment"
fi

# element-4: [unverified] rule
if grep -qF "[unverified]" "$FRAGMENT" 2>/dev/null; then
  ok "AC-15 element-4: [unverified] rule"
else
  fail "AC-15 element-4: '[unverified]' not in fragment"
fi

# element-5 / AC-9: honest ceiling — 'declared' + 'commitment-less accreted'
if grep -qF "declared" "$FRAGMENT" 2>/dev/null && grep -qF "commitment-less accreted" "$FRAGMENT" 2>/dev/null; then
  ok "AC-15 element-5 / AC-9: declared + commitment-less accreted"
else
  fail "AC-15 element-5 / AC-9: 'declared' and 'commitment-less accreted' not both in fragment"
fi

# AC-9: honest-ceiling statement present
if grep -qF "commitment-less accreted" "$FRAGMENT" 2>/dev/null; then
  ok "AC-9 honest-ceiling stated"
else
  fail "AC-9 honest-ceiling not stated"
fi

# frontmatter: injected-by lists anvil, code-review, design-review
for consumer in anvil code-review design-review; do
  if grep -qF "$consumer" "$FRAGMENT" 2>/dev/null; then
    ok "AC-15 frontmatter injected-by: $consumer"
  else
    fail "AC-15 frontmatter injected-by missing: $consumer"
  fi
done

# ---------------------------------------------------------------------------
# Task 2 / AC-1/2/3/10: design-spec template ## Architecture section
# ---------------------------------------------------------------------------

# AC-1: instructs SHALL-form per-component commitments
if grep -qF "SHALL" "$TEMPLATE" 2>/dev/null; then
  ok "AC-1 template contains SHALL instruction"
else
  fail "AC-1 template missing SHALL instruction"
fi

# AC-2: permits explicit no-commitment sentinel; old silent skip removed
if grep -qF "no structural commitment" "$TEMPLATE" 2>/dev/null; then
  ok "AC-2 template permits no-commitment sentinel"
else
  fail "AC-2 template missing no-commitment sentinel"
fi

# AC-3: references arch-rubric.md by path; does NOT restate the force text
if grep -qF "arch-rubric.md" "$TEMPLATE" 2>/dev/null; then
  ok "AC-3 template links arch-rubric.md"
else
  fail "AC-3 template does not link arch-rubric.md"
fi
# Negative check: must not restate the interface-economy force text inline
if grep -qF "interface economy / information-hiding" "$TEMPLATE" 2>/dev/null; then
  fail "AC-3 template restates interface-economy force text (must load, not restate)"
else
  ok "AC-3 template does not restate interface-economy force"
fi

# AC-10: depth-stakes decision rule present
if grep -qF "depth-stakes" "$TEMPLATE" 2>/dev/null; then
  ok "AC-10 template contains depth-stakes decision rule"
else
  fail "AC-10 template missing depth-stakes decision rule"
fi

# ---------------------------------------------------------------------------
# Task 5 / AC-6: wiring assertions (fragment referenced by consumer files)
# ---------------------------------------------------------------------------

FRAG_PATH="skills/_shared/inject/design-soundness-honor-check.md"

for surface_file in "$ANVIL" "$BATCH" "$DREV"; do
  surface_name="$(basename "$(dirname "$surface_file")")/$(basename "$surface_file")"
  if grep -qF "$FRAG_PATH" "$surface_file" 2>/dev/null; then
    ok "AC-6/AC-13 wiring: $surface_name references fragment"
  else
    fail "AC-6/AC-13 wiring: $surface_name does NOT reference fragment"
  fi
done

# AC-6: fragment contains whole deliverable + whole ## Architecture scope instruction
if grep -qF "whole deliverable" "$FRAGMENT" 2>/dev/null; then
  ok "AC-6 fragment contains 'whole deliverable'"
else
  fail "AC-6 fragment missing 'whole deliverable'"
fi

if grep -qF "whole ## Architecture" "$FRAGMENT" 2>/dev/null; then
  ok "AC-6 fragment contains 'whole ## Architecture'"
else
  fail "AC-6 fragment missing 'whole ## Architecture'"
fi

# AC-6 negative: no writing-plans task surface references the fragment
# (superpowers is a separate plugin, not vendored here — only check skills/ in this plugin)
if grep -rl "$FRAG_PATH" "$REPO_ROOT/skills/" 2>/dev/null | grep -v \
    "$ANVIL" | grep -v "$BATCH" | grep -v "$DREV" | grep -q .; then
  fail "AC-6 negative: fragment referenced outside the 3 named consumers in skills/"
else
  ok "AC-6 negative: fragment not referenced outside named consumers"
fi

# AC-13 single-home: design-review must NOT contain the old inline design-soundness prose block
# The specific inline block shipped in Phase 3.2 starts with "Check (design-soundness lens)"
if grep -qF "Check (design-soundness lens)" "$DREV" 2>/dev/null; then
  fail "AC-13 single-home: old inline 'Check (design-soundness lens)' block still present in design-review/SKILL.md"
else
  ok "AC-13 single-home: old inline block removed from design-review/SKILL.md"
fi

# ---------------------------------------------------------------------------
# Task 4 / AC-7/AC-14: deterministic floor behavior (using fixtures)
# ---------------------------------------------------------------------------

if [ ! -f "$FLOOR" ]; then
  fail "AC-7 floor script exists at $FLOOR"
else
  ok "AC-7 floor script exists"

  # (a) honored fixture (commitment-bearing) + real consumer files → exit 0
  HON_SPEC="$FIX_DIR/honored/spec.md"
  if [ -f "$HON_SPEC" ]; then
    if bash "$FLOOR" "$HON_SPEC" "$ANVIL" "$BATCH" "$DREV" >/dev/null 2>&1; then
      ok "AC-7 floor: honored spec + wired consumers → exit 0"
    else
      fail "AC-7 floor: honored spec + wired consumers → non-zero (unexpected)"
    fi
  else
    fail "AC-7 floor: honored fixture spec not found at $HON_SPEC"
  fi

  # (b) commitment-bearing spec + a consumer missing the ref → non-zero + BLOCK
  VIO_SPEC="$FIX_DIR/violated/spec.md"
  if [ -f "$VIO_SPEC" ]; then
    DUMMY_CONSUMER="$(mktemp)"
    echo "# dummy consumer — no fragment ref" > "$DUMMY_CONSUMER"
    floor_rc=0
    floor_out="$(bash "$FLOOR" "$VIO_SPEC" "$DUMMY_CONSUMER" 2>&1)" || floor_rc=$?
    rm -f "$DUMMY_CONSUMER"
    if [ "$floor_rc" -ne 0 ]; then
      ok "AC-7 floor: spec + unwired consumer → non-zero"
    else
      fail "AC-7 floor: spec + unwired consumer → exit 0 (should be non-zero)"
    fi
    # BLOCK line must not contain commitment body text (only spec path + consumer + fragment path)
    if printf '%s' "$floor_out" | grep -qF "BLOCK:"; then
      ok "AC-7 floor: BLOCK line present"
    else
      fail "AC-7 floor: BLOCK line absent in non-zero output"
    fi
  else
    fail "AC-7 floor: violated fixture spec not found at $VIO_SPEC"
  fi

  # (c) additive fixture (AC-2 sentinel → zero commitments) → exit 0 vacuous
  ADD_SPEC="$FIX_DIR/additive/spec.md"
  if [ -f "$ADD_SPEC" ]; then
    # Even without any consumer file, additive → vacuous pass
    if bash "$FLOOR" "$ADD_SPEC" 2>/dev/null; then
      ok "AC-14 floor: additive spec → vacuous exit 0"
    else
      fail "AC-14 floor: additive spec → non-zero (should be vacuous pass)"
    fi
  else
    fail "AC-14 floor: additive fixture spec not found at $ADD_SPEC"
  fi

  # (c2) descriptive-only fixture (has ## Architecture, no sentinel → nonzero per predicate)
  DESC_SPEC="$FIX_DIR/descriptive-only/spec.md"
  if [ -f "$DESC_SPEC" ]; then
    DUMMY_CONSUMER2="$(mktemp)"
    echo "# dummy consumer — no fragment ref" > "$DUMMY_CONSUMER2"
    desc_rc=0
    bash "$FLOOR" "$DESC_SPEC" "$DUMMY_CONSUMER2" >/dev/null 2>&1 || desc_rc=$?
    rm -f "$DUMMY_CONSUMER2"
    if [ "$desc_rc" -ne 0 ]; then
      ok "AC-7 floor: descriptive-only spec (no sentinel) → nonzero (requires fragment ref)"
    else
      fail "AC-7 floor: descriptive-only spec → exit 0 (should require fragment ref)"
    fi
  else
    fail "AC-7 floor: descriptive-only fixture spec not found at $DESC_SPEC"
  fi

  # (d) --dup-check: fails when fragment body is statically copied into another .md
  DUP_MD="$(mktemp).md"
  # Create a file that statically copies a key fragment body phrase
  printf '# dup\n\nstructural commitment\nhonor\n## Architecture\ndepth-stakes\ndescriptive-only\n[unverified]\ndeclared\ncommitment-less accreted\n' > "$DUP_MD"
  dup_rc=0
  bash "$FLOOR" --dup-check "$DUP_MD" >/dev/null 2>&1 || dup_rc=$?
  rm -f "$DUP_MD"
  if [ "$dup_rc" -ne 0 ]; then
    ok "AC-13 --dup-check: static body copy detected → non-zero"
  else
    fail "AC-13 --dup-check: static body copy not detected (exit 0)"
  fi

  # --dup-check passes when consumer only has a load-by-path reference line
  REF_MD="$(mktemp).md"
  printf '# ref\n\nLoad: skills/_shared/inject/design-soundness-honor-check.md\n' > "$REF_MD"
  if bash "$FLOOR" --dup-check "$REF_MD" >/dev/null 2>&1; then
    ok "AC-13 --dup-check: path-reference only → exit 0"
  else
    fail "AC-13 --dup-check: path-reference only → non-zero (false positive)"
  fi
  rm -f "$REF_MD"
fi

# ---------------------------------------------------------------------------
# Task 7 / CONTEXT.md glossary
# ---------------------------------------------------------------------------

if grep -qF "design-soundness-honor-check.md" "$CONTEXT" 2>/dev/null; then
  ok "CONTEXT.md references fragment path (glossary entry present)"
else
  fail "CONTEXT.md does not reference design-soundness-honor-check.md"
fi

# Single-home: CONTEXT.md must not contain the fragment body verbatim
# (spot-check: the five sentinel phrases must NOT all appear in CONTEXT.md verbatim)
ctx_hits=0
for phrase in "structural commitment" "depth-stakes" "descriptive-only" "commitment-less accreted"; do
  grep -qF "$phrase" "$CONTEXT" 2>/dev/null && ctx_hits=$((ctx_hits+1))
done
# It's OK for CONTEXT to reference a term, but it should not have all 4 phrases (which would indicate body copy)
if [ "$ctx_hits" -ge 4 ]; then
  fail "CONTEXT.md may contain fragment body verbatim (all $ctx_hits sentinel phrases found)"
else
  ok "CONTEXT.md does not appear to contain fragment body verbatim"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
