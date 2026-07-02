#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK_DIR="$REPO_ROOT/.touchstone/checker/pre-commit"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
CHECKS="check-adr-cite.sh check-inject-dual-home.sh check-anvil-stage-name.sh check-no-stamped-evidence.sh check-orphan-check.sh check-adr-number-unique.sh"

# AC-29: each exists + executable
for c in $CHECKS; do
  [ -x "$CHK_DIR/$c" ] && ok "AC-29 $c exists+exec" || fail "AC-29 $c missing/not-exec"
done

# AC-28: each passes on the clean committed tree
for c in $CHECKS; do
  ( cd "$REPO_ROOT" && bash "$CHK_DIR/$c" ) >/dev/null 2>&1 && ok "AC-28 $c clean→0" || fail "AC-28 $c nonzero on clean tree"
done

# AC-30: each detects its target violation on crafted input (checks accept an
# optional $TOUCHSTONE_CHECK_ROOT override so the test can point them at a fixture tree).
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
detect() { # <check> <setup-fn>
  local c="$1" setup="$2"; local root="$TMP/$c"; mkdir -p "$root"; "$setup" "$root"
  TOUCHSTONE_CHECK_ROOT="$root" bash "$CHK_DIR/$c" >/dev/null 2>&1 && return 1 || return 0
}
setup_adr() { mkdir -p "$1/skills/x"; printf 'see ADR-1234 for why\n' > "$1/skills/x/SKILL.md"; }
detect check-adr-cite.sh setup_adr && ok "AC-30 adr-cite detects" || fail "AC-30 adr-cite miss"

setup_anvil() {
  mkdir -p "$1/skills/anvil" "$1/scripts"
  printf 'STAGES = {"entry-precondition", "plan-review", "final-review"}\n' > "$1/scripts/check-stage-return.py"
  # shellcheck disable=SC2016  # "$d" literal is intentional: fixture writes it as text, not a shell expansion
  printf 'bash scripts/normalize-stage-return.sh bogus-stage "$d"\n' > "$1/skills/anvil/SKILL.md"
}
detect check-anvil-stage-name.sh setup_anvil && ok "AC-30 anvil-stage-name detects" || fail "AC-30 anvil-stage miss"

setup_stamped() { mkdir -p "$1/scripts/tests/transcripts"; printf 'x\n' > "$1/scripts/tests/transcripts/deadbeef1234-review.md"; ( cd "$1" && git init -q && git add -A && git commit -q -m x ); }
detect check-no-stamped-evidence.sh setup_stamped && ok "AC-30 no-stamped-evidence detects" || fail "AC-30 stamped miss"

setup_adrdup() { mkdir -p "$1/docs/adr"; printf 'a\n' > "$1/docs/adr/0007-one.md"; printf 'b\n' > "$1/docs/adr/0007-two.md"; }
detect check-adr-number-unique.sh setup_adrdup && ok "AC-30 adr-number-unique detects" || fail "AC-30 adr-dup miss"

setup_dualhome() { # a fragment + a consumer restating ≥2 of its sentinel lines
  mkdir -p "$1/skills/_shared/inject" "$1/skills/x"
  printf '# frag\n\nThe cold reviewer cannot see CONTEXT so every lens must be injected verbatim here.\nA union review grounds each lens to equal depth or it ships the design-soundness gap.\n' > "$1/skills/_shared/inject/frag.md"
  printf '# consumer\n\nThe cold reviewer cannot see CONTEXT so every lens must be injected verbatim here.\nA union review grounds each lens to equal depth or it ships the design-soundness gap.\n' > "$1/skills/x/SKILL.md"
}
detect check-inject-dual-home.sh setup_dualhome && ok "AC-30 inject-dual-home detects" || fail "AC-30 dual-home miss"

setup_orphan() { mkdir -p "$1/.touchstone/checker"; printf '#!/usr/bin/env bash\nexit 0\n' > "$1/.touchstone/checker/check-loose.sh"; chmod +x "$1/.touchstone/checker/check-loose.sh"; }
detect check-orphan-check.sh setup_orphan && ok "AC-30 orphan-check detects" || fail "AC-30 orphan miss"

echo "== test-touchstone-checks: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
