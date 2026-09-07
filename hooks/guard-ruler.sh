#!/usr/bin/env bash
# hooks/guard-ruler.sh — shipped PreToolUse(Edit|Write) hook: the frozen-ruler guard.
# An Edit or Write is blocked (exit 2, the path named on stderr) when its path is an epic's
# build/freeze.json, a file that freeze.json lists (build/ruler.yaml is protected this way
# only), or anything under that epic's build/ruler/ (a new file there counts). Every other
# path — build/disputes.yaml above all — passes silently. A wrong frozen test is a dispute
# entry, never an edit. Needs bash + jq; no jq → exit 0 (held-out's sha check remains).
set -u

payload="$(cat 2>/dev/null || true)"
command -v jq >/dev/null 2>&1 || exit 0
path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$path" ] || exit 0
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

normalize() {  # absolute path with . and .. collapsed, no filesystem access needed
  local p="$1" out="" part
  case "$p" in /*) ;; *) p="$cwd/$p" ;; esac
  local IFS='/'
  for part in $p; do
    case "$part" in
      ''|'.') ;;
      '..') out="${out%/*}" ;;
      *) out="$out/$part" ;;
    esac
  done
  printf '%s' "${out:-/}"
}

target="$(normalize "$path")"
block() {  # <why>
  printf 'guard-ruler: %s is frozen (%s) — a wrong test is an entry in build/disputes.yaml, never an edit\n' "$target" "$1" >&2
  exit 2
}

dir="${target%/*}"
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ "${dir##*/}" = "build" ] && [ -f "$dir/freeze.json" ]; then
    [ "$target" = "$dir/freeze.json" ] && block "the freeze record itself"
    case "$target" in "$dir/ruler/"*) block "under $dir/ruler/" ;; esac
    # a listed key is repo-relative (the epic layout), epic-relative (a fixture layout) or absolute
    root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$root" ] || root="$cwd"
    epic="${dir%/build}"
    while IFS= read -r listed; do
      [ -n "$listed" ] || continue
      case "$listed" in
        /*) abs="$(normalize "$listed")"; [ "$abs" = "$target" ] && block "listed in $dir/freeze.json" ;;
        *)  for base in "$root" "$epic" "$cwd"; do
              [ "$(normalize "$base/$listed")" = "$target" ] && block "listed in $dir/freeze.json"
            done
            case "$target" in *"/$listed") block "listed in $dir/freeze.json" ;; esac ;;
      esac
    done < <(jq -r '.files | keys[]' "$dir/freeze.json" 2>/dev/null)
    exit 0
  fi
  dir="${dir%/*}"
done
exit 0
