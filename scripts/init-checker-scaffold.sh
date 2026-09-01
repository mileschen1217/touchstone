#!/usr/bin/env bash
# init-checker-scaffold.sh — the deterministic steps of /touchstone:init,
# absorbed from prose (skills/init/SKILL.md's former Step 1 idempotence
# table + Step 3 mkdir + Step 4 yaml write + Step 5 summary), plus the
# checker-dir/.gitignore bootstrap this script already owned. The skill
# keeps only the interactive workspace-root prompt (judgment/interaction);
# everything mechanical lives here.
#
# Usage: init-checker-scaffold.sh [--project-root <dir>] [--workspace-root <path>] [--reset]
#
#   --project-root <dir>    default: $CLAUDE_PROJECT_DIR, else the current dir
#   --workspace-root <path> default: .touchstone (used only when (re)writing —
#                            i.e. missing file, or --reset)
#   --reset                 back up an existing parseable touchstone.yaml to
#                            <project-root>/.claude/touchstone.yaml.bak, then rewrite
#   --help                  print this usage and exit 0
#
# Exit codes (the four idempotence states):
#   0  written — touchstone.yaml was missing (created), or --reset was passed
#      on an existing parseable file (backed up to .bak, then rewritten)
#   0  already configured — touchstone.yaml exists, parses, --reset not
#      passed; current config printed, file left untouched. Distinguish from
#      the "written" case above by the literal "already configured" line.
#   1  malformed — touchstone.yaml exists but fails to parse; left
#      untouched; message names the file + parse-error location
#   2  mkdir/write failure, or missing python3/PyYAML dependency — message
#      names the failing path
#
# A legacy `adopted_disciplines` key is ignored (disciplines are no longer
# elected — source-as-truth is always on) and dropped on any rewrite.
set -uo pipefail

usage() {
  sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

proj=""
ws_root_arg=""
reset=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) proj="${2:-}"; shift 2 ;;
    --workspace-root) ws_root_arg="${2:-}"; shift 2 ;;
    --reset) reset=1; shift ;;
    --help) usage; exit 0 ;;
    *) echo "init-checker-scaffold.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$proj" ] || proj="${CLAUDE_PROJECT_DIR:-$PWD}"
ws_root_write="${ws_root_arg:-.touchstone}"

yaml="$proj/.claude/touchstone.yaml"
ws_root="$ws_root_write"

# ---- Step 1 (idempotence): decide from current file state before touching
# anything else — a missing/malformed/no-reset file never reaches mkdir or
# the yaml write below.
if [ -f "$yaml" ]; then
  command -v python3 >/dev/null 2>&1 || { echo "init-checker-scaffold.sh: python3 not found" >&2; exit 2; }
  python3 -c 'import yaml' 2>/dev/null || { echo "init-checker-scaffold.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }

  if ! python3 - "$yaml" <<'PY'
import sys, yaml
path = sys.argv[1]
try:
    with open(path, encoding='utf-8') as f:
        yaml.safe_load(f)
except yaml.YAMLError as e:
    mark = getattr(e, 'problem_mark', None)
    loc = f"line {mark.line + 1}, column {mark.column + 1}" if mark is not None else "unknown location"
    print(f"init-checker-scaffold.sh: {path}: malformed YAML — parse error at {loc}: {e}", file=sys.stderr)
    sys.exit(1)
PY
  then
    exit 1
  fi

  if [ "$reset" -eq 0 ]; then
    echo "Current config:"
    cat "$yaml"
    echo "already configured — run /touchstone:init --reset to overwrite."
    exit 0
  fi

  bak="$proj/.claude/touchstone.yaml.bak"
  cp "$yaml" "$bak" || { echo "init-checker-scaffold.sh: could not write $bak" >&2; exit 2; }
  echo "Preserved prior yaml at .bak"
fi

# ---- Step 2 (was Step 3): seven workspace subpaths.
for sub in specs docs/adr epics plans archive/specs archive/epics research; do
  mkdir -p "$proj/$ws_root/$sub" || { echo "init-checker-scaffold.sh: mkdir failed: $proj/$ws_root/$sub" >&2; exit 2; }
done

# ---- Step 3 (was Step 3b): checker scaffold + .gitignore carve (idempotent;
# converges any partial state to canonical). Checker dirs stay at
# .touchstone/checker/ regardless of a custom workspace_root.
gi="$proj/.gitignore"
for stage in pre-commit pre-push; do
  mkdir -p "$proj/.touchstone/checker/$stage" || { echo "init-checker-scaffold.sh: mkdir failed: $proj/.touchstone/checker/$stage" >&2; exit 2; }
  : > "$proj/.touchstone/checker/$stage/.gitkeep" || { echo "init-checker-scaffold.sh: write failed: $proj/.touchstone/checker/$stage/.gitkeep" >&2; exit 2; }
done
[ -f "$gi" ] || : > "$gi"
tmp="$(mktemp)"; grep -vxF '!.touchstone/checker/' "$gi" | grep -vxF '!.touchstone/checker/**' > "$tmp" || true
mv "$tmp" "$gi"
if [ "$(grep -cxF '.touchstone/*' "$gi")" -eq 0 ]; then
  printf '.touchstone/*\n' >> "$gi"
fi
printf '!.touchstone/checker/\n!.touchstone/checker/**\n' >> "$gi"
if [ "$ws_root" != ".touchstone" ]; then
  ws_line="${ws_root}/*"
  if [ "$(grep -cxF "$ws_line" "$gi")" -eq 0 ]; then
    printf '%s\n' "$ws_line" >> "$gi"
  fi
fi

# ---- Step 4: write yaml.
plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(grep -o '"version": *"[^"]*"' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
[ -n "$version" ] || version="unknown"
mkdir -p "$proj/.claude" || { echo "init-checker-scaffold.sh: mkdir failed: $proj/.claude" >&2; exit 2; }
{
  printf '# written by /touchstone:init v%s. Hand-editable.\n' "$version"
  printf 'schema_version: 2\n'
  printf 'workspace_root: %s\n' "$ws_root"
} > "$yaml" || { echo "init-checker-scaffold.sh: write failed: $yaml" >&2; exit 2; }

# ---- Step 5: verification summary.
echo "✓ Wrote $yaml"
printf '  workspace_root:      %s\n' "$ws_root"
echo
echo "Next: try /touchstone:design-spec <feature-name>"
exit 0
