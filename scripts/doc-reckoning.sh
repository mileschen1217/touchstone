#!/usr/bin/env bash
# doc-reckoning.sh — mechanical half of the epic-close Doc Reckoning.
# Scans the epic's git range and doc tree, then prints the ## Doc Reckoning
# block (same shape as the close reference's output template) to stdout.
# It lists facts and advisory candidates ONLY — every follow-up decision
# (write/downgrade a bridge, delete, move, rung, lever, distill) is the
# human's; this script never acts on its own findings.
#
# Usage: doc-reckoning.sh <epic-index-path>
#   Range comes from the index frontmatter's `started:` / `landed:` dates
#   (landed empty -> today). Repo root = git toplevel of the index location.
# Exit: 0 printed (findings are advisory, never a failure) | 2 operational error.
set -uo pipefail

INDEX="${1:-}"
[ -n "$INDEX" ] && [ -f "$INDEX" ] \
  || { echo "doc-reckoning: usage: doc-reckoning.sh <epic-index-path>" >&2; exit 2; }

REPO="$(cd "$(dirname "$INDEX")" && git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$REPO" ] || { echo "doc-reckoning: index not inside a git repo" >&2; exit 2; }

fm_field() { # fm_field <file> <key> — first frontmatter value for key
  awk -v k="$2" 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit}
    f && $0 ~ "^"k":" { sub("^"k":[[:space:]]*",""); print; exit }' "$1"
}

STARTED="$(fm_field "$INDEX" started)"
LANDED="$(fm_field "$INDEX" landed)"
[ -n "$STARTED" ] || { echo "doc-reckoning: index has no started: date" >&2; exit 2; }
[ -n "$LANDED" ] || LANDED="$(date -u +%Y-%m-%d)"

DOC_DIRS=".touchstone/research .touchstone/specs .touchstone/plans .touchstone/docs"
glog() { git -C "$REPO" log --since "$STARTED" --until "${LANDED}T23:59:59" "$@"; }

# --- gather -----------------------------------------------------------------

# shellcheck disable=SC2086 # DOC_DIRS is an intentional word-split list
created="$(glog --diff-filter=A --name-only --format= -- $DOC_DIRS | grep '\.md$' | sort -u)"
# shellcheck disable=SC2086
killed="$(glog --diff-filter=D --name-only --format= -- $DOC_DIRS | grep '\.md$' | sort -u)"

surviving_md() { # all surviving .md under the doc dirs
  local d
  for d in $DOC_DIRS; do
    [ -d "$REPO/$d" ] && find "$REPO/$d" -type f -name '*.md'
  done
}

completed_levers() { # lever-ish slugs in ROADMAP § Completed (best-effort)
  [ -f "$REPO/ROADMAP.md" ] || return 0
  awk '/^## Completed/{f=1;next} f&&/^## /{exit} f' "$REPO/ROADMAP.md"
}

repo_paths_in() { # existing repo paths cited in a file/section (stdin)
  grep -oE '[A-Za-z0-9_][A-Za-z0-9_/.-]+\.(sh|md|py|json|yaml|yml|jsonl)' \
    | sort -u | while IFS= read -r p; do [ -e "$REPO/$p" ] && echo "$p"; done
}

is_bridge() { [ "$(fm_field "$1" kind)" = "bridge" ]; }

# --- print the block ---------------------------------------------------------

echo "## Doc Reckoning"
echo
echo "**Deposit (from specs):**"
found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *"/specs/"*) ;; *) continue ;; esac
  lever="$(grep -m1 -oE '\*\*Lever this spec advances:\*\*.*' "$REPO/$f" 2>/dev/null \
    | sed 's/\*\*Lever this spec advances:\*\*[[:space:]]*//')"
  echo "- \`$f\` → ${lever:-none — no Source-level Deposit section}"
  found=1
done <<< "$created"
[ "$found" -eq 1 ] || echo "- (none in range)"
echo
echo "**Created:**"
found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  found=1
  if [ ! -f "$REPO/$f" ]; then
    echo "- \`$f\` — created then removed within range"
    continue
  fi
  kind="$(fm_field "$REPO/$f" kind)"; killon="$(fm_field "$REPO/$f" kill-on)"
  line="- \`$f\` — kind: \`${kind:-none}\` · kill-on: \`${killon:-none}\`"
  if [ "$kind" = "bridge" ] && [ -z "$killon" ]; then
    line="$line **← finding (advisory): bridge without kill-on**"
  fi
  echo "$line"
done <<< "$created"
[ "$found" -eq 1 ] || echo "- (none)"
echo
echo "**Killed:**"
found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  found=1
  sha="$(glog --diff-filter=D --format='%h' -- "$f" | head -1)"
  echo "- \`$f\` — removed in \`${sha:-unknown}\`"
done <<< "$killed"
[ "$found" -eq 1 ] || echo "- (none)"
echo
echo "**Pending kills:**"
found=0
completed="$(completed_levers)"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  killon="$(fm_field "$f" kill-on)"
  [ -n "$killon" ] || continue
  if [ -n "$completed" ] && printf '%s' "$completed" | grep -qF "$killon"; then
    echo "- \`${f#"$REPO"/}\` — kill-on \`$killon\` (lever in ROADMAP § Completed but doc still present)"
    found=1
  fi
done < <(surviving_md)
[ "$found" -eq 1 ] || echo "- (none)"
echo
echo "**Stale-candidate bridges (advisory):**"
found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  is_bridge "$f" || continue
  rel="${f#"$REPO"/}"
  glog --format= --name-only -- "$rel" | grep -q . || continue  # touched in range only
  doc_ct="$(git -C "$REPO" log -1 --format=%ct -- "$rel" 2>/dev/null)"
  [ -n "$doc_ct" ] || continue
  while IFS= read -r src; do
    [ -n "$src" ] || continue
    [ "$src" = "$rel" ] && continue
    src_ct="$(git -C "$REPO" log -1 --format=%ct -- "$src" 2>/dev/null)"
    [ -n "$src_ct" ] || continue
    if [ $((src_ct - doc_ct)) -gt $((30 * 86400)) ]; then
      echo "- \`$rel\` — referenced source \`$src\` is $(((src_ct - doc_ct) / 86400)) days newer"
      found=1
    fi
  done < <(repo_paths_in < "$f")
done < <(surviving_md)
[ "$found" -eq 1 ] || echo "- (none)"
echo
echo "**Rung-misclassification candidates (advisory):**"
found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  is_bridge "$f" || continue
  rel="${f#"$REPO"/}"
  while IFS= read -r sec; do
    [ -n "$sec" ] || continue
    n="$(awk -v s="## $sec" '$0==s{f=1;next} f&&/^## /{exit} f' "$f" | repo_paths_in | grep -c .)"
    if [ "$n" -eq 1 ]; then
      echo "- \`$rel\` § \`$sec\` — cites only one source path; suggested rung: 2 | 3 | argue cross-cutting"
      found=1
    fi
  done < <(grep -E '^## ' "$f" | sed 's/^## //')
done < <(surviving_md)
[ "$found" -eq 1 ] || echo "- (none)"
echo
echo "**Doc-as-workaround candidates (advisory):**"
found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  is_bridge "$f" || continue
  rel="${f#"$REPO"/}"
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    echo "- \`$rel\`:$hit"
    found=1
  done < <(grep -inE 'deprecated|kept until|do not use|no-op stub|legacy path' "$f" | cut -c1-160)
done < <(surviving_md)
[ "$found" -eq 1 ] || echo "- (none)"
echo
echo "**Built specs (distill-or-archive candidates):**"
found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *"/specs/"*) ;; *) continue ;; esac
  [ -f "$REPO/$f" ] || continue
  sha="$(glog --format='%h' -- "$f" | tail -1)"
  echo "- \`$f\` — landed \`${sha:-unknown}\`; recommended: human decides — archive | distill <sections> | move-whole"
  found=1
done <<< "$created"
[ "$found" -eq 1 ] || echo "- (none)"
exit 0
