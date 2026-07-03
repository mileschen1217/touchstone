#!/usr/bin/env bash
# SC2016: grep patterns search for the literal string ${CLAUDE_PLUGIN_ROOT} in file content
#         (single-quote intentional — no expansion wanted).
# shellcheck disable=SC2016
# deployed-smoke.sh — verify the deployed plugin cache matches what this repo ships.
#
# Locates the cache at ~/.claude/plugins/cache/touchstone/touchstone/<version>/
# where <version> is read from .claude-plugin/plugin.json (or overridden with --version).
#
# Prints PASS/FAIL for four checks:
#   (1) key files exist: skills/*/SKILL.md count ≥ repo, hooks/ and scripts/ present
#   (2) all scripts/**/*.sh in the cache carry the filesystem exec bit
#   (3) bare-path lint: no unguarded "bash scripts/..." or "Read \`skills/..." in cache skills/**/*.md
#   (4) every ${CLAUDE_PLUGIN_ROOT}/<path> referenced in this repo's skills/ exists in the cache
#
# Usage:
#   bash scripts/deployed-smoke.sh                  # checks version from plugin.json
#   bash scripts/deployed-smoke.sh --version 0.11.0 # override version
#   CACHE_ROOT=<path> bash scripts/deployed-smoke.sh # override cache root
set -uo pipefail

# SMOKE_REPO_ROOT overrides the repo root (used in tests to point at a fake repo).
REPO_ROOT="${SMOKE_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# --- resolve version ---
VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    *) echo "Usage: $0 [--version <ver>]" >&2; exit 1 ;;
  esac
done
if [ -z "$VERSION" ]; then
  VERSION="$(grep -o '"version": *"[^"]*"' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null \
    | grep -o '"[^"]*"$' | tr -d '"')"
  [ -n "$VERSION" ] || { echo "[smoke] error: could not parse version from .claude-plugin/plugin.json" >&2; exit 1; }
fi

# --- locate cache ---
CACHE_ROOT="${CACHE_ROOT:-$HOME/.claude/plugins/cache/touchstone/touchstone}"
CACHE="$CACHE_ROOT/$VERSION"

echo "[smoke] repo version : $VERSION"
echo "[smoke] cache path   : $CACHE"
echo ""

if [ ! -d "$CACHE" ]; then
  echo "FAIL: version $VERSION not deployed (cache directory not found: $CACHE)"
  echo "      Deploy: bump version → merge PR → run /plugins update → /reload-plugins"
  exit 1
fi

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "PASS ($1)"; }
bad() { fail=$((fail+1)); echo "FAIL ($1): $2"; }

# --- (1) key files exist ---
repo_skill_count="$(find "$REPO_ROOT/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
cache_skill_count="$(find "$CACHE/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
hooks_present=0; scripts_present=0
[ -d "$CACHE/hooks" ]   && hooks_present=1
[ -d "$CACHE/scripts" ] && scripts_present=1
if [ "$cache_skill_count" -ge "$repo_skill_count" ] \
   && [ "$hooks_present" -eq 1 ] \
   && [ "$scripts_present" -eq 1 ]; then
  ok "1-key-files" "skills=$cache_skill_count (≥$repo_skill_count), hooks/ and scripts/ present"
else
  bad "1-key-files" "skills=$cache_skill_count (need ≥$repo_skill_count), hooks_present=$hooks_present, scripts_present=$scripts_present"
fi

# --- (2) exec bits on all scripts/**/*.sh ---
missing_exec=""
while IFS= read -r f; do
  [ -x "$f" ] || missing_exec="$missing_exec\n  $f"
done < <(find "$CACHE/scripts" -name '*.sh' 2>/dev/null | sort)
if [ -z "$missing_exec" ]; then
  ok "2-exec-bits" "all scripts/**/*.sh are executable"
else
  bad "2-exec-bits" "missing exec bit on:$missing_exec"
fi

# --- (3) bare-path lint on cache skills/**/*.md ---
# Replicates the pattern from check-bare-plugin-paths.sh without git dependency.
bare_hits=""
while IFS= read -r f; do
  prev_exempt=0
  lineno=0
  while IFS= read -r line; do
    lineno=$((lineno+1))
    this_exempt=0
    printf '%s' "$line" | grep -qF '<!-- bare-path-ok -->' && this_exempt=1
    if [ "$this_exempt" -eq 1 ] || [ "$prev_exempt" -eq 1 ]; then
      prev_exempt=$this_exempt; continue
    fi
    prev_exempt=$this_exempt
    # Pattern A: bash/run + bare path
    if printf '%s' "$line" | grep -qE '(^|[[:space:]])(bash|run)[[:space:]]+"?(scripts|skills)/'; then
      if ! printf '%s' "$line" | grep -qF '${CLAUDE_PLUGIN_ROOT}'; then
        bare_hits="$bare_hits\n  $f:$lineno"
      fi
    fi
    # Pattern B: Read/read + backtick bare path
    if printf '%s' "$line" | grep -qE '(Read|read)[[:space:]]+`(skills|scripts|commands|agents)/'; then
      if ! printf '%s' "$line" | grep -qF '${CLAUDE_PLUGIN_ROOT}'; then
        bare_hits="$bare_hits\n  $f:$lineno"
      fi
    fi
  done < "$f"
done < <(find "$CACHE/skills" "$CACHE/commands" "$CACHE/agents" -name '*.md' 2>/dev/null | sort)
if [ -z "$bare_hits" ]; then
  ok "3-bare-path-lint" "no bare execution paths in cache skills/**/*.md"
else
  bad "3-bare-path-lint" "bare paths found:$bare_hits"
fi

# --- (4) CLAUDE_PLUGIN_ROOT/<path> references resolve in cache ---
missing_refs=""
while IFS= read -r ref; do
  rel="${ref#\${CLAUDE_PLUGIN_ROOT\}/}"
  [ -e "$CACHE/$rel" ] || missing_refs="$missing_refs\n  $rel"
done < <(grep -rh 'CLAUDE_PLUGIN_ROOT' "$REPO_ROOT/skills/" 2>/dev/null \
           | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^`" ]+' | sort -u)
if [ -z "$missing_refs" ]; then
  ok "4-plugin-root-refs" "all \${CLAUDE_PLUGIN_ROOT}/... refs resolve in cache"
else
  bad "4-plugin-root-refs" "missing in cache:$missing_refs"
fi

echo ""
echo "PASS=$pass FAIL=$fail  (version=$VERSION)"
[ "$fail" -eq 0 ]
