#!/usr/bin/env bash
fail=0
expect_exit() { label="$1"; want="$2"; shift 2; out="$("$@" 2>&1)"; rc=$?; if { [ "$want" = zero ] && [ "$rc" -eq 0 ]; } || { [ "$want" = nonzero ] && [ "$rc" -ne 0 ]; }; then echo "PASS: $label"; else echo "FAIL: $label (rc=$rc)"; fail=1; fi; }
expect_exit "target says ok" zero bash scripts/target.sh
exit "$fail"
