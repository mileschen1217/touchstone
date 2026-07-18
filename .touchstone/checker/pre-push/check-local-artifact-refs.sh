#!/usr/bin/env bash
# check-local-artifact-refs.sh — pre-push gate: outgoing diff must not add
# machine-local AC-N labels (from gitignored specs) to cold-reader surfaces.
# scripts/tests-smoke/** is exempt (fixtures deliberately carry AC-N); a line carrying
# <!-- local-ref-ok --> — or the added line directly after one — is exempt.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
cd "$root" || exit 0
range="${TOUCHSTONE_CHECK_RANGE:-}"
if [ -z "$range" ]; then
  git rev-parse --verify -q origin/main >/dev/null 2>&1 || exit 0
  range="origin/main..HEAD"
fi
bad=""
while IFS= read -r f; do
  case "$f" in
    scripts/tests-smoke/*|.touchstone/*) continue ;;
  esac
  [ -f "$f" ] || continue
  hits="$(git diff "$range" -- "$f" | awk '
    /^\+\+\+/ { next }
    /^\+/ {
      line = substr($0, 2)
      if (index(line, "<!-- local-ref-ok -->") > 0) { prev_ok = 1; next }
      if (line ~ /AC-[0-9]/ && !prev_ok) print "  +" line
      prev_ok = 0
      next
    }
    { prev_ok = 0 }
  ')"
  [ -n "$hits" ] && bad="${bad}
${f}:
${hits}"
done < <(git diff "$range" --name-only 2>/dev/null)
if [ -n "$bad" ]; then
  echo "[check-local-artifact-refs] outgoing diff adds AC-N labels on cold-reader surfaces:"
  echo "$bad"
  echo "Scrub the label into descriptive prose, or mark a deliberate example with <!-- local-ref-ok --> (same line or the line above)."
  exit 1
fi
exit 0
