#!/usr/bin/env bash
# Run a review through a complementary provider CLI and leave auditable
# liveness plus a normalized last-message file in the caller's result dir.
set -uo pipefail

usage() {
  echo "usage: run-external-reviewer.sh --provider <codex|claude-code> --lens-file <path> --subject-file <path> --result-dir <dir> [--timeout <seconds>]" >&2
}

provider=""
lens_file=""
subject_file=""
result_dir=""
timeout_s=600
while [ $# -gt 0 ]; do
  case "$1" in
    --provider) provider="${2:-}"; shift 2 ;;
    --lens-file) lens_file="${2:-}"; shift 2 ;;
    --subject-file) subject_file="${2:-}"; shift 2 ;;
    --result-dir) result_dir="${2:-}"; shift 2 ;;
    --timeout) timeout_s="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

case "$provider" in codex|claude-code) ;; *) usage; exit 2 ;; esac
[ -f "$lens_file" ] || { echo "run-external-reviewer.sh: lens file not found: $lens_file" >&2; exit 2; }
[ -f "$subject_file" ] || { echo "run-external-reviewer.sh: subject file not found: $subject_file" >&2; exit 2; }
case "$timeout_s" in ''|*[!0-9]*) echo "run-external-reviewer.sh: timeout must be a positive integer" >&2; exit 2 ;; esac
[ "$timeout_s" -gt 0 ] || { echo "run-external-reviewer.sh: timeout must be a positive integer" >&2; exit 2; }
mkdir -p "$result_dir" || { echo "run-external-reviewer.sh: cannot create result dir: $result_dir" >&2; exit 2; }

role_prompt="$(cat -- "$lens_file")"

if [ "$provider" = codex ]; then
  command -v codex >/dev/null 2>&1 || { echo "run-external-reviewer.sh: codex unavailable" >&2; exit 1; }
  raw="$result_dir/raw_codex.jsonl"
  last="$result_dir/last-message.txt"
  if ! timeout "$timeout_s" codex exec --ephemeral --json --skip-git-repo-check \
      -o "$last" "$role_prompt" < "$subject_file" > "$raw" 2>&1; then
    echo "run-external-reviewer.sh: codex failed; inspect $raw" >&2
    exit 1
  fi
else
  command -v claude >/dev/null 2>&1 || { echo "run-external-reviewer.sh: claude unavailable" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "run-external-reviewer.sh: jq unavailable" >&2; exit 2; }
  raw="$result_dir/raw_claude.json"
  last="$result_dir/last-message-claude.txt"
  if ! timeout "$timeout_s" claude -p --output-format json \
      --permission-mode dontAsk --no-session-persistence \
      --system-prompt "$role_prompt" < "$subject_file" > "$raw" 2>&1; then
    echo "run-external-reviewer.sh: claude failed; inspect $raw" >&2
    exit 1
  fi
  if ! jq -er '.result | select(type == "string" and length > 0)' "$raw" > "$last"; then
    echo "run-external-reviewer.sh: claude returned no result; inspect $raw" >&2
    exit 1
  fi
fi

[ -s "$raw" ] && [ -s "$last" ] || {
  echo "run-external-reviewer.sh: missing liveness output for $provider" >&2
  exit 1
}
printf 'status=ok\nprovider=%s\nraw=%s\nlast=%s\n' "$provider" "$raw" "$last"
