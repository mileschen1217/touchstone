#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BOOT="$REPO_ROOT/scripts/init-checker-scaffold.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
mk() { local d; d="$(mktemp -d)"; ( cd "$d" && git init -q ); echo "$d"; }
trackable() { ( cd "$1" && ! git check-ignore -q .touchstone/checker/pre-commit/.gitkeep ); }
carve_order_ok() { # !checker lines appear AFTER .touchstone/*
  awk '/^\.touchstone\/\*$/{seen=1} /^!\.touchstone\/checker\//{if(!seen){print "BAD"; exit}}' "$1/.gitignore" | grep -q BAD && return 1 || return 0
}

# AC-34: fresh, .gitignore already has .touchstone/*
d="$(mk)"; printf '.touchstone/*\n' > "$d/.gitignore"; bash "$BOOT" "$d"
{ [ -f "$d/.touchstone/checker/pre-commit/.gitkeep" ] && [ -f "$d/.touchstone/checker/pre-push/.gitkeep" ] && trackable "$d"; } \
  && ok "AC-34 fresh bootstrap trackable" || fail "AC-34"

# AC-35: no .gitignore → created with canonical 3 lines in order
d="$(mk)"; bash "$BOOT" "$d"; { [ -f "$d/.gitignore" ] && trackable "$d" && carve_order_ok "$d"; } && ok "AC-35 gitignore created" || fail "AC-35"

# AC-36: idempotent from fully bootstrapped → no dup of any of the 3 lines
d="$(mk)"; bash "$BOOT" "$d"; bash "$BOOT" "$d"
fail36=0
for pat in '.touchstone/\*' '!.touchstone/checker/$' '!.touchstone/checker/\*\*'; do
  n="$(grep -cE "^$pat" "$d/.gitignore")"; [ "$n" -eq 1 ] || { fail "AC-36 line '$pat' x$n"; fail36=1; }
done
[ "$fail36" -eq 0 ] && ok "AC-36 idempotent no dup"

# AC-37: missing .gitkeep re-added
d="$(mk)"; bash "$BOOT" "$d"; rm "$d/.touchstone/checker/pre-commit/.gitkeep"; bash "$BOOT" "$d"
[ -f "$d/.touchstone/checker/pre-commit/.gitkeep" ] && ok "AC-37 gitkeep re-added" || fail "AC-37"

# AC-38: parent ignore present, carve absent → adds carve only, no dup parent
d="$(mk)"; printf '.touchstone/*\n' > "$d/.gitignore"; bash "$BOOT" "$d"
{ [ "$(grep -cE '^\.touchstone/\*$' "$d/.gitignore")" -eq 1 ] && trackable "$d"; } && ok "AC-38 carve added, no dup" || fail "AC-38"

# AC-39: one stage dir missing → added
d="$(mk)"; bash "$BOOT" "$d"; rm -rf "$d/.touchstone/checker/pre-push"; bash "$BOOT" "$d"
[ -d "$d/.touchstone/checker/pre-push" ] && ok "AC-39 missing stage added" || fail "AC-39"

# AC-42: carve BEFORE parent (inert) → reordered after
d="$(mk)"; printf '!.touchstone/checker/\n!.touchstone/checker/**\n.touchstone/*\n' > "$d/.gitignore"
mkdir -p "$d/.touchstone/checker/pre-commit"; bash "$BOOT" "$d"
{ carve_order_ok "$d" && trackable "$d"; } && ok "AC-42 reordered" || fail "AC-42"

# Regression pin: the blanket `.touchstone/*` rule the scaffold writes already
# covers `.touchstone/ledger/` transitively — no scaffold change carves an
# exception for it (unlike checker/, above). If this ever goes red, the
# blanket rule was narrowed and the ledger dir needs an explicit gitignore line.
d="$(mk)"; bash "$BOOT" "$d"
( cd "$d" && git check-ignore -q .touchstone/ledger/entries.jsonl ) \
  && ok "ledger-dir-gitignored-via-blanket-rule" || fail "ledger-dir-gitignored-via-blanket-rule"

# G4-3: workspace_root: .swarm → gitignore contains .swarm/* AND !.touchstone/checker/
d="$(mk)"; mkdir -p "$d/.claude"; printf 'workspace_root: .swarm\n' > "$d/.claude/touchstone.yaml"
bash "$BOOT" "$d"
{ grep -qxF '.swarm/*' "$d/.gitignore" && grep -qxF '!.touchstone/checker/' "$d/.gitignore"; } \
  && ok "G4-3 ws_root .swarm: .swarm/* and !.touchstone/checker/ present" || fail "G4-3 ws_root .swarm"

echo "== test-init-checker-scaffold: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
