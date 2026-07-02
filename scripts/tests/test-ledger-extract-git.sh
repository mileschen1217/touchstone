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

# --- AC-20: incremental re-scan (only the new chain, cursor advances) ---
R2="$(mkrepo ac20)"
T0b=1710000000
SHA_E1="$(commit_at "$R2" "$T0b"           "feat: add x" x.sh "line-1")"
SHA_E2="$(commit_at "$R2" "$((T0b+1*DAY))" "fix: patch x" x.sh "line-2")"

LDIR2="$TMP/ac20/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR2" "$X" --repo "$R2" > "$TMP/ac20/digest1.jsonl"
LC1="$(grep -c . "$TMP/ac20/digest1.jsonl")"
S1="$(jq -r --arg r "$R2" '.git[$r].last_swept' "$LDIR2/scan-state.json")"

SHA_E3="$(commit_at "$R2" "$((T0b+2*DAY))" "feat: add y" y.sh "line-3")"
SHA_E4="$(commit_at "$R2" "$((T0b+3*DAY))" "fix: patch y" y.sh "line-4")"

TOUCHSTONE_LEDGER_DIR="$LDIR2" "$X" --repo "$R2" > "$TMP/ac20/digest2.jsonl"
LC2="$(grep -c . "$TMP/ac20/digest2.jsonl")"
ANCHOR2="$(jq -r '.payload.anchor_sha' "$TMP/ac20/digest2.jsonl")"
S2="$(jq -r --arg r "$R2" '.git[$r].last_swept' "$LDIR2/scan-state.json")"
HEAD_R2="$(git -C "$R2" rev-parse HEAD)"

if [ "$LC1" = 1 ] && [ "$S1" != "null" ] && [ -n "$S1" ]; then
  ok "AC-20 first run: one chain recorded, last_swept committed"
else
  fail "AC-20 first run (lc1=$LC1 s1=$S1)"
fi

if [ "$LC2" = 1 ] && [ "$ANCHOR2" = "$SHA_E3" ] && [ "$S2" = "$HEAD_R2" ] && [ "$S2" != "$S1" ]; then
  ok "AC-20 incremental re-run: emits only the new chain, last_swept advances to HEAD"
else
  fail "AC-20 incremental re-run (lc2=$LC2 anchor2=$ANCHOR2 want_anchor=$SHA_E3 s2=$S2 head=$HEAD_R2 s1=$S1)"
fi

# unrelated shas must not leak from the (already-recorded) first chain
LEAK="$(jq -r '.payload.fix_shas[]' "$TMP/ac20/digest2.jsonl" | grep -F -x "$SHA_E2" || true)"
if [ -z "$LEAK" ]; then
  ok "AC-20 incremental re-run does not re-walk commits before last_swept"
else
  fail "AC-20 incremental re-run leaked pre-cursor commit ($LEAK)"
fi

# --- AC-20: unreachable last_swept -> window-bounded full rescan, digest
# equals a fresh scan over the same repo state ---
BOGUS="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
jq -c --arg r "$R2" --arg sha "$BOGUS" '.git[$r].last_swept = $sha' "$LDIR2/scan-state.json" > "$LDIR2/scan-state.json.tmp"
mv "$LDIR2/scan-state.json.tmp" "$LDIR2/scan-state.json"

TOUCHSTONE_LEDGER_DIR="$LDIR2" "$X" --repo "$R2" > "$TMP/ac20/digest3.jsonl"
LC3="$(grep -c . "$TMP/ac20/digest3.jsonl")"
S3="$(jq -r --arg r "$R2" '.git[$r].last_swept' "$LDIR2/scan-state.json")"

LDIR_FRESH="$TMP/ac20/ledger-fresh"
TOUCHSTONE_LEDGER_DIR="$LDIR_FRESH" "$X" --repo "$R2" > "$TMP/ac20/digest-fresh.jsonl"

SORTED3="$(jq -Sc . "$TMP/ac20/digest3.jsonl" | sort)"
SORTED_FRESH="$(jq -Sc . "$TMP/ac20/digest-fresh.jsonl" | sort)"

if [ "$LC3" = 2 ] && [ "$SORTED3" = "$SORTED_FRESH" ]; then
  ok "AC-20 unreachable last_swept: full rescan digest equals a fresh-scan digest"
else
  fail "AC-20 unreachable last_swept rescan (lc3=$LC3 equal=$([ "$SORTED3" = "$SORTED_FRESH" ] && echo yes || echo no))"
fi

if [ "$S3" = "$HEAD_R2" ]; then
  ok "AC-20 unreachable last_swept: recovers by advancing last_swept to HEAD"
else
  fail "AC-20 unreachable last_swept recovery (s3=$S3 head=$HEAD_R2)"
fi

# --- --propose-cursors: scan-state untouched, bare git-section proposal written ---
R3="$(mkrepo propose)"
T0c=1720000000
commit_at "$R3" "$T0c" "feat: seed" z.sh "line-1" >/dev/null
LDIR3="$TMP/propose/ledger"
PROPOSE_F="$TMP/propose/proposed.json"
TOUCHSTONE_LEDGER_DIR="$LDIR3" "$X" --repo "$R3" --propose-cursors "$PROPOSE_F" > /dev/null
if [ ! -e "$LDIR3/scan-state.json" ] && [ -s "$PROPOSE_F" ]; then
  PROPOSED_SHA="$(jq -r --arg r "$R3" '.[$r].last_swept' "$PROPOSE_F")"
  HEAD_R3="$(git -C "$R3" rev-parse HEAD)"
  HAS_GIT_ENVELOPE="$(jq 'has("git")' "$PROPOSE_F")"
  if [ "$PROPOSED_SHA" = "$HEAD_R3" ] && [ "$HAS_GIT_ENVELOPE" = "false" ]; then
    ok "propose-mode: bare git-section proposal written, scan-state.json untouched"
  else
    fail "propose-mode content (proposed_sha=$PROPOSED_SHA head=$HEAD_R3 has_envelope=$HAS_GIT_ENVELOPE)"
  fi
else
  fail "propose-mode (scan-state exists=$([ -e "$LDIR3/scan-state.json" ] && echo yes || echo no) propose file size=$(wc -c < "$PROPOSE_F" 2>/dev/null))"
fi

# --- --since is read-only: no scan-state.json written ---
R4="$(mkrepo since)"
T0d=1730000000
commit_at "$R4" "$T0d" "feat: seed" w.sh "line-1" >/dev/null
commit_at "$R4" "$((T0d+1*DAY))" "fix: patch w" w.sh "line-2" >/dev/null
LDIR4="$TMP/since/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR4" "$X" --repo "$R4" --since "1970-01-01T00:00:00Z" > "$TMP/since/digest.jsonl"
RC4=$?
if [ "$RC4" -eq 0 ] && [ ! -e "$LDIR4/scan-state.json" ]; then
  ok "--since is read-only (no scan-state.json written)"
else
  fail "--since read-only mode (rc=$RC4 scan-state exists=$([ -e "$LDIR4/scan-state.json" ] && echo yes || echo no))"
fi

echo "== $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
