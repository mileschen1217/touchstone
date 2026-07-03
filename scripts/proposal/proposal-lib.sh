#!/usr/bin/env bash
# proposal-lib.sh — shared helpers for the proposal fact family.
# Source this file. Provides:
#   proposal_lib_resolve_dir          — prints the ledger dir (TOUCHSTONE_LEDGER_DIR
#                                        or <git-toplevel>/.touchstone/ledger)
#   open_entries <ledger-dir>         — prints the full OPEN-entry set as JSONL.
#
# Open entry (latest-fact rule): an entries.jsonl record for which either
# (a) no resolution fact references its id in entry_ids, or (b) the LATEST
# (by ts) referencing fact has kind=revoked — and which appears in no PENDING
# proposal's benefit_witness (pending = proposal with no accepted/rejected
# resolution). Rejected entries stay closed (a rejection is a decision);
# the reopen lever is new evidence, never old entries reviving.

proposal_lib_resolve_dir() {
  if [ -n "${TOUCHSTONE_LEDGER_DIR:-}" ]; then
    printf '%s\n' "$TOUCHSTONE_LEDGER_DIR"
    return 0
  fi
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$top" ]; then
    echo "proposal: not inside a git repo; set TOUCHSTONE_LEDGER_DIR" >&2
    return 1
  fi
  printf '%s\n' "$top/.touchstone/ledger"
}

open_entries() {
  local dir="$1"
  [ -f "$dir/entries.jsonl" ] || return 0
  jq -c -n \
    --slurpfile es <(cat "$dir/entries.jsonl") \
    --slurpfile ps <(cat "$dir/proposals.jsonl" 2>/dev/null) \
    --slurpfile rs <(cat "$dir/resolutions.jsonl" 2>/dev/null) '
    ([ $rs[] | select(.kind=="accepted" or .kind=="rejected") | .proposal_id ]) as $decided
    # bind the proposal BEFORE piping into index(): `($decided | index(.id))`
    # would evaluate .id against $decided (an array) and error out.
    | ([ $ps[] | . as $p | select(($decided | index($p.id)) == null) | $p.benefit_witness[] ]) as $pending_claims
    | $es[]
    | . as $e
    | ([ $rs[] | select((.entry_ids // []) | index($e.id) != null) ] | sort_by(.ts)) as $covering
    | select(
        ( ($covering | length) == 0 or ($covering[-1].kind == "revoked") )
        and ( ($pending_claims | index($e.id)) == null )
      )
  '
}
