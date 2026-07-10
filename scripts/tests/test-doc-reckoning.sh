#!/usr/bin/env bash
# test-doc-reckoning.sh — S2-4: doc-reckoning.sh prints the ## Doc Reckoning
# block in the SAME section shape as the close reference's output template,
# and its mechanical findings (created/killed/pending-kill/bridge-no-kill-on)
# are grounded in a synthetic git repo, not hardcoded.
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# SC2016: backticked literals inside single-quoted fixtures/greps are text, not expansions.
# shellcheck disable=SC2015,SC2016
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/scripts/doc-reckoning.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- synthetic repo ----------------------------------------------------------
R="$TMP/repo"
mkdir -p "$R/.touchstone/epics/demo" "$R/.touchstone/specs" "$R/.touchstone/docs"
git -C "$TMP" init -q "$R"
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed

printf -- '---\nslug: demo\nstatus: active\nstarted: 2020-01-01\nlanded:\n---\n# demo\n' \
  > "$R/.touchstone/epics/demo/index.md"
printf -- '---\nkind: spec\nepics: [demo]\n---\n## Source-level Deposit\n- **Lever this spec advances:** `lever-x`\n' \
  > "$R/.touchstone/specs/2020-01-02-demo.md"
printf -- '---\nkind: bridge\n---\n# b1 no kill-on\n' > "$R/.touchstone/docs/b1.md"
printf -- '---\nkind: bridge\nkill-on: lever-done\n---\n# b2\n' > "$R/.touchstone/docs/b2.md"
printf -- '# ROADMAP\n\n## Active Epics\n\n## Completed\n| demo | lever-done | done |\n' > "$R/ROADMAP.md"
printf -- '---\nkind: diagnostic\n---\ndoomed\n' > "$R/.touchstone/docs/doomed.md"
# spec WITHOUT a Source-level Deposit section (exercises the none-branch)
printf -- '---\nkind: spec\nepics: [demo]\n---\n# bare spec\n' > "$R/.touchstone/specs/2020-01-03-bare.md"
# b3: bridge that trips all three advisory scanners — cites exactly ONE source
# path in a section (rung), contains a workaround trigger phrase, and the cited
# source is later committed >30 days after the bridge (stale)
mkdir -p "$R/scripts"
printf -- 'echo util v1\n' > "$R/scripts/util.sh"
printf -- '---\nkind: bridge\nkill-on: lever-future\n---\n# b3\n\n## Impl\nkept until lever-future ships; see scripts/util.sh\n' > "$R/.touchstone/docs/b3.md"
git -C "$R" add -A
GIT_AUTHOR_DATE=2020-01-02T00:00:00 GIT_COMMITTER_DATE=2020-01-02T00:00:00 \
  git -C "$R" -c user.email=t@t -c user.name=t commit -q -m "epic docs"
git -C "$R" rm -q .touchstone/docs/doomed.md
GIT_AUTHOR_DATE=2020-01-05T00:00:00 GIT_COMMITTER_DATE=2020-01-05T00:00:00 \
  git -C "$R" -c user.email=t@t -c user.name=t commit -q -m "kill doomed doc"
printf -- 'echo util v2\n' > "$R/scripts/util.sh"
git -C "$R" add scripts/util.sh
GIT_AUTHOR_DATE=2020-03-15T00:00:00 GIT_COMMITTER_DATE=2020-03-15T00:00:00 \
  git -C "$R" -c user.email=t@t -c user.name=t commit -q -m "util moves on"

out="$(bash "$CHK" "$R/.touchstone/epics/demo/index.md")"; rc=$?
[ "$rc" -eq 0 ] && ok "(a) exit 0" || fail "(a) rc=$rc"

# (b) section shape: exactly the template's 8 bold headers, in order
want_headers='**Deposit (from specs):**
**Created:**
**Killed:**
**Pending kills:**
**Stale-candidate bridges (advisory):**
**Rung-misclassification candidates (advisory):**
**Doc-as-workaround candidates (advisory):**
**Built specs (distill-or-archive candidates):**'
got_headers="$(printf '%s\n' "$out" | grep -E '^\*\*')"
[ "$got_headers" = "$want_headers" ] \
  && ok "(b) 8 template section headers, exact order" || fail "(b) headers=$got_headers"

printf '%s\n' "$out" | grep -q '^## Doc Reckoning' \
  && ok "(b2) block title present" || fail "(b2) no title"

# (c) created spec listed with its lever
printf '%s\n' "$out" | grep -q '2020-01-02-demo.md.*lever-x' \
  && ok "(c) deposit lever extracted" || fail "(c) no lever line"

# (d) bridge without kill-on flagged (advisory)
printf '%s\n' "$out" | grep -q 'b1.md.*bridge without kill-on' \
  && ok "(d) bridge-no-kill-on finding" || fail "(d) missing finding"

# (e) killed doc listed with removing commit
printf '%s\n' "$out" | grep -qE 'doomed.md.*removed in .[0-9a-f]{7,}' \
  && ok "(e) killed doc + commit sha" || fail "(e) missing killed line"

# (f) pending kill: b2's lever-done is in ROADMAP Completed and doc survives
printf '%s\n' "$out" | grep -q 'b2.md.*kill-on `lever-done`' \
  && ok "(f) pending kill detected" || fail "(f) missing pending kill"

# (g) built spec listed as human-decides candidate
printf '%s\n' "$out" | grep -q '2020-01-02-demo.md.*human decides' \
  && ok "(g) distill-or-archive candidate listed" || fail "(g) missing built-spec line"

# (i) created-then-removed branch of Created (doomed.md added AND deleted in range)
printf '%s\n' "$out" | grep -q 'doomed.md.*created then removed within range' \
  && ok "(i) created-then-removed branch" || fail "(i) missing branch line"

# (j) Deposit none-branch for a spec without the section
printf '%s\n' "$out" | grep -q '2020-01-03-bare.md.*none — no Source-level Deposit section' \
  && ok "(j) deposit none-branch" || fail "(j) missing none line"

# (k) stale scanner: util.sh committed 73 days after b3
printf '%s\n' "$out" | grep -qE 'b3.md.*scripts/util.sh.*[0-9]+ days newer' \
  && ok "(k) stale-candidate bridge detected" || fail "(k) missing stale line"

# (l) rung scanner: b3 § Impl cites exactly one source path
printf '%s\n' "$out" | grep -q 'b3.md.*Impl.*cites only one source path' \
  && ok "(l) rung-misclassification detected" || fail "(l) missing rung line"

# (m) workaround scanner: trigger phrase "kept until"
printf '%s\n' "$out" | grep -qi 'b3.md.*kept until' \
  && ok "(m) doc-as-workaround detected" || fail "(m) missing workaround line"

# (h) operational errors fail closed with rc=2
bash "$CHK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "(h) no-arg → rc=2" || fail "(h) rc=$rc"

echo "== test-doc-reckoning: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
