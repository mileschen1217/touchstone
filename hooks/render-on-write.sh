#!/usr/bin/env bash
# hooks/render-on-write.sh — shipped PostToolUse(Write|Edit|Bash) hook: the dossier
# staleness sweep. The decision is never the written path (a Bash payload carries none):
# for every epic dir under W/epics/ and W/archive/epics/ (W = workspace_root from
# <root>/.claude/touchstone.yaml, default .touchstone — the key config-resolver.md reads,
# parsed here with grep/sed so the gate needs no python3),
#   stale ⇔ dossier.html is absent while epic.yaml exists, or
#           `find <dir> -mindepth 1 -newer dossier.html -print -quit` returns any entry
#           (files of every extension and directories below the root, so a deletion counts
#           through its parent's mtime; the epic dir itself is excluded because writing
#           dossier.html updates it; the renderer's own outputs dossier.html / pr-body.md
#           are excluded).
# Stale → this plugin's own scripts/dossier-render.sh (plugin-root = the directory above
# this script's own directory, never <root>/scripts/) re-renders it; not stale → no
# subprocess, no write. Zero epic dirs → exit 0, no output, after the two root stats.
# Cost per tool call = one find per epic dir, stopping at its first hit.
#
# SAFETY CONTRACT: never blocks a tool call. Every path — no root, missing renderer or
# python3, a render failure — exits 0 and prints at most ONE line. A render failure
# leaves the previous dossier.html untouched (dossier-render.sh writes it once, at the
# very end, after all parsing) and names the failure. Several stale dirs share the one
# line. PostToolUse plain stdout is not shown to the session, so the line is emitted as
# JSON `{"systemMessage": "..."}` — the form that surfaces.
set -u

payload="$(cat 2>/dev/null || true)"
pcwd=""
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  pcwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
fi
[ -n "$pcwd" ] || pcwd="$PWD"

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  command -v git >/dev/null 2>&1 || exit 0
  root="$(git -C "$pcwd" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$root" ] && [ -d "$root" ] || exit 0
root="$(cd "$root" 2>/dev/null && pwd)" || exit 0
[ -n "$root" ] || exit 0

# W = workspace_root from <root>/.claude/touchstone.yaml (default .touchstone) — grep the
# first `^workspace_root:` line, strip an inline comment, trim, strip surrounding quotes.
w=""
wcfg="$root/.claude/touchstone.yaml"
if [ -f "$wcfg" ]; then
  w="$(grep -m1 -E '^[[:space:]]*workspace_root:' "$wcfg" 2>/dev/null | sed -E 's/^[[:space:]]*workspace_root:[[:space:]]*//')"
  case "$w" in
    \"*) w="${w#\"}"; w="${w%%\"*}" ;;
    \'*) w="${w#\'}"; w="${w%%\'*}" ;;
    *)   w="${w%%#*}"; w="$(printf '%s' "$w" | sed 's/[[:space:]]*$//')" ;;
  esac
fi
[ -n "$w" ] || w=".touchstone"
case "$w" in
  /*) wroot="$w" ;;
  *)  wroot="$root/$w" ;;
esac

# the two root stats — zero epic dirs → silent exit
epics="$wroot/epics"; archive="$wroot/archive/epics"
[ -d "$epics" ] || [ -d "$archive" ] || exit 0

stale=()
for base in "$epics" "$archive"; do
  [ -d "$base" ] || continue
  for d in "$base"/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    if [ ! -f "$d/dossier.html" ]; then
      [ -f "$d/epic.yaml" ] && stale+=("$d")
      continue
    fi
    if [ -n "$(find "$d" -mindepth 1 -newer "$d/dossier.html" ! -name dossier.html ! -name pr-body.md -print -quit 2>/dev/null)" ]; then
      stale+=("$d")
    fi
  done
done
[ "${#stale[@]}" -gt 0 ] || exit 0

emit() {  # one systemMessage line, jq when present
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg msg "$1" '{systemMessage: $msg}' 2>/dev/null && return 0
  fi
  printf '{"systemMessage":"%s"}\n' "$(printf '%s' "$1" | sed 's/["\\]/\\&/g')"
}

plugin_root="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd -P)" || exit 0
renderer="$plugin_root/scripts/dossier-render.sh"
[ -f "$renderer" ] || exit 0
if ! command -v python3 >/dev/null 2>&1; then
  emit "dossier-render skipped: python3 not found"
  exit 0
fi

rendered=""; failed=""
for d in "${stale[@]}"; do
  rel="${d#"$wroot"/}"
  if out="$(bash "$renderer" "$d" 2>&1)"; then
    rendered="${rendered:+$rendered, }$rel"
  else
    failed="${failed:+$failed; }dossier-render failed: $rel: $(printf '%s\n' "$out" | head -1)"
  fi
done
msg=""
[ -n "$rendered" ] && msg="dossier re-rendered: $rendered"
[ -n "$failed" ] && msg="${msg:+$msg; }$failed"
[ -n "$msg" ] && emit "$msg"
exit 0
