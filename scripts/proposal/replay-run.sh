#!/usr/bin/env bash
# replay-run.sh — read-only bounded git-history replay for a proposal's cost
# witness. Runs the sidecar's replay.sh once per commit in <rev-range>
# (against the CURRENT working directory's repo) and joins fires to ledger
# entries via git:<sha> evidence refs. Prints `fires=<n> hits=<m>` then one
# `unmatched fire: <sha>` line per fire with no matching entry. The fires/hits
# output is the CALLER's to embed in a proposal fact via facts-append.sh —
# this script writes nothing.
# Usage: replay-run.sh <proposal-dir> <rev-range>
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/proposal-lib.sh"

PDIR="${1:-}"; RANGE="${2:-}"
if [ -z "$PDIR" ] || [ -z "$RANGE" ]; then
  echo "replay-run: usage: replay-run.sh <proposal-dir> <rev-range>" >&2
  exit 1
fi
if [ ! -f "$PDIR/replay.sh" ]; then
  echo "replay-run: no replay.sh in $PDIR (cost witness degrades to kind=declared)" >&2
  exit 1
fi

DIR="$(proposal_lib_resolve_dir)" || exit 1
ENTRIES="$DIR/entries.jsonl"

SHAS="$(git rev-list "$RANGE" 2>/dev/null)"
if [ -z "$SHAS" ]; then
  echo "replay-run: empty or invalid rev-range: $RANGE" >&2
  exit 1
fi

# read-only enforcement: replay.sh is an arbitrary sidecar script we do not
# control. Capture the working tree's status before the sha loop and compare
# once after — any difference means the sidecar mutated the repo, which
# violates this script's read-only commitment.
STATUS_BEFORE="$(git status --porcelain 2>/dev/null)"

fires=0; hits=0; unmatched=""
for sha in $SHAS; do
  out="$(bash "$PDIR/replay.sh" "$sha")" \
    || { echo "replay-run: replay.sh failed at $sha" >&2; exit 1; }
  # require EXACTLY one line matching "<sha> (fire|pass)" — a sidecar that
  # prints extra lines (e.g. one per commit instead of one for the requested
  # sha) must not be silently parsed via a trailing-token match.
  if [ "$(printf '%s\n' "$out" | grep -c .)" -ne 1 ] \
     || ! printf '%s\n' "$out" | grep -qxE "$sha (fire|pass)"; then
    echo "replay-run: replay.sh printed malformed output at $sha" >&2
    exit 1
  fi
  case "$out" in
    *" fire")
      fires=$((fires+1))
      if [ -f "$ENTRIES" ] \
         && jq -e --arg r "git:$sha" 'select(.evidence != null) | .evidence[] | select(.ref==$r)' \
              "$ENTRIES" >/dev/null 2>&1; then
        hits=$((hits+1))
      else
        unmatched="$unmatched $sha"
      fi
      ;;
    *" pass") : ;;
  esac
done

STATUS_AFTER="$(git status --porcelain 2>/dev/null)"
if [ "$STATUS_BEFORE" != "$STATUS_AFTER" ]; then
  echo "replay-run: sidecar replay.sh mutated the working tree — replay aborted" >&2
  exit 1
fi

echo "fires=$fires hits=$hits"
for u in $unmatched; do
  echo "unmatched fire: $u"
done
exit 0
