#!/usr/bin/env bash
# check-witness-lines.sh <verdict-file> — STRUCTURAL presence + format check for
# reviewer witness lines (P2 REQ-5 / AC-14). Single home of the format: the
# reviewer-witness-lines.md fragment. This checker renders the Tier A verdict
# ONLY (presence + format validity); it NEVER judges count-adequacy against
# claimed acts or authenticity — those are Tier B/C reviewer spot-checks.
#
# Contract:
#   input : a file holding a reviewer verdict's text
#   floor : ≥ 1 well-formed READ line (unconditional — a verdict always asserts
#           about the artifact under review).
#   format: READ line  == `READ: <path> | first heading: "<quoted heading>"`
#           RUN  line  == `RUN:  <command> | <key output line>`  (0+ allowed)
#           A line beginning `READ:` / `RUN:` that does not match its format is a
#           malformed-witness FAIL (a fabrication-adjacent shape must not pass as
#           absent — fail closed).
#   output: exit 0 + "pass" | exit 1 + a violation list.
#   error : file missing / unreadable → exit 2.
set -uo pipefail

[ $# -eq 1 ] || { echo "usage: check-witness-lines.sh <verdict-file>" >&2; exit 2; }
f="$1"
[ -f "$f" ] || { echo "FAIL: file not found: $f" >&2; exit 2; }

violations=0
note() { echo "VIOLATION: $*"; violations=$((violations+1)); }

# A READ line: `READ:` <space> <non-empty path> `|` first heading: "<quoted>"
read_ok=0
read_total=0
while IFS= read -r line; do
  read_total=$((read_total+1))
  if printf '%s' "$line" | grep -qE '^READ:[[:space:]]+[^|]+\|[[:space:]]*first heading:[[:space:]]*"[^"]*"[[:space:]]*$'; then
    read_ok=$((read_ok+1))
  else
    note "malformed READ witness line: $line"
  fi
done < <(grep -E '^READ:' "$f" || true)

# A RUN line: `RUN:` <space> <non-empty command> `|` <non-empty key output>
while IFS= read -r line; do
  printf '%s' "$line" | grep -qE '^RUN:[[:space:]]+[^|]+\|[[:space:]]*[^[:space:]].*$' \
    || note "malformed RUN witness line: $line"
done < <(grep -E '^RUN:' "$f" || true)

# The unconditional floor: ≥ 1 well-formed READ line.
if [ "$read_ok" -lt 1 ]; then
  note "no well-formed READ witness line (≥1 required — the unconditional floor)"
fi

if [ "$violations" -eq 0 ]; then echo "pass"; exit 0; fi
echo "RED: $violations violation(s) ($read_ok/$read_total READ lines well-formed)"; exit 1
