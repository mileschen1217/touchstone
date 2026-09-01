#!/usr/bin/env bash
# check-resolve-config.sh — verifies scripts/resolve-config.sh's contract:
# a valid config (green) resolves to exit 0 + the six expected key=value
# lines; a malformed config (red) resolves to non-zero + a message naming
# the file. Fixtures: .touchstone/checker/fixtures/resolve-config/{green,red}/
# (each a fake project root holding .claude/touchstone.yaml).
#
# Two invocation shapes:
#   TOUCHSTONE_CHECK_ROOT set (rail-loop per-subdir mode) — asserts the ONE
#   fixture tree named by the env var and exits 0/non-zero so the generic
#   rail loop's green-notrip / red-trip contract holds: correct resolution of
#   the green tree exits 0 (notrip); correct rejection of the red tree exits
#   non-zero (trip, since a red tree IS the malformed-config case by
#   construction — the checker confirms resolve-config.sh catches it).
#   TOUCHSTONE_CHECK_ROOT unset (bare invocation) — self-contained: runs BOTH
#   fixture trees itself and exits 0 only if both assertions hold.
#
# Output on failure: one line per violation, prefixed [check-resolve-config].
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
resolver="$repo_root/scripts/resolve-config.sh"
fixtures="$repo_root/.touchstone/checker/fixtures/resolve-config"

# assert_green <dir> -- resolve-config must exit 0 and print exactly the six
# expected key=value lines.
assert_green() {
  local dir="$1" out rc n
  out="$(bash "$resolver" --root "$dir" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[check-resolve-config] $dir: expected exit 0 (valid config), got $rc: $out"
    return 1
  fi
  n="$(printf '%s\n' "$out" | grep -cE '^(specs|adr|epics|plans|archive|research)=')"
  if [ "$n" -ne 6 ]; then
    echo "[check-resolve-config] $dir: expected 6 key=value lines, got $n: $out"
    return 1
  fi
  return 0
}

# assert_red <dir> -- resolve-config must exit non-zero and name the
# malformed file in its message.
assert_red() {
  local dir="$1" out rc yaml
  out="$(bash "$resolver" --root "$dir" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "[check-resolve-config] $dir: expected non-zero exit (malformed config), got 0: $out"
    return 1
  fi
  yaml="$dir/.claude/touchstone.yaml"
  if [ -f "$yaml" ] && ! printf '%s' "$out" | grep -qF "$(basename "$yaml")"; then
    echo "[check-resolve-config] $dir: error message does not name the malformed file: $out"
    return 1
  fi
  return 0
}

if [ -n "${TOUCHSTONE_CHECK_ROOT:-}" ]; then
  case "$(basename "$TOUCHSTONE_CHECK_ROOT")" in
    green*)
      assert_green "$TOUCHSTONE_CHECK_ROOT"; exit $?
      ;;
    red*)
      if assert_red "$TOUCHSTONE_CHECK_ROOT"; then exit 1; else exit 0; fi
      ;;
    *)
      echo "[check-resolve-config] $TOUCHSTONE_CHECK_ROOT: fixture dir name must start with green or red"
      exit 1
      ;;
  esac
fi

fail=0
assert_green "$fixtures/green" || fail=1
assert_red   "$fixtures/red"   || fail=1
exit "$fail"
