#!/usr/bin/env bash
# Smoke suite for the surviving deterministic checkers + the run-project-checks
# hook's classify_command. One green + one red case per target. Not a
# replacement for scripts/tests/ (removed) — just a fast sanity net.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fx="$here/fixtures"
scripts_dir="$(cd "$here/.." && pwd)"
hooks_dir="$(cd "$here/../../hooks" && pwd)"

fail=0

# expect_exit <label> <expected: zero|nonzero> -- <cmd...>
expect_exit() {
  label="$1"; want="$2"; shift 2
  out="$("$@" 2>&1)"; rc=$?
  if { [ "$want" = zero ] && [ "$rc" -eq 0 ]; } || { [ "$want" = nonzero ] && [ "$rc" -ne 0 ]; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (rc=$rc, want=$want)"; echo "$out"
    fail=1
  fi
}

expect_exit "check-spec-floor.sh green" zero \
  bash "$scripts_dir/check-spec-floor.sh" "$fx/floor-green.md"
expect_exit "check-spec-floor.sh red" nonzero \
  bash "$scripts_dir/check-spec-floor.sh" "$fx/floor-red.md"

expect_exit "check-live-bearing.sh green" zero \
  bash "$scripts_dir/check-live-bearing.sh" "$fx/live-green.md"
expect_exit "check-live-bearing.sh red" nonzero \
  bash "$scripts_dir/check-live-bearing.sh" "$fx/live-red.md"

expect_exit "check-evidence-reckoning.sh green" zero \
  bash "$scripts_dir/check-evidence-reckoning.sh" "$fx/reckoning-index-green.md" "$fx/reckoning-spec.md"
expect_exit "check-evidence-reckoning.sh red" nonzero \
  bash "$scripts_dir/check-evidence-reckoning.sh" "$fx/reckoning-index-red.md" "$fx/reckoning-spec.md"

expect_exit "design-review-precheck.sh green" zero \
  bash "$scripts_dir/design-review-precheck.sh" "$fx/floor-green.md"
expect_exit "design-review-precheck.sh red" nonzero \
  bash "$scripts_dir/design-review-precheck.sh" "$fx/floor-red.md"

# classify_command: source the hook (its source-guard skips main when sourced)
# and probe the function directly on a real commit vs a non-git command.
# shellcheck source=/dev/null
source "$hooks_dir/run-project-checks.sh"

cc_out="$(classify_command 'git commit -m "msg"')"
if [ "$cc_out" = "pre-commit" ]; then
  echo "PASS: run-project-checks.sh classify_command(commit)"
else
  echo "FAIL: run-project-checks.sh classify_command(commit) -> '$cc_out'"; fail=1
fi

cc_out="$(classify_command 'ls -la')"
if [ "$cc_out" = "none" ]; then
  echo "PASS: run-project-checks.sh classify_command(non-git)"
else
  echo "FAIL: run-project-checks.sh classify_command(non-git) -> '$cc_out'"; fail=1
fi

exit "$fail"
