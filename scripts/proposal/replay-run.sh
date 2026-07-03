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

fires=0; hits=0; unmatched=""
for sha in $SHAS; do
  line="$(bash "$PDIR/replay.sh" "$sha")" \
    || { echo "replay-run: replay.sh failed at $sha" >&2; exit 1; }
  case "${line##* }" in
    fire)
      fires=$((fires+1))
      if [ -f "$ENTRIES" ] \
         && jq -e --arg r "git:$sha" 'select(.evidence != null) | .evidence[] | select(.ref==$r)' \
              "$ENTRIES" >/dev/null 2>&1; then
        hits=$((hits+1))
      else
        unmatched="$unmatched $sha"
      fi
      ;;
    pass) : ;;
    *) echo "replay-run: replay.sh printed malformed line at $sha: '$line'" >&2; exit 1 ;;
  esac
done

echo "fires=$fires hits=$hits"
for u in $unmatched; do
  echo "unmatched fire: $u"
done
exit 0
