#!/usr/bin/env bash
# stub-l1-partial.sh — deliberately buggy L1 stub for sweep-run.sh's test
# suite: emits only the FIRST input record's candidate/v1 line then stops,
# silently dropping the rest. Reproduces an L1 command that exits 0 but
# appends FEWER candidate lines than input records — the output-shortfall
# class classify() must catch, distinct from a non-zero exit (F1) or a
# zero-output command (F2a). See .superpowers/sdd/task-7-report.md
# (Final-review fix wave 2).
set -u
jq -c 'select(.ref != null) | {schema:"candidate/v1", ref:.ref, is_miss:false}' | head -n 1
