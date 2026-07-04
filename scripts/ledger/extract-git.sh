#!/usr/bin/env bash
# extract-git.sh — L0 digest extractor for git fix-chains: a fix-classified
# commit (subject ^fix) pairs with the nearest prior non-fix commit sharing
# >=1 touched path within a pairwise window (default 14 days). Intervening
# fix commits are skipped in the anchor search so chains collapse to one
# non-fix anchor; one digest record is emitted per anchor aggregating its
# fixes.
#
# Usage: extract-git.sh [--window <days=14>] [--since ISO] [--epic slug]
#                        [--repo <path=.>]
#
# Read-only, stateless: every run walks the full history (the pairwise
# --window bound governs chain construction, not scan depth) and filters
# emitted records by anchor ts when --since (or --epic, resolved to a since
# bound) is given. Incremental behavior across sweeps comes from the CALLER
# passing a since bound (sweep-run.sh passes the last successful sweep's
# timestamp SHIFTED BACK by the pairing window, so a new fix whose anchor
# predates the sweep still surfaces its chain); already-appended chains are
# deduped downstream by ledger-append.sh's refs_overlap check on the
# git:<anchor-sha> ref.
#
# Merge commits are excluded (--no-merges): a merge's --name-only diff is
# taken against its first parent and mixes unrelated changes, which would
# pollute path-overlap anchor matching; conventional-commit "fix:"/"fix("
# subjects are not merge-commit subjects in this project's history.
set -u

WINDOW_DAYS=14
SINCE=""
EPIC=""
REPO="."

while [ $# -gt 0 ]; do
  case "$1" in
    --window|--since|--epic|--repo)
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
    --repo) REPO="$2"; shift 2 ;;
    *) echo "extract-git: unknown arg: $1" >&2; exit 1 ;;
  esac
done

WINDOW_SECS=$((WINDOW_DAYS * 86400))

REPO_TOPLEVEL="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_TOPLEVEL" ]; then
  echo "extract-git: not a git repo: $REPO" >&2
  exit 1
fi

# --epic best-effort resolution: use the epic index's `started:`
# frontmatter as a --since lower bound when the caller didn't already
# supply one; a missing index is not an error (best-effort — epic
# attribution on entries is nullable).
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

SOH=$'\x01'
US=$'\x02'

# emit records: one line per fix-chain anchor, SOH-delimited
# (sha SOH ciso SOH chain_len SOH fix_shas(US-joined) SOH paths(US-joined)
#  SOH subjects(US-joined)) — piped to jq below to build digest/v1 JSON
# safely (subjects/paths may contain arbitrary characters that awk should
# not be trusted to JSON-escape itself).
LOG_RAW="$(git -C "$REPO_TOPLEVEL" log --reverse --no-merges \
  --pretty=format:"%H${SOH}%ct${SOH}%cI${SOH}%s" --name-only 2>/dev/null)"

DIGEST_LINES="$(
  printf '%s\n' "$LOG_RAW" \
  | awk -v FS="$SOH" -v SOH="$SOH" -v US="$US" -v WINDOW="$WINDOW_SECS" '
    function is_fix_subject(s) {
      return (s ~ /^fix($|[^a-zA-Z])/)
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

exit 0
