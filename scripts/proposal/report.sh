#!/usr/bin/env bash
# report.sh — read-only reporting over the proposal fact substrate. Writes
# NOTHING (proposal facts enter only through facts-append.sh).
# Subcommands:
#   open-entries   freshness banner on stderr; open-entry JSONL on stdout
#   digest         freshness line first on stdout; ranked top-N proposal blocks
#                  (quota: $TOUCHSTONE_PROPOSAL_QUOTA, default 5)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/proposal-lib.sh"

DIR="$(proposal_lib_resolve_dir)" || exit 1

freshness() {
  if [ -f "$DIR/.last-finalize" ]; then
    printf 'last sweep finalize: %s\n' "$(cat "$DIR/.last-finalize")"
  else
    printf 'last sweep finalize: never\n'
  fi
}

cmd_open_entries() {
  freshness >&2
  open_entries "$DIR"
}

cmd_digest() {
  freshness
  local quota="${TOUCHSTONE_PROPOSAL_QUOTA:-5}"
  local pending total
  # pending = proposals with no accepted/rejected resolution, ranked
  # recurrence desc, latest_entry_ts desc, proposal id asc (deterministic
  # full-tie break). group_by sorts groups ascending by [rec, ts]; reverse
  # gives desc; sort_by(.id) orders inside each full-tie group.
  pending="$(jq -c -n \
    --slurpfile ps <(cat "$DIR/proposals.jsonl" 2>/dev/null) \
    --slurpfile rs <(cat "$DIR/resolutions.jsonl" 2>/dev/null) '
    ([ $rs[] | select(.kind=="accepted" or .kind=="rejected") | .proposal_id ]) as $decided
    | [ $ps[] | . as $p | select(($decided | index($p.id)) == null) | $p ]
    | group_by([.recurrence, .latest_entry_ts]) | reverse | map(sort_by(.id)) | add // []')"
  total="$(echo "$pending" | jq 'length')"
  if [ "$total" -eq 0 ]; then
    # nothing to rule on: distinguish "open entries exist but none proposed
    # yet" from "nothing open at all" (ledger absent, empty, or all-closed).
    if [ "$(open_entries "$DIR" | grep -c .)" -eq 0 ]; then
      echo "no open entries — run the sweep first"
    else
      echo "no pending proposals"
    fi
    return 0
  fi
  echo "$pending" | jq -r --argjson q "$quota" '
    .[0:$q][] |
    ("## " + .title + "  " + (if .auto_install_eligible then "[auto-installable]" else "[needs-your-call]" end)),
    ("class: " + .class_desc),
    ("recurrence: " + (.recurrence|tostring) + " (" + (.benefit_witness | join(", ")) + ")"),
    ("cost: " + (if .cost_witness.kind=="replay"
       then "replay fires=" + (.cost_witness.fires|tostring) + " hits=" + (.cost_witness.hits|tostring)
            + (if .cost_witness.fires != .cost_witness.hits
               then " — extra fires: " + ((.cost_witness.samples // ["unlisted"]) | join(", "))
               else "" end)
       else "declared: " + .cost_witness.note end)),
    ("body: " + .body_ref),
    ""'
  if [ "$total" -gt "$quota" ]; then
    echo "$((total - quota)) more recorded below quota"
  fi
}

case "${1:-}" in
  open-entries) cmd_open_entries ;;
  digest)       cmd_digest ;;
  *) echo "report: usage: report.sh {open-entries|digest}" >&2; exit 1 ;;
esac
