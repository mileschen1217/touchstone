#!/usr/bin/env bash
# Smoke suite for the surviving deterministic checkers + the run-project-checks
# hook's classify_command. One green + one red case per target. Not a
# replacement for scripts/tests/ (removed) — just a fast sanity net.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fx="$here/fixtures"
scripts_dir="$(cd "$here/.." && pwd)"
hooks_dir="$(cd "$here/../../hooks" && pwd)"

fail=0

# expect_exit <label> <expected: zero|nonzero> -- <cmd...>
expect_exit() {
  label="$1"; want="$2"; shift 2
  out="$("$@" 2>&1)"; rc=$?
  if { [ "$want" = zero ] && [ "$rc" -eq 0 ]; } || { [ "$want" = nonzero ] && [ "$rc" -ne 0 ]; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (rc=$rc, want=$want)"; echo "$out"
    fail=1
  fi
}

# expect_out <label> <fixed-string> -- <cmd...>  — output must contain the string
expect_out() {
  label="$1"; pat="$2"; shift 2
  out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -qF -- "$pat"; then echo "PASS: $label"; else echo "FAIL: $label (missing: $pat)"; echo "$out"; fail=1; fi
}

# ---- check-artifact.sh: one green + one red per kind; each violation class asserted by line
ax="$fx/artifacts"; ca="$scripts_dir/check-artifact.sh"
expect_exit "check-artifact spec green (bootstrap-shaped)" zero bash "$ca" spec "$ax/spec-green.yaml" --root "$ax"
expect_out "check-artifact spec: numeric literal without basis is a warning" "warn: requirements[REQ-1].acs[AC-3].then: numeric literal" bash "$ca" spec "$ax/spec-green.yaml" --root "$ax"
expect_exit "check-artifact spec red" nonzero bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: block without purpose" "delta.blocks[parser].purpose: required" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: invariant without check" "invariants[INV-1].check: required" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: dangling ledger id" "requirements[REQ-1].basis: 'Q-99' resolves to no ledger line" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: path token in phase_map" "phase_map.position: human-facing panel carries a path-like token" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: unknown key under REQ" "requirements[REQ-1].notes: unknown key" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: invalid status enum" "status: 'done' not in" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: invalid check enum" "invariants[INV-2].check: 'manual' not in" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: dangling traces_to" "requirements[REQ-1].traces_to: 'US-9' names no US id" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: duplicate AC id" "duplicate id AC-1" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: dangling edge endpoint" "delta.edges[0].to: 'nowhere' names no block id" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: missing phase_map" "phase_map: required" bash "$ca" spec "$ax/spec-red-nomap.yaml" --root "$ax"
expect_exit "check-artifact review green" zero bash "$ca" review "$ax/review-green.yaml" --root "$ax"
expect_exit "check-artifact review red" nonzero bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: duplicate F id" "duplicate id F-3" bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: missing waiting_on_human" "waiting_on_human: required" bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: field path unresolvable in target" "'requirements[REQ-99].acs[AC-1]' resolves to nothing in the target spec" bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: [*] on an empty list resolves to nothing" "'waiting_on_human[*]' resolves to nothing" bash "$ca" review "$ax/review-red-star.yaml" --root "$ax"
expect_out "check-artifact review: degraded without reason" "degraded_reason: required when degraded is true" bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_exit "check-artifact deviation green" zero bash "$ca" deviation "$ax/deviation-green.yaml"
expect_exit "check-artifact deviation red" nonzero bash "$ca" deviation "$ax/deviation-red.yaml"
expect_out "check-artifact deviation: missing which_stage_could_have_caught" "entries[D-1].which_stage_could_have_caught: required" bash "$ca" deviation "$ax/deviation-red.yaml"
expect_out "check-artifact deviation: invalid panel" "entries[D-1].panel: 'flow' not in" bash "$ca" deviation "$ax/deviation-red.yaml"
expect_out "check-artifact deviation: quiz answer names no field id" "quiz.items[QZ-1].answer: names no field id" bash "$ca" deviation "$ax/deviation-red.yaml"
python3 - "$ca" "$ax" <<'PY3' || { echo "FAIL: check-artifact edge cases"; fail=1; }
import subprocess, sys, os, tempfile, shutil
ca, ax = sys.argv[1], sys.argv[2]
t = tempfile.mkdtemp()
shutil.copy(os.path.join(ax, 'spec-green.yaml'), t); shutil.copy(os.path.join(ax, 'ledger.md'), t)
def run(kind, text, name):
    p = os.path.join(t, name); open(p, 'w').write(text)
    r = subprocess.run(['bash', ca, kind, p, '--root', t], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr
base = open(os.path.join(ax, 'review-green.yaml')).read()
rc, out = run('review', base.replace('field: requirements[REQ-1].acs[AC-2].then', 'field: requirements[*].acs[AC-3].then'), 'r1.yaml')
assert rc == 0, out   # AC-3 sits under REQ-1; [*] must search every requirement
rc, out = run('review', base.replace('target: spec-green.yaml', 'target: ../spec-green.yaml'), 'r2.yaml')
assert rc == 1 and "escapes the --root" in out, out
open(os.path.join(t, 'ledger.md'), 'a').write('\n- Q-7a · suffixed id.\n')
spec = open(os.path.join(ax, 'spec-green.yaml')).read()
rc, out = run('spec', spec.replace('basis: [Q-1]', 'basis: [Q-7]'), 's1.yaml')
assert rc == 1 and "'Q-7' resolves to no ledger line" in out, out   # Q-7a must not resolve Q-7
rc, out = run('spec', spec.replace('date: 2026-01-01', 'date: "2026-01-01"'), 's2.yaml')
assert rc == 0, out   # quoted date string accepted
rc, out = run('spec', spec.replace('date: 2026-01-01', 'date: 20260101'), 's3.yaml')
assert rc == 1 and 'date: expected date' in out, out
shutil.rmtree(t)
print('PASS: check-artifact existential [*], root escape rejected, ledger id boundary, date type')
PY3
expect_out "check-artifact usage error" "usage:" bash "$ca" bogus "$ax/spec-green.yaml"
# the three schema files exist and every top-level field carries a reader tag
python3 - "$scripts_dir/../skills/_shared/schemas" <<'PY2' || { echo "FAIL: schema reader tags"; fail=1; }
import sys, os, yaml
d = sys.argv[1]
assert sorted(os.listdir(d)) == ['deviation.schema.yaml', 'review.schema.yaml', 'spec.schema.yaml'], os.listdir(d)
for f in os.listdir(d):
    s = yaml.safe_load(open(os.path.join(d, f)))
    for k, v in s['properties'].items():
        assert v.get('reader') in ('human', 'agent'), f'{f}: {k} has no reader tag'
print('PASS: three schemas, every top-level field reader-tagged')
PY2

expect_exit "check-evidence-reckoning.sh green" zero \
  bash "$scripts_dir/check-evidence-reckoning.sh" "$fx/reckoning-index-green.md" "$fx/reckoning-spec.md"
expect_exit "check-evidence-reckoning.sh red" nonzero \
  bash "$scripts_dir/check-evidence-reckoning.sh" "$fx/reckoning-index-red.md" "$fx/reckoning-spec.md"

# ---- design-review-precheck.sh: schema floor, draft skip, legacy md block, --attest
pc="$scripts_dir/design-review-precheck.sh"
expect_exit "design-review-precheck.sh green" zero bash "$pc" "$ax/spec-green.yaml"
expect_exit "design-review-precheck.sh red" nonzero bash "$pc" "$ax/spec-red.yaml"
expect_out "design-review-precheck.sh draft skipped" "PRE-CHECK skipped: draft" bash "$pc" "$ax/spec-red-nomap.yaml"
expect_exit "design-review-precheck.sh legacy md blocked" nonzero bash "$pc" "$fx/reckoning-spec.md"
qd="$(mktemp -d)"; sed 's/^status: draft/status: "draft"/' "$ax/spec-red-nomap.yaml" > "$qd/q.yaml"
expect_out "design-review-precheck.sh quoted draft skipped" "PRE-CHECK skipped: draft" bash "$pc" "$qd/q.yaml"
rm -rf "$qd"
expect_exit "design-review-precheck.sh --attest green (round-1 review.yaml with challenger)" zero bash "$pc" "$ax/spec-green.yaml" --attest
at="$(mktemp -d)"; cp "$ax/spec-green.yaml" "$ax/ledger.md" "$at/"
expect_exit "design-review-precheck.sh --attest red (no attestation)" nonzero bash "$pc" "$at/spec-green.yaml" --attest
expect_out "design-review-precheck.sh --attest names the missing attestation" "challenge attestation is missing" bash "$pc" "$at/spec-green.yaml" --attest
rm -rf "$at"

# classify_command: source the hook (its source-guard skips main when sourced)
# and probe the function directly on a real commit vs a non-git command.
# shellcheck source=/dev/null
source "$hooks_dir/run-project-checks.sh"

cc_out="$(classify_command 'git commit -m "msg"')"
if [ "$cc_out" = "pre-commit" ]; then
  echo "PASS: run-project-checks.sh classify_command(commit)"
else
  echo "FAIL: run-project-checks.sh classify_command(commit) -> '$cc_out'"; fail=1
fi

cc_out="$(classify_command 'ls -la')"
if [ "$cc_out" = "none" ]; then
  echo "PASS: run-project-checks.sh classify_command(non-git)"
else
  echo "FAIL: run-project-checks.sh classify_command(non-git) -> '$cc_out'"; fail=1
fi

# ---- dossier-render.sh: the fixture epic is copied under a synthetic project
# root (own .touchstone/gate-miss.md + docs/adr) so root discovery, archived
# placement, ADR resolution, and determinism are all exercised offline.
tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/.touchstone/epics" "$tmp_root/.touchstone/archive/epics" "$tmp_root/docs/adr"
cp -R "$fx/dossier-epic" "$tmp_root/.touchstone/epics/2026-01-01-fixture"
rm -f "$tmp_root/.touchstone/epics/2026-01-01-fixture/dossier.html"
printf '# gate-miss\n\n- 2026-01-02 | fixture | a miss | assay | human | L\n' > "$tmp_root/.touchstone/gate-miss.md"
printf -- '---\nstatus: Accepted\n---\n\n# ADR-0038 fixture decision\n\nBody.\n' > "$tmp_root/docs/adr/0038-fixture.md"
ed="$tmp_root/.touchstone/epics/2026-01-01-fixture"
dout="$ed/dossier.html"

expect_exit "dossier-render.sh green" zero bash "$scripts_dir/dossier-render.sh" --pr-body "$ed"
expect_exit "dossier-render.sh red (missing path)" nonzero bash "$scripts_dir/dossier-render.sh" "$tmp_root/nope"
expect_exit "dossier-render.sh red (path is a file)" nonzero bash "$scripts_dir/dossier-render.sh" "$dout"
mkdir -p "$tmp_root/noindex"
expect_exit "dossier-render.sh red (no index.md)" nonzero bash "$scripts_dir/dossier-render.sh" "$tmp_root/noindex"
bad="$tmp_root/.touchstone/epics/2026-01-09-badyaml"; mkdir -p "$bad"; cp "$fx/dossier-epic/index.md" "$bad/"; printf 'id: [unclosed\n' > "$bad/2026-01-09-bad.spec.yaml"
expect_out "dossier-render.sh red (malformed spec.yaml is fatal)" "not parseable YAML" bash "$scripts_dir/dossier-render.sh" "$bad"
[ -f "$bad/dossier.html" ] && { echo "FAIL: dossier written for malformed YAML"; fail=1; }
[ -f "$tmp_root/noindex/dossier.html" ] && { echo "FAIL: dossier written on red path"; fail=1; }

# expect_grep <label> <count-op> <n> <pattern>  — fixed-string count over the dossier
expect_grep() {
  label="$1"; op="$2"; n="$3"; pat="$4"
  c="$(grep -o -F -- "$pat" "$dout" | wc -l | tr -d ' ')"
  ok=0
  case "$op" in
    -eq) [ "$c" -eq "$n" ] && ok=1 ;;
    -ge) [ "$c" -ge "$n" ] && ok=1 ;;
  esac
  if [ "$ok" = 1 ]; then echo "PASS: dossier $label"; else echo "FAIL: dossier $label (count=$c, want $op $n): $pat"; fail=1; fi
}
if head -5 "$dout" | grep -q "GENERATED by scripts/dossier-render.sh" && head -5 "$dout" | grep -q "do not hand-edit"; then
  echo "PASS: dossier generated header in first 5 lines"
else
  echo "FAIL: dossier header not in first 5 lines"; fail=1
fi
expect_grep "four tabs in order" -eq 1 '>首頁</button><button data-tab="1" aria-selected="false">契約</button><button data-tab="2" aria-selected="false">結構變化</button><button data-tab="3" aria-selected="false">紀錄</button>'
expect_grep "three phase groups" -ge 3 '<h2>Phase '
expect_grep "front page: blocker list" -ge 1 '<h3>阻擋清單</h3>'
expect_grep "front page: gate strip" -ge 1 'class="strip"'
expect_grep "front page: sticky strip" -ge 1 '<div class="strip">'
expect_grep "explainer inlined (h1 text)" -ge 1 'Alpha buy-in explainer'
expect_grep "no iframe" -eq 0 '<iframe'
expect_grep "phase map rendered as panels" -ge 8 'class="panel"'
expect_grep "panel delta marker from deviation log" -ge 1 '實作≠計畫'
expect_grep "ADR one-liner links to file, not inlined" -ge 1 'href="../../../docs/adr/0038-fixture.md">ADR-0038</a>'
expect_grep "close: retrospective" -ge 1 '>回顧</span>'
expect_grep "close: evidence reckoning" -ge 1 '>證據清算</span>'
expect_grep "close: gate-miss line via ancestor root" -ge 1 'a miss'
expect_grep "AC-2 links to alpha anchor" -ge 1 'data-jump="2026-01-02-alpha-design--AC-2" tabindex="0">AC-2</a>'
expect_grep "REQ-1 links to alpha anchor" -ge 1 'data-jump="2026-01-02-alpha-design--REQ-1" tabindex="0">REQ-1</a>'
expect_grep "AC-2 anchor id exists" -eq 1 'id="2026-01-02-alpha-design--AC-2"'
expect_grep "REQ-1 anchor id exists" -eq 1 'id="2026-01-02-alpha-design--REQ-1"'
expect_grep "AC-99 undefined marker" -ge 1 'class="undef" title="no definition for AC-99'
expect_grep "AC-99 never linked" -eq 0 '>AC-99</a>'
expect_grep "AC-2a undefined (suffixed form)" -ge 1 'class="undef" title="no definition for AC-2a'
expect_grep "beta review resolves AC-1 in-phase" -ge 1 'data-jump="2026-01-03-beta-design--AC-1" tabindex="0">AC-1</a>'
expect_grep "inline code AC-2 untouched" -ge 1 '<code>AC-2</code>'
expect_grep "fenced AC-2 untouched" -ge 1 'fenced AC-2 must stay untouched'
expect_grep "defining heading not self-linked" -eq 0 'id="2026-01-02-alpha-design--AC-2"><a'
expect_grep "ADR-38 links" -ge 1 'data-jump="adr--38" tabindex="0">ADR-38</a>'
expect_grep "ADR-0038 links to same anchor" -ge 1 'data-jump="adr--38" tabindex="0">ADR-0038</a>'
expect_grep "ADR body rendered with anchor" -eq 1 'id="adr--38"'
expect_grep "dark palette present" -ge 1 'prefers-color-scheme: dark'
ext="$(grep -oiE "<(link|script|img|iframe|object|embed)[^>]*(src|href)[[:space:]]*=[[:space:]]*['\"]?https?://|@import[^;]*https?://|url\([^)]*https?://" "$dout" | wc -l | tr -d ' ')"
if [ "$ext" -eq 0 ]; then echo "PASS: dossier no external request targets"; else echo "FAIL: dossier external requests: $ext"; fail=1; fi
# hostile inlined explainer + hostile markdown links are neutralised
expect_grep "hostile: explainer body kept" -ge 1 'Beta explainer'
expect_grep "hostile: no iframe" -eq 0 '<iframe'
expect_grep "hostile: no script" -eq 0 '<script>alert'
expect_grep "hostile: no on* handlers" -eq 0 'onerror='
expect_grep "hostile: no onmouseover" -eq 0 'onmouseover='
expect_grep "hostile: no onclick" -eq 0 'onclick='
expect_grep "hostile: no javascript: href" -eq 0 'javascript:'
expect_grep "hostile: tab-split scheme neutralised" -eq 0 'java	script:'
expect_grep "hostile: nav link kept" -ge 1 'href="https://example.com/doc"'
expect_grep "hostile: markdown link attr-escaped" -eq 0 'href=""onmouseover'
expect_grep "hostile: AC-1 linked inside sanitized html" -ge 1 'data-jump="2026-01-03-beta-design--AC-1" tabindex="0">AC-1</a>'

# ---- YAML phase (gamma): projection, overlays, ledger anchors, Ship order, pr-body, INV-1
expect_grep "yaml: gamma phase group" -ge 1 'data-phase="2026-01-04-gamma.spec"'
expect_grep "yaml: four panels + D-1 overlay on the interface panel" -ge 1 '介面差異</abbr> <span class="pill warn"><abbr class="enum" title="built-ne-planned">實作≠計畫</abbr> · 1</span>'
expect_grep "yaml: D-1 entry anchored" -eq 1 'id="deviation--D-1"'
expect_grep "yaml: legacy deviation line under its own heading" -ge 1 '>舊版偏離行</span>'
expect_grep "yaml: review round summary row" -ge 1 '<th>門</th><th>輪</th><th>裁決</th>'
expect_grep "yaml: review finding F-1 anchored" -ge 1 'id="finding--F-1"'
expect_grep "yaml: basis Q-1 links to the ledger line" -ge 1 'data-jump="ledger--Q-1" tabindex="0">Q-1</a>'
expect_grep "yaml: ledger line anchored" -eq 1 'id="ledger--Q-1"'
expect_grep "yaml: ledger table row anchored" -eq 1 'id="ledger--A-1"'
expect_grep "yaml: AC-2 anchored in the requirements table" -eq 1 'id="2026-01-04-gamma.spec--AC-2"'
expect_grep "yaml: INV-1 anchored" -eq 1 'id="2026-01-04-gamma.spec--INV-1"'
expect_grep "yaml: front page lists waiting_on_human from the spec" -ge 1 'rule on the collision rename'
expect_grep "yaml: front page lists waiting_on_human from review.yaml" -ge 1 'accept F-1 as is'
expect_grep "yaml: front page lists waiting_on_human from deviation.yaml" -ge 1 'confirm the equals form stays'
expect_grep "yaml: quiz item rendered" -ge 1 'which panel changed during the build?'
expect_grep "yaml: quiz anchor rendered" -ge 1 '<code>phase_map.interface_delta</code>'
expect_grep "front page: decision line" -ge 1 '<dl class="dec">'
python3 - "$dout" "$ed/pr-body.md" "$ed" <<'PY' || { echo "FAIL: yaml projection checks"; fail=1; }
import re, sys, html as H, yaml, os
h = open(sys.argv[1], encoding='utf-8').read()
front = re.search(r'<section class="tab" id="tab-0">(.*?)<section class="tab" id="tab-1">', h, re.S).group(1)
heads = re.findall(r'<section class="fs"><h3>([^<]*)</h3>', front)
want = ['決策', '阻擋清單', '怎麼驗的', '檢查表']
assert heads == want, heads
pr = open(sys.argv[2], encoding='utf-8').read()
assert [x for x in re.findall(r'^## (.+)$', pr, re.M) if x != 'gate 條'] == want, 'pr-body sections differ from the page order'
assert 'D-1' in pr, 'pr-body lacks the D-1 overlay'
# no whole-file pre block in the YAML phase's sections (Map + Ship + 契約)
for tab_id in ('1', '2'):
    t = re.search(r'<section class="tab" id="tab-%s">(.*?)(?=<section class="tab" id="tab-|</main>)' % tab_id, h, re.S).group(1)
    g = re.search(r'<section class="phase" data-phase="2026-01-04-gamma.spec">(.*?)(?=<section class="phase"|$)', t, re.S)
    assert g and '<pre>' not in g.group(1), 'pre block in gamma tab ' + tab_id
assert '<pre>' not in front, 'pre block on the front page'
# INV-1: every text node in the gamma Map + Ship sections is a YAML field value, an id, a number, or a label
vals = set()
def walk(v):
    if isinstance(v, dict):
        for x in v.values(): walk(x)
    elif isinstance(v, list):
        for x in v: walk(x)
    elif v is not None:
        vals.add(str(v).strip())
ed = sys.argv[3]
for f in ('2026-01-04-gamma.spec.yaml', 'design-review-gamma/review.yaml', 'deviation.yaml'):
    walk(yaml.safe_load(open(os.path.join(ed, f), encoding='utf-8')))
legacy = [l[2:].strip() for l in open(os.path.join(ed, 'index.md'), encoding='utf-8').read().splitlines() if l.startswith('- phase ')]
checked = 0
for tab_id in ('0', '2'):
    t = re.search(r'<section class="tab" id="tab-%s">(.*?)(?=<section class="tab" id="tab-|</main>)' % tab_id, h, re.S).group(1)
    g = re.search(r'<article class="front">(.*?)</article>', t, re.S).group(1) if tab_id == '0' else re.search(r'<section class="phase" data-phase="2026-01-04-gamma.spec">(.*?)(?=<section class="phase"|$)', t, re.S).group(1)
    g = re.sub(r'<abbr class="enum"[^>]*>.*?</abbr>', '', g, flags=re.S)
    g = re.sub(r'<svg.*?</svg>', '', g, flags=re.S)
    g = re.sub(r'<(span|p|h\d|th)[^>]*class="(label|placeholder|pill [a-z]+|file|muted|footer)"[^>]*>.*?</\1>', '', g, flags=re.S)
    g = re.sub(r'<h2>.*?</h2>|<th>.*?</th>|<h3>[^<]*</h3>|<summary>.*?</summary>', '', g, flags=re.S)
    for node in re.findall(r'>([^<>]+)<', g):
      for n in re.split(r'\s·\s', H.unescape(node)):
        n = n.strip(' ·:—').strip()
        if not n or n in ('·', '—', '(', ')', ',', '·'): continue
        ok = n in vals or re.fullmatch(r'[A-Z]+-\d+|[\d.\s/項]+', n) or all(t in vals for t in n.split()) or n in ('Phases', 'title', '#', '結構變化', '階段') or any(n in v for v in vals) or any(n in l for l in legacy) \
             or n in ('dossier.html', 'pr-body.md', 'Waiting on human', 'Quiz', 'Phase map', 'Legacy deviation lines')
        assert ok, 'renderer-authored text node: %r' % n
        checked += 1
assert checked >= 10, checked
print('PASS: front-page order == pr-body order; no whole-file pre; %d text nodes trace to YAML fields (INV-1)' % checked)
PY

# zero-delta phase → visible quiz waiver
zd="$tmp_root/.touchstone/epics/2026-01-07-zerodelta"; mkdir -p "$zd"
printf -- '---\nslug: zerodelta\nstatus: active\n---\n\n# Zero delta\n\n**Aim:** x.\n\n## Phases\n\n| # | Title | Spec | Plan | Status | Landed |\n|---|---|---|---|---|---|\n| 1 | Delta | [spec](2026-01-07-delta.spec.yaml) | — | active | |\n' > "$zd/index.md"
sed -e 's/^title: .*/title: Delta — zero deviation/' -e 's/^  record: .*/  record: ledger.md/' "$fx/dossier-epic/2026-01-04-gamma.spec.yaml" > "$zd/2026-01-07-delta.spec.yaml"
cp "$fx/artifacts/ledger.md" "$zd/ledger.md"
printf 'entries: []\nquiz: {waived: true, items: []}\nwaiting_on_human: []\n' > "$zd/deviation.yaml"
dout="$zd/dossier.html"
expect_exit "dossier-render.sh zero-delta green" zero bash "$scripts_dir/dossier-render.sh" "$zd"
expect_grep "zero-delta: quiz waiver visible" -ge 1 '>理解測驗免作</span>'
expect_grep "zero-delta: every panel as planned" -eq 4 '如計畫</abbr></span>'
md="$tmp_root/.touchstone/epics/2026-01-08-mdonly"; mkdir -p "$md"; printf -- '---\nslug: mdonly\nstatus: active\n---\n\n# Md only\n\n**Aim:** x.\n' > "$md/index.md"
expect_out "dossier-render.sh --pr-body red (no YAML phase)" "needs a YAML phase" bash "$scripts_dir/dossier-render.sh" --pr-body "$md"
dout="$ed/dossier.html"

# not-writable epic dir → exit 1 naming the cause
ro="$tmp_root/.touchstone/epics/2026-01-04-readonly"; mkdir -p "$ro"; cp "$fx/dossier-epic/index.md" "$ro/"; chmod 500 "$ro"
ro_out="$(bash "$scripts_dir/dossier-render.sh" "$ro" 2>&1)"; ro_rc=$?
chmod 700 "$ro"
if [ "$ro_rc" -ne 0 ] && printf '%s' "$ro_out" | grep -q "not writable" && printf '%s' "$ro_out" | grep -q "$ro"; then
  echo "PASS: dossier-render.sh red (not writable)"
else
  echo "FAIL: dossier-render.sh red (not writable) rc=$ro_rc: $ro_out"; fail=1
fi

# classification branches, close sections, code links inside inlined html
python3 - "$dout" <<'PY' || { echo "FAIL: dossier classification / close / inlined-html checks"; fail=1; }
import re,sys
h=open(sys.argv[1],encoding='utf-8').read()
chunks=re.split(r'<section class="tab" id="tab-(\d)">',h)[1:]
t={chunks[i]:chunks[i+1] for i in range(0,len(chunks),2)}
def files_in(i): return set(re.findall(r'<span class="file"[^>]*>([^<]+)</span>',t[i]))
assert {'assay-notes.md','local-decision.md','stray.md','2026-01-02-alpha-design.md','2026-01-03-beta-design.md'} <= files_in('1'), files_in('1')
assert {'evidence.md','task-01.md','build-plan.md','anvil-review-2026-01-02/review.md'} <= files_in('3'), files_in('3')
assert 'flag instead of header' in t['3'], 'deviation-log.md bullet not merged into 紀錄'
epic_chunk=t['1'].split('data-phase="epic"')[1] if 'data-phase="epic"' in t['1'] else ''
assert 'stray.md' in epic_chunk, 'stray.md not in 契約 epic group'
allf=set().union(*[files_in(i) for i in t])
for f in ['assay-notes.md','local-decision.md','evidence.md','task-01.md','build-plan.md','stray.md','2026-01-02-alpha-buyin.html']:
    assert f in allf, f+' absent from page'
assert 'Body.' not in t['1'], 'ADR body inlined into 契約 (should be a one-liner)'
for s in ['回顧','證據清算','處置']:
    assert f'>{s}</span>' in t['3'], s+' missing from 紀錄'
    assert f'>{s}</span>' not in t['0'], s+' leaked into 首頁'
embs=re.findall(r'<div class="embedded">(.*?)</div>',t['3'],re.S)
assert any('data-jump="2026-01-02-alpha-design--AC-1" tabindex="0">AC-1</a>' in e for e in embs), 'AC-1 not linked inside inlined explainer'
print('PASS: dossier classification branches / close sections / inlined-html code links')
PY

# no project root → visible note, exit 0
noroot="$(mktemp -d)"
cp -R "$fx/dossier-epic" "$noroot/ep"; rm -f "$noroot/ep/dossier.html"
expect_exit "dossier-render.sh no-root green" zero bash "$scripts_dir/dossier-render.sh" "$noroot/ep"
if grep -q 'No project root' "$noroot/ep/dossier.html"; then echo "PASS: dossier no-root note visible"; else echo "FAIL: dossier no-root note missing"; fail=1; fi
rm -rf "$noroot"

# --root override wins over the ancestor walk
expect_exit "dossier-render.sh --root green" zero bash "$scripts_dir/dossier-render.sh" --root "$tmp_root" "$ed"
expect_exit "dossier-render.sh --root red (not a dir)" nonzero bash "$scripts_dir/dossier-render.sh" --root "$tmp_root/nope" "$ed"

# determinism
cp "$dout" "$tmp_root/first.html"
bash "$scripts_dir/dossier-render.sh" "$ed" >/dev/null
if cmp -s "$dout" "$tmp_root/first.html"; then echo "PASS: dossier deterministic"; else echo "FAIL: dossier output differs between runs"; fail=1; fi

# archived placement resolves the same root
mv "$ed" "$tmp_root/.touchstone/archive/epics/2026-01-01-fixture"
ed2="$tmp_root/.touchstone/archive/epics/2026-01-01-fixture"
bash "$scripts_dir/dossier-render.sh" "$ed2" >/dev/null
if grep -q 'a miss' "$ed2/dossier.html"; then echo "PASS: dossier archived epic resolves root"; else echo "FAIL: archived epic lost gate-miss"; fail=1; fi

# index-only epic
mkdir -p "$tmp_root/.touchstone/epics/2026-01-05-lone"
printf -- '---\nslug: lone\nstatus: proposed\n---\n\n# Lone\n\n**Aim:** nothing.\n' > "$tmp_root/.touchstone/epics/2026-01-05-lone/index.md"
dout="$tmp_root/.touchstone/epics/2026-01-05-lone/dossier.html"
expect_exit "dossier-render.sh index-only green" zero bash "$scripts_dir/dossier-render.sh" "$tmp_root/.touchstone/epics/2026-01-05-lone"
expect_grep "index-only: four tabs" -eq 4 'class="tab"'
expect_grep "index-only: map placeholder" -ge 1 'no phase map in this epic'

# spec without a phase map + same-date specs grouped by slug
sd="$tmp_root/.touchstone/epics/2026-01-06-samedate"
mkdir -p "$sd/anvil-review-gamma"
printf -- '---\nslug: samedate\nstatus: active\n---\n\n# Samedate\n\n**Aim:** x.\n\n## Phases\n\n| # | Title | Spec | Plan | Status | Landed |\n|---|---|---|---|---|---|\n| 1 | Beta | [spec](2026-01-03-beta-design.md) | — | active | |\n| 2 | Gamma | [spec](2026-01-03-gamma-design.md) | — | active | |\n' > "$sd/index.md"
printf -- '---\ntype: spec\n---\n\n# Beta\n\n## Acceptance Criteria\n\n#### AC-1 — b\n' > "$sd/2026-01-03-beta-design.md"
printf -- '---\ntype: spec\n---\n\n# Gamma\n\n## Acceptance Criteria\n\n#### AC-1 — g\n' > "$sd/2026-01-03-gamma-design.md"
printf '# Review gamma\n\nAC-1 holds.\n' > "$sd/anvil-review-gamma/review.md"
printf '# Notes\n\nundated-by-slug, dated only.\n' > "$sd/2026-01-03-notes.md"
dout="$sd/dossier.html"
expect_exit "dossier-render.sh same-date green" zero bash "$scripts_dir/dossier-render.sh" "$sd"
expect_grep "no-phase-map placeholder per spec" -ge 2 'no phase map in this spec'
expect_grep "gamma review resolves gamma AC-1" -ge 1 'data-jump="2026-01-03-gamma-design--AC-1" tabindex="0">AC-1</a>'
python3 - "$dout" <<'PY' || { echo "FAIL: same-date grouping"; fail=1; }
import re,sys
h=open(sys.argv[1],encoding='utf-8').read()
parts=re.split(r'<section class="phase" data-phase="([^"]+)">',h)[1:]
groups={}
for i in range(0,len(parts),2): groups.setdefault(parts[i],'');groups[parts[i]]+=parts[i+1]
assert 'anvil-review-gamma/review.md' in groups.get('2026-01-03-gamma-design',''), 'gamma review not in gamma group'
assert '2026-01-03-notes.md' in groups.get('epic',''), 'date-only file not in epic group'
print('PASS: dossier same-date grouping by slug; date-only file in epic group')
PY

rm -rf "$tmp_root"

exit "$fail"
