#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ex="$here/../spec-extract.sh"
fix="$here/floor-fixtures"
fail=0
out="$(bash "$ex" reqs "$fix/req-happy.md")"
if [ "$out" != "$(printf 'REQ-1\nREQ-2')" ]; then echo "FAIL reqs: [$out]"; fail=$((fail+1)); else echo "ok reqs"; fi
if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail"; exit 1; fi
