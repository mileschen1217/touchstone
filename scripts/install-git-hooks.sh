#!/usr/bin/env bash
# install-git-hooks.sh — one-shot, idempotent installer for repo-local git hooks.
# installed-by: touchstone install-git-hooks
#
# Writes thin pre-commit and pre-push wrapper hooks that glob-execute
# .touchstone/checker/<stage>/check-*.sh before git commit / push.
# Complements the CC PreToolUse(Bash) hook (which fires only inside Claude Code);
# git hooks fire for terminal-direct commits/pushes too.
#
# Idempotent: a hook that already carries our marker is overwritten/updated.
# A foreign hook (no marker) is refused — the script prints guidance and exits 1.
#
# Worktree-safe: uses `git rev-parse --git-path hooks` (not the hardcoded .git/hooks).
#
# Usage: bash scripts/install-git-hooks.sh
set -uo pipefail

MARKER="# installed-by: touchstone install-git-hooks"

die() { printf '[install-git-hooks] error: %s\n' "$*" >&2; exit 1; }
say() { printf '[install-git-hooks] %s\n' "$*"; }

command -v git >/dev/null 2>&1 || die "git not found"
HOOKS_DIR="$(git rev-parse --git-path hooks 2>/dev/null)" \
  || die "not inside a git repository"
[ -n "$HOOKS_DIR" ] || die "could not resolve hooks directory"

# Normalise: git rev-parse --git-path hooks may return a relative path in worktrees
case "$HOOKS_DIR" in
  /*) ;;                                          # already absolute
  *)  HOOKS_DIR="$(git rev-parse --show-toplevel)/$HOOKS_DIR" ;;
esac
mkdir -p "$HOOKS_DIR"

# write_hook <stage>  — installs the wrapper for that stage
write_hook() {
  local stage="$1"
  local hook_path="$HOOKS_DIR/$stage"

  # Guard: existing hook without our marker → refuse
  if [ -e "$hook_path" ]; then
    if ! grep -qF "$MARKER" "$hook_path" 2>/dev/null; then
      printf '[install-git-hooks] SKIP %s: file already exists without our marker.\n' "$hook_path" >&2
      printf '  To install touchstone hooks, either:\n' >&2
      printf '    (a) remove or rename the existing hook, then re-run, or\n' >&2
      printf '    (b) manually append the wrapper logic to your existing hook.\n' >&2
      return 1
    fi
    say "overwriting existing touchstone $stage hook (marker present)"
  else
    say "installing $stage hook → $hook_path"
  fi

  cat > "$hook_path" <<HOOK
#!/usr/bin/env bash
$MARKER
# Thin wrapper: glob-executes .touchstone/checker/$stage/check-*.sh.
# Absent stage directory or zero matching files → passes silently.
# Non-executable check file → error exit 1 (misconfiguration).
set -uo pipefail
root="\$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
dir="\$root/.touchstone/checker/$stage"
[ -d "\$dir" ] || exit 0
for chk in "\$dir"/check-*.sh; do
  [ -e "\$chk" ] || continue    # zero-glob literal → skip
  if [ ! -x "\$chk" ]; then
    printf '[git-hook] FAIL: %s is not executable (chmod +x it)\n' "\$chk" >&2
    exit 1
  fi
  "\$chk" || exit 1             # execute directly; fail-fast on first failure
done
exit 0
HOOK

  chmod +x "$hook_path"
}

rc=0
write_hook pre-commit || rc=1
write_hook pre-push   || rc=1

if [ "$rc" -eq 0 ]; then
  say "done. Hooks installed in $HOOKS_DIR"
  say "Re-run any time to update wrappers (safe if marker is present)."
fi
exit "$rc"
