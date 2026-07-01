#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HANDLER="$REPO_ROOT/hooks/run-project-checks.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# fire <cwd> <command> -> sets RC and CAP (captured stderr)
fire() {
  local cwd="$1" cmd="$2"
  local payload; payload="$(jq -nc --arg c "$cmd" --arg d "$cwd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}')"
  CAP="$(printf '%s' "$payload" | bash "$HANDLER" 2>&1)"; RC=$?
}
mkrepo() { local d="$1"; mkdir -p "$d"; ( cd "$d" && git init -q ); }
addcheck() { # <repo> <stage> <name> <exit>
  local dir="$1/.touchstone/checker/$2"; mkdir -p "$dir"
  printf '#!/usr/bin/env bash\necho "%s ran"\nexit %s\n' "$3" "$4" > "$dir/$3"; chmod +x "$dir/$3"
}

# AC-1: clean pre-commit → exit 0
R="$TMP/a"; mkrepo "$R"; addcheck "$R" pre-commit check-ok.sh 0
fire "$R" 'git commit -m x'; [ "$RC" -eq 0 ] && ok "AC-1 clean → 0" || fail "AC-1 got rc=$RC"

# AC-2: failing pre-commit → exit 2, names the check, surfaces BOTH streams, and
# (proxy for) no commit object created — we drive a real `git commit` ONLY when the
# handler exits 0, so a blocked handler leaves HEAD unchanged.
# NOTE: the "no new commit object" clause is co-discharged by the live-bearing AC-13
# (the real CC exit-2-blocks-the-tool contract) — this offline test proves the handler
# decision (exit 2 + named + both streams), and simulates the block by gating the commit.
R="$TMP/b"; mkrepo "$R"; addcheck "$R" pre-commit check-foo.sh 1
# make the check emit to BOTH stdout and stderr so we can assert both are surfaced
printf '#!/usr/bin/env bash\necho "foo-stdout"\necho "foo-stderr" >&2\nexit 1\n' > "$R/.touchstone/checker/pre-commit/check-foo.sh"; chmod +x "$R/.touchstone/checker/pre-commit/check-foo.sh"
( cd "$R" && git commit -q --allow-empty -m seed )   # a baseline HEAD to compare against
before="$( cd "$R" && git rev-parse HEAD )"
fire "$R" 'git commit -m x'
[ "$RC" -eq 0 ] && ( cd "$R" && git commit -q --allow-empty -m x )   # only commit if handler allowed
after="$( cd "$R" && git rev-parse HEAD )"
{ [ "$RC" -eq 2 ] \
  && printf '%s' "$CAP" | grep -q "check-foo.sh" \
  && printf '%s' "$CAP" | grep -q "foo-stdout" \
  && printf '%s' "$CAP" | grep -q "foo-stderr" \
  && [ "$before" = "$after" ]; } \
  && ok "AC-2 fail → 2 + named + both streams + no new commit" || fail "AC-2 rc=$RC before=$before after=$after cap=$CAP"

# AC-3: fail-fast — check-a fails, check-b must not run
R="$TMP/c"; mkrepo "$R"; addcheck "$R" pre-commit check-a.sh 1; addcheck "$R" pre-commit check-b.sh 0
fire "$R" 'git commit -m x'
printf '%s' "$CAP" | grep -q "check-a.sh" && ! printf '%s' "$CAP" | grep -q "check-b.sh ran" \
  && ok "AC-3 fail-fast" || fail "AC-3 cap=$CAP"

# AC-4: stage dispatch — commit runs only pre-commit
R="$TMP/d"; mkrepo "$R"; addcheck "$R" pre-commit check-c.sh 1; addcheck "$R" pre-push check-p.sh 1
fire "$R" 'git commit -m x'; printf '%s' "$CAP" | grep -q "check-c.sh" && ! printf '%s' "$CAP" | grep -q "check-p.sh" \
  && ok "AC-4 commit→pre-commit only" || fail "AC-4a cap=$CAP"
fire "$R" 'git push'
{ printf '%s' "$CAP" | grep -q "check-p.sh" && ! printf '%s' "$CAP" | grep -q "check-c.sh"; } \
  && ok "AC-4 push→pre-push only" || fail "AC-4b cap=$CAP"

# AC-5: absent pre-commit stage → passthrough; present failing pre-push → 2
R="$TMP/e"; mkrepo "$R"; addcheck "$R" pre-push check-p.sh 1
fire "$R" 'git commit -m x'; [ "$RC" -eq 0 ] && ok "AC-5 absent stage → 0" || fail "AC-5a rc=$RC"
fire "$R" 'git push'; [ "$RC" -eq 2 ] && ok "AC-5 present pre-push → 2" || fail "AC-5b rc=$RC"

# AC-6: multi-repo — cwd inside B runs B's checks not A's
A="$TMP/A"; B="$TMP/B"; mkrepo "$A"; mkrepo "$B"; addcheck "$A" pre-commit check-A.sh 1; addcheck "$B" pre-commit check-B.sh 1
fire "$B" 'git commit -m x'; printf '%s' "$CAP" | grep -q "check-B.sh" && ! printf '%s' "$CAP" | grep -q "check-A.sh" \
  && ok "AC-6 resolves cwd's repo" || fail "AC-6 cap=$CAP"

# AC-7: cwd not a repo → exit 0
fire "$TMP" 'git commit -m x'; [ "$RC" -eq 0 ] && ok "AC-7 non-repo cwd → 0" || fail "AC-7 rc=$RC"

# AC-9: git -C <abs> resolves from that path
R="$TMP/g"; mkrepo "$R"; addcheck "$R" pre-commit check-g.sh 1
fire "$TMP" "git -C $R commit -m x"; printf '%s' "$CAP" | grep -q "check-g.sh" \
  && ok "AC-9 -C abs resolves target" || fail "AC-9 cap=$CAP"

# AC-44: relative git -C ./sub resolves against payload cwd, not process cwd
R="$TMP/h"; mkrepo "$R/sub"; addcheck "$R/sub" pre-commit check-h.sh 1
fire "$R" 'git -C ./sub commit -m x'; printf '%s' "$CAP" | grep -q "check-h.sh" \
  && ok "AC-44 relative -C vs payload cwd" || fail "AC-44 cap=$CAP"

# AC-10: no checker dir → passthrough
R="$TMP/i"; mkrepo "$R"; fire "$R" 'git commit -m x'; [ "$RC" -eq 0 ] && ok "AC-10 no checker dir → 0" || fail "AC-10 rc=$RC"

# AC-11: non-git command → passthrough
R="$TMP/j"; mkrepo "$R"; addcheck "$R" pre-commit check-j.sh 1
fire "$R" 'ls -la'; [ "$RC" -eq 0 ] && ok "AC-11 non-git → 0" || fail "AC-11 rc=$RC"

# AC-12: checker dir present, zero check-*.sh → 0
R="$TMP/k"; mkrepo "$R"; mkdir -p "$R/.touchstone/checker/pre-commit"
fire "$R" 'git commit -m x'; [ "$RC" -eq 0 ] && ok "AC-12 zero-glob → 0" || fail "AC-12 rc=$RC"

# non-exec check → named block (exit 2), not silent run-via-bash
R="$TMP/nx"; mkrepo "$R"; mkdir -p "$R/.touchstone/checker/pre-commit"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/.touchstone/checker/pre-commit/check-nx.sh"   # NOT chmod +x
fire "$R" 'git commit -m x'
{ [ "$RC" -eq 2 ] && printf '%s' "$CAP" | grep -q "not executable"; } && ok "non-exec → named block" || fail "non-exec rc=$RC cap=$CAP"

# AC-8: worktree — .git is a file, resolve to worktree toplevel
R="$TMP/wtbase"; mkrepo "$R"; ( cd "$R" && git commit -q --allow-empty -m seed )
WT="$TMP/wt"; ( cd "$R" && git worktree add -q "$WT" -b wtbr ) 2>/dev/null
addcheck "$WT" pre-commit check-wt.sh 1
fire "$WT" 'git commit -m x'; printf '%s' "$CAP" | grep -q "check-wt.sh" \
  && ok "AC-8 worktree toplevel" || fail "AC-8 cap=$CAP"

echo "== test-run-project-checks: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
