#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/.touchstone/checker/pre-commit/check-exec-bits-all.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }

# (a) checker exists and is executable
[ -f "$CHK" ] && ok "(a) checker file exists" || fail "(a) checker missing: $CHK"
[ -x "$CHK" ] && ok "(a) checker is executable" || fail "(a) checker not executable (check git index mode)"

# (b) clean committed tree exits 0
( cd "$REPO_ROOT" && bash "$CHK" ) >/dev/null 2>&1 \
  && ok "(b) clean tree -> exit 0" \
  || fail "(b) clean tree non-zero (exec-bit violation still present in this tree)"

# (c) detection — fixture git repo with a 100644 scripts/tests/*.sh
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/fixture"
mkdir -p "$FIX/scripts/tests"
( cd "$FIX" && git init -q \
  && printf '#!/usr/bin/env bash\nexit 0\n' > scripts/tests/detect.sh \
  && git add scripts/tests/detect.sh \
  && git commit -q -m init ) 2>/dev/null
# Verify the fixture file is indeed 100644 (default for `git add`)
_mode="$(cd "$FIX" && git ls-files -s scripts/tests/detect.sh | awk '{print $1}')"
[ "$_mode" = "100644" ] \
  && ok "(c) fixture precondition: detect.sh is 100644" \
  || fail "(c) fixture precondition failed: expected 100644, got '${_mode}'"
# Checker must exit non-zero on this fixture
TOUCHSTONE_CHECK_ROOT="$FIX" bash "$CHK" >/dev/null 2>&1 \
  && fail "(c) checker missed the 100644 violation (false-green)" \
  || ok "(c) checker detects 100644 scripts/tests/*.sh -> exit non-zero"

echo "== test-check-exec-bits-all: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
