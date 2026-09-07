#!/usr/bin/env bash
# PostToolUse(Write|Edit): render each epic touched by a Claude file write or a
# Codex apply_patch payload. This hook is advisory and never blocks the write.
set -u

command -v jq >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
if [ -n "$file_path" ]; then
  paths="$file_path"
else
  patch="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
  [ -n "$patch" ] || exit 0
  paths="$(printf '%s\n' "$patch" | sed -nE 's/^\*\*\* (Add|Update) File: (.+)$/\2/p')"
fi
[ -n "$paths" ] || exit 0

pcwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$pcwd" ] || pcwd="$PWD"

root="${TOUCHSTONE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
if [ -z "$root" ]; then
  if command -v git >/dev/null 2>&1; then
    root="$(git -C "$pcwd" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  [ -n "$root" ] || root="$pcwd"
fi
[ -n "$root" ] && [ -d "$root" ] || exit 0
root="$(cd "$root" 2>/dev/null && pwd -P)" || exit 0

read_workspace_root() {
  local path="$1" value=""
  [ -f "$path" ] || return 0
  value="$(grep -m1 -E '^[[:space:]]*workspace_root:' "$path" 2>/dev/null | sed -E 's/^[[:space:]]*workspace_root:[[:space:]]*//')"
  case "$value" in
    \"*) value="${value#\"}"; value="${value%%\"*}" ;;
    \'*) value="${value#\'}"; value="${value%%\'*}" ;;
    *) value="${value%%#*}"; value="$(printf '%s' "$value" | sed 's/[[:space:]]*$//')" ;;
  esac
  printf '%s' "$value"
}

neutral="$root/touchstone.yaml"
legacy="$root/.claude/touchstone.yaml"
w_neutral="$(read_workspace_root "$neutral")"
w_legacy="$(read_workspace_root "$legacy")"
if [ -n "$w_neutral" ] && [ -n "$w_legacy" ] && [ "$w_neutral" != "$w_legacy" ]; then
  jq -nc '{systemMessage:"dossier-render skipped: conflicting touchstone.yaml files"}' 2>/dev/null \
    || printf '{"systemMessage":"dossier-render skipped: conflicting touchstone.yaml files"}\n'
  exit 0
fi
w="${w_neutral:-${w_legacy:-.touchstone}}"
case "$w" in /*) wroot="$w" ;; *) wroot="$root/$w" ;; esac

epic_dirs=""
while IFS= read -r path; do
  case "$path" in *.yaml|*.yml) ;; *) continue ;; esac
  case "$path" in /*) abs="$path" ;; *) abs="$pcwd/$path" ;; esac
  abs_dir="$(cd "$(dirname "$abs")" 2>/dev/null && pwd -P)" || continue
  abs="$abs_dir/$(basename "$abs")"
  rel=""
  case "$abs" in
    "$wroot"/epics/*) base="$wroot/epics"; rel="${abs#"$base"/}" ;;
    "$wroot"/archive/epics/*) base="$wroot/archive/epics"; rel="${abs#"$base"/}" ;;
    *) continue ;;
  esac
  epic="${rel%%/*}"
  [ -n "$epic" ] && [ "$epic" != "$rel" ] || continue
  case "$epic" in .|..) continue ;; esac
  epic_dir="$base/$epic"
  [ -d "$epic_dir" ] || continue
  epic_dirs="${epic_dirs:+${epic_dirs}
}${epic_dir}"
done <<EOF
$paths
EOF
[ -n "$epic_dirs" ] || exit 0

plugin_root="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd -P)" || exit 0
renderer="$plugin_root/scripts/dossier-render.sh"
[ -f "$renderer" ] || exit 0
if ! command -v python3 >/dev/null 2>&1; then
  jq -nc '{systemMessage:"dossier-render skipped: python3 not found"}' 2>/dev/null \
    || printf '{"systemMessage":"dossier-render skipped: python3 not found"}\n'
  exit 0
fi

while IFS= read -r epic_dir; do
  [ -n "$epic_dir" ] || continue
  out="$(bash "$renderer" "$epic_dir" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    first_line="$(printf '%s\n' "$out" | head -1)"
    jq -nc --arg msg "dossier-render failed: $first_line" '{systemMessage: $msg}' 2>/dev/null \
      || printf '{"systemMessage":"dossier-render failed"}\n'
    exit 0
  fi
done <<EOF
$(printf '%s\n' "$epic_dirs" | sort -u)
EOF
exit 0
