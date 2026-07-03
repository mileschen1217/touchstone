#!/usr/bin/env bash
# replay-run.sh suite: fires-vs-hits over a bounded window; mid-range error.
# Spec joins: AC-10 (+ Error Handling: replay script errors mid-range).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RR="$REPO_ROOT/scripts/proposal/replay-run.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
[ -x "$RR" ] && ok "exec bit: replay-run.sh" || fail "exec bit"

# fixture repo: 3 commits; commits 2 and 3 carry a MARKER file (failing state)
FR="$TMP/fixrepo"; mkdir -p "$FR"; git -C "$FR" init -q
git -C "$FR" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c1
touch "$FR/MARKER"; git -C "$FR" add MARKER
git -C "$FR" -c user.email=t@t -c user.name=t commit -q -m c2
echo x > "$FR/MARKER"; git -C "$FR" add MARKER
git -C "$FR" -c user.email=t@t -c user.name=t commit -q -m c3
SHA2="$(git -C "$FR" rev-parse HEAD~1)"
SHA3="$(git -C "$FR" rev-parse HEAD)"

# ledger: one entry whose git evidence names SHA2 (so SHA3's fire is unmatched)
L="$TMP/ledger"; mkdir -p "$L"
jq -nc --arg ref "git:$SHA2" '{schema:"catch-miss/v1", id:"e1", ts:"2026-07-01T00:00:00Z",
  caught_by:"human", should_have:"design-review", gap_class:"missing-AC", what:"w",
  evidence:[{kind:"git", ref:$ref}], source:"label"}' > "$L/entries.jsonl"

# sidecar replay.sh: fire when the commit tree contains MARKER
P="$TMP/sidecar"; mkdir -p "$P"
cat > "$P/replay.sh" <<'EOS'
#!/usr/bin/env bash
sha="$1"
if git ls-tree -r --name-only "$sha" | grep -qx MARKER; then
  echo "$sha fire"
else
  echo "$sha pass"
fi
EOS

OUT="$(cd "$FR" && TOUCHSTONE_LEDGER_DIR="$L" bash "$RR" "$P" "HEAD~2..HEAD")"
rc=$?
[ "$rc" -eq 0 ] && ok "AC-10 replay exits 0" || fail "AC-10 rc=$rc"
echo "$OUT" | grep -q '^fires=2 hits=1$' && ok "AC-10 fires=2 hits=1" || fail "AC-10 counts: $OUT"
echo "$OUT" | grep -q "^unmatched fire: $SHA3$" && ok "AC-10 unmatched sample named" || fail "AC-10 sample"

# mid-range error: replay.sh non-zero on a commit → failing sha named, non-zero
cat > "$P/replay.sh" <<'EOS'
#!/usr/bin/env bash
exit 3
EOS
ERR="$(cd "$FR" && TOUCHSTONE_LEDGER_DIR="$L" bash "$RR" "$P" "HEAD~1..HEAD" 2>&1 >/dev/null)"
rc=$?
[ "$rc" -ne 0 ] && echo "$ERR" | grep -q "failed at $SHA3" \
  && ok "mid-range error names sha, exits non-zero" || fail "mid-range: rc=$rc '$ERR'"

# regression: a sidecar printing MULTIPLE lines (e.g. one per commit instead
# of one for the requested sha) must not be silently trailing-token parsed —
# that undercounts fires to 0. Require exactly one line, else malformed +
# non-zero, naming the sha.
cat > "$P/replay.sh" <<'EOS'
#!/usr/bin/env bash
sha="$1"
echo "$sha fire"
echo "$sha pass"
EOS
ERR="$(cd "$FR" && TOUCHSTONE_LEDGER_DIR="$L" bash "$RR" "$P" "HEAD~1..HEAD" 2>&1 >/dev/null)"
rc=$?
[ "$rc" -ne 0 ] && echo "$ERR" | grep -q "malformed output at $SHA3" \
  && ok "regression: multi-line sidecar output rejected, sha named (not fires=0)" || fail "regression multi-line: rc=$rc '$ERR'"

# regression: replay-run.sh's read-only commitment is enforced by detection —
# a sidecar replay.sh that mutates the working tree must abort non-zero.
cat > "$P/replay.sh" <<'EOS'
#!/usr/bin/env bash
sha="$1"
touch "mutated-by-replay"
echo "$sha pass"
EOS
ERR="$(cd "$FR" && TOUCHSTONE_LEDGER_DIR="$L" bash "$RR" "$P" "HEAD~1..HEAD" 2>&1 >/dev/null)"
rc=$?
[ "$rc" -ne 0 ] && echo "$ERR" | grep -q "mutated the working tree" \
  && ok "regression: sidecar mutation detected, replay aborted" || fail "regression mutation: rc=$rc '$ERR'"
rm -f "$FR/mutated-by-replay"

# missing replay.sh → non-zero (declared-path routing)
rm "$P/replay.sh"
(cd "$FR" && TOUCHSTONE_LEDGER_DIR="$L" bash "$RR" "$P" "HEAD~1..HEAD" >/dev/null 2>&1) \
  && fail "missing replay.sh must be non-zero" || ok "missing replay.sh exits non-zero"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
