#!/usr/bin/env bash
# reconcile.sh — read-only follow-through report at epic close: pure joins
# over proposals × resolutions × entries × fire-log. Writes NOTHING.
# Fire counts are RAW per checker basename since its first kind=installed
# fact (no revoke upper bound — see the fire-count section comment); events
# with no installed fact at all are reported separately, never hidden.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/proposal-lib.sh"

DIR="$(proposal_lib_resolve_dir)" || exit 1

slurp() { cat "$1" 2>/dev/null || true; }

echo "== proposal follow-through =="
jq -r -n \
  --slurpfile ps <(slurp "$DIR/proposals.jsonl") \
  --slurpfile rs <(slurp "$DIR/resolutions.jsonl") '
  [ $ps[] | . as $p
    | ([ $rs[] | select(.proposal_id==$p.id) ]) as $f
    | select(([ $f[] | select(.kind=="accepted") ] | length) > 0)
    | select(([ $f[] | select(.kind=="installed" or .kind=="completed") ] | length) == 0)
    | "accepted, not yet installed/completed: " + $p.id + " — " + $p.title
      + ([ $f[] | select(.kind=="install-failed")
           | " [install-failed: triage=" + .triage + "]" ] | join(""))
  ] | if length == 0 then "accepted, not yet installed/completed: none" else .[] end'
echo "rejected: $(jq -s '[ .[] | select(.kind=="rejected") ] | length' <(slurp "$DIR/resolutions.jsonl"))"

echo "== installed checks: fire counts (raw since first install) =="
# fire-log.jsonl's PRODUCER (the runtime hook's fire_log(), hooks/run-project-
# checks.sh) always resolves the ledger dir from the committing repo's git
# toplevel — it never honors TOUCHSTONE_LEDGER_DIR. When this script is run
# with an override, fire counts below are only meaningful if the override
# equals <toplevel>/.touchstone/ledger; otherwise the fire-log read here is
# simply the file the hook never wrote to.
# Attribution is RAW per basename: every fire-log event with ts >= the
# basename's FIRST installed fact counts, with no revoke upper bound — a
# revoke removes the file, so a live file firing after a stale revoked fact
# is real signal, never zeroed by ledger windowing (the phantom-filtering
# defect this replaced). Events predating the first install (historical
# failed-proof phantoms) stay excluded.
# commit denominator: fires alone have no rate; append the commit count since
# first install from the repo owning the ledger dir (retirement judgment
# reads fires ÷ commits, not raw fires). No repo resolvable → commits=n/a.
FIRE_REPO="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || true)"
jq -r -n \
  --slurpfile rs <(slurp "$DIR/resolutions.jsonl") \
  --slurpfile fl <(slurp "$DIR/fire-log.jsonl") '
  ([ $rs[] | select(.kind=="installed")
     | . + {_base: (.proof.installed_path | split("/") | last)} ]) as $inst
  | ($inst | group_by(._base)) as $groups
  | if ($groups | length) == 0 then "none" else
      $groups[]
      | (.[0]._base) as $base
      | (map(.ts) | min) as $first
      | (map(.proposal_id) | unique | join(", ")) as $pids
      | ([ $fl[] | select(.check==$base and .ts >= $first) ] | length) as $cnt
      | $base + " (" + $pids + "): fires=" + ($cnt|tostring) + " since " + $first
    end' \
| while IFS= read -r line; do
    case "$line" in
      *" since "*)
        start="${line##* since }"
        if [ -n "$FIRE_REPO" ]; then
          commits="$(git -C "$FIRE_REPO" rev-list --count HEAD --since="$start" 2>/dev/null || echo n/a)"
        else
          commits="n/a"
        fi
        echo "$line commits=$commits"
        ;;
      *) echo "$line" ;;
    esac
  done
echo "== fire events with no installed fact (raw, outside the pipeline) =="
jq -r -n \
  --slurpfile rs <(slurp "$DIR/resolutions.jsonl") \
  --slurpfile fl <(slurp "$DIR/fire-log.jsonl") '
  ([ $rs[] | select(.kind=="installed")
     | (.proof.installed_path | split("/") | last) ] | unique) as $known
  | ([ $fl[] | .check as $c | select(($known | index($c)) == null) ] | group_by(.check)) as $orphans
  | if ($orphans | length) == 0 then "none" else
      $orphans[] | (.[0].check) + ": fires=" + (length|tostring)
    end'

echo "== possible recurrence of a resolved class — human review =="
# A proposal can carry multiple resolution facts over the same entry_ids
# (e.g. accepted + install-failed) — each is a separate candidate match, so
# dedupe to ONE line per (new-entry, class) pair, keeping the earliest
# covering resolution (min ts) as the representative id.
jq -r -n \
  --slurpfile rs <(slurp "$DIR/resolutions.jsonl") \
  --slurpfile es <(slurp "$DIR/entries.jsonl") '
  ([ $es[] | {key:.id, value:.} ] | from_entries) as $emap
  | ([ $rs[] | . as $r
      | ([ ($r.entry_ids // [])[] | $emap[.] | select(. != null)
           | {sh:.should_have, gc:.gap_class} ] | unique) as $keys
      | $es[] | . as $e
      | select($e.ts > $r.ts)
      | select(($keys | index({sh:$e.should_have, gc:$e.gap_class})) != null)
      | {rid:$r.id, rts:$r.ts, eid:$e.id, sh:$e.should_have, gc:$e.gap_class}
    ]
    | sort_by(.rts)
    | group_by([.eid, .sh, .gc])
    | map(.[0])
    | map("resolution " + .rid + " ~ new entry " + .eid
        + " (class " + .sh + " × " + .gc + ")")
  )
  | if length == 0 then "none" else .[] end'

echo "== runs/ =="
if [ -d "$DIR/runs" ]; then
  echo "total size: $(du -sk "$DIR/runs" 2>/dev/null | awk '{print $1 "KB"}')"
else
  echo "total size: none"
fi
exit 0
