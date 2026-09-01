#!/usr/bin/env bash
# scripts/resolve-config.sh — read <project-root>/.claude/touchstone.yaml and
# print the derived six-field path bundle. Single home for the resolver logic;
# skills/_shared/config-resolver.md calls this script instead of restating it.
#
# Usage: resolve-config.sh [--root <dir>]
#   root = --root arg, else $CLAUDE_PROJECT_DIR, else pwd
#   exit 0 → prints six `key=value` lines, one per line: specs, adr, epics,
#            plans, archive, research (workspace_root absent, file absent, or
#            key absent → default .touchstone)
#   exit 1 → config file present but not parseable YAML: one line to stderr
#            naming the file and the parse-error location
#   exit 2 → missing dependency (PyYAML: `pip install pyyaml`)
#
# A legacy `adopted_disciplines` key is ignored — source-as-truth is always on.
# No caller branch — every caller gets the same six-field bundle.
set -uo pipefail

root=""
[ "${1:-}" = "--root" ] && root="${2:-}"
[ -n "$root" ] || root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$root" ] || root="$(pwd)"

config="$root/.claude/touchstone.yaml"

print_bundle() {  # <workspace_root>
  local w="$1"
  printf 'specs=%s/specs\n' "$w"
  printf 'adr=%s/docs/adr\n' "$w"
  printf 'epics=%s/epics\n' "$w"
  printf 'plans=%s/plans\n' "$w"
  printf 'archive=%s/archive/specs\n' "$w"
  printf 'research=%s/research\n' "$w"
}

if [ ! -f "$config" ]; then
  print_bundle ".touchstone"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "resolve-config.sh: python3 not found" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "resolve-config.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }

if ! workspace_root="$(python3 - "$config" <<'PY'
import sys, yaml

path = sys.argv[1]
try:
    with open(path, encoding='utf-8') as f:
        doc = yaml.safe_load(f)
except yaml.YAMLError as e:
    mark = getattr(e, 'problem_mark', None)
    if mark is not None:
        loc = f"line {mark.line + 1}, column {mark.column + 1}"
    else:
        loc = "unknown location"
    print(f"resolve-config.sh: {path}: YAML parse error at {loc}: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(doc, dict):
    doc = {}
w = doc.get('workspace_root') or '.touchstone'
print(w)
PY
)"; then
  exit 1
fi

print_bundle "$workspace_root"
exit 0
