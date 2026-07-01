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
    # skip -C <path> / -c k=v global options to reach the subcommand
    while [ $# -gt 0 ]; do
      case "$1" in
        -C) shift 2 ;;
        -c) shift 2 ;;
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
