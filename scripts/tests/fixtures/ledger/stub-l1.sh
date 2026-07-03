#!/usr/bin/env bash
# stub-l1.sh — judgment-agnostic L1 classifier stub for sweep-run.sh's test
# suite (Task 7 fixture; NOT the real haiku dispatch — see Task 8). Reads
# digest/v1 JSONL on stdin, emits one candidate/v1 line per input record on
# stdout.
#
# Correlation-hint convention (test-only; no schema field is added by this
# convention — it is a literal substring inside the existing text/subjects/
# snippet payload field): is_miss:true iff that text contains
# "TESTHINT:<key>" with key != "notmiss"; caught_by/should_have/gap_class
# are FIXED constants when is_miss:true — this stub performs no real
# judgment, it only proves the classify -> validate-candidates -> stage
# plumbing. See .superpowers/sdd/task-7-brief.md.
set -u
jq -c '
  ( if (.payload.text != null) then .payload.text
    elif (.payload.subjects != null) then (.payload.subjects | join(" "))
    elif (.payload.snippet != null) then .payload.snippet
    else "" end ) as $text
  | ($text | test("TESTHINT:")) as $has_hint
  | (if $has_hint then ($text | capture("TESTHINT:(?<key>[^ ]+)").key) else "" end) as $key
  | if $has_hint and ($key != "notmiss") then
      {schema:"candidate/v1", ref:.ref, is_miss:true,
       caught_by:"live-probe", should_have:"design-review", gap_class:"missing-AC",
       note:("stub-l1: TESTHINT:" + $key)}
    else
      {schema:"candidate/v1", ref:.ref, is_miss:false}
    end
'
