# shellcheck shell=bash
# cursor-lib.sh — shared byte-cursor scan-state mechanics for L0 tail-only
# extractors. "transcripts" and "firelog" share an IDENTICAL cursor
# contract (byte-cursor tail-only, AC-5/AC-6 semantics — see spec
# Interfaces § scan-state.json): scan forward from a per-file cursor, skip
# a final unterminated line (still being written), reset to 0 when the
# cursor exceeds the current file size. This file factors that mechanism
# out of extract-transcript.sh (built first) so extract-firelog.sh reuses
# it instead of re-deriving it. Sourced, not executed — no shebang exec
# bit needed; inherits the caller's `set` options.
#
# Functions:
#   cursor_lib_resolve_ledger_dir <caller-name>
#     Echoes the ledger dir ($TOUCHSTONE_LEDGER_DIR, or
#     <git-toplevel>/.touchstone/ledger). Returns 1 and prints
#     "<caller-name>: not inside a git repo; set TOUCHSTONE_LEDGER_DIR" to
#     stderr when neither is available.
#   cursor_lib_load_state <ldir>
#     Echoes the contents of <ldir>/scan-state.json, or '{}' if absent.
#   cursor_lib_section <state-json> <section-name>
#     Echoes state[section-name], or '{}' if the section is absent.
#   cursor_lib_fs_bytes <file>
#     Echoes the file's size in bytes.
#   cursor_lib_reset_if_shrunk <cursor> <fs-bytes>
#     Echoes 0 when cursor > fs-bytes (reset-on-shrink, AC-6); otherwise
#     echoes cursor unchanged.
#   cursor_lib_tail_effective_end <file> <fs-bytes>
#     Echoes the byte offset to scan up to: fs-bytes, or fs-bytes minus the
#     final line's byte length when <file> does not end in a newline (an
#     unterminated final line is treated as still being written and is
#     re-read whole once it gets a trailing newline).
#   cursor_lib_prune_stale <section-json>
#     Echoes section-json with any key whose path no longer exists as a
#     file removed (a source file deleted/rotated away).
#   cursor_lib_commit_section <ldir> <state-json> <section-name> <new-section-json>
#     Writes state-json with .[section-name] = new-section-json to
#     <ldir>/scan-state.json via temp+mv, creating <ldir> if needed.
#   cursor_lib_propose <propose-file> <new-section-json>
#     Writes new-section-json (bare, no envelope) to <propose-file> via
#     temp+mv, creating its parent dir if needed.

cursor_lib_resolve_ledger_dir() {
  local caller="$1" toplevel
  if [ -n "${TOUCHSTONE_LEDGER_DIR:-}" ]; then
    printf '%s\n' "$TOUCHSTONE_LEDGER_DIR"
    return 0
  fi
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$toplevel" ]; then
    echo "$caller: not inside a git repo; set TOUCHSTONE_LEDGER_DIR" >&2
    return 1
  fi
  printf '%s\n' "$toplevel/.touchstone/ledger"
}

cursor_lib_load_state() {
  local ldir="$1"
  local scan_state="$ldir/scan-state.json"
  if [ -f "$scan_state" ]; then
    cat "$scan_state"
  else
    printf '%s' '{}'
  fi
}

cursor_lib_section() {
  local state_json="$1" name="$2"
  printf '%s' "$state_json" | jq -c --arg n "$name" '.[$n] // {}'
}

cursor_lib_fs_bytes() {
  wc -c < "$1" | tr -d ' '
}

cursor_lib_reset_if_shrunk() {
  local cursor="$1" fs_bytes="$2"
  if [ "$cursor" -gt "$fs_bytes" ]; then
    echo 0
  else
    echo "$cursor"
  fi
}

cursor_lib_tail_effective_end() {
  local f="$1" fs_bytes="$2" last_byte last_line_bytes
  last_byte=""
  if [ "$fs_bytes" -gt 0 ]; then
    last_byte="$(tail -c 1 -- "$f")"
  fi
  if [ -n "$last_byte" ]; then
    last_line_bytes="$(tail -n 1 -- "$f" | LC_ALL=C wc -c | tr -d ' ')"
    echo $((fs_bytes - last_line_bytes))
  else
    echo "$fs_bytes"
  fi
}

cursor_lib_prune_stale() {
  local section_json="$1" k
  local keys=()
  while IFS= read -r k; do
    keys+=("$k")
  done < <(printf '%s' "$section_json" | jq -r 'keys[]')
  for k in "${keys[@]:-}"; do
    [ -n "$k" ] || continue
    if [ ! -f "$k" ]; then
      section_json="$(printf '%s' "$section_json" | jq -c --arg p "$k" 'del(.[$p])')"
    fi
  done
  printf '%s' "$section_json"
}

cursor_lib_commit_section() {
  local ldir="$1" state_json="$2" name="$3" new_section="$4"
  local scan_state="$ldir/scan-state.json" new_state tmp
  mkdir -p "$ldir" || return 1
  new_state="$(printf '%s' "$state_json" | jq -c --arg n "$name" --argjson v "$new_section" '.[$n] = $v')"
  tmp="$(mktemp "${scan_state}.tmp.XXXXXX")"
  printf '%s\n' "$new_state" > "$tmp"
  mv "$tmp" "$scan_state"
}

cursor_lib_propose() {
  local propose_file="$1" new_section="$2" tmp
  mkdir -p "$(dirname "$propose_file")" || return 1
  tmp="$(mktemp "${propose_file}.tmp.XXXXXX")"
  printf '%s\n' "$new_section" > "$tmp"
  mv "$tmp" "$propose_file"
}
