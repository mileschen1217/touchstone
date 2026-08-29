#!/usr/bin/env bash
# check-exec-bits-all.sh — four-surface exec-bit guard.
# Every script across hooks/*.sh, .touchstone/checker/**/check-*.sh,
# scripts/tests-smoke/*.sh, skills/**/check-*.sh, and skill/command-referenced
# scripts/*.sh paths
# must be 100755 in the git index.  A 100644 mode ships "Permission denied"
# when CC executes the file directly (the invocation-mode defect class, recurred ×3).
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

bad=""

# Tracked file -> the git index mode (what ships; the disk bit is not consulted,
# so a `chmod -x` on a tracked 100755 file is NOT caught here — the index is
# what the plugin cache receives). Untracked file -> the filesystem mode:
# skipping it would read green on a new 644 script until someone stages it.
check_tracked() {  # <repo-relative-path>
  local mode fsmode
  mode="$(cd "$root" && git ls-files -s "$1" 2>/dev/null | awk '{print $1}')"
  if [ -z "$mode" ]; then
    [ -e "$root/$1" ] || return
    [ -x "$root/$1" ] && return
    fsmode="$(stat -f %Lp "$root/$1" 2>/dev/null || stat -c %a "$root/$1" 2>/dev/null || true)"
    bad="${bad:+${bad}
}  $1 (filesystem mode ${fsmode:-unknown}, untracked)"
    return
  fi
  [ "$mode" = "100755" ] && return
  bad="${bad:+${bad}
}  $1 (index mode ${mode})"
}

# Surface 1: hooks/*.sh
if [ -d "$root/hooks" ]; then
  while IFS= read -r f; do
    check_tracked "${f#"$root"/}"
  done < <(find "$root/hooks" -maxdepth 1 -name '*.sh' | sort)
fi

# Surface 2: .touchstone/checker/**/check-*.sh (stage subdirs, depth ≥ 2)
if [ -d "$root/.touchstone/checker" ]; then
  while IFS= read -r f; do
    check_tracked "${f#"$root"/}"
  done < <(find "$root/.touchstone/checker" -mindepth 2 -name 'check-*.sh' | sort)
fi

# Surface 3: scripts/tests-smoke/*.sh, skill/checker scripts under skills/**/check-*.sh
if [ -d "$root/scripts/tests-smoke" ]; then
  while IFS= read -r f; do
    check_tracked "${f#"$root"/}"
  done < <(find "$root/scripts/tests-smoke" -maxdepth 1 -name '*.sh' | sort)
fi
if [ -d "$root/skills" ]; then
  while IFS= read -r f; do
    check_tracked "${f#"$root"/}"
  done < <(find "$root/skills" -name 'check-*.sh' | sort)
fi

# Surface 4: skill/command-referenced scripts/*.sh (enumerated from source grep)
# SC2016: ${CLAUDE_PLUGIN_ROOT} patterns are intentional literals, not shell expansions.
# shellcheck disable=SC2016
for _sdir in "$root/skills" "$root/commands"; do
  [ -d "$_sdir" ] || continue
  while IFS= read -r rel; do
    check_tracked "$rel"
  done < <(grep -rh '\${CLAUDE_PLUGIN_ROOT}/scripts/[^"} ]*\.sh' "$_sdir" 2>/dev/null \
    | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[^"} ]*\.sh' \
    | sed 's|\${CLAUDE_PLUGIN_ROOT}/||' \
    | sort -u || true)
done

if [ -n "$bad" ]; then
  echo "[check-exec-bits-all] the following files are not executable (index mode when tracked, filesystem mode when not; must be 100755):"
  echo "$bad"
  echo "Fix: git update-index --chmod=+x <path>"
  exit 1
fi
exit 0
