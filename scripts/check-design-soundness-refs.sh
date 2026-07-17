#!/usr/bin/env bash
# check-design-soundness-refs.sh — deterministic floor for the design-soundness wiring.
#
# WHAT IT CHECKS (reference-presence only):
#   Given a spec path, determine if the spec has ≥1 normative ## Architecture commitment.
#   If yes: verify each named consumer file references the pinned inject fragment by path.
#   If no commitments (additive sentinel OR no ## Architecture section): vacuous pass.
#   Emits NO honor verdict. Never parses commitment body text. Never judges depth.
#
# ZERO-VS-NONZERO COMMITMENT PREDICATE (non-semantic) — P2 REQ-6/AC-40:
#   New form (six-section template): a `depth-stakes:` marker line under a REQ
#     signals a structural commitment. Any such line → nonzero.
#   Legacy fallback (pre-P2 specs, no depth-stakes marker): the old ## Architecture
#     predicate — zero iff no "## Architecture" section, or its section carries the
#     literal "no structural commitment — additive" sentinel with no SHALL.
#   Otherwise: nonzero (requires fragment ref in every named consumer).
#   The floor never reads what a commitment says — only whether the marker/section exists.
#
# PINNED FRAGMENT PATH:
FRAGMENT_PATH="skills/_shared/inject/design-soundness-honor-check.md"
#
# USAGE:
#   check-design-soundness-refs.sh <spec> [<consumer-file>...]
#     → exit 0 if spec has zero commitments (vacuous) OR each consumer references fragment
#     → exit 1 if spec has ≥1 commitment and any consumer lacks the fragment reference
#       Output: "BLOCK: <spec-path> | <consumer-file> | expected: <fragment-path>"
#
#   check-design-soundness-refs.sh --dup-check <file.md>
#     → exit 1 if <file.md> appears to contain a STATIC BODY COPY of the fragment
#       (detected by the presence of all five sentinel phrases together in one file)
#     → exit 0 if the file only has a load-by-path reference line (or no reference at all)
#
# Guarantee: this script checks reference-presence only. It does not parse commitment
# text, does not score arch-rubric forces, and emits no honor verdict.
# Guarantee: additive sentinel → exit 0 without requiring any consumer reference.
# Guarantee: --dup-check detects static body copies (the single-home violation).

set -uo pipefail

# ---------------------------------------------------------------------------
# --dup-check mode: detect static body copy of the fragment in a file
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--dup-check" ]; then
  if [ $# -lt 2 ]; then
    echo "Usage: $0 --dup-check <file.md>" >&2
    exit 2
  fi
  target="$2"
  if [ ! -f "$target" ]; then
    echo "ERROR: file not found: $target" >&2
    exit 2
  fi
  # A static body copy is detected by all five sentinel phrases present together.
  # A load-by-path reference line only contains the path, not the body sentinels.
  hits=0
  for phrase in \
    "structural commitment" \
    "depth-stakes" \
    "descriptive-only" \
    "commitment-less accreted" \
    "[unverified]"
  do
    grep -qF "$phrase" "$target" 2>/dev/null && hits=$((hits+1))
  done
  if [ "$hits" -ge 5 ]; then
    echo "BLOCK: static body copy detected in $target (all five sentinel phrases present)"
    exit 1
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Normal mode: reference-presence check
# ---------------------------------------------------------------------------
if [ $# -lt 1 ]; then
  echo "Usage: $0 <spec-path> [<consumer-file>...]" >&2
  exit 2
fi

spec="$1"
shift
consumers=("$@")

if [ ! -f "$spec" ]; then
  echo "ERROR: spec not found: $spec" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 1: Determine zero-vs-nonzero commitment predicate (non-semantic)
# ---------------------------------------------------------------------------

# New-form predicate: any `depth-stakes:` marker line under a REQ → nonzero commitment.
has_depth_stakes=0
grep -qE '^depth-stakes:' "$spec" 2>/dev/null && has_depth_stakes=1

if [ "$has_depth_stakes" -eq 0 ]; then
  # No new-form marker → fall back to the legacy ## Architecture predicate (pre-P2 specs).
  if ! grep -qE "^## Architecture" "$spec" 2>/dev/null; then
    # No depth-stakes marker and no ## Architecture section → zero commitments → vacuous pass
    exit 0
  fi
  arch_section="$(awk '/^## Architecture/{found=1; next} found && /^## /{found=0} found{print}' "$spec")"
  # Additive sentinel counts as zero ONLY when the section carries the EXACT
  # documented sentinel AND no normative SHALL marker alongside it. Fail closed —
  # a contradictory section (exact sentinel + a SHALL) is treated as
  # commitment-bearing. Reference-presence only; never reads what a commitment says.
  if printf '%s' "$arch_section" | grep -qF "no structural commitment — additive" \
     && ! printf '%s' "$arch_section" | grep -qwE "SHALL"; then
    # Explicit legacy additive waiver, no commitment marker → zero commitments → vacuous pass
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Step 2: Spec has ≥1 commitment — verify each consumer references the fragment
# ---------------------------------------------------------------------------

if [ ${#consumers[@]} -eq 0 ]; then
  # No consumers named → nothing to check (vacuous on the consumer side)
  # This is a valid invocation (e.g. just checking if the spec is commitment-bearing)
  exit 0
fi

rc=0
for consumer in "${consumers[@]}"; do
  if [ ! -f "$consumer" ]; then
    echo "BLOCK: $spec | $consumer | expected: $FRAGMENT_PATH (consumer file not found)"
    rc=1
    continue
  fi
  if ! grep -qF "$FRAGMENT_PATH" "$consumer" 2>/dev/null; then
    echo "BLOCK: $spec | $consumer | expected: $FRAGMENT_PATH"
    rc=1
  fi
done

exit "$rc"
