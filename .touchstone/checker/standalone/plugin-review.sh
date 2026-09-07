#!/usr/bin/env bash
# plugin-review.sh — touchstone-local, never shipped. Independent semantic review
# of this plugin's instruction prose against plugin-review-rubric.md.
#
# Usage: plugin-review.sh <epic-dir> --reviewer <codex|claude-code> [--rounds N] [--root <dir>] [--dry-run]
#        plugin-review.sh --self-test
#
# Per round it writes <epic-dir>/plugin-review-<date>/round-<n>/ with one full
# lens file and one subject file for the explicitly selected fresh reviewer,
# plus that provider's liveness artifacts, review.yaml and score.md. Reviewer
# independence is selected by the maintainer; vendor diversity is not implicit.
#
# One round. The stopping rule is the injected fragment at
# skills/.shared/inject/severity-tiered-stopping-rule.md (cited, not copied — that
# file states the criterion that closes a gate round); this script always stops
# after round 1. Anything still open when the round closes rides to the next
# phase's backlog. The script fixes nothing — the maintainer session does.
#
# --dry-run writes the four lens/subject files into the round dir and exits 0
# without calling the reviewer — no review.yaml and no review claim.
#
#   exit 0 → a round was written · 1 → reviewer unavailable/failed
#   exit 2 → usage / missing python3 or PyYAML · 3 → reviewer produced no content
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rubric="$here/plugin-review-rubric.md"

next_round() {  # <day-dir>: an incomplete dry-run round is reusable
  [ -f "$1/round-1/review.yaml" ] && echo 2 || echo 1
}

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
    fragment (skills/.shared/inject/severity-tiered-stopping-rule.md); this
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

# Parse the selected reviewer's message -> review.yaml + score.md; print one machine line.
PARSE_PY=$(cat <<'PY'
import json, os, re, subprocess, sys, yaml

(msg_p, rubric_p, out_review, out_score, rnd_s, sha, target, prev_review,
 prev_sha, root, reviewer) = sys.argv[1:12]
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

findings = [norm(f, reviewer) for f in parsed if isinstance(f, dict)]

for i, f in enumerate(findings, 1):
    f['id'] = 'F-%d' % i
    f['provenance'] = provenance_of(f['file'], f['line'])

order = ['id', 'lens', 'type', 'provenance', 'severity', 'file', 'line',
         'summary', 'fix', 'status', 'found_by', 'refs']
findings = [{k: f[k] for k in order} for f in findings]

counts = {s: sum(1 for f in findings if f['severity'] == s) for s in ('C', 'H', 'M', 'L')}
providers = [{'lens': it['name'], 'arms': [reviewer]} for it in items]
degraded = bool(degraded_reason)

doc = {'gate': 'plugin-review', 'target': target, 'sha': sha, 'round': rnd,
       'providers': providers, 'degraded': degraded}
if degraded:
    doc['degraded_reason'] = degraded_reason
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
        fh.write('\nNo criterion scores were parsed from the reviewer message — every criterion counted 0.\n')
    fh.write('\n<!-- total=%d max=%d pct=%.1f -->\n' % (total, weighted_max, pct))

print('TOTAL=%d MAX=%d PCT=%.1f C=%d H=%d NEWCH=%d PREV=%s FINDINGS=%d'
      % (total, weighted_max, pct, counts['C'], counts['H'], new_ch,
         '' if prev_total is None else prev_total, len(findings)))
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
if mode == 'clean':
    if doc.get('degraded'):
        errs.append('degraded=%r reason=%r' % (doc.get('degraded'), doc.get('degraded_reason')))
    if [pv['arms'] for pv in (doc.get('providers') or [])] != [['codex']] * len(doc.get('providers') or []):
        errs.append('parser fixture must record the selected codex reviewer: %r' % doc.get('providers'))
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

# ------------------------------------------------------------------- lens/subject
# The two-file split: a full LENS body (strict output, score block, rubric) and a
# SUBJECT (plugin map summary + numbered plugin text). The subject bytes are never
# held in this script's own variables, only redirected by assemble-arm-task.sh.
score_block_all=$(cat <<'EOF'
C1.1: 2
C1.2: 1
... (through C4.3)
EOF
)

build_lens() {  # <out-file> <rubric-slice> <score-block>
  local out="$1" rubric_slice="$2" score_block="$3"
  {
    cat <<'EOF'
You are reviewing an agent-harness plugin's instruction prose (skills, agents, hooks,
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
    echo "Now emit the three parts in the strict output format above, reviewing the subject provided separately."
  } > "$out"
}

# subject_cmd_script <out-script> <mapsum-pyfile> <map-json> <file-list> <root>
# Writes a POSIX shell script whose stdout is the SUBJECT: the plugin map summary
# (MAPSUM_PY) followed by the numbered plugin text (the file-loop part) — nothing
# else. Same subject for every arm.
subject_cmd_script() {
  local out="$1" mapsum_pyfile="$2" map_json="$3" file_list="$4" root="$5"
  cat > "$out" <<CMD
echo "=== PLUGIN MAP (summary: per-stage load sets and lines, declared-but-absent edges, orphans, test-only nodes, waiver state, ratchet metrics; computed from the tree on this run) ==="
python3 "$mapsum_pyfile" "$map_json"
echo
echo "=== PLUGIN TEXT (every prose file in stages[*].load_set, agents/, hooks/; each line prefixed <n>:) ==="
while IFS= read -r f; do
  echo "=== \$f"
  awk '{ printf "%d:%s\n", NR, \$0 }' "$root/\$f"
  echo
done < "$file_list"
echo "=== END PLUGIN TEXT ==="
CMD
}

# --------------------------------------------------------------------- arguments
if [ "${1:-}" = "--self-test" ]; then
  command -v python3 >/dev/null 2>&1 || { echo "plugin-review.sh: python3 not found" >&2; exit 2; }
  python3 -c 'import yaml' 2>/dev/null || { echo "plugin-review.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }
  st_fail=0
  python3 -c "$LOOP_PY" selftest "$rubric" || st_fail=1

  st_round_state="$(mktemp -d)"
  mkdir -p "$st_round_state/round-1"
  [ "$(next_round "$st_round_state")" = 1 ] \
    && echo "PASS incomplete dry-run round remains runnable" \
    || { echo "FAIL incomplete dry-run round was counted complete"; st_fail=1; }
  : > "$st_round_state/round-1/review.yaml"
  [ "$(next_round "$st_round_state")" = 2 ] \
    && echo "PASS review.yaml marks round complete" \
    || { echo "FAIL completed round was not counted"; st_fail=1; }
  rm -rf "$st_round_state"

  # Parser regression cases run through PARSE_PY itself — the same
  # from_blocks / from_records / from_lines path the live round uses. The first
  # case is the shipped defect: an unquoted `: ` inside a summary makes
  # yaml.safe_load raise, and losing the block to it is a silent false-clean.
  st_dir="$(mktemp -d)"
  st_root="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$here")"
  parser_case() {  # <label> <msg-file> <want-findings> <clean|partial|noscore>
    local label="$1" msg="$2" want="$3" mode="$4" line rc ca_out ca_rc
    line="$(python3 -c "$PARSE_PY" "$msg" "$rubric" "$st_dir/review.yaml" \
      "$st_dir/score.md" 1 selftest selftest.spec.yaml "" "" "$st_root" codex \
      2>&1)"; rc=$?
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
    summary: single home: skills/.shared/inject/frag.md, restated here
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

  # The full lens/subject split runs through the actual assembler, without a CLI.
  st_map="$(mktemp)"; st_files="$(mktemp)"
  st_mapsum_py="$(mktemp)"; st_subject_script="$(mktemp)"; st_lens="$(mktemp)"
  bash "$st_root/scripts/plugin-map.sh" --root "$st_root" > "$st_map" 2>/dev/null
  python3 -c "$FILES_PY" "$st_map" "$st_root" > "$st_files"
  printf '%s' "$MAPSUM_PY" > "$st_mapsum_py"
  subject_cmd_script "$st_subject_script" "$st_mapsum_py" "$st_map" "$st_files" "$st_root"
  build_lens "$st_lens" "$rubric" "$score_block_all"
  st_round="$st_dir/split-round"
  if bash "$st_root/scripts/assemble-arm-task.sh" --arm codex --round-dir "$st_round" \
      --lens-file "$st_lens" --subject-cmd "bash '$st_subject_script'" --root "$st_root" \
      >/dev/null 2>&1 \
      && grep -q '^## Item 1 ' "$st_round/lens-codex.md" 2>/dev/null \
      && grep -q '^## Item 4 ' "$st_round/lens-codex.md" 2>/dev/null \
      && ! grep -q '=== PLUGIN TEXT' "$st_round/lens-codex.md" 2>/dev/null; then
    echo "PASS full lens split: has rubric items 1-4, no PLUGIN TEXT marker"
  else
    echo "FAIL full lens split"; st_fail=1
  fi
  if [ -f "$st_round/subject-codex.md" ] \
      && grep -q '=== PLUGIN TEXT' "$st_round/subject-codex.md" 2>/dev/null \
      && ! grep -q 'C1.1:' "$st_round/subject-codex.md" 2>/dev/null; then
    echo "PASS subject split: has PLUGIN TEXT marker, no score block"
  else
    echo "FAIL subject split"; st_fail=1
  fi
  rm -f "$st_map" "$st_files" "$st_mapsum_py" "$st_subject_script" "$st_lens"
  rm -rf "$st_round"

  # A normal plugin review has one explicitly selected, full-lens reviewer.
  # This catches regressions back to the historical hard-coded dual-vendor
  # shape: choosing Claude must neither require nor prepare a Codex arm.
  st_epic="$st_dir/single-reviewer-epic"
  mkdir -p "$st_epic"
  : > "$st_epic/selftest.spec.yaml"
  st_single_out="$(bash "$0" "$st_epic" --reviewer claude-code --root "$st_root" --dry-run 2>&1)"
  st_single_rc=$?
  st_single_round="$st_epic/plugin-review-$(date +%Y-%m-%d)/round-1"
  if [ "$st_single_rc" -eq 0 ] \
      && [ -f "$st_single_round/lens-claude-code.md" ] \
      && grep -q '^## Item 1 ' "$st_single_round/lens-claude-code.md" \
      && grep -q '^## Item 4 ' "$st_single_round/lens-claude-code.md" \
      && [ ! -e "$st_single_round/lens-codex.md" ]; then
    echo "PASS selected reviewer receives all four lenses and no second vendor arm is prepared"
  else
    echo "FAIL single-reviewer dry-run rc=$st_single_rc: $st_single_out"; st_fail=1
  fi

  rm -rf "$st_dir"
  exit "$st_fail"
fi

epic=""; rounds=1; reviewer=""; root=""; dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rounds)      [ $# -ge 2 ] || { echo "plugin-review.sh: --rounds needs a number" >&2; exit 2; }
                   rounds="$2"; shift 2 ;;
    --reviewer)    [ $# -ge 2 ] || { echo "plugin-review.sh: --reviewer needs codex or claude-code" >&2; exit 2; }
                   reviewer="$2"; shift 2 ;;
    --root)        [ $# -ge 2 ] || { echo "plugin-review.sh: --root needs a directory" >&2; exit 2; }
                   root="$2"; shift 2 ;;
    --dry-run)     dry_run=1; shift ;;
    -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
    -*)            echo "plugin-review.sh: unknown argument $1" >&2; exit 2 ;;
    *)             [ -z "$epic" ] || { echo "plugin-review.sh: one epic dir only" >&2; exit 2; }
                   epic="$1"; shift ;;
  esac
done
[ -n "$epic" ] || { echo "usage: plugin-review.sh <epic-dir> --reviewer <codex|claude-code> [--rounds N] [--root <dir>] [--dry-run]" >&2; exit 2; }
[ -d "$epic" ] || { echo "plugin-review.sh: no such epic dir: $epic" >&2; exit 2; }
epic="$(cd "$epic" && pwd)"
case "$reviewer" in
  codex|claude-code) ;;
  '') echo "plugin-review.sh: --reviewer is required; select a provider independent from the builder" >&2; exit 2 ;;
  *) echo "plugin-review.sh: unsupported reviewer '$reviewer' (want codex or claude-code)" >&2; exit 2 ;;
esac
case "$rounds" in ''|*[!0-9]*) echo "plugin-review.sh: --rounds must be a number" >&2; exit 2 ;; esac
[ "$rounds" -ge 1 ] || rounds=1
if [ "$rounds" -gt 1 ]; then
  echo "plugin-review.sh: --rounds $rounds requested — one round only; clamped to 1" >&2
  rounds=1
fi
[ -f "$rubric" ] || { echo "plugin-review.sh: rubric missing: $rubric" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "plugin-review.sh: python3 not found" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "plugin-review.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }

if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] || { echo "plugin-review.sh: not inside a git repo — pass --root <dir>" >&2; exit 2; }
fi
[ -d "$root" ] || { echo "plugin-review.sh: no such root: $root" >&2; exit 2; }
root="$(cd "$root" && pwd)"

# Liveness: an unavailable selected reviewer produces no review artifact.
reviewer_cli="$reviewer"; [ "$reviewer" = "claude-code" ] && reviewer_cli="claude"
if [ "$dry_run" -eq 0 ] && ! command -v "$reviewer_cli" >/dev/null 2>&1; then
  echo "plugin-review.sh: selected reviewer '$reviewer' is unavailable — no review.yaml written" >&2
  exit 1
fi

# ---------------------------------------------------------------- target + layout
target=""
for f in "$epic"/*.spec.yaml; do [ -f "$f" ] && target="$(basename "$f")"; done
[ -n "$target" ] || { echo "plugin-review.sh: no *.spec.yaml in $epic" >&2; exit 2; }
day_dir="$epic/plugin-review-$(date +%Y-%m-%d)"
sha="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)"

map_json="$(mktemp)"; file_list="$(mktemp)"; mapsum_pyfile="$(mktemp)"
subject_script="$(mktemp)"
trap 'rm -f "$map_json" "$file_list" "$mapsum_pyfile" "$subject_script"' EXIT
bash "$root/scripts/plugin-map.sh" --root "$root" > "$map_json" || {
  echo "plugin-review.sh: plugin-map.sh failed" >&2; exit 2; }
python3 -c "$FILES_PY" "$map_json" "$root" > "$file_list"

# The subject is generated once for the selected reviewer and redirected by the
# assembler, never held in this script's variables.
printf '%s' "$MAPSUM_PY" > "$mapsum_pyfile"
subject_cmd_script "$subject_script" "$mapsum_pyfile" "$map_json" "$file_list" "$root"
subject_cmd="bash '$subject_script'"

stop=""; rnd_done=0; pct_last="0.0"; c_last=0; h_last=0
while : ; do
  mkdir -p "$day_dir"
  n="$(next_round "$day_dir")"
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

  lens_tmp="$(mktemp)"
  build_lens "$lens_tmp" "$rubric" "$score_block_all"
  bash "$root/scripts/assemble-arm-task.sh" --arm "$reviewer" --round-dir "$rd" \
    --lens-file "$lens_tmp" --subject-cmd "$subject_cmd" --root "$root" >/dev/null \
    || { echo "plugin-review.sh: assemble-arm-task.sh failed for $reviewer" >&2; rm -f "$lens_tmp"; exit 2; }
  rm -f "$lens_tmp"

  if [ "$dry_run" -eq 1 ]; then
    echo "plugin-review: dry-run — reviewer=$reviewer; wrote $rd/lens-$reviewer.md ($(wc -c < "$rd/lens-$reviewer.md" | tr -d ' ') bytes), $rd/subject-$reviewer.md ($(wc -c < "$rd/subject-$reviewer.md" | tr -d ' ') bytes); no reviewer call, no review.yaml" >&2
    exit 0
  fi

  echo "plugin-review: round $n — reviewer=$reviewer over $(wc -c < "$rd/lens-$reviewer.md" | tr -d ' ') bytes of lens + $(wc -c < "$rd/subject-$reviewer.md" | tr -d ' ') bytes of subject" >&2
  if [ "$reviewer" = "codex" ]; then
    raw="$rd/raw_codex.jsonl"; message="$rd/last-message.txt"
  else
    raw="$rd/raw_claude.json"; message="$rd/last-message-claude.txt"
  fi
  if [ -s "$raw" ] && [ -s "$message" ]; then
    echo "plugin-review: reusing completed $reviewer liveness artifacts for parser retry" >&2
  elif ! bash "$root/scripts/run-external-reviewer.sh" --provider "$reviewer" \
      --lens-file "$rd/lens-$reviewer.md" --subject-file "$rd/subject-$reviewer.md" \
      --result-dir "$rd" --timeout 900 > "$rd/reviewer-status.txt"; then
    echo "plugin-review: $reviewer failed — no review.yaml for round $n" >&2
    exit 3
  fi
  [ -s "$message" ] || { echo "plugin-review: $reviewer produced no message — no review.yaml for round $n" >&2; exit 3; }

  line="$(python3 -c "$PARSE_PY" "$message" "$rubric" "$rd/review.yaml" \
    "$rd/score.md" "$n" "$sha" "$target" "$prev_review" "$prev_sha" \
    "$root" "$reviewer")" || { echo "plugin-review.sh: parse failed for round $n" >&2; exit 3; }
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
