#!/usr/bin/env bash
# Wiring suite: loop-skill body contract, phase-ship reference, close 5d,
# old-reporter reference sweep, version bump. Spec joins: AC-19, AC-22, AC-23.
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
SK="$REPO_ROOT/skills/insight/SKILL.md"
CL="$REPO_ROOT/skills/epic-driven-roadmap/references/close-and-doc-reckoning.md"
PS="$REPO_ROOT/skills/epic-driven-roadmap/references/phase-ship.md"

# --- AC-19: loop-skill body read cold ---
grep -qi 'elevated trust' "$SK" && ok "AC-19 declares elevated trust" || fail "AC-19 trust"
grep -q 'sole writer of check content' "$SK" && ok "AC-19 ownership boundary" || fail "AC-19 ownership"
grep -q 'scripts/proposal/' "$SK" && ok "AC-19 invokes scripts/proposal/*" || fail "AC-19 scripts"
grep -qi 'explicit human accept' "$SK" && ok "AC-19 never installs without accept" || fail "AC-19 accept"
grep -q 'metrics-report.sh' "$SK" && fail "AC-19 metrics procedure remains" || ok "AC-19 no metrics-reporting procedure"
grep -q 'auto-run gate efficiency report' "$SK" && fail "AC-19 old self-description remains" || ok "AC-19 old description gone"

# --- AC-22: close step 5d — reconcile only, no install anywhere in close ---
grep -q '^5d\.' "$CL" && ok "AC-22 step 5d present" || fail "AC-22 5d"
grep -q 'reconcile.sh' "$CL" && ok "AC-22 5d invokes reconcile.sh" || fail "AC-22 reconcile"
# scope the verbatim check to the 5d block itself — 5c already contains
# "verbatim" for its own paste instruction, which would false-pass a file-wide grep
BLOCK_5D="$(sed -n '/^5d\./,/^6\./p' "$CL")"
printf '%s\n' "$BLOCK_5D" | grep -q 'verbatim' && ok "AC-22 verbatim paste required" || fail "AC-22 verbatim"
grep -qE 'install\.sh|scripts/proposal/install' "$CL" && fail "AC-22 close doc carries an install invocation" || ok "AC-22 no install invocation in close doc"

# --- phase-ship reference ---
[ -f "$PS" ] && ok "phase-ship.md exists" || fail "phase-ship.md"
grep -q 'phase-record.sh' "$PS" && ok "phase-ship names phase-record" || fail "phase-ship record"
grep -q 'touchstone:insight' "$PS" && ok "phase-ship names insight" || fail "phase-ship insight"

# --- AC-23: old self-description swept off shipped surface + docs/CONTEXT ---
HITS="$(grep -rl 'auto-run gate efficiency report' "$REPO_ROOT/skills" "$REPO_ROOT/commands" "$REPO_ROOT/agents" "$REPO_ROOT/README.md" 2>/dev/null | grep -c . || true)"
[ "${HITS:-0}" -eq 0 ] && ok "AC-23 shipped surface swept" || fail "AC-23 hits=$HITS"
# docs/ + CONTEXT.md instructional refs must be updated too; docs/adr/ is the
# allowlisted historical record (ADRs keep their as-decided wording)
HITS2="$(grep -rl 'auto-run gate efficiency report' "$REPO_ROOT/docs" "$REPO_ROOT/CONTEXT.md" 2>/dev/null | grep -v '/adr/' | grep -c . || true)"
[ "${HITS2:-0}" -eq 0 ] && ok "AC-23 docs/CONTEXT swept (ADRs allowlisted)" || fail "AC-23 docs hits=$HITS2"
# README must describe the new split and no longer route metrics through insight
grep -q 'phase-record.sh' "$REPO_ROOT/README.md" && ok "AC-23 README names phase-record" || fail "AC-23 README phase-record"
# single grep, no pipe: a two-stage `grep | grep -q` can SIGPIPE-mask under pipefail
grep -Eiq 'insight.*metrics-report|metrics-report.*insight' "$REPO_ROOT/README.md" \
  && fail "AC-23 README still routes metrics through insight" || ok "AC-23 README metrics routing updated"

# --- version bump lockstep, exact target ---
V1="$(grep -o '"version": "[^"]*"' "$REPO_ROOT/.claude-plugin/plugin.json")"
V2="$(grep -o '"version": "[^"]*"' "$REPO_ROOT/.claude-plugin/marketplace.json")"
[ "$V1" = "$V2" ] && ok "version lockstep" || fail "version lockstep: $V1 vs $V2"
[ "$V1" = '"version": "0.13.0"' ] && ok "version is exactly 0.13.0" || fail "version: $V1"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
