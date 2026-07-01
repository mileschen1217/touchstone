#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }

# scan <checker-root> -> prints one finding per stray/misplaced/non-exec entry; exit reflects findings
scan() {
  local root="$1" found=0
  [ -d "$root" ] || return 0
  for entry in "$root"/*; do
    [ -e "$entry" ] || continue
    base="$(basename "$entry")"
    if [ -d "$entry" ]; then
      case "$base" in
        pre-commit|pre-push) : ;;
        *) echo "[stray-subdir] $entry"; found=1 ;;
      esac
    else
      echo "[stray-file] $entry (checks must live under a stage subdir)"; found=1
    fi
  done
  for stage in pre-commit pre-push; do
    for chk in "$root/$stage"/check-*.sh; do
      [ -e "$chk" ] || continue
      [ -x "$chk" ] || { echo "[non-executable] $chk"; found=1; }
    done
  done
  return "$found"
}

# AC-21: the live tree (valid-only) → no finding
scan "$REPO_ROOT/.touchstone/checker" >/dev/null 2>&1 && ok "AC-21 live tree clean" || fail "AC-21 live tree has structure findings"

# AC-20: unrecognised subdir flagged (fixture)
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/precommit"   # typo
out="$(scan "$TMP" 2>&1)"; printf '%s' "$out" | grep -q "stray-subdir" && ok "AC-20 typo subdir flagged" || fail "AC-20 out=$out"

# AC-22a: stray file directly under checker/ flagged
mkdir -p "$TMP/pre-commit"; printf 'x' > "$TMP/check-loose.sh"
out="$(scan "$TMP" 2>&1)"; printf '%s' "$out" | grep -q "stray-file" && ok "AC-22 stray file flagged" || fail "AC-22a out=$out"
rm -f "$TMP/check-loose.sh"; rm -rf "$TMP/precommit"

# AC-22b: non-executable check flagged
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/pre-commit/check-x.sh"   # not chmod +x
out="$(scan "$TMP" 2>&1)"; printf '%s' "$out" | grep -q "non-executable" && ok "AC-22 non-exec flagged" || fail "AC-22b out=$out"

echo "== test-checker-structure: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
