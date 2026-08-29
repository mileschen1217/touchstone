#!/usr/bin/env bash
# plugin-review.sh — touchstone-local, never shipped. Cross-vendor review of this
# plugin's instruction prose against .touchstone/checker/standalone/plugin-review-rubric.md.
#
# Usage: plugin-review.sh <epic-dir> [--rounds N] [--cc-findings <file>] [--root <dir>]
#        plugin-review.sh --self-test
#
# Per round it writes <epic-dir>/plugin-review-<date>/round-<n>/ with prompt.txt,
# raw_codex.jsonl, last-message.txt, review.yaml (gate plugin-review) and score.md.
# The Codex arm runs here; the CC arm is dispatched by the calling session and
# handed back through --cc-findings (challenger marker format, locator = file[:line]).
# Loop: at most 3 rounds, stop at 90 % of the weighted maximum, at the round cap,
# or on plateau (weighted total did not rise and no new C/H). The script fixes
# nothing between rounds — the maintainer session does.
#
#   exit 0 → a round was written · 1 → codex unavailable (no artifact written)
#   exit 2 → usage / missing python3 or PyYAML · 3 → codex produced no content
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rubric="$here/plugin-review-rubric.md"

# --------------------------------------------------------------- embedded python
# Loop decision + waiting_on_human + rubric shape. One home, used by the live loop
# and by --self-test.
LOOP_PY=$(cat <<'PY'
import re, sys, yaml

def rubric_shape(path):
    """Return (items, errors). items: [(n, name, weight, [criterion ids])]."""
    text = open(path, encoding='utf-8').read()
    items, errors = [], []
    for m in re.finditer(r'^## Item (\d) — (.+?) \(weight (\d+)\)$', text, re.M):
        n, name, w = int(m.group(1)), m.group(2).strip(), int(m.group(3))
        body = text[m.end():]
        nxt = re.search(r'^## Item ', body, re.M)
        if nxt:
            body = body[:nxt.start()]
        crits = re.findall(r'^- \[C%d\.(\d)\]' % n, body, re.M)
        items.append((n, name, w, ['C%d.%s' % (n, c) for c in crits]))
    if len(items) != 4:
        errors.append('rubric: expected exactly 4 items, found %d' % len(items))
    for n, name, w, crits in items:
        if not 3 <= len(crits) <= 4:
            errors.append('rubric: item %d has %d criteria (want 3-4)' % (n, len(crits)))
        if w <= 0:
            errors.append('rubric: item %d has no positive weight' % n)
    if '90 %' not in text and '90%' not in text:
        errors.append('rubric: no 90 % threshold stated')
    return items, errors

def decide(rnd, max_rounds, pct, total, prev_total, new_ch):
    """threshold > round cap > plateau > continue."""
    cap = min(max_rounds, 3)
    if pct >= 90.0:
        return 'stop=threshold'
    if rnd >= cap:
        return 'stop=max-rounds'
    if rnd >= 2 and prev_total is not None and total <= prev_total and not new_ch:
        return 'stop=plateau'
    return 'continue'

def waiting(findings):
    out = []
    for f in findings:
        if f.get('status') == 'open' and f.get('severity') in ('C', 'H'):
            out.append('%s %s %s:%s — %s' % (f.get('id'), f.get('severity'),
                                             f.get('file', '?'), f.get('line', 0),
                                             f.get('summary', '')))
    return out

mode = sys.argv[1]
if mode == 'decide':
    rnd, cap, pct, total = int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4]), int(sys.argv[5])
    prev = None if sys.argv[6] == '' else int(sys.argv[6])
    print(decide(rnd, cap, pct, total, prev, sys.argv[7] == '1'))
elif mode == 'finalize':
    p = sys.argv[2]
    doc = yaml.safe_load(open(p, encoding='utf-8'))
    doc['waiting_on_human'] = waiting(doc.get('findings') or [])
    with open(p, 'w', encoding='utf-8') as fh:
        yaml.safe_dump(doc, fh, sort_keys=False, allow_unicode=True, width=1000)
    print(len(doc['waiting_on_human']))
elif mode == 'selftest':
    items, errors = rubric_shape(sys.argv[2])
    for e in errors:
        print('FAIL ' + e)
    mx = sum(w * 2 * len(c) for _, _, w, c in items)
    if errors:
        sys.exit(1)
    print('PASS rubric shape: 4 items, 3-4 criteria each, weights %s, weighted max %d, 90 %% threshold'
          % ([w for _, _, w, _ in items], mx))
    ok = True
    # (a) round-2 at 85 %, no rise, no new C/H -> plateau, waiting_on_human carries the open C/H
    r = decide(2, 3, 85.0, 61, 61, False)
    ok &= r == 'stop=plateau'
    print('%s AC-32 plateau: round-2 85%% total 61 vs 61, no new C/H -> %s' % ('PASS' if r == 'stop=plateau' else 'FAIL', r))
    w = waiting([{'id': 'F-1', 'severity': 'H', 'status': 'open', 'file': 'skills/a/SKILL.md', 'line': 12, 'summary': 'rule without consumer'},
                 {'id': 'F-2', 'severity': 'M', 'status': 'open', 'file': 'skills/b/SKILL.md', 'line': 3, 'summary': 'noise'}])
    ok &= w == ['F-1 H skills/a/SKILL.md:12 — rule without consumer']
    print('%s AC-32 waiting_on_human lists only open C/H: %s' % ('PASS' if len(w) == 1 else 'FAIL', w))
    # (b) round-2 reaches the threshold
    r = decide(2, 3, 91.7, 66, 61, False)
    ok &= r == 'stop=threshold'
    print('%s AC-32 threshold: round-2 91.7%% -> %s' % ('PASS' if r == 'stop=threshold' else 'FAIL', r))
    # (c) round-2 introduces a new H -> continue
    r = decide(2, 3, 84.7, 61, 61, True)
    ok &= r == 'continue'
    print('%s AC-32 new C/H: round-2 no rise but a new H -> %s' % ('PASS' if r == 'continue' else 'FAIL', r))
    # (d) round 3 with an open H -> max-rounds, never a round-4
    r = decide(3, 3, 88.9, 64, 61, True)
    ok &= r == 'stop=max-rounds'
    print('%s AC-33 round cap: round-3 rising, new H -> %s (no round-4)' % ('PASS' if r == 'stop=max-rounds' else 'FAIL', r))
    r = decide(4, 3, 50.0, 36, 30, True)
    ok &= r == 'stop=max-rounds'
    print('%s AC-33 hard cap: --rounds beyond 3 -> %s' % ('PASS' if r == 'stop=max-rounds' else 'FAIL', r))
    w = waiting([{'id': 'F-3', 'severity': 'H', 'status': 'open', 'file': 'agents/x.md', 'line': 7, 'summary': 'declared-vs-actual'}])
    ok &= len(w) == 1
    print('%s AC-33 round-3 open H carried to waiting_on_human: %s' % ('PASS' if len(w) == 1 else 'FAIL', w))
    sys.exit(0 if ok else 1)
else:
    sys.exit('plugin-review.sh: unknown loop mode %s' % mode)
PY
)

# Prompt file list: stages[*].load_set U agents/* U hooks/*, from the live map.
FILES_PY=$(cat <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
root = sys.argv[2]
sel = set()
for st in d.get('stages') or []:
    sel.update(st.get('load_set') or [])
for n in d.get('nodes') or []:
    i = n.get('id', '')
    if i.startswith('agents/') or i.startswith('hooks/'):
        sel.add(i)
for p in sorted(sel):
    if os.path.isfile(os.path.join(root, p)):
        print(p)
PY
)

# Parse Codex's message -> review.yaml + score.md; print one machine line.
PARSE_PY=$(cat <<'PY'
import json, os, re, subprocess, sys, yaml

(msg_p, rubric_p, out_review, out_score, rnd_s, sha, target, prev_review,
 cc_file, prev_sha, root, providers_cc) = sys.argv[1:13]
rnd = int(rnd_s)

# ---- rubric: items, weights, criteria
text = open(rubric_p, encoding='utf-8').read()
items = []
for m in re.finditer(r'^## Item (\d) — (.+?) \(weight (\d+)\)$', text, re.M):
    n, name, w = int(m.group(1)), m.group(2).strip(), int(m.group(3))
    body = text[m.end():]
    nxt = re.search(r'^## Item ', body, re.M)
    if nxt:
        body = body[:nxt.start()]
    crits = ['C%d.%s' % (n, c) for c in re.findall(r'^- \[C%d\.(\d)\]' % n, body, re.M)]
    items.append({'n': n, 'name': name, 'weight': w, 'crits': crits})
by_n = {i['n']: i for i in items}
weighted_max = sum(i['weight'] * 2 * len(i['crits']) for i in items)

raw = open(msg_p, encoding='utf-8').read() if os.path.isfile(msg_p) else ''

# ---- findings: a fenced yaml/json block wins; else markdown lines
def from_records(chunk):
    """Line-oriented reader for the requested block shape. Survives what YAML will
    not: an unquoted `summary: ... gate: deliverable-review ...` is a parse error
    to yaml.safe_load, and losing the whole block to it is a silent false-clean."""
    out, cur = [], None
    for ln in chunk.splitlines():
        m = re.match(r'^\s*-\s+(\w+):\s*(.*)$', ln)
        if m:
            if cur:
                out.append(cur)
            cur = {m.group(1): m.group(2).strip()}
            continue
        m = re.match(r'^\s+(\w+):\s*(.*)$', ln)
        if m and cur is not None:
            cur[m.group(1)] = m.group(2).strip()
    if cur:
        out.append(cur)
    return [f for f in out if 'file' in f or 'summary' in f]

def from_blocks(t):
    for m in re.finditer(r'```(?:yaml|yml|json)?\s*\n(.*?)```', t, re.S):
        chunk = m.group(1)
        try:
            doc = yaml.safe_load(chunk)
        except Exception:
            doc = None
        if isinstance(doc, dict) and isinstance(doc.get('findings'), list):
            return doc['findings']
        if isinstance(doc, list) and doc and isinstance(doc[0], dict) and (
                'summary' in doc[0] or 'file' in doc[0]):
            return doc
        rec = from_records(chunk)
        if rec:
            return rec
    return None

def from_lines(t):
    out = []
    for ln in t.splitlines():
        if 'type=' not in ln and 'severity=' not in ln:
            continue
        loc = re.match(r'^\s*[-*]?\s*`?([\w./\-]+\.(?:md|sh|yaml|yml|json|txt))`?(?::(\d+))?', ln)
        if not loc:
            continue
        def attr(k, dflt=''):
            mm = re.search(k + r'=([^\s,;]+)', ln)
            return mm.group(1).strip('`,.') if mm else dflt
        out.append({'file': loc.group(1), 'line': int(loc.group(2) or 0),
                    'lens': attr('lens', '4'), 'type': attr('type', 'refinement'),
                    'severity': attr('severity', 'M'),
                    'summary': re.sub(r'\s*\b\w+=[^\s]+', '', ln).strip(' -*`'),
                    'fix': attr('fix', '')})
    return out

parsed = from_blocks(raw)
degraded_reason = ''
if parsed is None:
    parsed = from_lines(raw)
    if not parsed:
        degraded_reason = 'partial'

# ---- scores + verdict
scores = {}
for m in re.finditer(r'\bC(\d)\.(\d)\s*[:=]\s*([012])\b', raw):
    scores['C%s.%s' % (m.group(1), m.group(2))] = int(m.group(3))
vm = re.search(r'VERDICT\s*[:=]\s*(approve|revise|block)', raw, re.I)
verdict = vm.group(1).lower() if vm else 'revise'
if not scores:
    degraded_reason = degraded_reason or 'partial'

# ---- fix-induced provenance: changed line ranges between prev_sha and HEAD
hunks = {}
if rnd > 1 and prev_sha and prev_sha != sha:
    try:
        diff = subprocess.run(['git', '-C', root, 'diff', '-U0', prev_sha + '..' + sha],
                              capture_output=True, text=True, timeout=60).stdout
    except Exception:
        diff = ''
    cur = None
    for ln in diff.splitlines():
        if ln.startswith('+++ b/'):
            cur = ln[6:]
        elif ln.startswith('@@') and cur:
            m = re.search(r'\+(\d+)(?:,(\d+))?', ln)
            if m:
                s = int(m.group(1)); c = int(m.group(2) or 1)
                hunks.setdefault(cur, []).append((s, s + max(c, 1) - 1))

def provenance_of(f, l):
    for s, e in hunks.get(f, []):
        if s <= l <= e:
            return 'fix-induced'
    return 'original'

LENS_KEY = [(1, 'duplicate'), (1, 'contradiction'), (2, 'consumer'),
            (3, 'declared'), (3, 'architecture'), (4, 'workflow')]

def lens_name(v):
    s = str(v).strip()
    m = re.search(r'[1-4]', s[:3])
    if m:
        return by_n[int(m.group(0))]['name']
    low = s.lower()
    for n, kw in LENS_KEY:
        if kw in low:
            return by_n[n]['name']
    return by_n[4]['name']

TYPES = ('coverage-gap', 'real-defect', 'refinement', 'soundness')

def norm(f, agent):
    ty = str(f.get('type', 'refinement')).lower().strip()
    ty = ty if ty in TYPES else 'refinement'
    sev = str(f.get('severity', 'M')).strip().upper()[:1]
    sev = sev if sev in ('C', 'H', 'M', 'L') else 'M'
    try:
        line = int(f.get('line') or 0)
    except Exception:
        line = 0
    return {'agent': agent, 'lens': lens_name(f.get('lens', 4)), 'type': ty,
            'severity': sev, 'file': str(f.get('file') or '(unlocated)'), 'line': line,
            'summary': ' '.join(str(f.get('summary') or '').split())[:400] or '(no summary)',
            'fix': ' '.join(str(f.get('fix') or '').split())[:400] or '(no fix given)',
            'status': 'open'}

findings = [norm(f, 'codex') for f in parsed if isinstance(f, dict)]

# ---- CC arm: challenger marker lines, locator = file[:line]
cc = []
if cc_file and os.path.isfile(cc_file):
    for ln in open(cc_file, encoding='utf-8'):
        ln = ln.strip()
        if not ln or ln.startswith('#'):
            continue
        m = re.match(r'^([\w./\-]+?)(?::(\d+))?:\s+(.*)$', ln)
        if not m:
            continue
        rest = m.group(3)
        def attr(k, dflt=''):
            mm = re.search(r'\b' + k + r'=([^\s]+)', rest)
            return mm.group(1) if mm else dflt
        question = re.split(r'\s{2,}|\btype=', rest)[0].strip()
        cc.append({'file': m.group(1), 'line': int(m.group(2) or 0),
                   'lens': attr('lens', '4'), 'type': attr('type', 'refinement'),
                   'severity': attr('severity', 'M'), 'summary': question,
                   'fix': '(cc arm: question — the maintainer answers or fixes)',
                   'provenance_hint': attr('provenance', '')})

collapsed = 0
for c in cc:
    n = norm(c, 'cc')
    hit = next((f for f in findings if f['file'] == n['file'] and f['type'] == n['type']), None)
    if hit:
        hit['agent'] = 'codex+cc'
        hit['summary'] = (hit['summary'] + ' | cc: ' + n['summary'])[:800]
        collapsed += 1
    else:
        findings.append(n)

for i, f in enumerate(findings, 1):
    f['id'] = 'F-%d' % i
    f['provenance'] = provenance_of(f['file'], f['line'])

order = ['id', 'agent', 'lens', 'type', 'provenance', 'severity', 'file', 'line',
         'summary', 'fix', 'status']
findings = [{k: f[k] for k in order} for f in findings]

counts = {s: sum(1 for f in findings if f['severity'] == s) for s in ('C', 'H', 'M', 'L')}
providers = ['codex', 'cc'] if providers_cc == '1' else ['codex']
degraded = bool(degraded_reason) or providers_cc != '1'
reason = degraded_reason
if providers_cc != '1':
    stand = ('partial: CC arm not dispatched — standalone run; the calling session '
             'dispatches the CC arm and passes --cc-findings')
    reason = (degraded_reason + '; ' + stand) if degraded_reason else stand

doc = {'gate': 'plugin-review', 'target': target, 'sha': sha, 'round': rnd,
       'providers': providers, 'degraded': degraded}
if degraded:
    doc['degraded_reason'] = reason
doc.update({'verdict': verdict, 'counts': counts, 'rulings': [],
            'findings': findings, 'waiting_on_human': []})
with open(out_review, 'w', encoding='utf-8') as fh:
    yaml.safe_dump(doc, fh, sort_keys=False, allow_unicode=True, width=1000)

# ---- score.md
total = 0
rows = []
for it in items:
    got = sum(scores.get(c, 0) for c in it['crits'])
    sub = got * it['weight']
    total += sub
    rows.append((it, got, sub))
pct = (100.0 * total / weighted_max) if weighted_max else 0.0
prev_total = None
if prev_review:
    ps = os.path.join(os.path.dirname(prev_review), 'score.md')
    if os.path.isfile(ps):
        m = re.search(r'total=(\d+)', open(ps, encoding='utf-8').read())
        if m:
            prev_total = int(m.group(1))
plateau = 'yes' if (prev_total is not None and total <= prev_total) else 'no'

new_ch = 1
if prev_review and os.path.isfile(prev_review):
    try:
        pd = yaml.safe_load(open(prev_review, encoding='utf-8')) or {}
        seen = {(f.get('file'), f.get('summary')) for f in (pd.get('findings') or [])
                if f.get('severity') in ('C', 'H')}
        new_ch = 1 if any((f['file'], f['summary']) not in seen for f in findings
                          if f['severity'] in ('C', 'H')) else 0
    except Exception:
        new_ch = 1

with open(out_score, 'w', encoding='utf-8') as fh:
    fh.write('# plugin-review score — round %d\n\n' % rnd)
    fh.write('| item | weight | %s | raw | weighted |\n' % ' | '.join('c%d' % i for i in range(1, 5)))
    fh.write('|---|---|---|---|---|---|---|---|\n')
    for it, got, sub in rows:
        cells = [str(scores.get(c, 0)) for c in it['crits']] + ['—'] * (4 - len(it['crits']))
        fh.write('| %d %s | %d | %s | %d | %d |\n' % (it['n'], it['name'], it['weight'],
                                                      ' | '.join(cells), got, sub))
    fh.write('\nweighted total: **%d** / %d (**%.1f %%**) · threshold 90 %% · plateau vs previous round: %s\n'
             % (total, weighted_max, pct, plateau))
    if prev_total is not None:
        fh.write('previous round weighted total: %d\n' % prev_total)
    if not scores:
        fh.write('\nNo criterion scores were parsed from the Codex message — every criterion counted 0.\n')
    fh.write('\n<!-- total=%d max=%d pct=%.1f -->\n' % (total, weighted_max, pct))

print('TOTAL=%d MAX=%d PCT=%.1f C=%d H=%d NEWCH=%d PREV=%s COLLAPSED=%d FINDINGS=%d'
      % (total, weighted_max, pct, counts['C'], counts['H'], new_ch,
         '' if prev_total is None else prev_total, collapsed, len(findings)))
PY
)

# --------------------------------------------------------------------- arguments
if [ "${1:-}" = "--self-test" ]; then
  command -v python3 >/dev/null 2>&1 || { echo "plugin-review.sh: python3 not found" >&2; exit 2; }
  python3 -c 'import yaml' 2>/dev/null || { echo "plugin-review.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }
  python3 -c "$LOOP_PY" selftest "$rubric" || exit 1
  exit 0
fi

epic=""; rounds=3; cc_findings=""; root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rounds)      [ $# -ge 2 ] || { echo "plugin-review.sh: --rounds needs a number" >&2; exit 2; }
                   rounds="$2"; shift 2 ;;
    --cc-findings) [ $# -ge 2 ] || { echo "plugin-review.sh: --cc-findings needs a file" >&2; exit 2; }
                   cc_findings="$2"; shift 2 ;;
    --root)        [ $# -ge 2 ] || { echo "plugin-review.sh: --root needs a directory" >&2; exit 2; }
                   root="$2"; shift 2 ;;
    -h|--help)     sed -n '2,18p' "$0"; exit 0 ;;
    -*)            echo "plugin-review.sh: unknown argument $1" >&2; exit 2 ;;
    *)             [ -z "$epic" ] || { echo "plugin-review.sh: one epic dir only" >&2; exit 2; }
                   epic="$1"; shift ;;
  esac
done
[ -n "$epic" ] || { echo "usage: plugin-review.sh <epic-dir> [--rounds N] [--cc-findings <file>] [--root <dir>]" >&2; exit 2; }
[ -d "$epic" ] || { echo "plugin-review.sh: no such epic dir: $epic" >&2; exit 2; }
epic="$(cd "$epic" && pwd)"
case "$rounds" in ''|*[!0-9]*) echo "plugin-review.sh: --rounds must be a number" >&2; exit 2 ;; esac
[ "$rounds" -ge 1 ] || rounds=1
[ "$rounds" -le 3 ] || rounds=3          # AC-33: hard cap, no round-4 ever
[ -z "$cc_findings" ] || [ -f "$cc_findings" ] || { echo "plugin-review.sh: no such --cc-findings file: $cc_findings" >&2; exit 2; }
[ -f "$rubric" ] || { echo "plugin-review.sh: rubric missing: $rubric" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "plugin-review.sh: python3 not found" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "plugin-review.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }

if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] || { echo "plugin-review.sh: not inside a git repo — pass --root <dir>" >&2; exit 2; }
fi
[ -d "$root" ] || { echo "plugin-review.sh: no such root: $root" >&2; exit 2; }
root="$(cd "$root" && pwd)"

# Liveness (AC-31): no Codex, no artifact. A plugin-review round is never recorded
# as cross-vendor without the Codex artifacts.
if ! command -v codex >/dev/null 2>&1; then
  cat >&2 <<EOF
plugin-review.sh: codex not on PATH — no round directory and no review.yaml written.
  Liveness rule (single home): skills/cross-provider-reviewer/references/provenance.md —
  \`codex\` is listed in providers only when the round dir holds its raw_codex.jsonl and
  last-message.txt; a round without them is not a cross-vendor round.
EOF
  exit 1
fi

# ---------------------------------------------------------------- target + layout
target=""
for f in "$epic"/*.spec.yaml; do [ -f "$f" ] && target="$(basename "$f")"; done
[ -n "$target" ] || { echo "plugin-review.sh: no *.spec.yaml in $epic" >&2; exit 2; }
day_dir="$epic/plugin-review-$(date +%Y-%m-%d)"
sha="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)"
providers_cc=0; [ -n "$cc_findings" ] && providers_cc=1

map_json="$(mktemp)"; file_list="$(mktemp)"
trap 'rm -f "$map_json" "$file_list"' EXIT
bash "$root/scripts/plugin-map.sh" --root "$root" > "$map_json" || {
  echo "plugin-review.sh: plugin-map.sh failed" >&2; exit 2; }
python3 -c "$FILES_PY" "$map_json" "$root" > "$file_list"

stop=""; rnd_done=0; pct_last="0.0"; c_last=0; h_last=0
while : ; do
  mkdir -p "$day_dir"
  n=$(( $(find "$day_dir" -maxdepth 1 -type d -name 'round-*' 2>/dev/null | wc -l | tr -d ' ') + 1 ))
  if [ "$n" -gt 3 ]; then                                       # AC-33: never a round-4
    stop="max-rounds"; rnd_done=$((n - 1))
    lastdir="$day_dir/round-$rnd_done"
    [ -f "$lastdir/score.md" ] && pct_last="$(sed -n 's/.*pct=\([0-9.]*\).*/\1/p' "$lastdir/score.md" | tail -1)"
    if [ -f "$lastdir/review.yaml" ]; then
      read -r c_last h_last <<<"$(python3 -c 'import sys,yaml; c=(yaml.safe_load(open(sys.argv[1]))or{}).get("counts") or {}; print(c.get("C",0), c.get("H",0))' "$lastdir/review.yaml")"
    fi
    break
  fi
  rd="$day_dir/round-$n"
  mkdir -p "$rd"
  prev_review=""; prev_sha=""
  if [ "$n" -gt 1 ] && [ -f "$day_dir/round-$((n-1))/review.yaml" ]; then
    prev_review="$day_dir/round-$((n-1))/review.yaml"
    prev_sha="$(python3 -c 'import sys,yaml; print((yaml.safe_load(open(sys.argv[1]))or{}).get("sha",""))' "$prev_review")"
  fi

  # ---- prompt
  {
    cat <<'EOF'
You are reviewing a Claude Code plugin's instruction prose (skills, agents, hooks,
checkers). This is prose review, not code review: the defects are semantic — a rule
stated twice, a rule nobody obeys, a claim the dependency map contradicts, a workflow
step nothing downstream handles.

Score the plugin against the rubric below and report every finding you have.

Every finding names `file:line` (the line numbers in the PLUGIN TEXT section are real
file line numbers), one of the four rubric items as `lens` (give its number 1-4), a
`type` from coverage-gap | real-defect | refinement | soundness, a `severity` from
C | H | M | L, a one-line `summary`, and a one-line `fix`.

OUTPUT FORMAT — strict. Emit exactly these three parts, nothing else after them:

1. One fenced yaml block:

```yaml
findings:
  - file: skills/example/SKILL.md
    line: 42
    lens: 2
    type: real-defect
    severity: H
    summary: one line, no newline
    fix: one line, no newline
```

2. A score block, one line per rubric criterion, every criterion present:

C1.1: 2
C1.2: 1
... (through C4.3)

3. A final line:

VERDICT: approve|revise|block

=== RUBRIC (verbatim) ===
EOF
    cat "$rubric"
    echo
    echo "=== PLUGIN MAP (JSON, computed from the tree on this run) ==="
    cat "$map_json"
    echo
    echo "=== PLUGIN TEXT (every file in stages[*].load_set, agents/, hooks/) ==="
    while IFS= read -r f; do
      echo "=== $f"
      nl -ba "$root/$f"
      echo
    done < "$file_list"
    echo "=== END PLUGIN TEXT ==="
    echo
    echo "Now emit the three parts in the strict output format above."
  } > "$rd/prompt.txt"

  # ---- Codex arm (never -s read-only; </dev/null mandatory)
  echo "plugin-review: round $n — codex exec over $(wc -c < "$rd/prompt.txt" | tr -d ' ') bytes of prompt" >&2
  # `timeout` is GNU coreutils; stock macOS has none (Homebrew ships `gtimeout`). Absent
  # both → run unbounded rather than false-block with rc 127.
  tmo="$(command -v timeout || command -v gtimeout || true)"
  ${tmo:+"$tmo" 900} codex exec --json --skip-git-repo-check \
    -o "$rd/last-message.txt" "$(cat "$rd/prompt.txt")" </dev/null \
    > "$rd/raw_codex.jsonl" 2> "$rd/codex_stderr.log"
  crc=$?
  if [ ! -s "$rd/last-message.txt" ]; then
    echo "plugin-review: codex produced no message (rc=$crc) — no review.yaml for round $n." >&2
    echo "  fallback_reason: $( [ "$crc" -eq 124 ] && echo 'codex timeout (900s)' || echo "codex error: rc=$crc" )" >&2
    exit 3
  fi

  line="$(python3 -c "$PARSE_PY" "$rd/last-message.txt" "$rubric" "$rd/review.yaml" \
    "$rd/score.md" "$n" "$sha" "$target" "$prev_review" "$cc_findings" "$prev_sha" \
    "$root" "$providers_cc")" || { echo "plugin-review.sh: parse failed for round $n" >&2; exit 3; }
  eval "$line"
  rnd_done="$n"; pct_last="$PCT"; c_last="$C"; h_last="$H"

  d="$(python3 -c "$LOOP_PY" decide "$n" "$rounds" "$PCT" "$TOTAL" "$PREV" "$NEWCH")"
  case "$d" in
    stop=*) stop="${d#stop=}"; break ;;
  esac
done

last="$day_dir/round-$rnd_done/review.yaml"
if [ -f "$last" ]; then
  python3 -c "$LOOP_PY" finalize "$last" >/dev/null
fi
echo "plugin-review: rounds=$rnd_done score=${pct_last}% C=$c_last H=$h_last stop=$stop"
