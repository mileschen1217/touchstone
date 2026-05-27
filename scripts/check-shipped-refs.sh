#!/usr/bin/env bash
# Clone-completeness guard (shipped-doc-hygiene P1). Flags a committed docs/ or
# skills/ file that references an UNTRACKED dated artifact under the local-doc
# workspace_root (.../{specs,research,plans}/YYYY-MM-DD-...) — such a reference
# dangles in every clone.
#
# Best-effort floor (NOT complete). The predicate is deliberately narrow — only
# DATED artifacts — so that a flag is certainly a leak: a dated file under
# specs/research/plans is always a specific gitignored artifact, never a convention
# file (e.g. .m-workflow/epics/README.md, .m-workflow/vision.md are concrete but
# legit structural paths — NOT dated, so not flagged). False-negatives are expected
# (a leak written as a named-but-undated ref, an odd path form, or outside the dated
# dirs) — patch on sight. The fresh-context reviewer's grounded-claims lens is the
# semantic catch for what this floor misses.
#
# Judge: git ls-files (untracked => not in clone). NOT git check-ignore (the legacy
# .swarm paths are deleted/renamed, not gitignored — check-ignore would miss them).
# Scope: committed files under docs/ + skills/ (git ls-files), so untracked local
# drafts are never scanned. Exit: 0 pass | 1 leak(s) | 2 operational error.
set -uo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "ERROR: not inside a git work tree (cannot judge tracked-state)" >&2; exit 2; }

ws=".m-workflow"
cfg=".claude/m-workflow.yaml"
if [ -f "$cfg" ]; then
  v="$(awk -F: '/^workspace_root:/{gsub(/[[:space:]]/,"",$2); print $2}' "$cfg")"
  [ -n "$v" ] && ws="$v"
fi
# escape the workspace_root for use in an ERE
ws_re="$(printf '%s' "$ws" | sed 's/[.[\*^$()+?{}|]/\\&/g')"

violations=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  while IFS= read -r hit; do
    lineno="${hit%%:*}"
    token="${hit#*:}"
    case "$token" in *"<"*) continue;; esac
    if [ -z "$(git ls-files -- "$token" 2>/dev/null)" ]; then
      echo "$f:$lineno: $token"
      violations=$((violations+1))
    fi
  done < <(grep -noE "${ws_re}/(specs|research|plans)/[0-9]{4}-[0-9]{2}-[0-9]{2}[^<*[:space:]]*" "$f")
done < <(git ls-files -- docs skills)

if [ "$violations" -eq 0 ]; then echo "pass"; exit 0; fi
exit 1
