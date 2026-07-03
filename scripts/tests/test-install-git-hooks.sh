#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install-git-hooks.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# helper: init a bare repo and return its path
mkrepo() {
  local d="$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name T )
  printf '%s' "$d"
}

# helper: add a checker fixture with given exit code
addcheck() {
  local repo="$1" stage="$2" name="$3" exit_code="$4"
  local dir="$repo/.touchstone/checker/$stage"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\necho "%s ran"\nexit %s\n' "$name" "$exit_code" > "$dir/$name"
  chmod +x "$dir/$name"
}

# run the installer inside a given repo
run_install() {
  local repo="$1"
  ( cd "$repo" && bash "$INSTALL" >/dev/null 2>&1 )
  return $?
}

# --- (a) hooks installed and executable ---
R="$TMP/repo-a"; mkrepo "$R" >/dev/null
run_install "$R"; rc=$?
[ "$rc" -eq 0 ] && ok "(a) installer exits 0" || fail "(a) installer exited $rc"
hooks_dir="$( cd "$R" && git rev-parse --git-path hooks )"
case "$hooks_dir" in /*) ;; *) hooks_dir="$R/$hooks_dir" ;; esac
[ -f "$hooks_dir/pre-commit" ] && ok "(a) pre-commit file exists" || fail "(a) pre-commit missing"
[ -f "$hooks_dir/pre-push" ]   && ok "(a) pre-push file exists"   || fail "(a) pre-push missing"
[ -x "$hooks_dir/pre-commit" ] && ok "(a) pre-commit executable"  || fail "(a) pre-commit not +x"
[ -x "$hooks_dir/pre-push" ]   && ok "(a) pre-push executable"    || fail "(a) pre-push not +x"
grep -qF 'installed-by: touchstone install-git-hooks' "$hooks_dir/pre-commit" \
  && ok "(a) marker present in pre-commit" || fail "(a) marker missing in pre-commit"

# --- (b) violating checker → git commit blocked ---
R="$TMP/repo-b"; mkrepo "$R" >/dev/null
run_install "$R"
# git -c core.hooksPath drives the real pre-commit hook from that dir
hdir="$( cd "$R" && git rev-parse --git-path hooks )"
case "$hdir" in /*) ;; *) hdir="$R/$hdir" ;; esac
( cd "$R" && git commit --allow-empty -m seed -q )   # seed commit so HEAD exists
before="$( cd "$R" && git rev-parse HEAD )"
[ -n "$before" ] \
  && ok "(b) seed commit succeeded (HEAD non-empty)" \
  || fail "(b) seed commit FAILED — HEAD empty; blocking assertion skipped"
addcheck "$R" pre-commit check-bad.sh 1
( cd "$R" && git -c core.hooksPath="$hdir" commit --allow-empty -m blocked >/dev/null 2>&1 )
after="$( cd "$R" && git rev-parse HEAD )"
[ "$before" = "$after" ] \
  && ok "(b) failing checker blocks git commit (HEAD unchanged)" \
  || fail "(b) commit was NOT blocked (HEAD advanced)"

# --- (c) idempotent: re-run produces exactly one marker ---
R="$TMP/repo-c"; mkrepo "$R" >/dev/null
run_install "$R"; run_install "$R"; run_install "$R"
hdir="$( cd "$R" && git rev-parse --git-path hooks )"
case "$hdir" in /*) ;; *) hdir="$R/$hdir" ;; esac
count="$(grep -c 'installed-by: touchstone install-git-hooks' "$hdir/pre-commit" 2>/dev/null || echo 0)"
[ "$count" -eq 1 ] \
  && ok "(c) idempotent: exactly one marker after 3 runs" \
  || fail "(c) $count markers in pre-commit after 3 runs"

# --- (d) foreign hook → refuses to overwrite ---
R="$TMP/repo-d"; mkrepo "$R" >/dev/null
hdir="$( cd "$R" && git rev-parse --git-path hooks )"
case "$hdir" in /*) ;; *) hdir="$R/$hdir" ;; esac
mkdir -p "$hdir"
printf '#!/usr/bin/env bash\nexit 0\n' > "$hdir/pre-commit"
chmod +x "$hdir/pre-commit"
out="$( cd "$R" && bash "$INSTALL" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] \
  && ok "(d) installer exits non-zero when foreign hook exists" \
  || fail "(d) installer exited 0 — should have refused"
printf '%s' "$out" | grep -qi 'skip\|existing\|marker\|foreign\|remove\|rename' \
  && ok "(d) output explains how to proceed" \
  || fail "(d) no guidance in output: $out"
# original hook is unchanged
grep -qF 'installed-by' "$hdir/pre-commit" \
  && fail "(d) installer overwrote the foreign hook" \
  || ok "(d) foreign hook content preserved"

# --- (e) no checker directory (or empty) → hook exits 0 ---
R="$TMP/repo-e"; mkrepo "$R" >/dev/null
run_install "$R"
hdir="$( cd "$R" && git rev-parse --git-path hooks )"
case "$hdir" in /*) ;; *) hdir="$R/$hdir" ;; esac
# Case 1: .touchstone/checker/pre-commit/ is entirely absent
( cd "$R" && bash "$hdir/pre-commit" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ] \
  && ok "(e) hook exits 0 when checker directory absent" \
  || fail "(e) hook exited $rc with no checker dir (want 0)"
# Case 2: .touchstone/checker/pre-commit/ exists but is empty
mkdir -p "$R/.touchstone/checker/pre-commit"
( cd "$R" && bash "$hdir/pre-commit" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ] \
  && ok "(e) hook exits 0 when checker directory empty" \
  || fail "(e) hook exited $rc with empty checker dir (want 0)"

echo ""
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
