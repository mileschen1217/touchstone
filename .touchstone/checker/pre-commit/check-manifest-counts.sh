#!/usr/bin/env bash
# check-manifest-counts.sh — pre-commit: plugin.json's skill/agent counts equal
# `ls skills agents`; every prefix in shipped-surface.txt exists on disk.
#
# Counts clause: parses "<n> skills"/"<n> skill" and "<n> agents"/"<n> agent"
# out of .claude-plugin/plugin.json's "description" string with grep/sed (jq
# used when present, since a plain field extraction is easier there, but jq is
# optional — the grep/sed fallback covers its absence). Compares against the
# actual tree: skill count = number of skills/*/SKILL.md files; agent count =
# number of agents/*.md files. If the description carries no such number for a
# side, there is nothing to compare on that side and it passes (reported on
# stdout only under -v).
#
# Prefix clause: every non-comment, non-blank line of
# .touchstone/shipped-surface.txt must name a path (file or directory) that
# exists under root.
#
# INV-1 self-check: this checker decides only count-equality and path
# existence — no semantic judgement of what a skill/agent/prefix is for.
#
# Output on failure: quotes both numbers (counts clause) or the prefix (prefix
# clause), prefixed [check-manifest-counts], exit 1. Clean → exit 0.
set -uo pipefail

verbose=0
[ "${1:-}" = "-v" ] && verbose=1

root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

fail=0
plugin_json="$root/.claude-plugin/plugin.json"

get_description() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.description // empty' "$1" 2>/dev/null
  else
    grep -m1 '"description"' "$1" 2>/dev/null | sed -E 's/.*"description"[[:space:]]*:[[:space:]]*"(.*)"[[:space:]]*,?[[:space:]]*$/\1/'
  fi
}

if [ -f "$plugin_json" ]; then
  desc="$(get_description "$plugin_json")"
  skills_claimed="$(printf '%s\n' "$desc" | grep -oE '[0-9]+ skills?\b' | head -1 | grep -oE '[0-9]+')"
  agents_claimed="$(printf '%s\n' "$desc" | grep -oE '[0-9]+ agents?\b' | head -1 | grep -oE '[0-9]+')"

  skills_actual="$(find "$root/skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
  agents_actual="$(find "$root/agents" -mindepth 1 -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"

  if [ -n "${skills_claimed:-}" ]; then
    if [ "$skills_claimed" != "$skills_actual" ]; then
      echo "[check-manifest-counts] plugin.json description says $skills_claimed skills, tree holds $skills_actual (skills/*/SKILL.md)"
      fail=1
    elif [ "$verbose" -eq 1 ]; then
      echo "[check-manifest-counts] skills: $skills_claimed matches tree"
    fi
  elif [ "$verbose" -eq 1 ]; then
    echo "[check-manifest-counts] no skill count in description — nothing to compare"
  fi

  if [ -n "${agents_claimed:-}" ]; then
    if [ "$agents_claimed" != "$agents_actual" ]; then
      echo "[check-manifest-counts] plugin.json description says $agents_claimed agents, tree holds $agents_actual (agents/*.md)"
      fail=1
    elif [ "$verbose" -eq 1 ]; then
      echo "[check-manifest-counts] agents: $agents_claimed matches tree"
    fi
  elif [ "$verbose" -eq 1 ]; then
    echo "[check-manifest-counts] no agent count in description — nothing to compare"
  fi
fi

surface="$root/.touchstone/shipped-surface.txt"
if [ -f "$surface" ]; then
  while IFS= read -r line; do
    trimmed="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [ -z "$trimmed" ] && continue
    case "$trimmed" in \#*) continue ;; esac
    prefix="${trimmed%/}"
    if [ ! -e "$root/$prefix" ]; then
      echo "[check-manifest-counts] shipped-surface.txt prefix '$trimmed' does not exist under $root"
      fail=1
    fi
  done < "$surface"
fi

exit "$fail"
