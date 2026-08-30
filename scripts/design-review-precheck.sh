#!/usr/bin/env bash
# design-review-precheck.sh <spec.yaml> [--attest] — deterministic pre-check.
#   status draft → skipped (exit 0). Otherwise the spec must validate under
#   check-artifact.sh (schema = the floor; a `challenged-by` key is an unknown key and
#   fails there). --attest (anvil entry): additionally require a design-review
#   round's review.yaml in the spec's directory tree whose `target` is this spec and
#   whose `challenger` names a provider — the round-1 challenge attestation.
#   BLOCK (exit 1) with the cause; PROCEED (exit 0) clean; usage error (exit 2).
set -uo pipefail
spec="${1:-}"; [ -f "$spec" ] || { echo "usage: design-review-precheck.sh <spec.yaml> [--attest]" >&2; exit 2; }
attest=0; [ "${2:-}" = "--attest" ] && attest=1
here="$(cd "$(dirname "$0")" && pwd)"
case "$spec" in
  *.md) echo "BLOCK: legacy markdown spec — the heading-parsing floor is retired; author spec.yaml (design-spec) and re-run"; exit 1 ;;
esac
status="$(python3 -c 'import sys,yaml
try:
    d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
    print(str(d.get("status", "")).strip() if isinstance(d, dict) else "")
except Exception:
    print("")' "$spec")"
[ "$status" = "draft" ] && { echo "PRE-CHECK skipped: draft"; exit 0; }
dir="$(cd "$(dirname "$spec")" && pwd)"
if ! out="$(bash "$here/check-artifact.sh" spec "$spec" --root "$dir" 2>&1)"; then
  echo "BLOCK: spec does not validate (check-artifact spec)"; echo "$out"; exit 1
fi
[ -n "$out" ] && echo "$out"
# an explicit out-of-scope is the contract's scope bound — an empty non_goals blocks
ng="$(python3 -c 'import sys,yaml
d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
v = d.get("non_goals") if isinstance(d, dict) else None
print("empty" if not v else "ok")' "$spec")"
[ "$ng" = "empty" ] && { echo "BLOCK: non_goals empty — the contract states no out-of-scope route"; exit 1; }
if [ "$attest" -eq 1 ]; then
  base="$(basename "$spec")"
  found="$(python3 - "$dir" "$base" <<'PY'
import sys, os, glob, yaml
d, base = sys.argv[1], sys.argv[2]
for f in sorted(glob.glob(os.path.join(d, '**', 'review.yaml'), recursive=True)):
    try: r = yaml.safe_load(open(f, encoding='utf-8'))
    except Exception: continue
    if isinstance(r, dict) and r.get('gate') == 'design-review' and r.get('target') == base and r.get('challenger'):
        print(os.path.relpath(f, d)); break
PY
)"
  [ -n "$found" ] || { echo "BLOCK: no design-review review.yaml targets $base with a challenger provider — the round-1 challenge attestation is missing"; exit 1; }
  echo "attestation: $found"
fi
echo "PRE-CHECK OK → dispatch"; exit 0
