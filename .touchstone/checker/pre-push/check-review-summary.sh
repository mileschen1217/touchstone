#!/usr/bin/env bash
# check-review-summary.sh — pre-push guard: for each gate (design-review, deliverable-review,
# plugin-review, …) take the newest review.yaml under .touchstone/epics/ and block if it
# carries OPEN Critical or High findings (findings[].status == open; counts.C + counts.H
# when the file has no findings list). Newest-per-gate: a newer clean file from one gate
# never hides another gate's open findings.
#
# Absence → passthrough: no review.yaml, no PyYAML, or unreadable counts → exit 0.
# The guard does not mandate a review before every push — only that an existing
# review's unresolved C/H are not silently bypassed.
# Self-test: check-review-summary.sh --self-test
set -uo pipefail
if [ "${1:-}" = "--self-test" ]; then
  t="$(mktemp -d)"; mkdir -p "$t/.touchstone/epics/e/review-1"
  printf 'gate: deliverable-review\ncounts: {C: 0, H: 1, M: 0, L: 0}\n' > "$t/.touchstone/epics/e/review-1/review.yaml"
  TOUCHSTONE_CHECK_ROOT="$t" "$0" && { echo "self-test FAIL: C+H>0 passed"; exit 1; }
  printf 'gate: deliverable-review\ncounts: {C: 0, H: 0, M: 2, L: 0}\n' > "$t/.touchstone/epics/e/review-1/review.yaml"
  TOUCHSTONE_CHECK_ROOT="$t" "$0" || { echo "self-test FAIL: C+H=0 blocked"; exit 1; }
  rm -rf "$t"; echo "self-test OK"; exit 0
fi
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
search_dir="$root/.touchstone/epics"
[ -d "$search_dir" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
python3 -c 'import yaml' 2>/dev/null || exit 0

# Newest review.yaml PER GATE (design-review / deliverable-review / plugin-review …): a newer
# clean file from one gate must not hide an older gate's open Critical/High findings.
files="$(find "$search_dir" -name "review.yaml" -type f 2>/dev/null)"
[ -n "$files" ] || exit 0
blocks="$(python3 - <<'PY' "$files"
import sys, os, yaml
newest = {}
for f in sys.argv[1].split('\n'):
    if not f: continue
    try:
        r = yaml.safe_load(open(f, encoding='utf-8')) or {}
        gate = str(r.get('gate') or '?')
        ts = os.path.getmtime(f)
    except Exception:
        continue
    if gate not in newest or ts > newest[gate][0]:
        newest[gate] = (ts, f, r)
for gate, (ts, f, r) in sorted(newest.items()):
    # `counts` is the round's total; a finding's live state is its `status` (fixed / waived
    # findings stay counted). Block on OPEN Critical/High findings; fall back to counts only
    # when the file carries no findings list.
    fs = r.get('findings')
    try:
        if isinstance(fs, list):
            ch = sum(1 for x in fs if isinstance(x, dict) and x.get('severity') in ('C', 'H')
                     and x.get('status', 'open') == 'open')
        else:
            c = r.get('counts') or {}
            ch = int(c.get('C', 0)) + int(c.get('H', 0))
    except Exception:
        continue
    if ch > 0:
        print('%s\t%d\t%s' % (gate, ch, f))
PY
)"
[ -n "$blocks" ] || exit 0
echo "[check-review-summary] BLOCK: the newest review.yaml of a gate has unresolved Critical+High finding(s)"
printf '%s\n' "$blocks" | while IFS="$(printf '\t')" read -r gate ch f; do
  echo "  $gate: C+H = $ch — $f"
done
echo "  Fix or explicitly waive the findings before pushing."
exit 1
