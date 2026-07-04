#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# SC2034: some fixture commit shas (SHA_A, SHA_E1, SHA_E4) are captured to
# self-document the scenario (e.g. SHA_A must exist as the non-nearest
# non-fix candidate) without being asserted on directly.
# shellcheck disable=SC2015,SC2034
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
X="$REPO_ROOT/scripts/ledger/extract-git.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

DAY=86400

# mkrepo <name> — inits a fresh git repo at $TMP/<name>/repo, echoes its
# git-resolved toplevel path (macOS mktemp lives under a /tmp -> /private/tmp
# symlink; scan-state.json keys on git's resolved path, so tests must use
# the same resolved path for lookups, not the raw mktemp path).
mkrepo() {
  local r="$TMP/$1/repo"
  mkdir -p "$r"
  git -C "$r" init -q
  git -C "$r" config user.email t@t.com
  git -C "$r" config user.name t
  git -C "$r" rev-parse --show-toplevel
}

# commit_at <repo> <epoch> <subject> <file> <content-line> — appends a line
# to <file>, commits with author/committer date pinned to <epoch> (UTC),
# echoes the resulting commit sha.
commit_at() {
  local repo="$1" epoch="$2" subj="$3" file="$4" content="$5"
  printf '%s\n' "$content" >> "$repo/$file"
  git -C "$repo" add "$file"
  GIT_AUTHOR_DATE="@$epoch +0000" GIT_COMMITTER_DATE="@$epoch +0000" \
    git -C "$repo" commit -q -m "$subj"
  git -C "$repo" rev-parse HEAD
}

# --- AC-8: fix-chain pairing, chain collapse, window boundary ---
R="$(mkrepo ac8)"
T0=1700000000
SHA_A="$(commit_at  "$R" "$T0"              "feat: add f"                  f.sh "line-A")"
SHA_A2="$(commit_at "$R" "$((T0+1*DAY))"    "feat: touch f again"          f.sh "line-A2")"
SHA_B="$(commit_at  "$R" "$((T0+2*DAY))"    "fix: patch f"                 f.sh "line-B")"
SHA_C="$(commit_at  "$R" "$((T0+3*DAY))"    "fix: patch f more"            f.sh "line-C")"
SHA_D="$(commit_at  "$R" "$((T0+4*DAY))"    "fix: patch g only"            g.sh "line-D")"
SHA_F="$(commit_at  "$R" "$((T0+15*DAY))"   "fix: patch f at edge"         f.sh "line-F")"
SHA_E="$(commit_at  "$R" "$((T0+16*DAY))"   "fix: patch f outside window"  f.sh "line-E")"

LDIR="$TMP/ac8/ledger"
DIGEST="$TMP/ac8/digest.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --repo "$R" > "$DIGEST"
RC=$?
LC="$(grep -c . "$DIGEST")"
ANCHOR="$(jq -r '.payload.anchor_sha' "$DIGEST")"
CHAINLEN="$(jq -r '.payload.chain_len' "$DIGEST")"
FIXSHAS="$(jq -c '.payload.fix_shas' "$DIGEST")"

if [ "$RC" -eq 0 ] && [ "$LC" = 1 ] && [ "$ANCHOR" = "$SHA_A2" ] && [ "$CHAINLEN" = 3 ]; then
  ok "AC-8 exactly one record, anchor=A2, chain_len=3"
else
  fail "AC-8 record shape (rc=$RC lc=$LC anchor=$ANCHOR chainlen=$CHAINLEN want_anchor=$SHA_A2)"
fi

HAS_B="$(printf '%s' "$FIXSHAS" | jq --arg s "$SHA_B" 'index($s) != null')"
HAS_C="$(printf '%s' "$FIXSHAS" | jq --arg s "$SHA_C" 'index($s) != null')"
HAS_F="$(printf '%s' "$FIXSHAS" | jq --arg s "$SHA_F" 'index($s) != null')"
HAS_E="$(printf '%s' "$FIXSHAS" | jq --arg s "$SHA_E" 'index($s) != null')"
HAS_D="$(printf '%s' "$FIXSHAS" | jq --arg s "$SHA_D" 'index($s) != null')"
if [ "$HAS_B" = true ] && [ "$HAS_C" = true ] && [ "$HAS_F" = true ]; then
  ok "AC-8 fix_shas includes B, C, F"
else
  fail "AC-8 fix_shas includes B/C/F (has_b=$HAS_B has_c=$HAS_C has_f=$HAS_F fixshas=$FIXSHAS)"
fi
if [ "$HAS_E" = false ]; then
  ok "AC-8 E excluded (15d from nearest anchor A2, outside 14d window)"
else
  fail "AC-8 E should be excluded (has_e=$HAS_E)"
fi
if [ "$HAS_D" = false ]; then
  ok "AC-8 D excluded (no in-window non-fix anchor ever touched g.sh)"
else
  fail "AC-8 D should be excluded (has_d=$HAS_D)"
fi

PATHS="$(jq -c '.payload.paths' "$DIGEST")"
SUBJECTS="$(jq -c '.payload.subjects' "$DIGEST")"
PATHS_LEN="$(printf '%s' "$PATHS" | jq 'length')"
SUBJECTS_LEN="$(printf '%s' "$SUBJECTS" | jq 'length')"
if [ "$PATHS_LEN" -ge 1 ] && [ "$SUBJECTS_LEN" -ge 1 ]; then
  ok "AC-8 paths[] and subjects[] populated"
else
  fail "AC-8 paths/subjects populated (paths_len=$PATHS_LEN subjects_len=$SUBJECTS_LEN)"
fi

REF="$(jq -r '.ref' "$DIGEST")"
SOURCE="$(jq -r '.source' "$DIGEST")"
SCHEMA="$(jq -r '.schema' "$DIGEST")"
if [ "$REF" = "git:$SHA_A2" ] && [ "$SOURCE" = "git" ] && [ "$SCHEMA" = "digest/v1" ]; then
  ok "AC-8 digest/v1 envelope: schema, source, ref"
else
  fail "AC-8 envelope (ref=$REF source=$SOURCE schema=$SCHEMA)"
fi

# --- incremental-by-since: the caller (sweep-run) owns increment state as a
# single timestamp; extract-git filters emitted records by ANCHOR ts ---
R2="$(mkrepo since-inc)"
T0b=1710000000
SHA_E1="$(commit_at "$R2" "$T0b"           "feat: add x" x.sh "line-1")"
SHA_E2="$(commit_at "$R2" "$((T0b+1*DAY))" "fix: patch x" x.sh "line-2")"

TOUCHSTONE_LEDGER_DIR="$TMP/since-inc/ledger" "$X" --repo "$R2" > "$TMP/since-inc/digest1.jsonl"
LC1="$(grep -c . "$TMP/since-inc/digest1.jsonl")"

SHA_E3="$(commit_at "$R2" "$((T0b+2*DAY))" "feat: add y" y.sh "line-3")"
SHA_E4="$(commit_at "$R2" "$((T0b+3*DAY))" "fix: patch y" y.sh "line-4")"

# full stateless re-scan sees BOTH chains…
"$X" --repo "$R2" > "$TMP/since-inc/digest2-full.jsonl"
LC2_FULL="$(grep -c . "$TMP/since-inc/digest2-full.jsonl")"
# …and a --since bound after chain-1's anchor emits only the new chain.
SINCE_BOUND="$(python3 -c "import datetime;print(datetime.datetime.fromtimestamp($T0b+1*$DAY+3600, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null   || date -u -r $((T0b+1*DAY+3600)) +%Y-%m-%dT%H:%M:%SZ)"
"$X" --repo "$R2" --since "$SINCE_BOUND" > "$TMP/since-inc/digest2.jsonl"
LC2="$(grep -c . "$TMP/since-inc/digest2.jsonl")"
ANCHOR2="$(jq -r '.payload.anchor_sha' "$TMP/since-inc/digest2.jsonl")"

if [ "$LC1" = 1 ] && [ "$LC2_FULL" = 2 ]; then
  ok "incremental-by-since baseline: 1 chain first, 2 chains on a full stateless re-scan"
else
  fail "incremental-by-since baseline (lc1=$LC1 lc2_full=$LC2_FULL)"
fi

if [ "$LC2" = 1 ] && [ "$ANCHOR2" = "$SHA_E3" ]; then
  ok "incremental-by-since: --since after chain-1's anchor emits only the new chain"
else
  fail "incremental-by-since (lc2=$LC2 anchor2=$ANCHOR2 want_anchor=$SHA_E3)"
fi

# --- stateless: repeated runs never write any state file ---
LDIR2="$TMP/since-inc/ledger"
if [ ! -e "$LDIR2/scan-state.json" ]; then
  ok "stateless: no scan-state.json written by any run"
else
  fail "stateless (scan-state.json exists)"
fi

# --- window-shifted since (the sweep-run contract): a fix landing AFTER the
# last sweep still pairs with an anchor BEFORE it, because sweep-run passes
# --since = last-sweep MINUS the pairing window. A since bound between the
# anchor and the new fix filters the whole chain (anchor-ts filter — this is
# WHY the caller must shift); the shifted bound keeps it. ---
R5="$(mkrepo nolookback)"
T0e=1740000000
SHA_ANCHOR="$(commit_at "$R5" "$T0e"           "feat: add h"           h.sh "line-1")"
SHA_FIX1="$(commit_at   "$R5" "$((T0e+2*DAY))" "fix: patch h"          h.sh "line-2")"
SHA_FIX2="$(commit_at   "$R5" "$((T0e+7*DAY))" "fix: patch h again"    h.sh "line-3")"

# unshifted bound (a naive last-sweep at T0e+3d): chain filtered out.
BOUND_NAIVE="$(date -u -r $((T0e+3*DAY)) +%Y-%m-%dT%H:%M:%SZ)"
"$X" --repo "$R5" --since "$BOUND_NAIVE" > "$TMP/nolookback/naive.jsonl"
LC_NAIVE="$(grep -c . "$TMP/nolookback/naive.jsonl")"

# window-shifted bound (T0e+3d - 14d): chain emitted, includes the new fix.
BOUND_SHIFTED="$(date -u -r $((T0e+3*DAY-14*DAY)) +%Y-%m-%dT%H:%M:%SZ)"
"$X" --repo "$R5" --since "$BOUND_SHIFTED" > "$TMP/nolookback/shifted.jsonl"
LC_SHIFTED="$(grep -c . "$TMP/nolookback/shifted.jsonl")"
ANCHOR_SHIFTED="$(jq -r '.payload.anchor_sha' "$TMP/nolookback/shifted.jsonl")"
HAS_FIX2="$(jq -c '.payload.fix_shas' "$TMP/nolookback/shifted.jsonl" | jq --arg s "$SHA_FIX2" 'index($s) != null')"

if [ "$LC_NAIVE" = 0 ]; then
  ok "window-shift rationale: an unshifted since bound drops the old-anchor chain (anchor-ts filter)"
else
  fail "window-shift rationale (lc_naive=$LC_NAIVE)"
fi
if [ "$LC_SHIFTED" = 1 ] && [ "$ANCHOR_SHIFTED" = "$SHA_ANCHOR" ] && [ "$HAS_FIX2" = true ]; then
  ok "window-shifted since: pre-bound anchor's chain emitted, new fix included"
else
  fail "window-shifted since (lc=$LC_SHIFTED anchor=$ANCHOR_SHIFTED has_fix2=$HAS_FIX2)"
fi

# --- --since is read-only: no scan-state.json written ---
R4="$(mkrepo since)"
T0d=1730000000
commit_at "$R4" "$T0d" "feat: seed" w.sh "line-1" >/dev/null
commit_at "$R4" "$((T0d+1*DAY))" "fix: patch w" w.sh "line-2" >/dev/null
LDIR4="$TMP/since/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR4" "$X" --repo "$R4" --since "1970-01-01T00:00:00Z" > "$TMP/since/digest.jsonl"
RC4=$?
if [ "$RC4" -eq 0 ] && [ ! -e "$LDIR4/scan-state.json" ] && [ "$(grep -c . "$TMP/since/digest.jsonl")" = 1 ]; then
  ok "--since epoch-0 emits the chain and writes no state"
else
  fail "--since mode (rc=$RC4 lc=$(grep -c . "$TMP/since/digest.jsonl"))"
fi

echo "== $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
