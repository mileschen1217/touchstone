#!/usr/bin/env bash
# reconcile.sh — read-only follow-through report at epic close: pure joins
# over proposals × resolutions × entries × fire-log. Writes NOTHING.
# Fire counts are attributed PER kind=installed fact over the half-open
# interval [installed.ts, matching revoked.ts | now): phantom fire-events
# from failed proofs predate any installed fact and never count; a
# revoke→reinstall attributes each event to exactly one install.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/proposal-lib.sh"

DIR="$(proposal_lib_resolve_dir)" || exit 1
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

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

echo "== installed checks: fire counts =="
# fire-log.jsonl's PRODUCER (the runtime hook's fire_log(), hooks/run-project-
# checks.sh) always resolves the ledger dir from the committing repo's git
# toplevel — it never honors TOUCHSTONE_LEDGER_DIR. When this script is run
# with an override, fire counts below are only meaningful if the override
# equals <toplevel>/.touchstone/ledger; otherwise the fire-log read here is
# simply the file the hook never wrote to.
jq -r -n --arg now "$NOW" \
  --slurpfile rs <(slurp "$DIR/resolutions.jsonl") \
  --slurpfile fl <(slurp "$DIR/fire-log.jsonl") '
  ([ $rs[] | select(.kind=="installed") ]) as $inst
  | ($inst | map(. as $i
      | ([ $rs[] | select(.kind=="revoked" and .proposal_id==$i.proposal_id and (.ts > $i.ts)) ]
         | sort_by(.ts) | (.[0].ts // $now)) as $end
      | $i + {_end: $end, _base: ($i.proof.installed_path | split("/") | last)}
    )) as $withend
  | ($withend | length) as $n
  | if $n == 0 then "none" else
      range(0; $n) as $idx
      | $withend[$idx] as $i
      # honest annotation, not re-keying: fire-log records basename only, so
      # two DIFFERENT installed facts sharing a basename with overlapping
      # install intervals would each count the same fire events — flag it
      # rather than silently attribute.
      | ([ range(0; $n) | select(. != $idx) | $withend[.]
           | select(._base == $i._base and .ts < $i._end and $i.ts < ._end) ]
         | length) as $overlap
      | ([ $fl[] | select(.check==$i._base and .ts >= $i.ts and .ts < $i._end) ] | length) as $cnt
      | $i.proof.installed_path + " (" + $i.proposal_id + "): fires=" + ($cnt|tostring)
        + " in [" + $i.ts + ", " + $i._end + ")"
        + (if $overlap > 0 then " (shared basename — counts may overlap)" else "" end)
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
