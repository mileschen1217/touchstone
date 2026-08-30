#!/usr/bin/env bash
# plugin-review.sh — touchstone-local, never shipped. Cross-vendor review of this
# plugin's instruction prose against .touchstone/checker/standalone/plugin-review-rubric.md.
#
# Usage: plugin-review.sh <epic-dir> [--rounds N] [--cc-findings <file>] [--root <dir>] [--dry-run]
#        plugin-review.sh --self-test
#
# Per round it writes <epic-dir>/plugin-review-<date>/round-<n>/ with prompt.txt
# (codex, four lenses) and cc-prompt.txt (the cc arm, two lenses — rule-without-
# consumer and architecture-level declared-vs-actual; basis: the phase-4 spec's
# REQ-1), plus raw_codex.jsonl, last-message.txt, review.yaml (gate plugin-review)
# and score.md. The Codex arm runs here; the CC arm is dispatched by the calling
# session against cc-prompt.txt and handed back through --cc-findings (challenger
# marker format, locator = file[:line]).
#
# One round. The stopping rule is the injected fragment at
# skills/_shared/inject/severity-tiered-stopping-rule.md (cited, not copied — that
# file states the criterion that closes a gate round); this script always stops
# after round 1. Anything still open when the round closes rides to the next
# phase's backlog. The script fixes nothing — the maintainer session does.
#
# --dry-run writes prompt.txt and cc-prompt.txt into the round dir and exits 0
# without calling codex — no review.yaml, no cross-vendor claim.
#
#   exit 0 → a round was written · 1 → codex unavailable (no artifact written)
#   exit 2 → usage / missing python3 or PyYAML / a --cc-findings finding tagged
#            lens 1 or 4 · 3 → codex produced no content
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
    if not re.search(r'\d+\s*%', text):
        errors.append('rubric: no threshold percentage stated')
    return items, errors

def decide(rnd, max_rounds, pct, total, prev_total, new_ch):
    """One round only. The gate's stopping criterion lives in the injected
    fragment (skills/_shared/inject/severity-tiered-stopping-rule.md); this
    script's own cap is fixed at 1 regardless of max_rounds."""
    cap = 1
    if rnd >= cap:
        return 'stop=max-rounds'
    return 'continue'

def waiting(findings):
    out = []
    n = 0
    for f in findings:
        if f.get('status') == 'open' and f.get('severity') in ('C', 'H'):
            n += 1
            title = '%s %s %s:%s — %s' % (f.get('id'), f.get('severity'),
                                          f.get('file', '?'), f.get('line', 0),
                                          f.get('summary', ''))
            out.append({'id': 'W-%d' % n, 'kind': 'fix', 'owner': 'maintainer',
                        'title': title, 'refs': []})
    return out

def parse_cc_lens(path):
    """Read a --cc-findings file (challenger marker lines, locator = file[:line]).
    Return [(lens, locator), ...] — the same line shape PARSE_PY's cc arm reads,
    reduced to just the lens tag for ingestion filtering."""
    out = []
    for ln in open(path, encoding='utf-8'):
        ln = ln.strip()
        if not ln or ln.startswith('#'):
            continue
        m = re.match(r'^([\w./\-]+?)(?::(\d+))?:\s+(.*)$', ln)
        if not m:
            continue
        lm = re.search(r'\blens=([^\s]+)', m.group(3))
        lens = lm.group(1) if lm else '4'
        loc = m.group(1) + (':' + m.group(2) if m.group(2) else '')
        out.append((lens, loc))
    return out

def cc_ingest(path):
    """('ok', n) when every finding is lens 2 or 3; else ('reject', message) for
    the first lens 1 or 4 finding found — the cc arm carries lenses 2 and 3 only."""
    found = parse_cc_lens(path)
    for lens, loc in found:
        if lens not in ('2', '3'):
            msg = ('plugin-review: --cc-findings: finding at %s tagged lens %s — '
                   'the cc arm carries lenses 2 and 3 only' % (loc, lens))
            return 'reject', msg
    return 'ok', len(found)

mode = sys.argv[1]
if mode == 'decide':
    rnd, cap, pct, total = int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4]), int(sys.argv[5])
    prev = None if sys.argv[6] == '' else int(sys.argv[6])
    print(decide(rnd, cap, pct, total, prev, sys.argv[7] == '1'))
elif mode == 'cc_filter':
    status, val = cc_ingest(sys.argv[2])
    if status == 'reject':
        sys.stderr.write(val + '\n')
        sys.exit(2)
    print(val)
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
    print('PASS rubric shape: 4 items, 3-4 criteria each, weights %s, weighted max %d, threshold stated'
          % ([w for _, _, w, _ in items], mx))
    ok = True
    # (a) round 1 always stops, regardless of a higher --rounds request
    r = decide(1, 3, 50.0, 20, None, False)
    ok &= r == 'stop=max-rounds'
    print('%s one round: round-1, --rounds 3 requested -> %s' % ('PASS' if r == 'stop=max-rounds' else 'FAIL', r))
    r = decide(1, 1, 95.0, 60, None, False)
    ok &= r == 'stop=max-rounds'
    print('%s one round: round-1, --rounds 1 -> %s' % ('PASS' if r == 'stop=max-rounds' else 'FAIL', r))
    # (b) waiting_on_human lists only open C/H as W-n objects
    w = waiting([{'id': 'F-1', 'severity': 'H', 'status': 'open', 'file': 'skills/a/SKILL.md', 'line': 12, 'summary': 'rule without consumer'},
                 {'id': 'F-2', 'severity': 'M', 'status': 'open', 'file': 'skills/b/SKILL.md', 'line': 3, 'summary': 'noise'}])
    w_expect = [{'id': 'W-1', 'kind': 'fix', 'owner': 'maintainer',
                 'title': 'F-1 H skills/a/SKILL.md:12 — rule without consumer', 'refs': []}]
    ok &= w == w_expect
    print('%s waiting_on_human lists only open C/H as W-n objects: %s' % ('PASS' if w == w_expect else 'FAIL', w))
    w = waiting([{'id': 'F-3', 'severity': 'H', 'status': 'open', 'file': 'agents/x.md', 'line': 7, 'summary': 'declared-vs-actual'}])
    w3_expect = [{'id': 'W-1', 'kind': 'fix', 'owner': 'maintainer',
                  'title': 'F-3 H agents/x.md:7 — declared-vs-actual', 'refs': []}]
    ok &= w == w3_expect
    print('%s single open H carried to waiting_on_human as a W-n object: %s' % ('PASS' if w == w3_expect else 'FAIL', w))
    # (c) --cc-findings lens filter — driven directly, no subprocess, no codex
    import tempfile as _tempfile, os as _os
    def _mk(lines):
        fd, p = _tempfile.mkstemp()
        with _os.fdopen(fd, 'w', encoding='utf-8') as fh:
            fh.write('\n'.join(lines) + '\n')
        return p
    p1 = _mk(['skills/a/SKILL.md:12: the rule has no consumer lens=1 type=real-defect severity=H'])
    status, val = cc_ingest(p1)
    ok &= status == 'reject' and 'skills/a/SKILL.md:12' in val and 'lens 1' in val
    print('%s cc-findings ingestion rejects lens 1: %s %s' % ('PASS' if status == 'reject' else 'FAIL', status, val))
    _os.remove(p1)
    p2 = _mk(['agents/x.md:7: no downstream consumer lens=4 type=coverage-gap severity=L'])
    status, val = cc_ingest(p2)
    ok &= status == 'reject' and 'lens 4' in val
    print('%s cc-findings ingestion rejects lens 4: %s %s' % ('PASS' if status == 'reject' else 'FAIL', status, val))
    _os.remove(p2)
    p3 = _mk(['skills/a/SKILL.md:12: rule without consumer lens=2 type=real-defect severity=H',
              'agents/x.md:7: architecture-level declared-vs-actual lens=3 type=real-defect severity=H'])
    status, n3 = cc_ingest(p3)
    ok &= status == 'ok' and n3 == 2
    print('%s cc-findings ingestion accepts lens 2 and 3, both parsed: status=%s n=%s' % ('PASS' if (status == 'ok' and n3 == 2) else 'FAIL', status, n3))
    _os.remove(p3)
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
# prose only: the rubric reviews instruction text (skills, fragments, references, agents,
# hooks.json, schemas). Shell scripts are run, not read into a context — a 109 KB renderer
# in the prompt was 30 % of it and noise to every rubric item.
for p in sorted(sel):
    if p.endswith('.sh'):
        continue
    if os.path.isfile(os.path.join(root, p)):
        print(p)
PY
)

# Map summary for the reviewer: what each stage loads, the divergences, the two ratchet
# numbers — not the 150-edge list with file:line coordinates (64 KB, 18 % of the prompt).
MAPSUM_PY=$(cat <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
out = {
  'stages': [{'stage': s.get('stage'), 'entry': s.get('entry'), 'lines': s.get('lines'),
              'unique_lines': s.get('unique_lines'), 'load_set': s.get('load_set')} for s in d.get('stages') or []],
  'skills': d.get('skills'),
  'false_edges': d.get('false_edges'),
  'orphans': d.get('orphans'),
  'test_only': d.get('test_only'),
  'stale_waivers': d.get('stale_waivers'),
  'invalid_waivers': d.get('invalid_waivers'),
  'metrics': {k: v for k, v in (d.get('metrics') or {}).items() if k != 'untested_reachable_shell_files'},
  'notes': d.get('notes'),
}
json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
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

def norm(f, arm):
    ty = str(f.get('type', 'refinement')).lower().strip()
    ty = ty if ty in TYPES else 'refinement'
    sev = str(f.get('severity', 'M')).strip().upper()[:1]
    sev = sev if sev in ('C', 'H', 'M', 'L') else 'M'
    try:
        line = int(f.get('line') or 0)
    except Exception:
        line = 0
    return {'found_by': [arm], 'lens': lens_name(f.get('lens', 4)), 'type': ty,
            'severity': sev, 'file': str(f.get('file') or '(unlocated)'), 'line': line,
            'summary': ' '.join(str(f.get('summary') or '').split())[:400] or '(no summary)',
            'fix': ' '.join(str(f.get('fix') or '').split())[:400] or '(no fix given)',
            'status': 'open', 'refs': []}

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
        if 'cc' not in hit['found_by']:
            hit['found_by'] = hit['found_by'] + ['cc']
        hit['summary'] = (hit['summary'] + ' | cc: ' + n['summary'])[:800]
        collapsed += 1
    else:
        findings.append(n)

for i, f in enumerate(findings, 1):
    f['id'] = 'F-%d' % i
    f['provenance'] = provenance_of(f['file'], f['line'])

order = ['id', 'lens', 'type', 'provenance', 'severity', 'file', 'line',
         'summary', 'fix', 'status', 'found_by', 'refs']
findings = [{k: f[k] for k in order} for f in findings]

counts = {s: sum(1 for f in findings if f['severity'] == s) for s in ('C', 'H', 'M', 'L')}
# the CC arm counts only when its file yielded parsable findings — a flag alone is not an arm
cc_ran = providers_cc == '1' and len(cc) > 0
arms = ['codex', 'cc'] if cc_ran else ['codex']
providers = [{'lens': it['name'], 'arms': list(arms)} for it in items]
degraded = bool(degraded_reason) or not cc_ran
reason = degraded_reason
if not cc_ran:
    stand = ('partial: CC arm not dispatched — standalone run; the calling session '
             'dispatches the CC arm and passes --cc-findings') if providers_cc != '1' else \
            'partial: --cc-findings given but no parsable CC finding — the CC arm is not recorded'
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
    fh.write('\nweighted total: **%d** / %d (**%.1f %%**)\n' % (total, weighted_max, pct))
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

# ------------------------------------------------------------- parser assertions
# Reads the artifacts PARSE_PY just wrote and checks the one thing per case that
# a silent parse failure would hide. One home for all parser cases.
PARSE_ASSERT_PY=$(cat <<'PY'
import sys, yaml

review, score, want_n, mode, machine = sys.argv[1:6]
doc = yaml.safe_load(open(review, encoding='utf-8')) or {}
findings = doc.get('findings') or []
errs = []
if len(findings) != int(want_n):
    errs.append('findings=%d want %s' % (len(findings), want_n))
STAND = ('partial: CC arm not dispatched — standalone run; the calling session '
         'dispatches the CC arm and passes --cc-findings')   # the parser cases run standalone (no CC arm)
if mode == 'clean':
    if doc.get('degraded') and doc.get('degraded_reason') != STAND:
        errs.append('degraded=%r reason=%r' % (doc.get('degraded'), doc.get('degraded_reason')))
    if [pv['arms'] for pv in (doc.get('providers') or [])] != [['codex']] * len(doc.get('providers') or []):
        errs.append('standalone run must record the codex arm only: %r' % doc.get('providers'))
    need = ('id', 'found_by', 'lens', 'type', 'provenance', 'severity', 'file',
            'line', 'summary', 'fix', 'status', 'refs')
    for f in findings:
        miss = [k for k in need if k not in f]
        if miss:
            errs.append('%s missing %s' % (f.get('id'), miss))
        if not f.get('found_by'):
            errs.append('%s found_by empty' % f.get('id'))
    prov = doc.get('providers') or []
    if prov and not all(isinstance(p, dict) and 'lens' in p and 'arms' in p for p in prov):
        errs.append('providers not per-lens: %r' % prov)
elif mode == 'partial':
    if (doc.get('degraded_reason') or '').split(';')[0].strip() != 'partial':
        errs.append('degraded_reason=%r want partial' % doc.get('degraded_reason'))
elif mode == 'noscore':
    if (doc.get('degraded_reason') or '').split(';')[0].strip() != 'partial':
        errs.append('degraded_reason=%r want partial' % doc.get('degraded_reason'))
    if 'No criterion scores were parsed' not in open(score, encoding='utf-8').read():
        errs.append('score.md does not report the scores as absent')
    if 'TOTAL=0 ' not in machine:
        errs.append('machine line %r' % machine)
if errs:
    print('  ' + '; '.join(errs))
    sys.exit(1)
PY
)

# --------------------------------------------------------------------- arguments
if [ "${1:-}" = "--self-test" ]; then
  command -v python3 >/dev/null 2>&1 || { echo "plugin-review.sh: python3 not found" >&2; exit 2; }
  python3 -c 'import yaml' 2>/dev/null || { echo "plugin-review.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }
  st_fail=0
  python3 -c "$LOOP_PY" selftest "$rubric" || st_fail=1

  # Parser regression cases run through PARSE_PY itself — the same
  # from_blocks / from_records / from_lines path the live round uses. The first
  # case is the shipped defect: an unquoted `: ` inside a summary makes
  # yaml.safe_load raise, and losing the block to it is a silent false-clean.
  st_dir="$(mktemp -d)"
  st_root="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$here")"
  : > "$st_dir/cc-empty.txt"

  parser_case() {  # <label> <msg-file> <want-findings> <clean|partial|noscore>
    local label="$1" msg="$2" want="$3" mode="$4" line rc ca_out ca_rc
    line="$(python3 -c "$PARSE_PY" "$msg" "$rubric" "$st_dir/review.yaml" \
      "$st_dir/score.md" 1 selftest selftest.spec.yaml "" "$st_dir/cc-empty.txt" \
      "" "$st_root" 0 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "FAIL parser $label — PARSE_PY rc=$rc: $line"; st_fail=1; return
    fi
    ca_out="$(bash "$st_root/scripts/check-artifact.sh" review "$st_dir/review.yaml" --root "$st_root" 2>&1)"; ca_rc=$?
    if [ "$ca_rc" -ne 0 ]; then
      echo "FAIL parser $label — check-artifact.sh review rc=$ca_rc: $ca_out"; st_fail=1; return
    fi
    if python3 -c "$PARSE_ASSERT_PY" "$st_dir/review.yaml" "$st_dir/score.md" \
        "$want" "$mode" "$line"; then
      echo "PASS parser $label (review.yaml validates)"
    else
      echo "FAIL parser $label"; st_fail=1
    fi
  }

  cat > "$st_dir/m-colon.txt" <<'MSG'
```yaml
findings:
  - file: skills/a/SKILL.md
    line: 12
    lens: 2
    type: real-defect
    severity: H
    summary: single home: skills/_shared/inject/frag.md, restated here
    fix: cite the home, drop the copy
  - file: skills/b/SKILL.md
    line: 3
    lens: 1
    type: refinement
    severity: M
    summary: duplicate paragraph
    fix: delete one
  - file: agents/c.md
    line: 7
    lens: 4
    type: coverage-gap
    severity: L
    summary: no downstream consumer
    fix: name the consumer
```

C1.1: 2
C1.2: 2
VERDICT: revise
MSG
  parser_case "unquoted ': ' in a summary — all 3 findings recovered, none dropped" \
    "$st_dir/m-colon.txt" 3 clean

  cat > "$st_dir/m-empty.txt" <<'MSG'
Nothing structured this round.

```yaml
```

C1.1: 1
VERDICT: revise
MSG
  parser_case "empty fenced block — zero findings, degraded_reason partial" \
    "$st_dir/m-empty.txt" 0 partial

  cat > "$st_dir/m-nokey.txt" <<'MSG'
```yaml
notes: nothing structured this round
```

C1.1: 1
VERDICT: revise
MSG
  parser_case "fenced block with no findings key — zero findings, degraded_reason partial" \
    "$st_dir/m-nokey.txt" 0 partial

  cat > "$st_dir/m-lines.txt" <<'MSG'
- `skills/a/SKILL.md:12` lens=2 type=real-defect severity=H the rule has no consumer
- `skills/b/SKILL.md:3` lens=1 type=refinement severity=M duplicate paragraph
- `agents/c.md:7` lens=4 type=coverage-gap severity=L no downstream handler

C1.1: 2
VERDICT: revise
MSG
  parser_case "plain-list message — 3 findings parsed with every required key" \
    "$st_dir/m-lines.txt" 3 clean

  cat > "$st_dir/m-noscore.txt" <<'MSG'
```yaml
findings:
  - file: skills/a/SKILL.md
    line: 12
    lens: 2
    type: real-defect
    severity: H
    summary: one line
    fix: one line
```

VERDICT: revise
MSG
  parser_case "message with no score lines — score reported absent, never a silent 0" \
    "$st_dir/m-noscore.txt" 1 noscore

  rm -rf "$st_dir"
  exit "$st_fail"
fi

epic=""; rounds=1; cc_findings=""; root=""; dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rounds)      [ $# -ge 2 ] || { echo "plugin-review.sh: --rounds needs a number" >&2; exit 2; }
                   rounds="$2"; shift 2 ;;
    --cc-findings) [ $# -ge 2 ] || { echo "plugin-review.sh: --cc-findings needs a file" >&2; exit 2; }
                   cc_findings="$2"; shift 2 ;;
    --root)        [ $# -ge 2 ] || { echo "plugin-review.sh: --root needs a directory" >&2; exit 2; }
                   root="$2"; shift 2 ;;
    --dry-run)     dry_run=1; shift ;;
    -h|--help)     sed -n '2,27p' "$0"; exit 0 ;;
    -*)            echo "plugin-review.sh: unknown argument $1" >&2; exit 2 ;;
    *)             [ -z "$epic" ] || { echo "plugin-review.sh: one epic dir only" >&2; exit 2; }
                   epic="$1"; shift ;;
  esac
done
[ -n "$epic" ] || { echo "usage: plugin-review.sh <epic-dir> [--rounds N] [--cc-findings <file>] [--root <dir>] [--dry-run]" >&2; exit 2; }
[ -d "$epic" ] || { echo "plugin-review.sh: no such epic dir: $epic" >&2; exit 2; }
epic="$(cd "$epic" && pwd)"
case "$rounds" in ''|*[!0-9]*) echo "plugin-review.sh: --rounds must be a number" >&2; exit 2 ;; esac
[ "$rounds" -ge 1 ] || rounds=1
if [ "$rounds" -gt 1 ]; then
  echo "plugin-review.sh: --rounds $rounds requested — one round only; clamped to 1" >&2
  rounds=1
fi
[ -z "$cc_findings" ] || [ -f "$cc_findings" ] || { echo "plugin-review.sh: no such --cc-findings file: $cc_findings" >&2; exit 2; }
[ -f "$rubric" ] || { echo "plugin-review.sh: rubric missing: $rubric" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "plugin-review.sh: python3 not found" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "plugin-review.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }

# Lens filter at ingestion (AC-2) — runs before any round directory exists.
if [ -n "$cc_findings" ]; then
  python3 -c "$LOOP_PY" cc_filter "$cc_findings" || exit 2
fi

if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] || { echo "plugin-review.sh: not inside a git repo — pass --root <dir>" >&2; exit 2; }
fi
[ -d "$root" ] || { echo "plugin-review.sh: no such root: $root" >&2; exit 2; }
root="$(cd "$root" && pwd)"

# Liveness: no Codex, no artifact. A plugin-review round is never recorded
# as cross-vendor without the Codex artifacts. --dry-run never calls codex.
if [ "$dry_run" -eq 0 ] && ! command -v codex >/dev/null 2>&1; then
  cat >&2 <<EOF
plugin-review.sh: codex not on PATH — no round directory and no review.yaml written.
  Liveness rule (single home): skills/_shared/provenance.md —
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

map_json="$(mktemp)"; file_list="$(mktemp)"; cc_rubric="$(mktemp)"
trap 'rm -f "$map_json" "$file_list" "$cc_rubric"' EXIT
bash "$root/scripts/plugin-map.sh" --root "$root" > "$map_json" || {
  echo "plugin-review.sh: plugin-map.sh failed" >&2; exit 2; }
python3 -c "$FILES_PY" "$map_json" "$root" > "$file_list"

# cc-prompt.txt's rubric slice: items 2 and 3 only, verbatim — the cc arm's two
# lenses (design decision, basis: the phase-4 spec's REQ-1). codex keeps all four
# items via $rubric unchanged.
awk '/^## Item 4 /{exit} /^## Item 2 /{f=1} f{print}' "$rubric" > "$cc_rubric"

score_block_all=$(cat <<'EOF'
C1.1: 2
C1.2: 1
... (through C4.3)
EOF
)
score_block_cc=$(cat <<'EOF'
C2.1: 2
C2.2: 1
... (through C3.3)
EOF
)

# Shared prompt generation — one function, two prompt bodies (codex four lenses,
# cc lenses 2 and 3 only); everything but the rubric slice and score block is
# identical between prompt.txt and cc-prompt.txt.
build_prompt() {  # <out-file> <rubric-slice> <score-block>
  local out="$1" rubric_slice="$2" score_block="$3"
  {
    cat <<'EOF'
You are reviewing a Claude Code plugin's instruction prose (skills, agents, hooks,
checkers). This is prose review, not code review: the defects are semantic — a rule
stated twice, a rule nobody obeys, a claim the dependency map contradicts, a workflow
step nothing downstream handles.

Score the plugin against the rubric below and report every finding you have.

Every finding names `file:line` (the line numbers in the PLUGIN TEXT section are real
file line numbers), a rubric item number as `lens`, a `type` from coverage-gap |
real-defect | refinement | soundness, a `severity` from C | H | M | L, a one-line
`summary`, and a one-line `fix`.

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

EOF
    printf '%s\n' "$score_block"
    cat <<'EOF'

3. A final line:

VERDICT: approve|revise|block

=== RUBRIC (verbatim) ===
EOF
    cat "$rubric_slice"
    echo
    echo "=== PLUGIN MAP (summary: per-stage load sets and lines, declared-but-absent edges, orphans, test-only nodes, waiver state, ratchet metrics; computed from the tree on this run) ==="
    python3 -c "$MAPSUM_PY" "$map_json"
    echo
    echo "=== PLUGIN TEXT (every prose file in stages[*].load_set, agents/, hooks/; each line prefixed <n>:) ==="
    while IFS= read -r f; do
      echo "=== $f"
      awk '{ printf "%d:%s\n", NR, $0 }' "$root/$f"
      echo
    done < "$file_list"
    echo "=== END PLUGIN TEXT ==="
    echo
    echo "Now emit the three parts in the strict output format above."
  } > "$out"
}

stop=""; rnd_done=0; pct_last="0.0"; c_last=0; h_last=0
while : ; do
  mkdir -p "$day_dir"
  n=$(( $(find "$day_dir" -maxdepth 1 -type d -name 'round-*' 2>/dev/null | wc -l | tr -d ' ') + 1 ))
  if [ "$n" -gt 1 ]; then                                       # one round only, ever
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

  # ---- prompt (codex, four lenses) + cc-prompt (cc arm, lenses 2 and 3 only)
  build_prompt "$rd/prompt.txt" "$rubric" "$score_block_all"
  build_prompt "$rd/cc-prompt.txt" "$cc_rubric" "$score_block_cc"

  if [ "$dry_run" -eq 1 ]; then
    echo "plugin-review: dry-run — wrote $rd/prompt.txt ($(wc -c < "$rd/prompt.txt" | tr -d ' ') bytes) and $rd/cc-prompt.txt ($(wc -c < "$rd/cc-prompt.txt" | tr -d ' ') bytes); no codex call, no review.yaml" >&2
    exit 0
  fi

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
