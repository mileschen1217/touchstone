#!/usr/bin/env bash
# check-plugin-graph.sh — pre-commit: runs scripts/plugin-map.sh over the tree
# and blocks a commit on a false edge, an unwaived orphan, an unwaived
# test-only node, a stale waiver, or a waiver whose node is the target of a
# false edge (INV-4: a false edge is never waived).
#
# Absent scripts/plugin-map.sh (a consumer project this plugin does not
# govern) -> exit 0 silently. A non-zero plugin-map.sh exit (its own
# entries-file contract violated) is itself a block: print its stderr, exit 1.
# Absent python3 -> exit 0 with a one-line WARN on stderr.
#
# A reported orphan can be resolved by adding the node to
# .touchstone/checker/plugin-map.entries (a real reachability root) or by
# waiving it in .touchstone/checker/waivers.yaml with a reason and a date.
#
# INV-1: this checker reads plugin-map's counts and lists only — no
# independent graph judgement.
set -uo pipefail

root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

# plugin-map.sh is a committed script, never duplicated into a fixture tree
# (the fixture's --root is a measurement target, not a copy of the plugin).
# Locate it in the repo this checker script itself ships from, so a fixture
# run (TOUCHSTONE_CHECK_ROOT pointing at a fixtures/ subtree) still finds the
# real one; a consumer project that lacks scripts/plugin-map.sh entirely
# resolves the same way and exits 0 silently.
self_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
self_root="$(git -C "${self_dir:-.}" rev-parse --show-toplevel 2>/dev/null)"
[ -n "$self_root" ] || exit 0
pm="$self_root/scripts/plugin-map.sh"
[ -f "$pm" ] || exit 0

command -v python3 >/dev/null 2>&1 || {
  echo "[check-plugin-graph] WARN: python3 not found -- graph check skipped" >&2
  exit 0
}

errfile="$(mktemp "${TMPDIR:-/tmp}/check-plugin-graph.XXXXXX")"
pyfile="$(mktemp "${TMPDIR:-/tmp}/check-plugin-graph.py.XXXXXX")"
trap 'rm -f "$errfile" "$pyfile"' EXIT

json_out="$(bash "$pm" --root "$root" 2>"$errfile")"
rc=$?
if [ "$rc" -ne 0 ]; then
  cat "$errfile" >&2
  exit 1
fi

cat >"$pyfile" <<'PY'
import json, sys

try:
    data = json.load(sys.stdin)
except Exception as exc:
    print("[check-plugin-graph] could not parse plugin-map.sh output: %s" % exc)
    sys.exit(1)

lines = []
for fe in data.get('false_edges', []):
    lines.append(
        "[check-plugin-graph] false edge: %s claimed by %s at %s "
        "(the claiming body never names it)" % (fe['target'], fe['claimed_by'], fe['claim_at']))
for o in data.get('orphans', []):
    lines.append(
        "[check-plugin-graph] orphan: %s is reachable from no entry and no waiver "
        "-- add it to .touchstone/checker/plugin-map.entries or waive it in "
        ".touchstone/checker/waivers.yaml" % o)
for t in data.get('test_only', []):
    lines.append(
        "[check-plugin-graph] test-only: %s is reachable only from the smoke-test "
        "runner and is not waived" % t)
for w in data.get('stale_waivers', []):
    lines.append(
        "[check-plugin-graph] stale waiver: %s in .touchstone/checker/waivers.yaml "
        "now has a real in-edge from a non-test node -- remove or re-justify it" % w)

false_by_target = {}
for fe in data.get('false_edges', []):
    false_by_target.setdefault(fe['target'], fe)
for w in data.get('invalid_waivers', []):
    fe = false_by_target.get(w)
    if fe:
        lines.append(
            "[check-plugin-graph] invalid waiver: %s in .touchstone/checker/waivers.yaml "
            "is the target of a false edge claimed by %s at %s -- a false edge is "
            "never waived (INV-4)" % (w, fe['claimed_by'], fe['claim_at']))
    else:
        lines.append(
            "[check-plugin-graph] invalid waiver: %s in .touchstone/checker/waivers.yaml "
            "is the target of a false edge -- a false edge is never waived (INV-4)" % w)

if lines:
    print("\n".join(lines))
    sys.exit(1)
sys.exit(0)
PY

report="$(printf '%s' "$json_out" | python3 "$pyfile")"
rc2=$?
if [ "$rc2" -ne 0 ]; then
  [ -n "$report" ] && printf '%s\n' "$report"
  exit 1
fi
exit 0
