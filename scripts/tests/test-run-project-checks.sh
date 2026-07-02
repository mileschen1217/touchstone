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
  CAP="$(printf '%s' "$payload" | "$HANDLER" 2>&1)"; RC=$?
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

# rtk-wrapper end-to-end: an rtk-rewritten commit must still fire the repo's checks
# (regression for the first AC-13 live probe, which the rtk prefix silently bypassed).
R="$TMP/rtk"; mkrepo "$R"; addcheck "$R" pre-commit check-rtk.sh 1
fire "$R" 'rtk git commit -m x'
{ [ "$RC" -eq 2 ] && printf '%s' "$CAP" | grep -q "check-rtk.sh"; } \
  && ok "rtk-wrapped commit → checks fire + block" || fail "rtk wrapper rc=$RC cap=$CAP"

# FL-1: blocked commit → fire-log has 1 parseable event naming the check + stage (AC-11)
R="$TMP/fl1"; mkrepo "$R"; addcheck "$R" pre-commit check-fl1.sh 1
fire "$R" 'git commit -m x'
LOG="$R/.touchstone/ledger/fire-log.jsonl"
{ [ -f "$LOG" ] && [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 1 ] \
  && jq -e '.schema=="fire-event/v1" and .check=="check-fl1.sh" and .stage=="pre-commit" and (.ts|length>0) and (.repo|length>0)' "$LOG" >/dev/null 2>&1; } \
  && ok "FL-1 blocked commit → 1 parseable fire event naming check+stage" || fail "FL-1 log=$(cat "$LOG" 2>/dev/null)"

# FL-2a: ledger dir NEVER created (parent .touchstone chmod 555 before the first fire)
# → block still exit 2 named, no fire-log file, zero fire-log stderr (AC-12)
R="$TMP/fl2a"; mkrepo "$R"; addcheck "$R" pre-commit check-fl2.sh 1
chmod 555 "$R/.touchstone"
fire "$R" 'git commit -m x'; capB="$CAP"; rcB="$RC"
chmod 755 "$R/.touchstone"   # restore before trap cleanup
LOG="$R/.touchstone/ledger/fire-log.jsonl"
# exact-shape check: capB must be ONLY the 2 lines the check emits (FAIL header + check
# stdout) — nothing more. A loose substring grep (e.g. "permission denied|mkdir") misses
# other leaked fire_log stderr shapes, such as a bare append-redirect failure
# ("...: No such file or directory"); line-count pins the whole unwritable branch silent.
{ [ "$rcB" -eq 2 ] \
  && [ "$(printf '%s' "$capB" | grep -c '^')" -eq 2 ] \
  && printf '%s' "$capB" | sed -n '1p' | grep -q "check-fl2.sh" \
  && printf '%s' "$capB" | sed -n '2p' | grep -qx "check-fl2.sh ran" \
  && [ ! -f "$LOG" ]; } \
  && ok "FL-2a unwritable ledger dir never created → block still 2 named, no fire-log file, zero fire-log stderr" || fail "FL-2a rcB=$rcB capB=$capB log=$([ -f "$LOG" ] && echo present || echo absent)"

R="$TMP/fl2b"; mkrepo "$R"; addcheck "$R" pre-commit check-fl2p.sh 0
chmod 555 "$R/.touchstone"
fire "$R" 'git commit -m x'; rcP="$RC"; capP="$CAP"
chmod 755 "$R/.touchstone"
{ [ "$rcP" -eq 0 ] && ! printf '%s' "$capP" | grep -qi "permission denied\|mkdir"; } \
  && ok "FL-2b unwritable ledger dir, passing check → 0, zero fire-log stderr" || fail "FL-2b rc=$rcP cap=$capP"

# FL-3: two parallel direct executions with failing checks → 2 intact JSON lines (AC-23)
R="$TMP/fl3"; mkrepo "$R"; addcheck "$R" pre-commit check-fl3.sh 1
payload="$(jq -nc --arg c 'git commit -m x' --arg d "$R" \
  '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}')"
printf '%s' "$payload" | "$HANDLER" >/dev/null 2>&1 &
printf '%s' "$payload" | "$HANDLER" >/dev/null 2>&1 &
wait
LOG="$R/.touchstone/ledger/fire-log.jsonl"
lines=0; parsed_ok=1
if [ -f "$LOG" ]; then
  lines="$(wc -l < "$LOG" | tr -d ' ')"
  while IFS= read -r ln; do jq -e . >/dev/null 2>&1 <<<"$ln" || parsed_ok=0; done < "$LOG"
fi
{ [ "$lines" -eq 2 ] && [ "$parsed_ok" -eq 1 ]; } \
  && ok "FL-3 concurrent hook fires → 2 intact JSON lines" || fail "FL-3 lines=$lines log=$(cat "$LOG" 2>/dev/null)"

# FL-4: >512B repo path → fire-log line still ≤512 BYTES (wc -c) and still parses (AC-23 bound)
longpart="$(printf 'x%.0s' $(seq 1 50))"
P="$TMP/fl4"
for _i in $(seq 1 12); do P="$P/$longpart"; done
mkrepo "$P"; addcheck "$P" pre-commit check-fl4.sh 1
fire "$P" 'git commit -m x'
LOG="$P/.touchstone/ledger/fire-log.jsonl"
line="$(cat "$LOG" 2>/dev/null)"
bytes="$(printf '%s' "$line" | wc -c | tr -d ' ')"
{ [ -n "$line" ] && [ "$bytes" -le 512 ] && jq -e . >/dev/null 2>&1 <<<"$line"; } \
  && ok "FL-4 >512B repo path → line <=512 bytes, still parses" || fail "FL-4 bytes=$bytes line=$line"

# FL-5: symlink guard at BOTH levels → no fire-log write, block/pass semantics unchanged (Architecture)
# FL-5a: .touchstone itself is a symlink
R="$TMP/fl5a"; mkdir -p "$R"; ( cd "$R" && git init -q )
REAL="$TMP/fl5a-real"; mkdir -p "$REAL/checker/pre-commit"
printf '#!/usr/bin/env bash\necho "check-fl5a ran"\nexit 1\n' > "$REAL/checker/pre-commit/check-fl5a.sh"
chmod +x "$REAL/checker/pre-commit/check-fl5a.sh"
ln -s "$REAL" "$R/.touchstone"
fire "$R" 'git commit -m x'
{ [ "$RC" -eq 2 ] && printf '%s' "$CAP" | grep -q "check-fl5a.sh" && [ ! -e "$REAL/ledger" ]; } \
  && ok "FL-5a .touchstone symlinked → no fire-log write, block unaffected" || fail "FL-5a rc=$RC cap=$CAP"

# FL-5b: .touchstone/ledger is a symlink
R="$TMP/fl5b"; mkrepo "$R"; addcheck "$R" pre-commit check-fl5b.sh 1
TARGET="$TMP/fl5b-ledger-target"; mkdir -p "$TARGET"
ln -s "$TARGET" "$R/.touchstone/ledger"
fire "$R" 'git commit -m x'
{ [ "$RC" -eq 2 ] && printf '%s' "$CAP" | grep -q "check-fl5b.sh" && [ -z "$(ls -A "$TARGET" 2>/dev/null)" ]; } \
  && ok "FL-5b .touchstone/ledger symlinked → no fire-log write, block unaffected" || fail "FL-5b rc=$RC cap=$CAP"

echo "== test-run-project-checks: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
