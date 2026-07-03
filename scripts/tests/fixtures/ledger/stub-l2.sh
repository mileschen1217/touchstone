#!/usr/bin/env bash
# stub-l2.sh — judgment-agnostic L2 synthesizer stub for sweep-run.sh's test
# suite (Task 7 fixture; NOT the real sonnet dispatch — see Task 8). Reads
# enriched candidate/v1 JSONL on stdin (candidate fields plus the joined
# digest source/ts/payload, as built by sweep-run.sh's stage phase — every
# record here already has is_miss:true, sweep-run.sh filters before
# invoking L2) and emits staged catch-miss/v1 JSONL on stdout.
#
# Groups records sharing the same "TESTHINT:<key>" (same text fields
# stub-l1.sh reads) into ONE entry whose evidence[] carries every group
# member's ref — multi-kind when members came from different sources. This
# is the merge-CONTRACT plumbing AC-21 witnesses, not real merge judgment.
set -u
jq -s -c '
  def hint_key:
    ( if (.payload.text != null) then .payload.text
      elif (.payload.subjects != null) then (.payload.subjects | join(" "))
      elif (.payload.snippet != null) then .payload.snippet
      else "" end ) as $text
    | if ($text | test("TESTHINT:")) then ($text | capture("TESTHINT:(?<key>[^ ]+)").key)
      else "no-hint"
      end;
  group_by(hint_key)
  | .[]
  | {
      schema: "catch-miss/v1",
      caught_by: .[0].caught_by,
      should_have: .[0].should_have,
      gap_class: .[0].gap_class,
      what: ("stub-l2 merged incident (" + (length|tostring) + " source(s))"),
      evidence: [ .[] | {kind: .source, ref: .ref} ],
      source: ("sweep:" + .[0].source)
    }
'
