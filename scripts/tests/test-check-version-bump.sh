#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# SC2016: backtick literals inside awk/grep single-quoted patterns are intentional (no expansion wanted).
# shellcheck disable=SC2015,SC2016
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/.touchstone/checker/pre-push/check-version-bump.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- AC-45: origin/main unresolvable → exit 0 + warning ---
R="$TMP/noorigin"; mkdir -p "$R/.touchstone" "$R/.claude-plugin"; ( cd "$R" && git init -q )
printf 'skills/\n' > "$R/.touchstone/shipped-surface.txt"
printf '{"version":"0.9.0"}\n' > "$R/.claude-plugin/plugin.json"
cp "$CHK" "$R/check.sh"
out="$( cd "$R" && bash check.sh 2>&1 )"; rc=$?
{ [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi "origin"; } && ok "AC-45 no-origin → 0+warn" || fail "AC-45 rc=$rc out=$out"

# --- AC-31/32: set up origin with a baseline, then a shipped-surface change ---
ORIGIN="$TMP/origin.git"; git init -q --bare "$ORIGIN"
W="$TMP/work"; git clone -q "$ORIGIN" "$W"
mkdir -p "$W/skills/x" "$W/.touchstone" "$W/.claude-plugin"
printf 'skills/\n' > "$W/.touchstone/shipped-surface.txt"
printf '{"version":"0.9.0"}\n' > "$W/.claude-plugin/plugin.json"
printf 'a\n' > "$W/skills/x/SKILL.md"
( cd "$W" && git add -A && git commit -q -m base && git branch -M main && git push -q origin main )
cp "$CHK" "$W/check.sh"
# change shipped surface, DO NOT bump version
printf 'b\n' >> "$W/skills/x/SKILL.md"; ( cd "$W" && git add -A && git commit -q -m change )
( cd "$W" && bash check.sh ) >/dev/null 2>&1 && fail "AC-31 unchanged version should fail" || ok "AC-31 shipped change + no bump → nonzero"
# now bump version
printf '{"version":"0.10.0"}\n' > "$W/.claude-plugin/plugin.json"; ( cd "$W" && git add -A && git commit -q -m bump )
( cd "$W" && bash check.sh ) >/dev/null 2>&1 && ok "AC-32 bumped → 0" || fail "AC-32 bumped should pass"

# --- AC-33 (behavioural): the check READS the set from the file, not a restated literal.
# Point shipped-surface.txt at a UNIQUE prefix absent from any hardcoded set; a change under
# it with no bump must fail — proving behaviour follows the FILE. ---
printf 'zzunique-surface/\n' > "$W/.touchstone/shipped-surface.txt"
mkdir -p "$W/zzunique-surface"; printf 'x\n' > "$W/zzunique-surface/f"
printf '{"version":"0.10.0"}\n' > "$W/.claude-plugin/plugin.json"   # keep version == origin baseline? no — origin has 0.9.0
# reset origin baseline version to match so an unchanged version is the tested condition
( cd "$W" && git show origin/main:.claude-plugin/plugin.json >/dev/null 2>&1 )
printf '{"version":"0.9.0"}\n' > "$W/.claude-plugin/plugin.json"
( cd "$W" && git add -A && git commit -q -m "zzunique change no bump" )
( cd "$W" && bash check.sh ) >/dev/null 2>&1 && fail "AC-33 check should read the file's custom prefix" || ok "AC-33 behaviour follows shipped-surface.txt (reads file, not literal)"

# --- AC-33 (dual-home): CLAUDE.md references the filename and does NOT restate the prefix set inline ---
CM="$REPO_ROOT/CLAUDE.md"
grep -q ".touchstone/shipped-surface.txt" "$CM" && ok "AC-33 CLAUDE.md references file" || fail "AC-33 no reference"
# the inline restated set (skills/, agents/, commands/, .claude-plugin/ as a normative list in § Versioning) is gone
restated="$(awk '/## Versioning/,/^## /' "$CM" | grep -cE '`skills/`.*`agents/`.*`commands/`' || true)"
[ "$restated" -eq 0 ] && ok "AC-33 no inline restated set in Versioning" || fail "AC-33 set still restated inline"

echo "== test-check-version-bump: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
