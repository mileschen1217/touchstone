#!/usr/bin/env bash
# check-init-scaffold.sh — verifies scripts/init-checker-scaffold.sh's four
# idempotence states (AC-24): missing -> written; exists+no-reset -> already
# configured, untouched; exists+--reset -> .bak preserved, rewritten;
# malformed -> rejected, file left untouched. Fixtures (each a fake project
# root, a `.claude/touchstone.yaml` inside):
#   .touchstone/checker/fixtures/init-scaffold/green-missing/   (no .claude/)
#   .touchstone/checker/fixtures/init-scaffold/green-exists/    (valid yaml, no --reset)
#   .touchstone/checker/fixtures/init-scaffold/green-reset/     (valid yaml, run with --reset)
#   .touchstone/checker/fixtures/init-scaffold/red-malformed/   (malformed yaml)
#
# The script under test WRITES to its project root, so every assertion below
# copies the fixture into a scratch mktemp dir first — the committed fixture
# tree is never mutated.
#
# Two invocation shapes (mirrors check-resolve-config.sh):
#   TOUCHSTONE_CHECK_ROOT set (rail-loop per-subdir mode) — asserts the ONE
#   fixture tree named by the env var; a green* tree must NOT trip (this
#   checker exits 0), a red* tree MUST trip (this checker exits non-zero) —
#   trip here means "the scaffold script behaved correctly for that
#   fixture's scenario" (a red fixture IS the malformed case by
#   construction; correct rejection of it is what the rail loop wants).
#   TOUCHSTONE_CHECK_ROOT unset (bare invocation) — self-contained: runs
#   every fixture itself, exits 0 only if all four assertions hold.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
scaffold="$repo_root/scripts/init-checker-scaffold.sh"
fixtures="$repo_root/.touchstone/checker/fixtures/init-scaffold"

# scratch_copy <fixture-dir> -> prints a mktemp dir holding a copy of the
# fixture's contents. green-missing's placeholder .gitkeep is dropped so
# "missing" really means missing, not an empty-but-present tree.
scratch_copy() {
  local src="$1" dst
  dst="$(mktemp -d)"
  cp -R "$src/." "$dst/" 2>/dev/null || true
  rm -f "$dst/.gitkeep"
  printf '%s' "$dst"
}

assert_missing() {  # <fixture-dir> -- no yaml -> exit 0, file created, no "already configured"
  local fx="$1" scratch out rc
  scratch="$(scratch_copy "$fx")"
  out="$(bash "$scaffold" --project-root "$scratch" --workspace-root .touchstone 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[check-init-scaffold] $fx: expected exit 0 (missing -> written), got $rc: $out"; rm -rf "$scratch"; return 1
  fi
  if [ ! -f "$scratch/.claude/touchstone.yaml" ]; then
    echo "[check-init-scaffold] $fx: touchstone.yaml was not written"; rm -rf "$scratch"; return 1
  fi
  if printf '%s' "$out" | grep -q "already configured"; then
    echo "[check-init-scaffold] $fx: missing-file run must not print 'already configured': $out"; rm -rf "$scratch"; return 1
  fi
  rm -rf "$scratch"; return 0
}

assert_exists_noreset() {  # <fixture-dir> -- valid yaml, no --reset -> exit 0, "already configured", untouched
  local fx="$1" scratch out rc yaml before
  scratch="$(scratch_copy "$fx")"
  yaml="$scratch/.claude/touchstone.yaml"
  before="$(mktemp)"; cp "$yaml" "$before"
  out="$(bash "$scaffold" --project-root "$scratch" --workspace-root .touchstone 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[check-init-scaffold] $fx: expected exit 0 (already configured), got $rc: $out"; rm -rf "$scratch" "$before"; return 1
  fi
  if ! printf '%s' "$out" | grep -q "already configured"; then
    echo "[check-init-scaffold] $fx: expected an 'already configured' line: $out"; rm -rf "$scratch" "$before"; return 1
  fi
  if ! cmp -s "$before" "$yaml"; then
    echo "[check-init-scaffold] $fx: touchstone.yaml was modified without --reset"; rm -rf "$scratch" "$before"; return 1
  fi
  rm -rf "$scratch" "$before"; return 0
}

assert_reset() {  # <fixture-dir> -- valid yaml, --reset -> exit 0, .bak preserved, rewritten
  local fx="$1" scratch out rc
  scratch="$(scratch_copy "$fx")"
  out="$(bash "$scaffold" --project-root "$scratch" --workspace-root .touchstone --reset 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[check-init-scaffold] $fx: expected exit 0 (--reset), got $rc: $out"; rm -rf "$scratch"; return 1
  fi
  if [ ! -f "$scratch/.claude/touchstone.yaml.bak" ]; then
    echo "[check-init-scaffold] $fx: --reset did not produce touchstone.yaml.bak"; rm -rf "$scratch"; return 1
  fi
  rm -rf "$scratch"; return 0
}

assert_malformed() {  # <fixture-dir> -- malformed yaml -> exit non-zero, file named, untouched
  local fx="$1" scratch out rc yaml before
  scratch="$(scratch_copy "$fx")"
  yaml="$scratch/.claude/touchstone.yaml"
  before="$(mktemp)"; cp "$yaml" "$before"
  out="$(bash "$scaffold" --project-root "$scratch" --workspace-root .touchstone 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "[check-init-scaffold] $fx: expected non-zero exit (malformed), got 0: $out"; rm -rf "$scratch" "$before"; return 1
  fi
  if ! printf '%s' "$out" | grep -qF "$(basename "$yaml")"; then
    echo "[check-init-scaffold] $fx: error message does not name the malformed file: $out"; rm -rf "$scratch" "$before"; return 1
  fi
  if ! cmp -s "$before" "$yaml"; then
    echo "[check-init-scaffold] $fx: malformed touchstone.yaml was modified"; rm -rf "$scratch" "$before"; return 1
  fi
  rm -rf "$scratch" "$before"; return 0
}

run_for() {  # <fixture-basename> -> 0 if the scaffold script behaved correctly for that scenario
  case "$1" in
    green-missing) assert_missing "$fixtures/green-missing" ;;
    green-exists)  assert_exists_noreset "$fixtures/green-exists" ;;
    green-reset)   assert_reset "$fixtures/green-reset" ;;
    red-malformed) assert_malformed "$fixtures/red-malformed" ;;
    *) echo "[check-init-scaffold] unknown fixture: $1"; return 1 ;;
  esac
}

if [ -n "${TOUCHSTONE_CHECK_ROOT:-}" ]; then
  name="$(basename "$TOUCHSTONE_CHECK_ROOT")"
  case "$name" in
    green-*)
      run_for "$name"; exit $?
      ;;
    red-*)
      if run_for "$name"; then exit 1; else exit 0; fi
      ;;
    *)
      echo "[check-init-scaffold] $TOUCHSTONE_CHECK_ROOT: fixture dir name must start with green or red"
      exit 1
      ;;
  esac
fi

fail=0
for name in green-missing green-exists green-reset; do
  run_for "$name" || fail=1
done
run_for "red-malformed" || fail=1
exit "$fail"
