#!/usr/bin/env bash
# scripts/plugin-map.sh — Compute the plugin's dependency graph from the tree on
# every run and print it on stdout. Nothing is read from, or written to, a
# committed map: the map IS this run. The script writes no file anywhere.
#
# Usage: plugin-map.sh [--root <dir>] [--skill <name> | --mermaid]
#   (no mode)  JSON on stdout: nodes, edges, entries, stages, false_edges,
#              orphans, test_only (+ skills, metrics, stale_waivers,
#              invalid_waivers, notes)
#   --skill    that skill's transitive load set: `lines<TAB>bytes<TAB>path` rows
#              plus a `total` row (lines, bytes, files)
#   --mermaid  `flowchart LR` over the six stage entries and the invokes edges
#              between them
#   --root     tree to measure (default: the enclosing git worktree's toplevel)
#   --self-test  run the committed fixture trees under
#              .touchstone/checker/fixtures/ through this script and assert the
#              graph, entries-file and metrics contract; one PASS/FAIL line per
#              case, non-zero exit on any FAIL
#   exit 0 → map printed · 1 → bad root / entries-file contract violated (the
#   offending paths are listed on stderr) · 2 → usage error
#
# Node set — every file under skills/ agents/ hooks/ scripts/ (fixtures/ trees
# excluded), .touchstone/checker/{pre-commit,pre-push,standalone,baselines}/*,
# plugin-map.entries, waivers.yaml, plus any docs/** file a node names (docs
# nodes are leaves: they are never scanned for outbound edges).
#
# Edge set — extracted by naming: A → B when A's body (frontmatter excluded)
# contains B's repo-relative path, B's basename when that basename is unique
# among nodes, or the token `touchstone:<name>` resolving to a skill or an
# agent. Frontmatter `injected-by:` / `referenced-by:` on a fragment, and a
# `description:`'s `Callers —` clause, declare INBOUND edges; when the claimed
# consumer's own files never name the target, the claim is a false edge
# (`declared_only: true`, and an entry in false_edges).
#
# `stages[].lines` is the CONTEXT-LOADED line count: a fragment loaded by three
# skills in one stage costs three times, which is what the hand load map counts
# and what the ratchet must see. `stages[].unique_lines` is the same set counted
# once per file. Scripts, checkers, hooks and agents are in `load_set` (they are
# reached) but are not counted in `lines` — a script is run, not loaded into a
# context, and an agent runs in a context of its own.
set -uo pipefail

# --------------------------------------------------------------- self-test
# Runs this script over the committed fixture trees the checker rail already
# owns (no fixture of its own), so the map has an automated consumer instead of
# only the two checkers that read its JSON.
if [ "${1:-}" = "--self-test" ]; then
  command -v python3 >/dev/null 2>&1 || { printf 'plugin-map.sh: python3 not found\n' >&2; exit 1; }
  _self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  _repo="$(cd "$(dirname "$_self")/.." && pwd)"
  python3 - "$_self" "$_repo" <<'SELFTEST_EOF'
import json, os, shutil, subprocess, sys, tempfile

self_path, repo = sys.argv[1], sys.argv[2]
FX = os.path.join(repo, '.touchstone/checker/fixtures')
GRAPH = os.path.join(FX, 'plugin-graph')
fails = 0

def report(ok, label, detail=''):
    global fails
    print('%s %s%s' % ('PASS' if ok else 'FAIL', label, '' if ok else ' — ' + detail))
    if not ok:
        fails += 1

def run(root):
    return subprocess.run(['bash', self_path, '--root', root],
                          capture_output=True, text=True)

def mapped(root, label):
    r = run(root)
    if r.returncode != 0:
        report(False, label, 'rc=%d stderr=%s' % (r.returncode, r.stderr.strip()[:300]))
        return None
    try:
        return json.loads(r.stdout)
    except ValueError as exc:
        report(False, label, 'output is not JSON: %s' % exc)
        return None

# ---- graph fixtures
lbl = 'plugin-graph green: false_edges/orphans/test_only/stale/invalid all empty'
d = mapped(os.path.join(GRAPH, 'green'), lbl)
if d is not None:
    nonempty = [k for k in ('false_edges', 'orphans', 'test_only',
                            'stale_waivers', 'invalid_waivers') if d.get(k)]
    report(not nonempty, lbl, 'non-empty: %s' % nonempty)

lbl = 'plugin-graph red-false-edge: one false edge on skills/_shared/inject/frag.md claimed by skills/other/SKILL.md'
d = mapped(os.path.join(GRAPH, 'red-false-edge'), lbl)
if d is not None:
    fe = d.get('false_edges') or []
    ok = (len(fe) == 1 and fe[0].get('target') == 'skills/_shared/inject/frag.md'
          and fe[0].get('claimed_by') == 'skills/other/SKILL.md')
    report(ok, lbl, repr(fe))

for sub, key, want in (('red-orphan', 'orphans', ['scripts/lonely.sh']),
                       ('red-stale-waiver', 'stale_waivers', ['scripts/lonely.sh'])):
    lbl = 'plugin-graph %s: %s == %s' % (sub, key, want)
    d = mapped(os.path.join(GRAPH, sub), lbl)
    if d is not None:
        report(d.get(key) == want, lbl, repr(d.get(key)))

lbl = 'plugin-graph green-waived-orphan: the waived node is in neither orphans nor test_only, no stale/invalid waiver'
d = mapped(os.path.join(GRAPH, 'green-waived-orphan'), lbl)
if d is not None:
    ok = (not d.get('orphans') and not d.get('test_only') and not d.get('stale_waivers')
          and not d.get('invalid_waivers') and 'scripts/lonely.sh' in {n['id'] for n in (d.get('nodes') or [])})
    report(ok, lbl, 'orphans=%r test_only=%r stale=%r invalid=%r' % (d.get('orphans'), d.get('test_only'), d.get('stale_waivers'), d.get('invalid_waivers')))

lbl = 'plugin-graph red-invalid-waiver: invalid_waivers non-empty'
d = mapped(os.path.join(GRAPH, 'red-invalid-waiver'), lbl)
if d is not None:
    report(bool(d.get('invalid_waivers')), lbl, repr(d.get('invalid_waivers')))

lbl = 'plugin-graph red-bare-waiver: a waiver without reason/reviewed is invalid, the note names both fields'
d = mapped(os.path.join(GRAPH, 'red-bare-waiver'), lbl)
if d is not None:
    note = ' '.join(d.get('notes') or [])
    ok = (d.get('invalid_waivers') == ['scripts/lonely.sh']
          and 'reason' in note and 'reviewed' in note)
    report(ok, lbl, '%r / %r' % (d.get('invalid_waivers'), d.get('notes')))

# ---- ratchet fixture: the numbers the pre-push ratchet reads
lbl = 'plugin-ratchets green: stage 1 lines == 10 and both metrics keys present'
d = mapped(os.path.join(FX, 'plugin-ratchets/green'), lbl)
if d is not None:
    st = {s['stage']: s for s in (d.get('stages') or [])}
    m = d.get('metrics') or {}
    ok = (st.get(1, {}).get('lines') == 10
          and 'max_stage_load_lines' in m
          and 'untested_reachable_shell_lines' in m
          and 'untested_reachable_shell_files' in m)
    report(ok, lbl, 'stages=%r metrics=%r' % (
        [(s['stage'], s['lines']) for s in (d.get('stages') or [])], sorted(m)))
    # the identity clause `unique_lines == sum of the load set's line counts once per file`
    # (deviation D-12 rests on this field carrying it)
    lines_of = {n['id']: n['lines'] for n in (d.get('nodes') or [])}
    lbl = 'plugin-ratchets green: every stage unique_lines == sum of unique load-set file lines'
    bad = [(s['stage'], s.get('unique_lines'), sum(lines_of.get(p, 0) for p in set(s.get('load_set') or [])
                                                    if p in lines_of and not p.endswith(('.sh', '.json'))
                                                    and not p.startswith(('agents/', 'hooks/'))))
           for s in (d.get('stages') or [])]
    report(all(u == t for _, u, t in bad), lbl, repr(bad))

# ---- entries-file contract: violations exit 1 and name the offending path
scratch = tempfile.mkdtemp(prefix='plugin-map-selftest.')
try:
    ent = '.touchstone/checker/plugin-map.entries'

    def scratch_copy(name):
        dst = os.path.join(scratch, name)
        shutil.copytree(os.path.join(GRAPH, 'green'), dst)
        return dst

    tree = scratch_copy('missing-entry')
    p = os.path.join(tree, ent)
    kept = [l for l in open(p, encoding='utf-8').read().splitlines()
            if l.strip() != 'skills/demo/SKILL.md']
    open(p, 'w', encoding='utf-8').write('\n'.join(kept) + '\n')
    r = run(tree)
    lbl = 'entries contract: a required SKILL.md missing from the entries file exits 1 naming it'
    report(r.returncode == 1 and 'skills/demo/SKILL.md' in r.stderr, lbl,
           'rc=%d stderr=%s' % (r.returncode, r.stderr.strip()[:300]))

    tree = scratch_copy('absolute-entry')
    p = os.path.join(tree, ent)
    with open(p, 'a', encoding='utf-8') as fh:
        fh.write('/etc/hosts\n')
    r = run(tree)
    lbl = 'entries contract: an absolute path in the entries file exits 1 naming it'
    report(r.returncode == 1 and '/etc/hosts' in r.stderr, lbl,
           'rc=%d stderr=%s' % (r.returncode, r.stderr.strip()[:300]))
finally:
    shutil.rmtree(scratch, ignore_errors=True)

sys.exit(1 if fails else 0)
SELFTEST_EOF
  exit $?
fi

root=""; mode="json"; skill_arg=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)    [ $# -ge 2 ] || { printf 'plugin-map.sh: --root needs a directory\n' >&2; exit 2; }
               root="$2"; shift 2 ;;
    --skill)   [ $# -ge 2 ] || { printf 'plugin-map.sh: --skill needs a skill name\n' >&2; exit 2; }
               mode="skill"; skill_arg="$2"; shift 2 ;;
    --mermaid) mode="mermaid"; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *)         printf 'plugin-map.sh: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] || { printf 'plugin-map.sh: not inside a git repo — pass --root <dir>\n' >&2; exit 1; }
fi
[ -d "$root" ] || { printf 'plugin-map.sh: no such directory: %s\n' "$root" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf 'plugin-map.sh: python3 not found\n' >&2; exit 1; }

python3 - "$root" "$mode" "$skill_arg" <<'PYTHON_EOF'
import json, os, re, sys

root, mode, skill_arg = sys.argv[1], sys.argv[2], sys.argv[3]
root = os.path.abspath(root)

def rp(p):            # repo-relative
    return os.path.relpath(p, root)

def read(path):
    try:
        with open(os.path.join(root, path), 'r', encoding='utf-8', errors='replace') as f:
            return f.read()
    except (OSError, UnicodeError):
        return None

# ---------------------------------------------------------------- node set
SCAN_ROOTS = ['skills', 'agents', 'hooks', 'scripts']
CHECKER_DIRS = ['.touchstone/checker/pre-commit', '.touchstone/checker/pre-push',
                '.touchstone/checker/standalone', '.touchstone/checker/baselines']
CHECKER_FILES = ['.touchstone/checker/plugin-map.entries', '.touchstone/checker/waivers.yaml']
SKIP_NAMES = {'.DS_Store', '.gitkeep'}

paths = set()
for r in SCAN_ROOTS:
    base = os.path.join(root, r)
    if not os.path.isdir(base):
        continue
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(d for d in dirnames if d not in ('fixtures', '.git'))
        for fn in sorted(filenames):
            if fn in SKIP_NAMES:
                continue
            paths.add(rp(os.path.join(dirpath, fn)))
for d in CHECKER_DIRS:
    base = os.path.join(root, d)
    if os.path.isdir(base):
        for fn in sorted(os.listdir(base)):
            if fn not in SKIP_NAMES and os.path.isfile(os.path.join(base, fn)):
                paths.add(os.path.join(d, fn))
for f in CHECKER_FILES:
    if os.path.isfile(os.path.join(root, f)):
        paths.add(f)

def kind_of(p):
    b = os.path.basename(p)
    if p.startswith('skills/') and b == 'SKILL.md':                     return 'skill'
    if p.startswith('skills/_shared/schemas/'):                         return 'schema'
    if p.startswith('agents/'):                                         return 'agent'
    if p.startswith('hooks/'):                                          return 'hook'
    if re.match(r'^\.touchstone/checker/[^/]+/check-[^/]+\.sh$', p):    return 'checker'
    if p.endswith('.sh'):                                               return 'script'
    if p.startswith('docs/'):                                           return 'reference'
    if p.startswith('skills/_shared/'):                                 return 'fragment'
    if re.match(r'^skills/[^/]+/(references|templates)/', p):           return 'fragment'
    if re.match(r'^skills/[^/]+/[^/]+\.md$', p):                        return 'fragment'
    return 'doc'

LOADED_KINDS = {'skill', 'fragment', 'schema', 'reference', 'doc'}

def line_count(p):
    t = read(p)
    if t is None:
        return 0
    return t.count('\n') + (1 if t and not t.endswith('\n') else 0)

def byte_count(p):
    try:
        return os.path.getsize(os.path.join(root, p))
    except OSError:
        return 0

# ------------------------------------------------- body / frontmatter split
def body_lines(p):
    """[(lineno, text)] with .md frontmatter removed."""
    t = read(p)
    if t is None:
        return []
    ls = t.splitlines()
    start = 0
    if p.endswith('.md') and ls and ls[0].strip() == '---':
        for i in range(1, len(ls)):
            if ls[i].strip() == '---':
                start = i + 1
                break
    return [(i + 1, ls[i]) for i in range(start, len(ls))]

def frontmatter_lines(p):
    t = read(p)
    if t is None or not p.endswith('.md'):
        return []
    ls = t.splitlines()
    if not ls or ls[0].strip() != '---':
        return []
    out = []
    for i in range(1, len(ls)):
        if ls[i].strip() == '---':
            break
        out.append((i + 1, ls[i]))
    return out

# docs/** become nodes only when a scanned node names them; find those first.
scanned = sorted(paths)
docs_named = set()
docs_all = []
docs_base = os.path.join(root, 'docs')
if os.path.isdir(docs_base):
    for dirpath, dirnames, filenames in os.walk(docs_base):
        dirnames[:] = sorted(dirnames)
        for fn in sorted(filenames):
            docs_all.append(rp(os.path.join(dirpath, fn)))
docs_bn = {}
for d in docs_all:
    docs_bn.setdefault(os.path.basename(d), []).append(d)
for p in scanned:
    for _, line in body_lines(p):
        for d in docs_all:
            if d in line:
                docs_named.add(d)
        for bn, lst in docs_bn.items():
            if len(lst) == 1 and bn != 'README.md' and re.search(
                    r'(?<![A-Za-z0-9_-])%s(?![A-Za-z0-9_-])' % re.escape(bn), line):
                docs_named.add(lst[0])
if os.path.isfile(os.path.join(root, 'docs/adr/template.md')):
    docs_named.add('docs/adr/template.md')

nodes = sorted(paths | docs_named)
nodeset = set(nodes)
kinds = {p: kind_of(p) for p in nodes}
lines = {p: line_count(p) for p in nodes}
bytes_ = {p: byte_count(p) for p in nodes}

bn_index = {}
for p in nodes:
    bn_index.setdefault(os.path.basename(p), []).append(p)
# a basename names its node only as a whole token — `authoring.md` inside
# `adr-authoring.md` is a different file, not a reference to it
unique_bn = {b: (l[0], re.compile(r'(?<![A-Za-z0-9_-])%s(?![A-Za-z0-9_-])' % re.escape(b)))
             for b, l in bn_index.items() if len(l) == 1}

skill_of = {}   # skill name -> SKILL.md path
for p in nodes:
    m = re.match(r'^skills/([^/]+)/SKILL\.md$', p)
    if m:
        skill_of[m.group(1)] = p
agent_of = {}
for p in nodes:
    m = re.match(r'^agents/([^/]+)\.md$', p)
    if m:
        agent_of[m.group(1)] = p

def skill_unit(name):
    """Every node under skills/<name>/ — a skill's body is its whole directory."""
    pre = 'skills/%s/' % name
    return [p for p in nodes if p.startswith(pre)]

# ---------------------------------------------------------------- edges
edges = {}          # (from, to) -> dict
notes = []

# The verb decides the kind, and only as a whole word — `rewrites` is not a
# write, `download` is not a load.
LOAD_RE = re.compile(r'(?<![A-Za-z])(inject|load|prepend)', re.I)
WRITE_RE = re.compile(r'(?<![A-Za-z])writ(e|es|ing|ten)', re.I)

READ_VERB_RE = re.compile(r'\b(read|reads|reading|consult|consults|follow|follows)\b', re.I)

def edge_kind(target, line):
    if kinds[target] == 'agent':                     return 'dispatches'
    if target.endswith('.sh'):                       return 'runs'
    if LOAD_RE.search(line):                         return 'loads'
    # a line that both reads and writes ("Read templates/x.md and write <out>") names an
    # existing node as its INPUT — the written thing is the output placeholder, never the
    # node. A read verb on the line therefore wins over a write verb (plugin-review probe
    # 2026-08-30: epic-index.md dropped out of stage 0's load set on exactly this shape).
    if READ_VERB_RE.search(line):                    return 'reads'
    # a prose node (skill, fragment, reference, schema, doc) is never an OUTPUT of another node:
    # a write verb beside it means "written against / per this contract" — a read. `writes`
    # survives only for non-prose targets.
    if WRITE_RE.search(line) and kinds[target] not in LOADED_KINDS: return 'writes'
    return 'reads'

def add_edge(src, dst, kind, at, declared_only=False):
    if src == dst or dst not in nodeset or src not in nodeset:
        return
    key = (src, dst)
    if key in edges:
        if edges[key]['declared_only'] and not declared_only:
            edges[key].update(kind=kind, at=at, declared_only=False)
        return
    edges[key] = {'from': src, 'to': dst, 'kind': kind, 'at': at,
                  'declared_only': declared_only}

TOKEN_RE = re.compile(r'/?touchstone:([A-Za-z0-9][A-Za-z0-9_-]*)')

# Leaves — never scanned for outbound edges: docs/** (reference material), the
# two data files plugin-map itself reads (a path listed in the entry set or the
# waiver ledger is data, never a caller), and the schemas (a schema is a format
# contract naming no consumer; its header's `Keywords as in <sibling>.yaml` is a
# terminology citation, not a load — the hand dependency map lists all three
# schemas among the nodes that point to nothing).
scannable = [p for p in nodes
             if not p.startswith('docs/') and p not in CHECKER_FILES
             and kinds[p] != 'schema']
for src in scannable:
    for lineno, line in body_lines(src):
        at = '%s:%d' % (src, lineno)
        for dst in nodes:
            if dst != src and dst in line:
                add_edge(src, dst, edge_kind(dst, line), at)
        for bn, (dst, rx) in unique_bn.items():
            if dst != src and rx.search(line):
                add_edge(src, dst, edge_kind(dst, line), at)
        for m in TOKEN_RE.finditer(line):
            name = m.group(1)
            if name in agent_of:
                add_edge(src, agent_of[name], 'dispatches', at)
            elif name in skill_of:
                add_edge(src, skill_of[name], 'invokes', at)
        if 'Agent(' in line:
            for name, dst in agent_of.items():
                if name in line:
                    add_edge(src, dst, 'dispatches', at)

# the hook's stage glob — two edges the text cannot name file by file
hook = 'hooks/run-project-checks.sh'
if hook in nodeset:
    glob_at = '%s:1' % hook
    for lineno, line in body_lines(hook):
        if re.search(r'for\s+\w+\s+in\s+.*check-\*\.sh', line):
            glob_at = '%s:%d' % (hook, lineno)
            break
    for p in nodes:
        if re.match(r'^\.touchstone/checker/(pre-commit|pre-push)/check-.*\.sh$', p):
            add_edge(hook, p, 'runs', glob_at)
if 'hooks/hooks.json' in nodeset and hook in nodeset:
    add_edge('hooks/hooks.json', hook, 'runs', 'hooks/hooks.json:1')

# ------------------------------------------- declared (frontmatter) edges
false_edges = []

def resolve_claimant(raw):
    v = raw.strip().strip('`"\'')
    if not v:
        return None
    if v in skill_of:
        return skill_of[v], skill_unit(v)
    if v in nodeset:
        return v, [v]
    if v in unique_bn:
        return unique_bn[v][0], [unique_bn[v][0]]
    if v + '.md' in unique_bn:
        return unique_bn[v + '.md'][0], [unique_bn[v + '.md'][0]]
    return None

def names_target(files, target):
    tb = os.path.basename(target)
    tb_rx = unique_bn[tb][1] if unique_bn.get(tb, (None,))[0] == target else None
    for f in files:
        if f == target:
            continue
        for _, line in body_lines(f):
            if target in line:
                return True
            if tb_rx is not None and tb_rx.search(line):
                return True
            for m in TOKEN_RE.finditer(line):
                nm = m.group(1)
                if skill_of.get(nm) == target or agent_of.get(nm) == target:
                    return True
    return False

for tgt in nodes:
    for lineno, line in frontmatter_lines(tgt):
        claims = []
        m = re.match(r'^\s*(injected-by|referenced-by)\s*:\s*\[(.*)\]\s*$', line)
        if m:
            ekind0 = 'loads' if m.group(1) == 'injected-by' else 'reads'
            claims = [(c, ekind0) for c in m.group(2).split(',')]
        elif re.match(r'^\s*description\s*:', line) and re.search(r'Callers\s*[—-]', line):
            tail = re.split(r'Callers\s*[—-]', line, maxsplit=1)[1]
            claims = [(m2.group(1), 'invokes') for m2 in TOKEN_RE.finditer(tail)]
        for raw, ekind in claims:
            r = resolve_claimant(raw)
            if r is None:
                notes.append('unresolved declared consumer %r at %s:%d — ignored, not a false edge'
                             % (raw.strip(), tgt, lineno))
                continue
            src, unit = r
            if src == tgt:
                continue
            if names_target(unit, tgt):
                continue                       # claim honoured by the unit's body
            claim_at = '%s:%d' % (tgt, lineno)
            add_edge(src, tgt, ekind, claim_at, declared_only=True)
            false_edges.append({'claim_at': claim_at, 'claimed_by': src, 'target': tgt})

false_edges.sort(key=lambda e: (e['target'], e['claimed_by'], e['claim_at']))

# ---------------------------------------------------------------- entries
ENTRIES_FILE = '.touchstone/checker/plugin-map.entries'
WAIVERS_FILE = '.touchstone/checker/waivers.yaml'

entries, problems = [], []
etext = read(ENTRIES_FILE)
if etext is None:
    # A tree with no entry set is a plugin this repo does not govern (a consumer
    # project): derive the entries from the tree instead of failing.
    entries = sorted(skill_of.values())
    for extra in ('hooks/hooks.json', 'scripts/tests-smoke/run-smoke.sh'):
        if extra in nodeset:
            entries.append(extra)
    notes.append('%s absent — entry set derived from the tree' % ENTRIES_FILE)
else:
    for raw in etext.splitlines():
        p = raw.split('#', 1)[0].strip()
        if not p:
            continue
        entries.append(p)
        # repo-relative only: an absolute path or one that escapes root is a contract violation
        # even when it exists on disk
        if os.path.isabs(p) or os.path.normpath(p).startswith('..') or os.path.normpath(p) != p.rstrip('/'):
            problems.append('entries file path is not a normalized repo-relative path: %s' % p)
        elif not os.path.exists(os.path.join(root, p)):
            problems.append('entries file lists a path that does not exist: %s' % p)
    required = sorted(skill_of.values())
    for extra in ('hooks/hooks.json', 'scripts/tests-smoke/run-smoke.sh'):
        if extra in nodeset:
            required.append(extra)
    for r in required:
        if r not in entries:
            problems.append('required entry missing from %s: %s' % (ENTRIES_FILE, r))
entries = sorted(set(entries))

# ---------------------------------------------------------------- waivers
# A waiver states WHY the node has no in-edge and WHEN that was last reviewed;
# an entry missing either field is an unreviewable licence and counts invalid.
WAIVER_FIELDS = ('reason', 'reviewed')
waivers, bad_field_waivers = [], []
wtext = read(WAIVERS_FILE)
if wtext is not None:
    try:
        import yaml
        loaded = yaml.safe_load(wtext) or []
        if isinstance(loaded, list):
            for item in loaded:
                if isinstance(item, dict) and item.get('node'):
                    node = str(item['node'])
                    waivers.append(node)
                    missing = [f for f in WAIVER_FIELDS if not item.get(f)]
                    if missing:
                        bad_field_waivers.append((node, missing))
        else:
            notes.append('%s does not parse to a list — ignored' % WAIVERS_FILE)
    except ImportError:
        for line in wtext.splitlines():
            m = re.search(r'node\s*:\s*([^,}\s]+)', line)
            if m:
                node = m.group(1).strip().strip('"\'')
                waivers.append(node)
                missing = [f for f in WAIVER_FIELDS
                           if not re.search(r'\b%s\s*:\s*\S' % f, line)]
                if missing:
                    bad_field_waivers.append((node, missing))
        notes.append('PyYAML absent — waivers read with a line matcher')
for node, missing in bad_field_waivers:
    notes.append('waiver for %s in %s is missing required field(s): %s'
                 % (node, WAIVERS_FILE, ', '.join(missing)))
waivers = sorted(set(waivers))

# ------------------------------------------------------------ reachability
REAL = [e for e in edges.values() if not e['declared_only']]
adj = {}
for e in REAL:
    adj.setdefault(e['from'], []).append(e['to'])

def reach(seeds):
    seen, stack = set(), [s for s in seeds if s in nodeset]
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        stack.extend(adj.get(n, ()))
    return seen

SMOKE = 'scripts/tests-smoke/run-smoke.sh'
roots_all = set(entries) | set(waivers)
reach_all = reach(roots_all)
reach_nontest = reach(roots_all - {SMOKE})

orphans = sorted(p for p in nodes if p not in reach_all and p not in waivers)
test_only = sorted(p for p in nodes
                   if p in reach_all and p not in reach_nontest
                   and p != SMOKE and p not in waivers)

# A waiver is stale when a real in-edge comes from a node reachable WITHOUT the
# waived node itself as a root — a node reachable only through the waived node
# (its own dependent naming it back) cannot make the waiver stale.
stale_waivers = sorted({w for w in waivers
                        for e in REAL
                        if e['to'] == w and e['from'] != SMOKE
                        and e['from'] in reach(roots_all - {SMOKE, w})})
false_targets = {e['target'] for e in false_edges}
invalid_waivers = sorted({w for w in waivers if w in false_targets}
                         | {n for n, _ in bad_field_waivers})

# ------------------------------------------------------------ load closure
CLOSURE_KINDS = {'invokes', 'loads', 'reads', 'runs', 'dispatches'}
cadj = {}
for e in REAL:
    if e['kind'] in CLOSURE_KINDS:
        cadj.setdefault(e['from'], []).append(e['to'])
for k in cadj:
    cadj[k] = sorted(set(cadj[k]))

# The context-load walk stops at anything that is not itself loaded into the
# context: a script runs in a subprocess and an agent runs in a context of its
# own, so what THEY read is not on this stage's context bill.
cadj_load = {k: v for k, v in cadj.items() if kinds.get(k) in LOADED_KINDS}

def closure(seed, blocked=frozenset(), adjacency=None):
    a = cadj if adjacency is None else adjacency
    seen, stack = set(), [seed]
    while stack:
        n = stack.pop()
        if n in seen or n in blocked:
            continue
        seen.add(n)
        stack.extend(a.get(n, ()))
    return seen

STAGES = [
    (0, 'skills/epic-driven-roadmap/SKILL.md'),
    (1, 'skills/crucible/SKILL.md'),
    (2, 'skills/anvil/SKILL.md'),
    (3, 'skills/deliverable-review/SKILL.md'),
    (4, 'skills/epic-driven-roadmap/references/phase-ship.md'),
    (5, 'skills/epic-driven-roadmap/references/close.md'),
]
stage_entries = [e for _, e in STAGES if e in nodeset]
skill_stage_entries = {e for e in stage_entries if kinds.get(e) == 'skill'}

stages = []
for num, entry in STAGES:
    if entry not in nodeset:
        continue
    blocked = set(stage_entries) - {entry}       # a stage stops at every other stage's entry, skill or fragment
    lset = closure(entry, blocked)
    # contexts = the entry plus every skill it invokes (transitively) inside the stage
    contexts, stack, seen_ctx = [entry], [entry], {entry}
    while stack:
        n = stack.pop()
        for e in REAL:
            if (e['from'] == n and e['kind'] == 'invokes' and e['to'] in lset
                    and e['to'] not in seen_ctx and kinds.get(e['to']) == 'skill'):
                seen_ctx.add(e['to'])
                contexts.append(e['to'])
                stack.append(e['to'])
    loaded_total, per_ctx, uniq = 0, [], set()
    for c in sorted(contexts):
        cset = closure(c, (blocked | seen_ctx) - {c}, cadj_load)
        files = sorted(p for p in cset if kinds[p] in LOADED_KINDS)
        n_lines = sum(lines[p] for p in files)
        loaded_total += n_lines
        uniq.update(files)
        per_ctx.append({'context': c, 'lines': n_lines, 'files': files})
    stages.append({
        'stage': num,
        'entry': entry,
        'load_set': sorted(lset),
        'lines': loaded_total,
        'unique_lines': sum(lines[p] for p in uniq),
        'contexts': per_ctx,
    })

# --------------------------------------------------------- per-skill totals
skills_out = []
for name in sorted(skill_of):
    s = closure(skill_of[name])
    skills_out.append({'id': name,
                       'lines': sum(lines[p] for p in s),
                       'bytes': sum(bytes_[p] for p in s),
                       'files': len(s)})

# ---------------------------------------------------------------- metrics
smoke_text = read(SMOKE) or ''
fixture_dirs = set()
fx = os.path.join(root, '.touchstone/checker/fixtures')
if os.path.isdir(fx):
    fixture_dirs = {d for d in os.listdir(fx) if os.path.isdir(os.path.join(fx, d))}

def is_tested(p):
    """Named by the smoke runner, run by its fixture rail loop (a check-<name>.sh with a
    fixtures/<name>/ tree), or run by its --self-test loop (a script declaring --self-test
    while the runner carries that loop) — the same three consumers check-fixture-consumers
    enforces."""
    b = os.path.basename(p)
    # token-bounded: `map.sh` inside `plugin-map.sh`, or `run.sh` inside `foo-run.sh`, is not a mention
    def named(needle):
        return re.search(r'(?<![\w-])' + re.escape(needle) + r'(?![\w-])', smoke_text) is not None
    if named(p) or named(b):
        return True
    m = re.match(r'^check-(.*)\.sh$', b)
    if m and m.group(1) in fixture_dirs:
        return True
    if '--self-test' in smoke_text:
        try:
            return '--self-test' in open(os.path.join(root, p), encoding='utf-8', errors='replace').read()
        except OSError:
            return False
    return False

reachable_live = [p for p in nodes
                  if p in reach_all and p not in orphans and p not in test_only]
untested = sorted(p for p in reachable_live if p.endswith('.sh') and not is_tested(p))
metrics = {
    'max_stage_load_lines': max((s['lines'] for s in stages), default=0),
    'untested_reachable_shell_lines': sum(lines[p] for p in untested),
    'untested_reachable_shell_files': untested,
}

# ---------------------------------------------------------------- output
if problems:
    for p in problems:
        sys.stderr.write('plugin-map.sh: %s\n' % p)
    sys.exit(1)

if mode == 'skill':
    if skill_arg not in skill_of:
        sys.stderr.write('plugin-map.sh: no such skill: %s\n' % skill_arg)
        sys.exit(1)
    s = sorted(closure(skill_of[skill_arg]))
    for p in s:
        sys.stdout.write('%d\t%d\t%s\n' % (lines[p], bytes_[p], p))
    sys.stdout.write('total\t%d lines\t%d bytes\t%d files\n'
                     % (sum(lines[p] for p in s), sum(bytes_[p] for p in s), len(s)))
    sys.exit(0)

if mode == 'mermaid':
    ids = {p: re.sub(r'[^A-Za-z0-9]', '_', p) for p in stage_entries}
    out = ['flowchart LR']
    for num, entry in STAGES:
        if entry in ids:
            out.append('  %s["%d · %s"]' % (ids[entry], num, entry))
    seen = set()
    for e in sorted(REAL, key=lambda x: (x['from'], x['to'])):
        if e['kind'] == 'invokes' and e['from'] in ids and e['to'] in ids:
            k = (e['from'], e['to'])
            if k not in seen:
                seen.add(k)
                out.append('  %s --> %s' % (ids[e['from']], ids[e['to']]))
    sys.stdout.write('\n'.join(out) + '\n')
    sys.exit(0)

doc = {
    'nodes': [{'id': p, 'kind': kinds[p], 'path': p, 'lines': lines[p]} for p in nodes],
    'edges': sorted(edges.values(), key=lambda e: (e['from'], e['to'], e['at'])),
    'entries': entries,
    'stages': stages,
    'false_edges': false_edges,
    'orphans': orphans,
    'test_only': test_only,
    'skills': skills_out,
    'metrics': metrics,
    'stale_waivers': stale_waivers,
    'invalid_waivers': invalid_waivers,
    'notes': sorted(set(notes)),
}
sys.stdout.write(json.dumps(doc, indent=2, sort_keys=False, ensure_ascii=False) + '\n')
PYTHON_EOF
