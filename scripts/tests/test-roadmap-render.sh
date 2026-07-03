#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
# scripts/tests/test-roadmap-render.sh — tests for scripts/roadmap-render.sh
# Fixtures use synthetic slugs (demo-alpha/beta/done/cancelled) — no real epic slugs.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/roadmap-render.sh"
pass=0; fail=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1 ($2)"; }

# ---------------------------------------------------------------------------
# Fixture builder
# Creates a temp project root with 4 synthetic epics + _draft-brainstorm.md
# Prints the root path.
# ---------------------------------------------------------------------------
setup_fixture() {
  local root; root="$(mktemp -d "$TMP/fixture.XXXXXX")"
  local ep="$root/.touchstone/epics"
  mkdir -p "$ep/demo-alpha" "$ep/demo-beta" "$ep/demo-done" "$ep/demo-cancelled"

  # demo-alpha: active, phases spanning done/active/proposed
  cat > "$ep/demo-alpha/index.md" <<'EPEOF'
---
slug: demo-alpha
status: active
started: 2026-01-01
landed:
---

# Demo Alpha

**Aim:** Demonstrate the render script with an active epic having multiple phases.

## Phases

| # | Title | Status | Landed |
|---|---|---|---|
| 1 | First phase title here | done | 2026-01-15 |
| 2 | Second phase in progress | active | |
| 3 | Third phase not started | proposed | |
EPEOF

  # demo-beta: proposed, single phase
  cat > "$ep/demo-beta/index.md" <<'EPEOF'
---
slug: demo-beta
status: proposed
started: 2026-02-01
landed:
---

# Demo Beta

**Aim:** A proposed epic for testing the render output.

## Phases

| # | Title | Status | Landed |
|---|---|---|---|
| 1 | Planning phase | proposed | |
EPEOF

  # demo-done: done (status 3rd type)
  cat > "$ep/demo-done/index.md" <<'EPEOF'
---
slug: demo-done
status: done
started: 2025-12-01
landed: 2026-01-10
---

# Demo Done

**Aim:** A completed demo epic used as a test fixture.

## Phases

| # | Title | Status | Landed |
|---|---|---|---|
| 1 | Only phase | done | 2026-01-10 |
EPEOF

  # demo-cancelled: cancelled
  cat > "$ep/demo-cancelled/index.md" <<'EPEOF'
---
slug: demo-cancelled
status: cancelled  # folded into demo-done
started: 2025-11-01
landed:
---

# Demo Cancelled

**Aim:** A cancelled demo epic for status coverage in tests.

## Phases

| # | Title | Status | Landed |
|---|---|---|---|
| 1 | Phase one | cancelled | |
EPEOF

  # _draft-brainstorm.md with first-level bullets
  cat > "$ep/_draft-brainstorm.md" <<'BSEOF'
# Epic brainstorm — pre-decision draft

## Backlog candidates

- Candidate idea one for the backlog
- Candidate idea two for testing render
- Third candidate item here
BSEOF

  printf '%s' "$root"
}

# ---------------------------------------------------------------------------
# (a) Both ROADMAP.html and ROADMAP.md are created
# ---------------------------------------------------------------------------
root="$(setup_fixture)"
out="$(mktemp -d "$TMP/out.XXXXXX")"
bash "$SCRIPT" --root "$root" --out "$out" >/dev/null 2>&1
[ -f "$out/ROADMAP.md" ] \
  && ok "(a) ROADMAP.md created" \
  || fail "(a) ROADMAP.md created" "file missing at $out/ROADMAP.md"
[ -f "$out/ROADMAP.html" ] \
  && ok "(a) ROADMAP.html created" \
  || fail "(a) ROADMAP.html created" "file missing at $out/ROADMAP.html"
rm -rf "$root" "$out"

# ---------------------------------------------------------------------------
# (b) MD table row count equals epic count
# ---------------------------------------------------------------------------
root="$(setup_fixture)"
out="$(mktemp -d "$TMP/out.XXXXXX")"
bash "$SCRIPT" --root "$root" --out "$out" >/dev/null 2>&1
epic_count=4
row_count="$(grep -c '^| demo-' "$out/ROADMAP.md" 2>/dev/null)" || row_count=0
[ "$row_count" -eq "$epic_count" ] \
  && ok "(b) MD has $epic_count epic rows" \
  || fail "(b) MD row count" "got $row_count want $epic_count"
rm -rf "$root" "$out"

# ---------------------------------------------------------------------------
# (c) HTML contains each slug and status CSS class names
# ---------------------------------------------------------------------------
root="$(setup_fixture)"
out="$(mktemp -d "$TMP/out.XXXXXX")"
bash "$SCRIPT" --root "$root" --out "$out" >/dev/null 2>&1
for slug in demo-alpha demo-beta demo-done demo-cancelled; do
  grep -qF "$slug" "$out/ROADMAP.html" \
    && ok "(c) HTML contains slug $slug" \
    || fail "(c) HTML slug $slug" "not found in html"
done
for cls in badge-active badge-proposed badge-done badge-cancelled; do
  grep -qF "$cls" "$out/ROADMAP.html" \
    && ok "(c) HTML contains class $cls" \
    || fail "(c) HTML class $cls" "not found in html"
done
rm -rf "$root" "$out"

# ---------------------------------------------------------------------------
# (d) Two runs produce identical ROADMAP.md (idempotent)
# ---------------------------------------------------------------------------
root="$(setup_fixture)"
out1="$(mktemp -d "$TMP/out.XXXXXX")"; out2="$(mktemp -d "$TMP/out.XXXXXX")"
bash "$SCRIPT" --root "$root" --out "$out1" >/dev/null 2>&1
bash "$SCRIPT" --root "$root" --out "$out2" >/dev/null 2>&1
diff "$out1/ROADMAP.md" "$out2/ROADMAP.md" >/dev/null 2>&1 \
  && ok "(d) ROADMAP.md is idempotent across two runs" \
  || fail "(d) ROADMAP.md idempotent" "diff found between two runs"
rm -rf "$root" "$out1" "$out2"

# ---------------------------------------------------------------------------
# (e) Missing _draft-brainstorm.md: no crash; HTML has no Backlog section
# ---------------------------------------------------------------------------
root="$(setup_fixture)"
rm -f "$root/.touchstone/epics/_draft-brainstorm.md"
out="$(mktemp -d "$TMP/out.XXXXXX")"
bash "$SCRIPT" --root "$root" --out "$out" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] \
  && ok "(e) exits 0 without _draft-brainstorm.md" \
  || fail "(e) exit code without _draft-brainstorm" "rc=$rc"
[ -f "$out/ROADMAP.html" ] \
  && ok "(e) ROADMAP.html produced without brainstorm" \
  || fail "(e) ROADMAP.html produced without brainstorm" "file missing"
grep -qF 'class="backlog"' "$out/ROADMAP.html" \
  && fail "(e) HTML should not have Backlog section" "backlog div found" \
  || ok "(e) HTML has no Backlog section when file absent"
rm -rf "$root" "$out"

# ---------------------------------------------------------------------------
# (f) Bad frontmatter epic: warning on stderr; other epics still rendered
# ---------------------------------------------------------------------------
root="$(setup_fixture)"
mkdir -p "$root/.touchstone/epics/demo-broken"
printf 'not frontmatter at all\n**Aim:** Broken epic.\n' \
  > "$root/.touchstone/epics/demo-broken/index.md"
out="$(mktemp -d "$TMP/out.XXXXXX")"
err="$(bash "$SCRIPT" --root "$root" --out "$out" 2>&1 1>/dev/null)"
[ -f "$out/ROADMAP.md" ] \
  && ok "(f) ROADMAP.md produced despite broken epic" \
  || fail "(f) ROADMAP.md with broken epic" "file missing"
grep -qF "demo-alpha" "$out/ROADMAP.md" \
  && ok "(f) other epics rendered alongside broken one" \
  || fail "(f) other epics rendered" "demo-alpha not in ROADMAP.md"
# warning should mention broken or missing info
printf '%s' "$err" | grep -qiE 'WARNING|warning' \
  && ok "(f) WARNING emitted to stderr for broken epic" \
  || fail "(f) WARNING for broken epic" "no WARNING in stderr: $err"
rm -rf "$root" "$out"

# ---------------------------------------------------------------------------
# (g) Aim containing '|' is escaped in ROADMAP.md (column count preserved)
# ---------------------------------------------------------------------------
root_g="$(mktemp -d "$TMP/pipe.XXXXXX")"
ep_g="$root_g/.touchstone/epics/demo-pipe"
mkdir -p "$ep_g"
cat > "$ep_g/index.md" <<'EPEOF'
---
slug: demo-pipe
status: active
started: 2026-01-01
landed:
---

# Demo Pipe

**Aim:** Before | after the pipe character.

## Phases

| # | Title | Status | Landed |
|---|---|---|---|
| 1 | Only phase | active | |
EPEOF
out_g="$(mktemp -d "$TMP/out.XXXXXX")"
bash "$SCRIPT" --root "$root_g" --out "$out_g" >/dev/null 2>&1
row="$(grep '^| demo-pipe' "$out_g/ROADMAP.md" 2>/dev/null || true)"
# The '|' in Aim must be rendered as '\|' so Markdown parsers see it as text,
# not a column separator.  Check that the escaped form is present in the row.
printf '%s' "$row" | grep -qF '\|' \
  && ok "(g) pipe in Aim escaped as \\| in MD table row" \
  || fail "(g) Aim pipe escaping" "no \\| in row: $row"
rm -rf "$root_g" "$out_g"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "== test-roadmap-render: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
