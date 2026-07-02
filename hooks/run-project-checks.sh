#!/usr/bin/env bash
# run-project-checks.sh — CC PreToolUse(Bash) handler: run a repo's own
# .touchstone/checker/<stage>/check-*.sh before the agent's git commit/push.
# SAFETY CONTRACT (mirrors stamp-run.sh): every infra failure exits 0; ONLY a
# covered command whose project check fails exits 2. Checks are locus-agnostic.
set -u

# classify_command <shell-string> -> echoes pre-commit | pre-push | none
# EXCLUDED is matched BEFORE COVERED and overrides it (spec precedence).
classify_command() {
  cmd="$1"
  # EXCLUDED first: read-only/config/dry-run/stash/other-verbs + cd-prefixed commit (KNOWN-LIMITATION)
  case "$cmd" in
    *"git commit --dry-run"*)            echo none; return ;;
    *"git config commit"*)               echo none; return ;;
    *"git cherry-pick"*|*"git revert"*|*"git merge"*) echo none; return ;;
    *"cd "*"&&"*"git commit"*)           echo none; return ;;   # cd-prefixed commit: cannot resolve <p>
    *"git status"*|*"git log"*|*"git diff"*|*"git show"*|*"git stash"*) echo none; return ;;
  esac
  # COVERED: a real git commit / push subcommand anywhere in the string.
  # Strip env/assignment prefixes and a leading `cd … &&` was already excluded above.
  # Find the git invocation: the first word `git` that is a command head.
  # Split on && ; || and inspect each segment's first token.
  #
  # TWO IFS regimes (bash-3.2 gotcha, do NOT collapse them):
  #   * IFS=';&|' selects the SEGMENT word-list for `for seg in $cmd` (chain split).
  #   * IFS=" \t\n" (whitespace) MUST be restored before each `set -- $seg`, or the
  #     segment is one un-split token and `$1` is the whole string (≠ "git") → every
  #     covered form wrongly classifies `none`. `set -f` guards commit messages that
  #     contain a glob (`git commit -m "fix *.go"`) from pathname expansion.
  set -f
  oldIFS="$IFS"; IFS=';&|'
  matched=none
  for seg in $cmd; do
    IFS=' 	
'                      # restore whitespace word-splitting for the token reparse
    # shellcheck disable=SC2086  # intentional: unquoted $seg for word-splitting; set -f guards globs
    set -- $seg
    IFS=';&|'                # restore chain-split IFS for the next for-iteration
    # drop leading VAR=val and env prefixes
    while [ $# -gt 0 ]; do case "$1" in *=*) shift ;; env) shift ;; *) break ;; esac; done
    [ "${1:-}" = "git" ] || continue
    shift
    # skip -C <path> / -c k=v global options to reach the subcommand.
    # `[ $# -gt 1 ] || break` guards a malformed trailing `git -C` (no path arg):
    # on bash 3.2 a bare `shift 2` with $#=1 is a no-op that would spin this loop.
    while [ $# -gt 0 ]; do
      case "$1" in
        -C) [ $# -gt 1 ] || break; shift 2 ;;
        -c) [ $# -gt 1 ] || break; shift 2 ;;
        --git-dir=*|--work-tree=*) shift ;;
        *) break ;;
      esac
    done
    case "${1:-}" in
      commit) matched=pre-commit ;;
      push)   matched=pre-push ;;
    esac
  done
  IFS="$oldIFS"; set +f
  echo "$matched"; return
}

# effective_git_dir <cmd> <payload_cwd> -> echoes the dir to resolve the repo from.
# Honours `git -C <path>`; a RELATIVE -C path joins to payload cwd (NOT the hook's
# own process cwd, which is the plugin root). Falls back to payload cwd.
effective_git_dir() {
  cmd="$1"; pcwd="$2"
  set -f                       # parity with classify_command: guard globby commit msgs
  # shellcheck disable=SC2086  # intentional: unquoted $cmd for word-splitting to parse tokens
  set -- $cmd
  set +f
  # find `git` head then a -C value
  while [ $# -gt 0 ]; do [ "$1" = "git" ] && break; shift; done
  [ "${1:-}" = "git" ] && shift
  cdir=""
  # `[ $# -gt 1 ] || break` guards a malformed trailing `git -C` (no path arg) —
  # a bare `shift 2` with $#=1 is a bash-3.2 no-op that would spin this loop.
  while [ $# -gt 0 ]; do
    case "$1" in
      -C) cdir="${2:-}"; [ $# -gt 1 ] || break; shift 2 ;;
      -c) [ $# -gt 1 ] || break; shift 2 ;;
      *) break ;;
    esac
  done
  if [ -n "$cdir" ]; then
    case "$cdir" in
      /*) echo "$cdir" ;;                 # absolute
      *)  echo "$pcwd/$cdir" ;;           # relative → join payload cwd
    esac
  else
    echo "$pcwd"
  fi
}

main() {
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v git >/dev/null 2>&1 || exit 0
  payload="$(cat 2>/dev/null || true)"; [ -n "$payload" ] || exit 0
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
  [ -n "$cmd" ] || exit 0
  stage="$(classify_command "$cmd")"
  [ "$stage" = none ] && exit 0
  pcwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
  [ -n "$pcwd" ] || pcwd="$PWD"
  gdir="$(effective_git_dir "$cmd" "$pcwd")"
  root="$(git -C "$gdir" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] || exit 0                 # not a repo / infra → passthrough
  dir="$root/.touchstone/checker/$stage"
  [ -d "$dir" ] || exit 0                   # absent stage → passthrough
  for chk in "$dir"/check-*.sh; do
    [ -e "$chk" ] || continue               # zero-glob → literal, skip
    # Honour the +x contract: a non-executable check is a MISCONFIGURED check, not
    # an infra fault — surface it as a named block (the structure meta-check AC-22
    # flags it pre-emptively, but the runtime must not silently run it via `bash`).
    if [ ! -x "$chk" ]; then
      printf '[touchstone-checker] FAIL: %s is not executable (chmod +x it)\n' "$chk" >&2
      exit 2
    fi
    if ! out="$("$chk" 2>&1)"; then         # execute directly, honouring the +x bit
      printf '[touchstone-checker] FAIL: %s\n%s\n' "$chk" "$out" >&2
      exit 2                                # fail-fast: first failure blocks
    fi
  done
  exit 0                                     # all passed / zero-glob
}

# source-guard: tests source this file for classify_command/effective_git_dir
# without running main. Only run main when executed directly (stdin is the payload).
case "${BASH_SOURCE[0]}" in
  "$0") main ;;
esac
