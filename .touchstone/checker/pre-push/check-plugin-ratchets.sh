#!/usr/bin/env bash
# check-plugin-ratchets.sh — pre-push: two size ratchets from plugin-map.sh
# (max_stage_load_tokens, untested_reachable_shell_lines) must not exceed the
# committed baseline (.touchstone/checker/baselines/plugin-ratchets.txt); a
# measurement below baseline prints "ratchet may fall" for the maintainer to
# tighten it — this checker never rewrites the baseline itself.
# max_stage_load_tokens = the max over stages of (sum of the byte size of the
# UNION of that stage's contexts[].files, under --root) / 4, integer division.
#
# plugin-map.sh is this checker's own sibling tool — never duplicated into a
# fixture tree — located relative to THIS script's own path, then run with
# `--root <measured-tree>` so it measures a fixture standing in for "a repo"
# during the smoke rail exactly as readily as the real repo.
set -uo pipefail

root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

here="$(cd "$(dirname "$0")" && pwd)"
own_repo="$(cd "$here/../../.." && pwd 2>/dev/null)" || exit 0
pm="$own_repo/scripts/plugin-map.sh"
[ -f "$pm" ] || exit 0                       # tooling not installed — passthrough

bf="$root/.touchstone/checker/baselines/plugin-ratchets.txt"
[ -f "$bf" ] || exit 0                       # no ratchet baseline for this tree — passthrough

# ---- baseline file: "key value" per line, `#` starts a comment, blanks skipped.
read_key() {  # <key> -> prints the matching stripped "key value" line, or nothing
  local key="$1" raw stripped k
  while IFS= read -r raw; do
    stripped="${raw%%#*}"
    stripped="$(printf '%s' "$stripped" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -n "$stripped" ] || continue
    k="${stripped%% *}"
    [ "$k" = "$key" ] && { printf '%s\n' "$stripped"; return 0; }
  done < "$bf"
  return 1
}

malformed=0
b_max=""; b_shell=""
for key in max_stage_load_tokens untested_reachable_shell_lines; do
  line="$(read_key "$key")"
  if [ -z "$line" ]; then
    printf '[check-plugin-ratchets] BLOCK: baseline missing key: %s\n' "$key"
    malformed=1
    continue
  fi
  val="${line#* }"
  val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  case "$val" in
    ''|*[!0-9]*)
      printf '[check-plugin-ratchets] BLOCK: baseline line not an integer: %s\n' "$line"
      malformed=1
      continue ;;
  esac
  case "$key" in
    max_stage_load_tokens) b_max="$val" ;;
    untested_reachable_shell_lines) b_shell="$val" ;;
  esac
done
[ "$malformed" -eq 0 ] || exit 1

command -v python3 >/dev/null 2>&1 || { echo "[check-plugin-ratchets] WARNING: python3 not found — skipping (infra-safe)"; exit 0; }

map_json="$(bash "$pm" --root "$root" 2>&1)"; map_rc=$?
if [ "$map_rc" -ne 0 ]; then
  printf '[check-plugin-ratchets] BLOCK: plugin-map.sh --root %s failed (rc=%s):\n%s\n' "$root" "$map_rc" "$map_json"
  exit 1
fi

if ! metrics="$(printf '%s' "$map_json" | python3 -c '
import json, os, sys
d = json.load(sys.stdin)
root = sys.argv[1]
max_tokens = 0
for st in d.get("stages", []):
    files = set()
    for ctx in st.get("contexts", []):
        files.update(ctx.get("files", []))
    total_bytes = 0
    for f in files:
        try:
            total_bytes += os.path.getsize(os.path.join(root, f))
        except OSError:
            pass
    tokens = total_bytes // 4
    if tokens > max_tokens:
        max_tokens = tokens
m = d.get("metrics", {})
print(max_tokens)
print(m.get("untested_reachable_shell_lines", 0))
' "$root" 2>&1)"; then
  printf '[check-plugin-ratchets] BLOCK: could not parse plugin-map.sh metrics:\n%s\n' "$metrics"
  exit 1
fi

m_max="$(printf '%s\n' "$metrics" | sed -n '1p')"
m_shell="$(printf '%s\n' "$metrics" | sed -n '2p')"

block=0
report_key() {  # <key> <measured> <baseline>
  local key="$1" m="$2" b="$3"
  if [ "$m" -gt "$b" ]; then
    printf '[check-plugin-ratchets] BLOCK: %s measured %s > baseline %s\n' "$key" "$m" "$b"
    block=1
  elif [ "$m" -lt "$b" ]; then
    printf 'ratchet may fall: %s %s \342\206\222 %s\n' "$key" "$b" "$m"
  fi
}
report_key max_stage_load_tokens "$m_max" "$b_max"
report_key untested_reachable_shell_lines "$m_shell" "$b_shell"

[ "$block" -eq 0 ] || exit 1
exit 0
