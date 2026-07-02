#!/usr/bin/env bash
# extract-git.sh — L0 digest extractor for git fix-chains: a fix-classified
# commit (subject ^fix) pairs with the nearest prior non-fix commit sharing
# >=1 touched path within a pairwise window (default 14 days). Intervening
# fix commits are skipped in the anchor search so chains collapse to one
# non-fix anchor; one digest record is emitted per anchor aggregating its
# fixes. See .touchstone/specs/2026-07-02-catch-attribution-ledger-design.md
# (REQ-3).
#
# Usage: extract-git.sh [--window <days=14>] [--since ISO] [--epic slug]
#                        [--propose-cursors FILE] [--repo <path=.>]
#
# Default mode (no --since/--epic/--propose-cursors): unfiltered,
# cursor-advancing — commits the new last_swept sha to
# $TOUCHSTONE_LEDGER_DIR/scan-state.json section "git" (keyed by repo
# toplevel path). Records are emitted only for fix commits AFTER
# last_swept, but the anchor search walks the full --window regardless of
# the cursor: a new fix whose nearest non-fix anchor predates the cursor
# must still pair (a literal last_swept..HEAD walk would make that anchor
# invisible and silently drop the fix — the no-lookback gap). When
# last_swept is unreachable (rebase/force-push) or absent (first run), the
# extractor falls back to a full history walk — the same pairwise --window
# bound governs chain construction either way, there is no separate
# scan-depth cap ("window-bounded full rescan" = full walk, window-bounded
# pairing).
# --propose-cursors FILE: same unfiltered scan, but the proposed git
# section (bare, no "git" envelope) is written to FILE instead of
# scan-state.json — sweep mode; the caller merges it after a successful
# ledger-append.sh.
# --since/--epic: read-only ad-hoc query — scans full history, filters
# emitted records by anchor ts, never touches scan-state.json or a
# propose file.
#
# Merge commits are excluded (--no-merges): a merge's --name-only diff is
# taken against its first parent and mixes unrelated changes, which would
# pollute path-overlap anchor matching; conventional-commit "fix:"/"fix("
# subjects are not merge-commit subjects in this project's history.
set -u

WINDOW_DAYS=14
SINCE=""
EPIC=""
PROPOSE_FILE=""
REPO="."

while [ $# -gt 0 ]; do
  case "$1" in
    --window|--since|--epic|--propose-cursors|--repo)
      if [ $# -lt 2 ]; then
        echo "extract-git: $1 requires a value" >&2
        exit 1
      fi
      ;;
  esac
  case "$1" in
    --window) WINDOW_DAYS="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --epic) EPIC="$2"; shift 2 ;;
    --propose-cursors) PROPOSE_FILE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) echo "extract-git: unknown arg: $1" >&2; exit 1 ;;
  esac
done

WINDOW_SECS=$((WINDOW_DAYS * 86400))

READONLY=0
if [ -n "$SINCE" ] || [ -n "$EPIC" ]; then
  READONLY=1
fi

REPO_TOPLEVEL="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_TOPLEVEL" ]; then
  echo "extract-git: not a git repo: $REPO" >&2
  exit 1
fi

# --epic best-effort resolution: use the epic index's `started:`
# frontmatter as a --since lower bound when the caller didn't already
# supply one; a missing index is not an error (best-effort, per spec
# Interfaces § CLI shapes — epic attribution on entries is nullable).
if [ -n "$EPIC" ] && [ -z "$SINCE" ]; then
  EPIC_INDEX="$REPO_TOPLEVEL/.touchstone/epics/$EPIC/index.md"
  if [ -f "$EPIC_INDEX" ]; then
    SINCE="$(grep -m1 '^started:' "$EPIC_INDEX" | sed 's/^started:[[:space:]]*//')"
  fi
fi

HEAD_SHA="$(git -C "$REPO_TOPLEVEL" rev-parse HEAD 2>/dev/null)"
if [ -z "$HEAD_SHA" ]; then
  # empty repo / no commits yet: nothing to scan.
  exit 0
fi

OLD_GIT_SECTION='{}'
STATE_JSON='{}'
LDIR=""
SCAN_STATE=""
if [ "$READONLY" -eq 0 ]; then
  if [ -n "${TOUCHSTONE_LEDGER_DIR:-}" ]; then
    LDIR="$TOUCHSTONE_LEDGER_DIR"
  else
    TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [ -z "$TOPLEVEL" ]; then
      echo "extract-git: not inside a git repo; set TOUCHSTONE_LEDGER_DIR" >&2
      exit 1
    fi
    LDIR="$TOPLEVEL/.touchstone/ledger"
  fi
  SCAN_STATE="$LDIR/scan-state.json"
  if [ -f "$SCAN_STATE" ]; then
    STATE_JSON="$(cat "$SCAN_STATE")"
  fi
  OLD_GIT_SECTION="$(printf '%s' "$STATE_JSON" | jq -c '.git // {}')"
fi

LAST_SWEPT=""
if [ "$READONLY" -eq 0 ]; then
  LAST_SWEPT="$(printf '%s' "$OLD_GIT_SECTION" | jq -r --arg r "$REPO_TOPLEVEL" '.[$r].last_swept // empty')"
fi

RANGE=""
if [ -n "$LAST_SWEPT" ]; then
  if git -C "$REPO_TOPLEVEL" rev-parse --verify --quiet "${LAST_SWEPT}^{commit}" >/dev/null 2>&1 \
     && git -C "$REPO_TOPLEVEL" merge-base --is-ancestor "$LAST_SWEPT" HEAD 2>/dev/null; then
    RANGE="${LAST_SWEPT}..HEAD"
  fi
  # else: last_swept is unreachable — fall back to a full history walk
  # (RANGE stays empty), same as a first-ever run.
fi

SOH=$'\x01'
US=$'\x02'

# IS_INCREMENTAL gates two independent things: (1) which commits populate
# the anchor search (window-wide, via --since, NOT last_swept..HEAD — a
# literal cursor-bounded walk would hide an anchor that predates the
# cursor and silently drop a new fix that pairs with it) and (2) which
# fix commits are allowed to EMIT a record (only those in last_swept..HEAD
# — NEW_SHAS below). A full-history run (first-ever sweep, or recovery
# from an unreachable last_swept) has no cursor, so every commit is
# eligible for both.
IS_INCREMENTAL=0
ANCHOR_SINCE_EPOCH=""
NEW_SHAS=""
if [ -n "$RANGE" ]; then
  IS_INCREMENTAL=1
  LAST_SWEPT_CT="$(git -C "$REPO_TOPLEVEL" log -1 --format=%ct "$LAST_SWEPT" 2>/dev/null)"
  if [ -n "$LAST_SWEPT_CT" ]; then
    ANCHOR_SINCE_EPOCH=$((LAST_SWEPT_CT - WINDOW_SECS))
  fi
  # else: committer date lookup failed unexpectedly — leave
  # ANCHOR_SINCE_EPOCH empty so the log walk below degrades to full
  # history (correctness over efficiency).
  # US-joined, not newline-joined: BSD awk (macOS default) rejects a
  # multi-line -v value ("newline in string").
  NEW_SHAS="$(git -C "$REPO_TOPLEVEL" rev-list "$RANGE" 2>/dev/null | tr '\n' "$US")"
fi

# emit records: one line per fix-chain anchor, SOH-delimited
# (sha SOH ciso SOH chain_len SOH fix_shas(US-joined) SOH paths(US-joined)
#  SOH subjects(US-joined)) — piped to jq below to build digest/v1 JSON
# safely (subjects/paths may contain arbitrary characters that awk should
# not be trusted to JSON-escape itself).
# bash 3.2 treats "${ARR[@]}" on a possibly-empty array as unbound under
# set -u, so the optional range arg is branched here rather than expanded
# from an array.
if [ "$IS_INCREMENTAL" -eq 1 ] && [ -n "$ANCHOR_SINCE_EPOCH" ]; then
  LOG_RAW="$(git -C "$REPO_TOPLEVEL" log --reverse --no-merges \
    --since="@${ANCHOR_SINCE_EPOCH}" \
    --pretty=format:"%H${SOH}%ct${SOH}%cI${SOH}%s" --name-only HEAD 2>/dev/null)"
else
  LOG_RAW="$(git -C "$REPO_TOPLEVEL" log --reverse --no-merges \
    --pretty=format:"%H${SOH}%ct${SOH}%cI${SOH}%s" --name-only 2>/dev/null)"
fi

DIGEST_LINES="$(
  printf '%s\n' "$LOG_RAW" \
  | awk -v FS="$SOH" -v SOH="$SOH" -v US="$US" -v WINDOW="$WINDOW_SECS" \
        -v is_incremental="$IS_INCREMENTAL" -v new_shas="$NEW_SHAS" '
    function is_fix_subject(s) {
      return (s ~ /^fix($|[^a-zA-Z])/)
    }
    BEGIN {
      # new_shas = `git rev-list last_swept..HEAD` output (one sha per
      # line), empty on a full-history run. Record emission is gated on
      # is_new so a commit that only exists to widen the anchor search
      # (window-wide, predating the cursor) never itself surfaces a
      # record — that would re-emit an already-swept chain.
      if (is_incremental == "1") {
        nnew = split(new_shas, new_arr, US)
        for (ni = 1; ni <= nnew; ni++) {
          if (new_arr[ni] != "") is_new_sha[new_arr[ni]] = 1
        }
      }
    }
    {
      if ($0 == "") { next }
      if (index($0, SOH) > 0) {
        n = split($0, f, SOH)
        sha = f[1]
        nseen++
        order[nseen] = sha
        ct_of[sha] = f[2]
        ciso_of[sha] = f[3]
        subj = f[4]
        for (i = 5; i <= n; i++) subj = subj SOH f[i]
        subject_of[sha] = subj
        is_fix[sha] = is_fix_subject(subj) ? 1 : 0
        is_new[sha] = (is_incremental == "1") ? (sha in is_new_sha) : 1
        npaths[sha] = 0
        cur = sha
        next
      }
      npaths[cur]++
      paths_of[cur, npaths[cur]] = $0
    }
    END {
      for (idx = 1; idx <= nseen; idx++) {
        sha = order[idx]
        if (is_fix[sha] && !is_new[sha]) {
          # old fix (before the cursor, present only to widen the anchor
          # search): never updates path_last_nonfix (still a fix) and
          # never emits (already-swept) — skip outright rather than
          # falling into the non-fix branch below.
          continue
        }
        if (is_fix[sha]) {
          best_sha = ""; best_ct = -1
          for (p = 1; p <= npaths[sha]; p++) {
            path = paths_of[sha, p]
            cand = path_last_nonfix[path]
            if (cand != "") {
              cct = ct_of[cand] + 0
              if (cct > best_ct) { best_ct = cct; best_sha = cand }
            }
          }
          if (best_sha != "" && (ct_of[sha] + 0 - best_ct) <= WINDOW) {
            if (!(best_sha in anchor_seen)) {
              anchor_seen[best_sha] = 1
              anchor_order[++nanchors] = best_sha
              subj_list[best_sha] = subject_of[best_sha]
              for (p2 = 1; p2 <= npaths[best_sha]; p2++) {
                pth = paths_of[best_sha, p2]
                key = best_sha SUBSEP pth
                if (!(key in path_union_seen)) {
                  path_union_seen[key] = 1
                  nunion[best_sha]++
                  path_union[best_sha, nunion[best_sha]] = pth
                }
              }
            }
            nfix[best_sha]++
            fix_list[best_sha, nfix[best_sha]] = sha
            subj_list[best_sha] = subj_list[best_sha] US subject_of[sha]
            for (p3 = 1; p3 <= npaths[sha]; p3++) {
              pth = paths_of[sha, p3]
              key = best_sha SUBSEP pth
              if (!(key in path_union_seen)) {
                path_union_seen[key] = 1
                nunion[best_sha]++
                path_union[best_sha, nunion[best_sha]] = pth
              }
            }
          }
          # fix commits never update path_last_nonfix — this is what
          # makes intervening fixes skip in the anchor search.
        } else {
          for (p = 1; p <= npaths[sha]; p++) {
            path_last_nonfix[paths_of[sha, p]] = sha
          }
        }
      }
      for (a = 1; a <= nanchors; a++) {
        sha = anchor_order[a]
        fixes = ""
        for (k = 1; k <= nfix[sha]; k++) {
          fixes = (k == 1) ? fix_list[sha, k] : fixes US fix_list[sha, k]
        }
        pth = ""
        for (k = 1; k <= nunion[sha]; k++) {
          pth = (k == 1) ? path_union[sha, k] : pth US path_union[sha, k]
        }
        print sha SOH ciso_of[sha] SOH nfix[sha] SOH fixes SOH pth SOH subj_list[sha]
      }
    }
  '
)"

DIGEST_JSON="$(
  printf '%s\n' "$DIGEST_LINES" \
    | jq -Rc --arg soh "$SOH" --arg us "$US" '
        select(length > 0)
        | split($soh) as $f
        | {
            schema: "digest/v1",
            source: "git",
            ref: ("git:" + $f[0]),
            ts: $f[1],
            payload: {
              anchor_sha: $f[0],
              fix_shas: ($f[3] | split($us)),
              paths: ($f[4] | split($us)),
              chain_len: ($f[2] | tonumber),
              subjects: ($f[5] | split($us))
            }
          }
      '
)"

if [ -n "$SINCE" ]; then
  DIGEST_JSON="$(printf '%s\n' "$DIGEST_JSON" | jq -c --arg since "$SINCE" 'select(length>0) | select(.ts >= $since)')"
fi

printf '%s\n' "$DIGEST_JSON" | sed '/^$/d'

if [ "$READONLY" -eq 1 ]; then
  exit 0
fi

NEW_GIT_SECTION="$(printf '%s' "$OLD_GIT_SECTION" | jq -c --arg r "$REPO_TOPLEVEL" --arg sha "$HEAD_SHA" '.[$r] = {last_swept: $sha}')"

if [ -n "$PROPOSE_FILE" ]; then
  mkdir -p "$(dirname "$PROPOSE_FILE")" || { echo "extract-git: cannot create dir for $PROPOSE_FILE" >&2; exit 1; }
  TMP_PROPOSE="$(mktemp "${PROPOSE_FILE}.tmp.XXXXXX")"
  printf '%s\n' "$NEW_GIT_SECTION" > "$TMP_PROPOSE"
  mv "$TMP_PROPOSE" "$PROPOSE_FILE"
  exit 0
fi

mkdir -p "$LDIR" || { echo "extract-git: cannot create ledger dir $LDIR" >&2; exit 1; }
NEW_STATE="$(printf '%s' "$STATE_JSON" | jq -c --argjson g "$NEW_GIT_SECTION" '.git = $g')"
TMP_STATE="$(mktemp "${SCAN_STATE}.tmp.XXXXXX")"
printf '%s\n' "$NEW_STATE" > "$TMP_STATE"
mv "$TMP_STATE" "$SCAN_STATE"

exit 0
