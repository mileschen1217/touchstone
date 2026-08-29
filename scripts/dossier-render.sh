#!/usr/bin/env bash
# scripts/dossier-render.sh — Generate <epic-dir>/dossier.html from an epic dir's
# YAML artifacts (spec.yaml / review.yaml / deviation.yaml) and, on the legacy path,
# its markdown/html sources. The dossier is a VIEW, never a home: regenerate it
# (phase-ship, epic close), never hand-edit it. Output is deterministic (no
# timestamps, no random ids) so re-runs on unchanged sources are byte-identical.
# Every visible sentence is a field value or a source line; the renderer authors
# only labels and placeholders.
#
# Usage: dossier-render.sh [--root <dir>] [--pr-body] <epic-dir>
#   exit 0 → <epic-dir>/dossier.html written (+ <epic-dir>/pr-body.md with --pr-body:
#            the newest YAML phase's Ship tab as text, sections in the tab's order)
#   exit 1 → path missing / not a dir / no index.md / dir not writable / PyYAML absent
#            while a .yaml artifact is present / a .yaml artifact that does not parse to a
#            mapping / --pr-body with no YAML phase (nothing written) — cause on stderr
#
# YAML path (a phase whose spec is *.spec.yaml; schemas: skills/_shared/schemas/):
#   契約  = title / stories / requirements+ACs / invariants / delta blocks / contracts /
#           non-goals / risks, ids anchored `<stem>--<id>`; basis ids link to the ledger
#           line (`ledger--<id>`, the assay record's `- <id>` / `| <id>` lines)
#   Map   = the four phase_map panels, D-n entries overlaid on their panel, legacy
#           deviation lines under their own heading
#   Build = every review.yaml: verdict line + findings table; raw records collapsed
#   Ship  = header · four panels+D-n · structure overlay (delta blocks/edges, or an
#           inlined structure-overlay.html) · evidence+invariant table · review
#           verdicts · quiz (or its waiver) · waiting on human · closing message
#
# Input-resolution contract (single home — the spec restates it only as the
# contract under test):
#   project root   = --root when given; else nearest ancestor of <epic-dir>
#                    containing a `.touchstone/` dir; none → gate-miss + ADR
#                    lookups skipped, noted in the page. Input set = epic dir +
#                    <root>/.touchstone/gate-miss.md + cited ADR files under
#                    <root>/docs/adr and <root>/.touchstone/docs/adr.
#   stage tabs     = 位置 (index.md minus close sections; waiting list = spec status, open
#                    questions, unshipped phases, YAML waiting_on_human — legacy deviation
#                    lines stay on the Map tab) · 契約 (assay-*.md,
#                    *-design.md, frontmatter type: spec|adr, cited project-root
#                    ADRs, and any file matching no pattern) · Map (each spec's
#                    `## Phase map` or a visible placeholder, + index `## Deviation
#                    log`) · Build (*review*/review.md, evidence.md, deviation*.md,
#                    task-*.md, *plan*.md) · Ship (*explainer*, *quiz*, *buyin*;
#                    .html inlined by <body> inner HTML, never iframed) · Close
#                    (index Retrospective / Evidence Reckoning / Disposition +
#                    gate-miss.md lines containing the slug).
#   phase grouping = a spec defines a phase; slug = stem minus leading YYYY-MM-DD-
#                    and trailing -design. A file joins the phase whose slug its
#                    name contains; else the phase whose date it contains when
#                    exactly one spec carries that date; else the "epic" group.
#   code links     = whole tokens AC-N / REQ-N / US-N / ADR-N (suffixed forms are
#                    their own token) link to `<spec-stem>--<CODE>` (ADR: `adr--<N>`,
#                    leading zeros stripped); undefined → <span class="undef">;
#                    tokens inside code spans / fences / their own defining heading
#                    are untouched; same code in several specs → the current
#                    phase's spec wins, else the first with a title listing the rest.
set -uo pipefail

root_override=""; pr_body=0
while [ $# -gt 1 ]; do
  case "$1" in
    --root)
      [ -n "${2:-}" ] || { printf 'dossier-render.sh: --root needs a directory\n' >&2; exit 1; }
      [ -d "$2" ] || { printf 'dossier-render.sh: --root is not a directory: %s\n' "$2" >&2; exit 1; }
      root_override="$2"; shift 2 ;;
    --pr-body) pr_body=1; shift ;;
    *) printf 'usage: dossier-render.sh [--root <dir>] [--pr-body] <epic-dir>\n' >&2; exit 1 ;;
  esac
done
[ $# -eq 1 ] || { printf 'usage: dossier-render.sh [--root <dir>] [--pr-body] <epic-dir>\n' >&2; exit 1; }
epic_dir="$1"
[ -e "$epic_dir" ] || { printf 'dossier-render.sh: path does not exist: %s\n' "$epic_dir" >&2; exit 1; }
[ -d "$epic_dir" ] || { printf 'dossier-render.sh: not a directory: %s\n' "$epic_dir" >&2; exit 1; }
[ -f "$epic_dir/index.md" ] || { printf 'dossier-render.sh: no index.md in %s\n' "$epic_dir" >&2; exit 1; }
[ -w "$epic_dir" ] || { printf 'dossier-render.sh: directory not writable: %s\n' "$epic_dir" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf 'dossier-render.sh: python3 not found\n' >&2; exit 1; }
if find "$epic_dir" -name '*.yaml' | grep -q . && ! python3 -c 'import yaml' 2>/dev/null; then
  printf 'dossier-render.sh: PyYAML not installed and %s holds .yaml artifacts — run: python3 -m pip install pyyaml\n' "$epic_dir" >&2; exit 1
fi

python3 - "$epic_dir" "$root_override" "$pr_body" <<'PYTHON_EOF'
import sys, os, re, html, glob
try:
    import yaml
except ImportError:
    yaml = None

epic_dir = os.path.abspath(sys.argv[1])
root_override = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None
want_pr_body = sys.argv[3] == '1'
TABS = ['首頁', '契約', '結構變化', '紀錄']
CLOSE_SECTIONS = {'Retrospective', 'Evidence Reckoning', 'Disposition'}
CODE_RE = re.compile(r'(?<![\w-])((?:AC|REQ|US|ADR|INV|D|F|QZ|Q|A|C|R|B)-\d+(?:[a-z]+|/\d+[a-z]*)*)(?![\w-])')
STRICT = ('AC-', 'REQ-', 'US-', 'ADR-')   # undefined → red marker; other families → plain text

# ---------- helpers ----------
def read(p):
    with open(p, encoding='utf-8') as fh:
        return fh.read()

def find_root(start):
    d = start
    while True:
        if os.path.isdir(os.path.join(d, '.touchstone')):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent

def frontmatter(text):
    m = re.match(r'^---\s*\n(.*?)\n---\s*\n?', text, re.DOTALL)
    fm = {}
    if m:
        for line in m.group(1).splitlines():
            if ':' in line:
                k, v = line.split(':', 1)
                fm[k.strip()] = v.split('#')[0].strip()
        return fm, text[m.end():]
    return fm, text

def sections(body):
    """Split markdown body into [(h2-title-or-'', text)] on `## ` headings (fence-aware)."""
    out, title, buf, fence = [], '', [], False
    for line in body.splitlines():
        if line.startswith('```'):
            fence = not fence
        if not fence and line.startswith('## '):
            out.append((title, '\n'.join(buf)))
            title, buf = line[3:].strip(), []
        else:
            buf.append(line)
    out.append((title, '\n'.join(buf)))
    return out

def first_h1(body):
    for line in body.splitlines():
        if line.startswith('# '):
            return line[2:].strip()
    return ''

def spec_slug(stem):
    s = re.sub(r'^\d{4}-\d{2}-\d{2}-', '', stem)
    return re.sub(r'(-design|\.spec)$', '', s)

def load_yaml(p):
    """A YAML artifact that does not parse to a mapping is fatal — never rendered as an empty phase."""
    try:
        d = yaml.safe_load(read(p))
    except Exception as e:
        print(f'dossier-render.sh: not parseable YAML: {os.path.relpath(p, epic_dir)} — {e}', file=sys.stderr); sys.exit(1)
    if not isinstance(d, dict):
        print(f'dossier-render.sh: YAML artifact is not a mapping: {os.path.relpath(p, epic_dir)}', file=sys.stderr); sys.exit(1)
    return d

def sval(v):
    """A YAML scalar as display text."""
    return '' if v is None else str(v).strip()

def spec_date(stem):
    m = re.match(r'^(\d{4}-\d{2}-\d{2})-', stem)
    return m.group(1) if m else ''

def adr_key(code):
    return 'adr--' + str(int(code.split('-', 1)[1]))

def attr(v):
    """Escape a value for use inside a double-quoted HTML attribute."""
    return html.escape(str(v), quote=True)

def slug_id(s):
    """Anchor-id-safe form of a file stem: [A-Za-z0-9._-] only."""
    return re.sub(r'[^A-Za-z0-9._-]', '-', s)

def stem_of(rel):
    return slug_id(os.path.splitext(os.path.basename(rel))[0])

def safe_url(u):
    """Reject scheme-bearing URLs other than http(s)/mailto and fragments/relative paths."""
    u = re.sub(r'[\t\r\n]', '', u).strip()
    if re.match(r'^(https?:|mailto:|#|/|\.|[A-Za-z0-9_])', u) and not re.match(r'^\s*(javascript|data|vbscript):', u, re.I):
        return u
    return '#'

# ---------- inlined-html sanitizer (allowlist) ----------
from html.parser import HTMLParser

ALLOWED_TAGS = {'h1','h2','h3','h4','h5','h6','p','div','span','ul','ol','li','table','thead','tbody','tr','th','td',
                'pre','code','strong','em','b','i','a','br','hr','blockquote','section','article','header','footer',
                'details','summary','dl','dt','dd','small','sup','sub','img'}
VOID_TAGS = {'br', 'hr', 'img'}
DROP_WITH_CONTENT = {'script', 'style', 'iframe', 'object', 'embed', 'noscript', 'template', 'svg', 'math'}
ALLOWED_ATTRS = {'class', 'id', 'title', 'colspan', 'rowspan', 'alt', 'open', 'href', 'src'}

class Sanitizer(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.out, self.drop_depth = [], 0
    def handle_starttag(self, tag, attrs):
        if self.drop_depth:
            if tag in DROP_WITH_CONTENT: self.drop_depth += 1
            return
        if tag in DROP_WITH_CONTENT:
            self.drop_depth = 1; return
        if tag not in ALLOWED_TAGS:
            return
        kept = []
        for k, v in attrs:
            k = k.lower()
            if k not in ALLOWED_ATTRS or k.startswith('on'):
                continue
            v = v or ''
            if k == 'href':
                v = safe_url(v)
            elif k == 'src':
                if tag != 'img' or not v.strip().lower().startswith('data:'):
                    continue  # no request-bearing src survives
            elif k == 'id':
                v = slug_id(v)
            kept.append(f' {k}="{attr(v)}"')
        self.out.append(f'<{tag}{"".join(kept)}>')
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
    def handle_endtag(self, tag):
        if self.drop_depth:
            if tag in DROP_WITH_CONTENT: self.drop_depth -= 1
            return
        if tag in ALLOWED_TAGS and tag not in VOID_TAGS:
            self.out.append(f'</{tag}>')
    def handle_data(self, data):
        if not self.drop_depth: self.out.append(html.escape(data, quote=False))
    def handle_entityref(self, name):
        if not self.drop_depth: self.out.append(f'&{name};')
    def handle_charref(self, name):
        if not self.drop_depth: self.out.append(f'&#{name};')
    def handle_comment(self, data): pass
    def handle_decl(self, decl): pass
    def handle_pi(self, data): pass

def sanitize_html(fragment):
    s = Sanitizer(); s.feed(fragment); s.close()
    return ''.join(s.out)

# ---------- inventory ----------
files = []
for dp, dns, fns in os.walk(epic_dir):
    dns.sort()
    for fn in sorted(fns):
        rel = os.path.relpath(os.path.join(dp, fn), epic_dir)
        if rel in ('dossier.html', 'pr-body.md') or not (fn.endswith('.md') or fn.endswith('.html') or fn.endswith('.yaml')):
            continue
        files.append(rel)

index_text = read(os.path.join(epic_dir, 'index.md'))
index_fm, index_body = frontmatter(index_text)
slug = index_fm.get('slug') or os.path.basename(epic_dir)
epic_title = first_h1(index_body) or slug
root = root_override or find_root(epic_dir)

def in_record_dir(rel):
    """A file inside a review / reverify / batch directory is process record, not reader content."""
    d = os.path.dirname(rel).replace(os.sep, '/').lower()
    return bool(d) and any(w in d for w in ('review', 'reverify', 'batch'))

def is_spec(rel):
    if rel == 'index.md' or in_record_dir(rel):
        return False
    base = os.path.basename(rel)
    if base.endswith('-design.md') or base.startswith('assay-') or base.endswith('.spec.yaml'):
        return True
    if base.endswith('.md'):
        fm, _ = frontmatter(read(os.path.join(epic_dir, rel)))
        return fm.get('type') in ('spec', 'adr')
    return False

# phases: from the index Phases table (order), each row's spec link defines a phase
phase_rows = []
for title, text in sections(index_body):
    if title == 'Phases':
        for line in text.splitlines():
            if not line.startswith('|'):
                continue
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if len(cells) < 3 or not cells[0].isdigit():
                continue
            m = re.search(r'\]\(([^)]+)\)', cells[2])
            phase_rows.append({'num': cells[0], 'title': cells[1], 'spec': m.group(1) if m else ''})

spec_files = [f for f in files if is_spec(f) and (f.endswith('.md') or f.endswith('.spec.yaml'))]
def is_yaml_spec(rel): return rel.endswith('.spec.yaml')
phases = []  # [{'key','title','spec','slug','date'}]
seen = set()
for row in phase_rows:
    sp = row['spec']
    if sp and sp in spec_files and sp not in seen:
        stem = stem_of(sp)
        phases.append({'key': stem, 'title': f"Phase {row['num']} — {row['title']}", 'spec': sp,
                       'slug': spec_slug(stem), 'date': spec_date(stem)})
        seen.add(sp)
for sp in spec_files:
    base = os.path.basename(sp)
    if sp in seen or base.startswith('assay-'):
        continue
    stem = os.path.splitext(base)[0]
    if is_yaml_spec(sp):
        yd = load_yaml(os.path.join(epic_dir, sp)) or {}
        phases.append({'key': stem_of(sp), 'title': sval(yd.get('title')) or stem, 'spec': sp, 'slug': spec_slug(stem), 'date': spec_date(stem)})
        seen.add(sp); continue
    phases.append({'key': stem, 'title': first_h1(frontmatter(read(os.path.join(epic_dir, sp)))[1]) or stem,
                   'spec': sp, 'slug': spec_slug(stem), 'date': spec_date(stem)})
    seen.add(sp)
EPIC = {'key': 'epic', 'title': 'Epic-level', 'spec': '', 'slug': '', 'date': ''}
date_count = {}
for p in phases:
    if p['date']:
        date_count[p['date']] = date_count.get(p['date'], 0) + 1

def phase_of(rel):
    name = rel.replace(os.sep, '/')
    for p in phases:
        if p['spec'] == rel:
            return p
    for p in phases:
        if p['slug'] and p['slug'] in name:
            return p
    for p in phases:
        if p['date'] and p['date'] in name and date_count.get(p['date']) == 1:
            return p
    return EPIC

def stage_of(rel):
    base = os.path.basename(rel).lower()
    if rel == 'index.md':
        return '位置'
    if rel in spec_files:
        return '契約'
    if base == 'structure-overlay.html':
        return 'overlay'  # linked from the Ship tab's structure overlay section
    if 'explainer' in base or 'quiz' in base or 'buyin' in base:
        return 'Ship'
    if base == 'review.yaml' and in_record_dir(rel):
        return 'Build'
    if base == 'deviation.yaml' and not in_record_dir(rel):
        return 'Build'
    if in_record_dir(rel) and base != 'review.md':
        return 'record'  # raw transcripts → Build tab, one collapsed "Review record" per dir
    if (base == 'review.md' and 'review' in rel.lower()) or base == 'evidence.md' \
       or base.startswith('deviation') or base.startswith('task-') or 'plan' in base:
        return 'Build'
    return '契約'  # unmatched → 契約 epic group, never dropped

# ---------- definitions (anchors) ----------
defs = {}  # code -> [(owner_key, anchor_id)]
def add_def(code, owner, anchor):
    defs.setdefault(code, []).append((owner, anchor))

LEDGER_RE = re.compile(r'^(?:- |\| )((?:Q|A|C|R|B)-\d+)\b')
for rel in files:
    if os.path.basename(rel).startswith('assay-') and rel.endswith('.md'):
        for line in read(os.path.join(epic_dir, rel)).splitlines():
            m = LEDGER_RE.match(line)
            if m and m.group(1) not in defs:
                add_def(m.group(1), 'ledger', f'ledger--{m.group(1)}')
for sp in spec_files:
    stem = stem_of(sp)
    if is_yaml_spec(sp):
        yd = load_yaml(os.path.join(epic_dir, sp)) or {}
        for us in yd.get('user_stories') or []:
            if isinstance(us, dict) and us.get('id'): add_def(str(us['id']), stem, f"{stem}--{us['id']}")
        for r in yd.get('requirements') or []:
            if isinstance(r, dict) and r.get('id'):
                add_def(str(r['id']), stem, f"{stem}--{r['id']}")
                for a in r.get('acs') or []:
                    if isinstance(a, dict) and a.get('id'): add_def(str(a['id']), stem, f"{stem}--{a['id']}")
        for iv in yd.get('invariants') or []:
            if isinstance(iv, dict) and iv.get('id'): add_def(str(iv['id']), stem, f"{stem}--{iv['id']}")
        continue
    _, body = frontmatter(read(os.path.join(epic_dir, sp)))
    fence = False
    for line in body.splitlines():
        if line.startswith('```'):
            fence = not fence; continue
        if fence:
            continue
        m = re.match(r'^####\s+(AC-\d+[a-z0-9/]*)\b', line) or \
            re.match(r'^###\s+Requirement:\s+(REQ-\d+[a-z0-9/]*)\b', line) or \
            re.match(r'^-\s+(US-\d+[a-z0-9/]*)\b', line)
        if m:
            add_def(m.group(1), stem, f'{stem}--{m.group(1)}')

# ADRs cited anywhere in the epic dir → resolved against the project root
adr_cited = set()
for rel in files:
    if rel.endswith('.md') or rel.endswith('.html'):
        for m in CODE_RE.finditer(read(os.path.join(epic_dir, rel))):
            if m.group(1).startswith('ADR-') and re.fullmatch(r'ADR-\d+', m.group(1)):
                adr_cited.add(m.group(1))
adr_files = {}  # key -> path
if root:
    hits = []
    for d in ('docs/adr', '.touchstone/docs/adr'):
        hits += glob.glob(os.path.join(root, d, '*.md'))
    by_num = {}
    for h in sorted(hits):
        m = re.match(r'^(\d+)-', os.path.basename(h))
        if m:
            by_num.setdefault(int(m.group(1)), h)
    # fixpoint: an ADR rendered into the page may itself cite ADRs — those are
    # rendered too, so every ADR link in the page has an in-page anchor.
    pending = sorted(adr_cited)
    while pending:
        code = pending.pop()
        k = adr_key(code)
        n = int(code.split('-')[1])
        if k in adr_files or n not in by_num:
            continue
        adr_files[k] = by_num[n]
        for m in CODE_RE.finditer(read(by_num[n])):
            c = m.group(1)
            if re.fullmatch(r'ADR-\d+', c) and adr_key(c) not in adr_files:
                pending.append(c)

yaml_dev_defs = {}   # D-n -> anchor (filled when deviation.yaml is read)
def resolve(code, owner):
    if code in yaml_dev_defs:
        return yaml_dev_defs[code], []
    if code.startswith('ADR-') and re.fullmatch(r'ADR-\d+', code):
        k = adr_key(code)
        return (k, []) if k in adr_files else (None, [])
    cands = defs.get(code)
    if not cands:
        return None, []
    for o, a in cands:
        if o == owner:
            return a, []
    return cands[0][1], [a for _, a in cands[1:]]

# ---------- markdown → html (minimal, with code linking) ----------
def link_codes(escaped, owner, skip=None):
    def sub(m):
        code = m.group(1)
        if code == skip:
            return code
        anchor, alts = resolve(code, owner)
        if anchor is None:
            if not code.startswith(STRICT):
                return code
            return f'<span class="undef" title="no definition for {code} in this epic">{code}</span>'
        t = f' title="also defined at: {", ".join(alts)}"' if alts else ''
        return f'<a class="code" data-jump="{attr(anchor)}" tabindex="0"{t}>{code}</a>'
    return CODE_RE.sub(sub, escaped)

def inline(text, owner, skip=None):
    spans = []
    def stash(m):
        spans.append(f'<code>{html.escape(m.group(1))}</code>')
        return f'\x00{len(spans)-1}\x00'
    text = re.sub(r'`([^`]+)`', stash, text)
    text = html.escape(text, quote=False)
    text = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)',
                  lambda m: f'<a href="{attr(safe_url(html.unescape(m.group(2))))}">{m.group(1)}</a>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'(?<![\w*])\*([^*\n]+?)\*(?![\w*])', r'<em>\1</em>', text)
    text = link_codes(text, owner, skip)
    return re.sub(r'\x00(\d+)\x00', lambda m: spans[int(m.group(1))], text)

def md_to_html(body, owner, define=False, ledger=False):
    out, lines, i = [], body.splitlines(), 0
    para, ul, table = [], None, None
    def flush_para():
        if para:
            out.append('<p>' + inline(' '.join(para), owner) + '</p>'); para.clear()
    def flush_list():
        nonlocal ul
        if ul is not None:
            out.append(f'</{ul}>'); ul = None
    def flush_table():
        nonlocal table
        if table:
            out.append('<div class="tbl"><table>' + ''.join(table) + '</table></div>'); table = None
    while i < len(lines):
        line = lines[i]
        if line.startswith('```'):
            flush_para(); flush_list(); flush_table()
            buf = []; i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                buf.append(lines[i]); i += 1
            out.append('<pre>' + html.escape('\n'.join(buf)) + '</pre>'); i += 1; continue
        hm = re.match(r'^(#{1,6})\s+(.*)$', line)
        if hm:
            flush_para(); flush_list(); flush_table()
            lvl, text = len(hm.group(1)), hm.group(2).strip()
            anchor, skip = '', None
            if define:
                dm = re.match(r'^(?:Requirement:\s+)?((?:AC|REQ)-\d+[a-z0-9/]*)\b', text)
                if dm:
                    skip = dm.group(1); anchor = f' id="{owner}--{skip}"'
            out.append(f'<h{min(lvl+1,6)}{anchor}>{inline(text, owner, skip)}</h{min(lvl+1,6)}>')
            i += 1; continue
        if line.strip().startswith('|'):
            flush_para(); flush_list()
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if all(re.fullmatch(r':?-+:?', c) for c in cells if c):
                i += 1; continue
            tag = 'th' if table is None else 'td'
            if table is None:
                table = []
            lm_ = LEDGER_RE.match(line.strip()) if ledger else None
            rid = f' id="ledger--{lm_.group(1)}"' if lm_ else ''
            table.append(f'<tr{rid}>' + ''.join(f'<{tag}>{inline(c, owner, lm_.group(1) if lm_ else None)}</{tag}>' for c in cells) + '</tr>')
            i += 1; continue
        flush_table()
        lm = re.match(r'^(\s*)([-*]|\d+\.)\s+(.*)$', line)
        if lm:
            flush_para()
            kind = 'ol' if lm.group(2)[0].isdigit() else 'ul'
            if ul != kind:
                flush_list(); out.append(f'<{kind}>'); ul = kind
            text = lm.group(3)
            skip, anchor = None, ''
            if define:
                dm = re.match(r'^(US-\d+[a-z0-9/]*)\b', text)
                if dm:
                    skip = dm.group(1); anchor = f' id="{owner}--{skip}"'
            if ledger:
                dm = LEDGER_RE.match('- ' + text)
                if dm:
                    skip = dm.group(1); anchor = f' id="ledger--{skip}"'
            out.append(f'<li{anchor}>{inline(text, owner, skip)}</li>')
            i += 1; continue
        if re.fullmatch(r'\s*(-{3,}|\*{3,})\s*', line):
            flush_para(); flush_list(); out.append('<hr>'); i += 1; continue
        if line.startswith('>'):
            flush_para(); flush_list()
            out.append('<blockquote>' + inline(line.lstrip('> ').strip(), owner) + '</blockquote>'); i += 1; continue
        if not line.strip():
            flush_para(); flush_list(); i += 1; continue
        para.append(line.strip()); i += 1
    flush_para(); flush_list(); flush_table()
    return '\n'.join(out)

def html_body_inner(text):
    m = re.search(r'<body[^>]*>(.*?)</body>', text, re.DOTALL | re.IGNORECASE)
    inner = m.group(1) if m else text
    return sanitize_html(inner)

def link_codes_in_html(fragment, owner):
    # link codes in text nodes only (not inside tags, not inside <code>/<pre>)
    parts = re.split(r'(<[^>]+>)', fragment)
    depth = 0; out = []
    for part in parts:
        if part.startswith('<'):
            t = part.lower()
            if re.match(r'<(code|pre)\b', t): depth += 1
            elif re.match(r'</(code|pre)\b', t): depth = max(0, depth - 1)
            out.append(part)
        elif depth == 0:
            out.append(link_codes(part, owner))
        else:
            out.append(part)
    return ''.join(out)

def fm_table(fm):
    if not fm:
        return ''
    rows = ''.join(f'<tr><th>{html.escape(k)}</th><td>{html.escape(v)}</td></tr>' for k, v in fm.items())
    return f'<div class="tbl"><table>{rows}</table></div>'

def article(title, rel, inner, anchor=''):
    head = f'<header>{fspan(rel)}</header>' if rel else ''
    return f'<article{anchor}>{head}<h2>{html.escape(title)}</h2>{inner}</article>'
# note: `anchor` is always built from slug_id()/adr_key() output — attribute-safe by construction.

# ---------- extraction (every visible sentence is taken from a source file) ----------
LONG_FILE = 60  # lines; longer files collapse behind a summary line

def first_para(body):
    """First non-heading, non-list, non-fence paragraph (≤ 220 chars)."""
    fence = False; buf = []
    for line in body.splitlines():
        if line.startswith('```'):
            fence = not fence; continue
        if fence: continue
        s = line.strip()
        if not s:
            if buf: break
            continue
        if s.startswith(('#', '|', '- ', '* ', '>', '---')):
            if buf: break
            continue
        buf.append(s)
    t = ' '.join(buf)
    return t if len(t) <= 220 else t[:217].rsplit(' ', 1)[0] + '…'

def bullets(text):
    """Top-level `- ` items of a markdown fragment (fence-aware), raw text."""
    out, fence = [], False
    for line in text.splitlines():
        if line.startswith('```'):
            fence = not fence; continue
        if not fence and re.match(r'^- ', line):
            out.append(line[2:].strip())
    return out

def field(items, label):
    for it in items:
        m = re.match(r'^\*\*' + re.escape(label) + r'[^*]*\*\*\s*(.*)$', it)
        if m: return m.group(1).strip()
    return ''

def pill(status):
    s = (status or '').lower()
    cls = {'accepted': 'ok', 'done': 'ok', 'active': 'accent', 'accepted-candidate': 'warn', 'proposed': 'muted',
           'draft': 'muted', 'paused': 'warn', 'cancelled': 'crit', 'blocked': 'crit'}.get(s, 'muted')
    return f'<span class="pill {cls}">{html.escape(status or "—")}</span>'

META_ZH = {'date': '日期', 'kind': '種類', 'type': '類型', 'started': '開始', 'landed': '落地'}
def meta_line(fm, extra=''):
    parts = []
    for k in ('status', 'date', 'kind', 'type', 'started', 'landed'):
        if fm.get(k):
            parts.append(zpill(sval(fm[k]).lower()) if k == 'status' else f'<span>{lab(META_ZH.get(k, k))} {zh(sval(fm[k]).lower()) if k in ("kind", "type") else html.escape(sval(fm[k]))}</span>')
    if extra: parts.append(extra)
    return f'<p class="meta">{" · ".join(parts)}</p>' if parts else ''

def phase_map_panels(spec_body):
    """The four panels of `## Phase map` as [(label, markdown)] — from the spec, never authored."""
    sec = [t for h, t in sections(spec_body) if h == 'Phase map']
    if not sec: return None
    panels, cur, buf, fence = [], None, [], False
    for line in sec[0].splitlines():
        if line.startswith('```'): fence = not fence
        m = None if fence else re.match(r'^- \*\*([^*]+?)\.?\*\*\s*(.*)$', line)
        if m:
            if cur: panels.append((cur, '\n'.join(buf)))
            cur, buf = m.group(1).strip(), [m.group(2)]
        elif cur is not None:
            buf.append(re.sub(r'^  ', '', line))
    if cur: panels.append((cur, '\n'.join(buf)))
    return panels

def sentence_citing(code, texts):
    """First sentence in the given texts that mentions the code (spec first)."""
    for t in texts:
        for s in re.split(r'(?<=[.。])\s+|\n', t):
            if re.search(r'(?<![\w-])' + re.escape(code) + r'(?![\w-])', s) and not s.lstrip().startswith(('#', '|')):
                s = s.strip().lstrip('-* ').strip()
                return s if len(s) <= 240 else s[:237].rsplit(' ', 1)[0] + '…'
    return ''

def verdict_lines(text):
    out = []
    for line in text.splitlines():
        if re.search(r'\bverdict\b', line, re.I) and re.search(r'approve|revise|block', line, re.I) \
           or re.match(r'^\**Ready to merge', line) or re.match(r'^providers_(used|expected)', line):
            out.append(line.strip().strip('*'))
    return out

def collapsed(summary_html, inner_html, open_=False):
    return f'<details class="fold"{" open" if open_ else ""}><summary>{summary_html}</summary><div class="fold-body">{inner_html}</div></details>'

def fspan(rel):
    return f'<span class="file" title="{attr("檔案 " + rel)}">{html.escape(rel)}</span>'
def file_card(rel, title, fm, body, owner, define=False, force_open=False, ledger=False):
    """A source file: h2 + meta line; body inline if short, else collapsed behind its first paragraph."""
    n = body.count('\n') + 1
    rendered = md_to_html(body, owner, define=define, ledger=ledger)
    file_span = f'{fspan(rel)} · {n} lines'
    head = f'<h3 class="file-title">{html.escape(title)}</h3>{meta_line(fm, file_span)}'
    if n > LONG_FILE and not force_open:
        summ = '<span class="lead">' + inline(first_para(body), owner) + '</span> <span class="muted">(full text)</span>'
        return f'<article>{head}{collapsed(summ, rendered)}</article>'
    return f'<article>{head}{rendered}</article>'

# ---------- per-source parsing ----------
index_sections = {h: t for h, t in sections(index_body)}
aim_m = re.search(r'^\*\*Aim:\*\*\s*(.+)$', index_body, re.M)
aim = aim_m.group(1).strip() if aim_m else ''
phase_table_rows = []
for line in index_sections.get('Phases', '').splitlines():
    if line.startswith('|'):
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) >= 5 and cells[0].isdigit():
            phase_table_rows.append(cells)

specs = {}  # rel -> dict
YAML_PANELS = [('Position', 'position'), ('Structure before → after', 'structure_before_after'),
               ('Interface delta', 'interface_delta'), ('Flow + scope', 'scope')]
PANEL_OF = {'position': 'position', 'structure_before_after': 'structure', 'interface_delta': 'interface', 'scope': 'scope'}  # phase_map field → deviation panel enum
for sp in spec_files:
    if is_yaml_spec(sp):
        yd = load_yaml(os.path.join(epic_dir, sp)) or {}
        pm = yd.get('phase_map') if isinstance(yd.get('phase_map'), dict) else {}
        fm = {k: sval(yd.get(k)) for k in ('status', 'date') if yd.get(k) is not None}
        fm['type'] = 'spec'
        specs[sp] = {'yaml': yd, 'fm': fm, 'body': '', 'title': sval(yd.get('title')) or stem_of(sp),
                     'foundation': [], 'stories': [], 'reqs': [], 'ac_rows': [],
                     'panels': [(lab, sval(pm.get(k))) for lab, k in YAML_PANELS] if pm else None, 'markers': 0}
        continue
    fm, body = frontmatter(read(os.path.join(epic_dir, sp)))
    idx_rows = []
    in_ac = False
    for line in body.splitlines():
        if line.startswith('## '): in_ac = line[3:].strip() == 'Acceptance Criteria'
        if in_ac and line.startswith('|'):
            c = [x.strip() for x in line.strip().strip('|').split('|')]
            if len(c) >= 3 and re.match(r'^REQ-\d+', c[0]) and re.match(r'^AC-\d+', c[1]):
                idx_rows.append(c)
    reqs = re.findall(r'^### Requirement:\s+(REQ-\d+)\s*—\s*(.+)$', body, re.M)
    specs[sp] = {'fm': fm, 'body': body, 'title': first_h1(body) or stem_of(sp),
                 'foundation': bullets([t for h, t in sections(body) if h == 'Foundation'][0]) if any(h == 'Foundation' for h, _ in sections(body)) else [],
                 'stories': [b for b in bullets('\n'.join(t for h, t in sections(body) if h == 'User Stories')) if b.startswith('US-')],
                 'reqs': reqs, 'ac_rows': idx_rows, 'panels': phase_map_panels(body),
                 'markers': len(re.findall(r'\[(NEEDS CLARIFICATION|unverified):', re.sub(r'`[^`]*`', '', body)))}

texts_for_citation = [specs[s]['body'] for s in spec_files] + [index_body]

deviation_lines = bullets(index_sections.get('Deviation log', ''))
for rel in files:
    if os.path.basename(rel).lower().startswith('deviation') and not in_record_dir(rel):
        deviation_lines += bullets(frontmatter(read(os.path.join(epic_dir, rel)))[1])

yaml_dev = None   # deviation.yaml of the epic dir (phase-1 form: one per epic dir)
for rel in files:
    if os.path.basename(rel) == 'deviation.yaml' and not in_record_dir(rel):
        yaml_dev = load_yaml(os.path.join(epic_dir, rel)) or {'entries': [], 'quiz': {}, 'waiting_on_human': []}
        for e in yaml_dev.get('entries') or []:
            if isinstance(e, dict) and e.get('id'): yaml_dev_defs[str(e['id'])] = f"deviation--{e['id']}"
        break
reviews = []   # [(rel, dict)] every review.yaml, sorted by path
for rel in files:
    if os.path.basename(rel) == 'review.yaml':
        d = load_yaml(os.path.join(epic_dir, rel))
        if d: reviews.append((rel, d))
def reviews_for(p):
    return [(rel, d) for rel, d in reviews if phase_of(rel) is p or d.get('target') == os.path.basename(p['spec'])]

def dev_lines_for(p):
    if p is EPIC:
        return [d for d in deviation_lines if not any(q['slug'] and (q['slug'] in d or f"phase {q['num']}" in d.lower()) for q in phases)]
    return [d for d in deviation_lines if (p['slug'] and p['slug'] in d) or f"phase {p['num']}" in d.lower()]
for i, p in enumerate(phases):
    p['num'] = next((r[0] for r in phase_table_rows if p['spec'] in r[2]), str(i + 1))

# ---------- YAML projection (every sentence is a field value; labels are the only renderer text) ----------
def yv(v, owner):
    return inline(sval(v), owner)

def lab(text):
    return f'<span class="label">{html.escape(text)}</span>'

def yaml_table(rows, header, owner, anchor_col=None, stem=''):
    """rows: list of lists of raw scalars; header: labels. anchor_col: index whose value is an id → row id."""
    h = ''.join(f'<th>{html.escape(x)}</th>' for x in header)
    body = ''
    for r in rows:
        rid = f' id="{attr(stem + "--" + sval(r[anchor_col]))}"' if anchor_col is not None and sval(r[anchor_col]) else ''
        skip = sval(r[anchor_col]) if anchor_col is not None else None
        body += f'<tr{rid}>' + ''.join(f'<td>{c if (isinstance(c, str) and c.startswith("<abbr")) else inline(sval(c), owner, skip if j == anchor_col else None)}</td>' for j, c in enumerate(r)) + '</tr>'
    return f'<div class="tbl"><table><tr>{h}</tr>{body}</table></div>'

def yaml_contract_card(p, s):
    yd, k = s['yaml'], p['key']
    parts = [f'<h3 class="file-title">{yv(yd.get("title"), k)}</h3>',
             meta_line({kk: v for kk, v in s['fm'].items() if kk != 'status'}, fspan(p['spec']))]
    agent = []   # reader: agent fields — folded
    if yd.get('facts_source'):
        fs = yd['facts_source']
        parts.append(f'<p class="meta">{lab("帳")} <span class="file">{html.escape(sval(fs.get("record")))}</span> · {lab("引用裁決")} {len(fs.get("consensus") or [])}</p>')
        agent.append(f'<h4>{lab("共識 id")}</h4><p>{" ".join(link_codes(sval(c), k) for c in fs.get("consensus") or [])}</p>')
    if yd.get('user_stories'):
        parts.append(collapsed(f'<span class="lead">{lab("使用者故事")}</span> <span class="num">{len(yd["user_stories"])}</span>', '<ul>' + ''.join(
            f'<li id="{attr(k + "--" + sval(u.get("id")))}">{inline(sval(u.get("id")), k, sval(u.get("id")))} · {yv(u.get("as"), k)} · {yv(u.get("want"), k)} · {yv(u.get("so_that"), k)}</li>'
            for u in yd['user_stories'] if isinstance(u, dict)) + '</ul>'))
    if yd.get('requirements'):
        reqs = [r for r in yd['requirements'] if isinstance(r, dict)]
        n_ac = sum(len(r.get('acs') or []) for r in reqs)
        parts.append(f'<p class="meta">{lab("需求")} {len(reqs)} · {lab("驗收條件")} {n_ac} · {lab("不變式")} {len(yd.get("invariants") or [])}</p>')
        rows = ''
        for r in yd['requirements']:
            if not isinstance(r, dict): continue
            rid = sval(r.get('id'))
            acs = ' '.join(f'<a class="code" data-jump="{attr(k + "--" + sval(a.get("id")))}" tabindex="0">{html.escape(sval(a.get("id")))}</a>' for a in r.get('acs') or [] if isinstance(a, dict))
            basis = ' '.join(link_codes(sval(b), k) for b in r.get('basis') or [])
            rows += f'<tr id="{attr(k + "--" + rid)}"><td class="num">{html.escape(rid)}</td><td>{yv(r.get("shall"), k)}</td><td class="num">{acs}</td><td class="num">{basis}</td></tr>'
            for a in r.get('acs') or []:
                if not isinstance(a, dict): continue
                aid = sval(a.get('id'))
                ab = ' '.join(link_codes(sval(b), k) for b in a.get('basis') or [])
                lb = zpill('live-bearing', 'warn') if a.get('live_bearing') is True else ''
                rows += f'<tr id="{attr(k + "--" + aid)}" class="ac"><td class="num">{html.escape(aid)} {lb}</td><td>{lab("給定")} {yv(a.get("given"), k)} · {lab("當")} {yv(a.get("when"), k)} · {lab("則")} {yv(a.get("then"), k)}</td><td></td><td class="num">{ab}</td></tr>'
        agent.append(f'<h4>{lab("需求")}</h4><div class="tbl"><table><tr><th>id</th><th>應 / 給定 · 當 · 則</th><th>驗收條件</th><th>依據</th></tr>{rows}</table></div>')
    if yd.get('invariants'):
        agent.append(f'<h4>{lab("不變式")}</h4>' + yaml_table([[i.get('id'), i.get('rule'), i.get('check'), i.get('why_ref')] for i in yd['invariants'] if isinstance(i, dict)], ['id', '規則', '檢查', '依據'], k, 0, k))
    d = yd.get('delta') if isinstance(yd.get('delta'), dict) else {}
    if d.get('blocks'):
        parts.append(f'<p class="meta">{lab("結構變更區塊")} <span class="num">{len(d["blocks"])}</span> · <a class="code" data-jump="{attr(k + "--structure")}" tabindex="0">結構變化</a></p>')
        agent.append(f'<h4>{lab("變更區塊")}</h4>' + yaml_table([[b.get('id'), b.get('op'), b.get('kind'), b.get('purpose')] for b in d['blocks'] if isinstance(b, dict)], ['id', '動作', '種類', '目的'], k))
    if d.get('contracts'):
        agent.append(f'<h4>{lab("契約介面")}</h4>' + yaml_table([[c.get('id'), c.get('schema')] for c in d['contracts'] if isinstance(c, dict)], ['id', 'schema'], k))
    if yd.get('non_goals'):
        parts.append(collapsed(f'<span class="lead">{lab("不做")}</span> <span class="num">{len(yd["non_goals"])}</span>', '<ul>' + ''.join(f'<li>{yv(n, k)}</li>' for n in yd['non_goals']) + '</ul>'))
    if yd.get('risks'):
        parts.append(collapsed(f'<span class="lead">{lab("風險")}</span> <span class="num">{len(yd["risks"])}</span>', yaml_table([[zh(r.get('priority')), r.get('problem'), r.get('measure'), r.get('why_ref')] for r in yd['risks'] if isinstance(r, dict)], ['優先', '問題', '對策', '依據'], k)))
    if yd.get('waiting_on_human'):
        parts.append(f'<h4>{lab("等你裁")}</h4><ul class="todo">' + ''.join(f'<li>{yv(w, k)}</li>' for w in yd['waiting_on_human']) + '</ul>')
    if agent:
        parts.append(collapsed(f'<span class="lead">{lab("agent 用欄位")}</span> <span class="muted">{lab("需求 · 驗收條件 · 不變式 · 變更 · 契約介面")}</span>', ''.join(agent)))
    return f'<article>{"".join(parts)}</article>'

def dev_entries_for_panel(key):
    if not yaml_dev: return []
    key = PANEL_OF.get(key, key)
    return [e for e in yaml_dev.get('entries') or [] if isinstance(e, dict) and sval(e.get('panel')) == key]

def dev_entry_html(e, owner, anchor=True):
    did = sval(e.get('id'))
    aid = f' id="{attr("deviation--" + did)}"' if anchor else ''
    return (f'<li{aid}>{inline(did, owner, did)} · {yv(e.get("date"), owner)} · {lab("缺口")} {yv(e.get("gap"), owner)} · '
            f'{lab("處置")} {yv(e.get("disposition"), owner)} · {lab("哪一階段可抓到")} {yv(e.get("which_stage_could_have_caught"), owner)}</li>')

def yaml_panels_html(p, s, legacy_lines, anchor=True):
    k, cards = p['key'], ''
    for (label, key), (_, text) in zip(YAML_PANELS, s['panels']):
        hits = dev_entries_for_panel(key)
        mark = '<span class="pill warn">built ≠ planned</span>' if hits else '<span class="pill ok">as planned</span>'
        body = f'<p>{yv(text, k)}</p>'
        if hits:
            body += f'<p class="delta">{lab("偏離")}</p><ul>' + ''.join(dev_entry_html(e, k, anchor) for e in hits) + '</ul>'
        cards += f'<section class="panel"><h4>{lab(label)} {mark}</h4>{body}</section>'
    other = dev_entries_for_panel('none')
    if other:
        cards += f'<section class="panel"><h4>{lab("未歸面板的偏離")}</h4><ul>' + ''.join(dev_entry_html(e, k, anchor) for e in other) + '</ul></section>'
    if legacy_lines:
        cards += f'<section class="panel"><h4>{lab("舊版偏離行")}</h4><ul>' + ''.join(f'<li>{inline(d, k)}</li>' for d in legacy_lines) + '</ul></section>'
    return f'<div class="panels">{cards}</div>'

def review_verdict_line(rel, d, owner):
    c = d.get('counts') if isinstance(d.get('counts'), dict) else {}
    parts = [yv(d.get('gate'), owner), f'{lab("輪")} {yv(d.get("round"), owner)}', f'{lab("裁決")} {yv(d.get("verdict"), owner)}',
             f'{lab("C")} {yv(c.get("C"), owner)} {lab("H")} {yv(c.get("H"), owner)} {lab("M")} {yv(c.get("M"), owner)} {lab("L")} {yv(c.get("L"), owner)}',
             f'{lab("審查方")} {" ".join(yv(x, owner) for x in d.get("providers") or [])}']
    if d.get('degraded') is True:
        parts.append(f'<span class="pill crit">degraded</span> {yv(d.get("degraded_reason"), owner)}')
    return f'<li>{fspan(rel)} · ' + ' · '.join(parts) + '</li>'

def review_findings_table(d, owner):
    rows = []
    for f in d.get('findings') or []:
        if not isinstance(f, dict): continue
        loc = sval(f.get('field')) or (sval(f.get('file')) + (f":{f['line']}" if f.get('line') is not None else ''))
        rows.append([f.get('id'), f.get('severity'), f.get('type'), f.get('agent'), loc, f.get('summary'), f.get('status')])
    if not rows:
        return f'<p class="placeholder">no findings</p>'
    return yaml_table(rows, ['id', '嚴重度', '類型', 'agent', '位置', '摘要', '狀態'], owner)

def evidence_table(p, s):
    """AC × status from the newest deliverable-review review.yaml of this phase; invariants with their check."""
    k, yd = p['key'], s['yaml']
    dr = [(rel, d) for rel, d in reviews_for(p) if d.get('gate') == 'deliverable-review']
    status = {}
    if dr:
        for f in dr[-1][1].get('findings') or []:
            if isinstance(f, dict):
                for m in re.finditer(r'\b((?:AC|INV)-\d+)\b', sval(f.get('field'))):
                    status[m.group(1)] = f'{sval(f.get("status"))} · {sval(f.get("summary"))}'
    rows = []
    for r in yd.get('requirements') or []:
        for a in (r.get('acs') or []) if isinstance(r, dict) else []:
            if isinstance(a, dict):
                aid = sval(a.get('id'))
                rows.append([aid, 'live-bearing' if a.get('live_bearing') is True else '', a.get('then'), status.get(aid, '') if dr else None])
    for i in yd.get('invariants') or []:
        if isinstance(i, dict):
            rows.append([sval(i.get('id')), sval(i.get('check')), i.get('rule'), status.get(sval(i.get('id')), '') if dr else None])
    if not rows:
        return f'<p class="placeholder">no acceptance criteria or invariants in this spec</p>'
    def row(r):
        st = '<span class="placeholder">not yet reviewed</span>' if r[3] is None else inline(r[3], k)
        return f'<tr><td class="num">{link_codes(r[0], k)}</td><td>{lab(sval(r[1])) if sval(r[1]) else ""}</td><td>{yv(r[2], k)}</td><td>{st}</td></tr>'
    hdr = '<tr><th>id</th><th>種類</th><th>則 / 規則</th><th>證據</th></tr>'
    flagged = [r for r in rows if r[3]]
    n_flag = len(flagged)
    head = f'<p class="meta">{lab("項目")} {len(rows)} · {lab("審查標記")} {n_flag}</p>'
    top = f'<div class="tbl"><table>{hdr}{"".join(row(r) for r in flagged)}</table></div>' if flagged else ''
    return head + top + collapsed(f'<span class="lead">{lab("全部項目")}</span>', f'<div class="tbl"><table>{hdr}{"".join(row(r) for r in rows)}</table></div>')

OP_FILL = {'add': ('var(--ok-bg)', 'var(--ok)'), 'change': ('var(--warn-bg)', 'var(--warn)'), 'remove': ('var(--crit-bg)', 'var(--crit)')}
def structure_svg(blocks, edges):
    """Deterministic before→after picture: one box per delta block (colour = op), one arrow per edge."""
    ids = [sval(b.get('id')) for b in blocks if isinstance(b, dict)]
    if not ids: return ''
    outs = {i: [sval(e.get('to')) for e in edges if isinstance(e, dict) and sval(e.get('from')) == i] for i in ids}
    depth = {}
    def dep(i, seen=()):
        if i in depth: return depth[i]
        if i in seen: return 0
        depth[i] = 1 + max([dep(t, seen + (i,)) for t in outs.get(i, []) if t in ids] or [-1])
        return depth[i]
    for i in ids: dep(i)
    rows = {}
    for i in ids: rows.setdefault(depth[i], []).append(i)
    W, H, GX, GY, PAD = 150, 44, 22, 40, 14
    cols = max(len(m) for m in rows.values())
    width = PAD * 2 + cols * W + (cols - 1) * GX
    pos = {}
    for r, (dv, members) in enumerate(sorted(rows.items(), key=lambda kv: -kv[0])):
        off = (width - (len(members) * W + (len(members) - 1) * GX)) / 2
        for c, i in enumerate(members): pos[i] = (off + c * (W + GX), PAD + r * (H + GY))
    height = PAD * 2 + len(rows) * H + (len(rows) - 1) * GY
    out = [f'<svg class="structure" viewBox="0 0 {width} {height}" role="img" aria-label="structure delta">',
           '<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="var(--muted)"/></marker></defs>']
    for e in edges:
        if not isinstance(e, dict): continue
        a, b = sval(e.get('from')), sval(e.get('to'))
        if a not in pos or b not in pos: continue
        x1, y1 = pos[a][0] + W / 2, pos[a][1] + H
        x2, y2 = pos[b][0] + W / 2, pos[b][1]
        dash = ' stroke-dasharray="5 4"' if sval(e.get('op')) == 'remove' else ''
        out.append(f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="var(--muted)" stroke-width="1.5" marker-end="url(#arr)"{dash}/>')
    for b in blocks:
        if not isinstance(b, dict): continue
        i = sval(b.get('id')); x, y = pos[i]
        fill, stroke = OP_FILL.get(sval(b.get('op')), ('var(--code)', 'var(--line)'))
        deco = ' text-decoration="line-through"' if sval(b.get('op')) == 'remove' else ''
        out.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{W}" height="{H}" rx="6" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
        out.append(f'<text x="{x + W/2:.0f}" y="{y + 19:.0f}" text-anchor="middle" font-size="12" font-weight="600" fill="var(--ink)"{deco}>{html.escape(i)}</text>')
        out.append(f'<text x="{x + W/2:.0f}" y="{y + 34:.0f}" text-anchor="middle" font-size="10" fill="var(--muted)">{html.escape(ZH.get(sval(b.get("op")), sval(b.get("op"))))} · {html.escape(ZH.get(sval(b.get("kind")), sval(b.get("kind"))))}</text>')
    out.append('</svg>')
    legend = ''.join(zpill(op, c) + ' ' for op, c in (('add', 'ok'), ('change', 'warn'), ('remove', 'crit')))
    return f'<div class="figure">{"".join(out)}<p class="meta">{legend}</p></div>'

def structure_overlay(p, s):
    k = p['key']
    ov = [f for f in files if os.path.basename(f) == 'structure-overlay.html' and phase_of(f) in (p, EPIC)]
    d = s['yaml'].get('delta') if isinstance(s['yaml'].get('delta'), dict) else {}
    blocks = [b for b in d.get('blocks') or [] if isinstance(b, dict)]
    edges = [e for e in d.get('edges') or [] if isinstance(e, dict)]
    if not blocks:
        return '<p class="placeholder">no structural delta declared</p>'
    out = structure_svg(blocks, edges)
    if ov:
        out += f'<p class="meta">{lab("互動疊圖")} <a href="{attr(ov[0])}">{fspan(ov[0])}</a></p>'
    tables = yaml_table([[b.get('op'), b.get('id'), b.get('kind'), b.get('purpose')] for b in blocks], ['動作', '區塊', '種類', '目的'], k)
    if edges:
        tables += yaml_table([[e.get('op'), e.get('from'), e.get('to'), e.get('label')] for e in edges], ['動作', '從', '到', '說明'], k)
    return out + collapsed(f'<span class="lead">{lab("區塊與連線")}</span>', tables)

def quiz_html(p):
    k = p['key']
    q = (yaml_dev or {}).get('quiz') if yaml_dev else None
    entries = (yaml_dev or {}).get('entries') or []
    if yaml_dev is None:
        return '<p class="placeholder">尚無 deviation.yaml</p>'
    if not entries or (isinstance(q, dict) and q.get('waived') is True):
        return f'<p class="waiver">{lab("理解測驗免作")} · {lab("零偏離：本 phase 沒有 D-n")}</p>'
    items = (q.get('items') or []) if isinstance(q, dict) else []
    if not items:
        return '<p class="placeholder">理解測驗尚未出題</p>'
    out = ''
    for it in items:
        if not isinstance(it, dict): continue
        res = f' <span class="pill {"ok" if sval(it.get("result")) == "pass" else "crit"}">{html.escape(sval(it.get("result")))}</span>' if it.get('result') else ''
        out += f'<li>{yv(it.get("id"), k)}{res} · {yv(it.get("question"), k)}<details class="fold"><summary>{lab("答案")}</summary><div class="fold-body">{yv(it.get("answer"), k)} · {lab("錨點")} <code>{html.escape(sval(it.get("anchor")))}</code></div></details></li>'
    return f'<div id="{attr(k + "--quiz")}">' + collapsed(f'<span class="lead">{lab("題目")}</span> <span class="num">{len(items)}</span>', f'<ol class="quiz">{out}</ol>') + '</div>'

def waiting_union(p, s):
    out = [(os.path.basename(p['spec']), w) for w in s['yaml'].get('waiting_on_human') or []]
    for gate in ('design-review', 'deliverable-review'):
        rel, d = newest_review(p, gate)
        if d: out += [(rel, w) for w in d.get('waiting_on_human') or []]
    if yaml_dev:
        out += [('deviation.yaml', w) for w in yaml_dev.get('waiting_on_human') or []]
    return out

# ---------- zh-TW label table (enum → label; identifiers never translated) ----------
LAB_ZH = {'Retrospective': '回顧', 'Evidence Reckoning': '證據清算', 'Disposition': '處置', 'Pivots': '轉向', 'Open Questions': '未決問題', 'Foundation': '基礎'}
ZH = {
    'C': '嚴重', 'H': '高', 'M': '中', 'L': '低',
    'approve': '通過', 'revise': '修改', 'block': '阻擋',
    'pass': '通過', 'fail': '未過', 'pending': '待審', 'n/a': '不適用',
    'open': '未處理', 'fixed': '已修', 'waived': '豁免', 'unverified': '未驗證',
    'coverage-gap': '覆蓋缺口', 'real-defect': '真缺陷', 'refinement': '精修', 'soundness': '健全性',
    'original': '原始', 'fix-induced': '修復引入',
    'add': '新增', 'change': '改動', 'remove': '移除',
    'position': '位置', 'structure': '結構前後', 'interface': '介面差異', 'scope': '範圍', 'none': '未歸面板',
    'design-review': '設計審查', 'deliverable-review': '交付審查', 'tests': '測試', 'quiz': '理解測驗', 'ship-gate': '出貨門',
    'draft': '草稿', 'accepted-candidate': '待接受', 'accepted': '已接受', 'superseded': '已取代',
    'active': '進行中', 'proposed': '提議', 'paused': '暫停', 'done': '完成', 'cancelled': '取消',
    'approvable': '可核准', 'blocked': '被擋住', 'not-reviewed': '尚未審',
    'true': '是', 'false': '否',
    'degraded': '降級', 'as-planned': '如計畫', 'built-ne-planned': '實作≠計畫', 'live-bearing': '需實跑',
    'component': '元件', 'skill': '技能', 'fragment': '片段', 'agent': 'agent', 'command': '指令', 'schema': 'schema', 'doc': '文件',
    'high': '高', 'medium': '中', 'low': '低', 'spec': 'spec', 'adr': 'ADR',
    'owner': '擁有者', 'builder': '建置者', 'author': '作者 session', 'complete': '完成', 'partial': '部分',
}
def zh(v):
    """Enum value → zh-TW label with the English key kept as an abbr title."""
    v = sval(v)
    return f'<abbr class="enum" title="{attr(v)}">{html.escape(ZH.get(v, v))}</abbr>' if v in ZH else html.escape(v)
def zpill(v, cls=None):
    v = sval(v)
    c = cls or {'approve': 'ok', 'pass': 'ok', 'fixed': 'ok', 'accepted': 'ok', 'done': 'ok', 'approvable': 'ok',
                'revise': 'warn', 'pending': 'warn', 'waived': 'warn', 'accepted-candidate': 'warn', 'paused': 'warn', 'not-reviewed': 'warn', 'unverified': 'warn',
                'block': 'crit', 'fail': 'crit', 'open': 'crit', 'blocked': 'crit', 'cancelled': 'crit',
                'n/a': 'muted', 'draft': 'muted', 'proposed': 'muted'}.get(v, 'muted')
    return f'<span class="pill {c}">{zh(v)}</span>'
ROW_CAP = 7
def capped(items_html, label='另'):
    """≤7 rows open; the rest folded behind a count."""
    if len(items_html) <= ROW_CAP:
        return ''.join(items_html)
    return ''.join(items_html[:ROW_CAP]) + collapsed(f'<span class="lead">{html.escape(label)} {len(items_html) - ROW_CAP} 項</span>', ''.join(items_html[ROW_CAP:]))

# ---------- decision state per YAML phase (derived from enums and counts only) ----------
SEV_ORDER = {'C': 0, 'H': 1, 'M': 2, 'L': 3}
def newest_review(p, gate):
    rs = [(rel, d) for rel, d in reviews_for(p) if sval(d.get('gate')) == gate]
    return rs[-1] if rs else (None, None)
def open_blockers(p):
    """Open Critical/High findings across the newest round of each gate."""
    out = []
    for gate in ('design-review', 'deliverable-review'):
        rel, d = newest_review(p, gate)
        if not d: continue
        for f in d.get('findings') or []:
            if isinstance(f, dict) and sval(f.get('severity')) in ('C', 'H') and sval(f.get('status')) == 'open':
                out.append((rel, f))
    return sorted(out, key=lambda x: (SEV_ORDER.get(sval(x[1].get('severity')), 9), sval(x[1].get('id'))))
def quiz_state():
    if not yaml_dev: return 'pending'
    q = yaml_dev.get('quiz') if isinstance(yaml_dev.get('quiz'), dict) else {}
    if not (yaml_dev.get('entries') or []) or q.get('waived') is True: return 'n/a'
    items = [i for i in (q.get('items') or []) if isinstance(i, dict)]
    if not items: return 'pending'
    res = [sval(i.get('result')) for i in items]
    if any(r == 'miss' for r in res): return 'fail'
    if all(r == 'pass' for r in res): return 'pass'
    return 'pending'
def gate_rows(p):
    rows = []
    for gate in ('design-review', 'deliverable-review'):
        rel, d = newest_review(p, gate)
        if not d: rows.append((gate, 'pending', None, None, '')); continue
        v = sval(d.get('verdict'))
        st = 'pass' if v == 'approve' else 'fail'
        rows.append((gate, st, d, rel, ''))
    rows.append(('tests', 'n/a', None, None, ''))
    rows.append(('quiz', quiz_state(), None, 'deviation.yaml' if yaml_dev else None, ''))
    rows.append(('ship-gate', 'n/a', None, None, ''))
    return sorted(rows, key=lambda r: {'fail': 0, 'pending': 1, 'pass': 2, 'n/a': 3}[r[1]])
def decision(p, s):
    n_block = len(open_blockers(p)) + len(waiting_union(p, s))
    if n_block: return 'blocked', n_block
    if any(st == 'pending' and g in ('design-review', 'deliverable-review') for g, st, *_ in gate_rows(p)): return 'not-reviewed', 0
    return 'approvable', 0
def next_action(d):
    c = d.get('counts') if isinstance(d.get('counts'), dict) else {}
    C, H = int(c.get('C') or 0), int(c.get('H') or 0)
    if C: return '→ 阻擋，交人裁'
    if H >= 3: return '→ 再驗一輪'
    if sval(d.get('verdict')) == 'approve': return '→ 收斂'
    return '→ 修後收斂'
def counts_html(d, owner):
    c = d.get('counts') if isinstance(d.get('counts'), dict) else {}
    return ' '.join(f'{lab(ZH[k])} {yv(c.get(k), owner)}' for k in ('C', 'H', 'M', 'L'))
GATE_OWNER = {'design-review': 'author', 'deliverable-review': 'builder', 'tests': 'builder', 'quiz': 'owner', 'ship-gate': 'owner'}
def gate_strip_html(p, s):
    k = p['key']
    rows = ''
    for gate, st, d, rel, _ in gate_rows(p):
        extra = f'{lab("負責")} {zh(GATE_OWNER.get(gate, ""))} · ' if st in ('fail', 'pending') else ''
        if d is not None:
            extra = f'{lab("第")} {yv(d.get("round"), k)} {lab("輪")} · {counts_html(d, k)} · {zh(d.get("verdict"))}'
            if d.get('degraded') is True: extra += f' · {zpill("degraded", "crit")}<details class="inl"><summary>{lab("原因")}</summary>{yv(d.get("degraded_reason"), k)}</details>'
        link = f' <a href="{attr(rel)}" title="{attr(rel)}">{lab("紀錄")}</a>' if rel else ''
        rows += f'<tr><td>{zh(gate)}</td><td>{zpill(st)}</td><td>{extra}{link}</td></tr>'
    return f'<div class="tbl"><table class="gates"><tr><th>門</th><th>狀態</th><th>觀測 · 紀錄</th></tr>{rows}</table></div>'

# ---------- the four surfaces ----------
groups = list(reversed(phases)) + [EPIC]   # newest phase first, epic-level last
tab = {t: {g['key']: [] for g in groups} for t in TABS}
notes = []
if not root:
    notes.append('No project root (`.touchstone/` ancestor) found — gate-miss and ADR lookups skipped.')
yaml_phases = [p for p in phases if 'yaml' in specs[p['spec']]]
current = yaml_phases[-1] if yaml_phases else None   # newest YAML phase = the one under decision
for i, p in enumerate(phases):
    p['num'] = next((r[0] for r in phase_table_rows if p['spec'] in r[2]), str(i + 1))

def front_sections(p, s):
    """[(label, html, text)] — the 首頁 in reading order; text = the PR-body projection."""
    k, yd = p['key'], s['yaml']
    state, n = decision(p, s)
    secs = []
    n_ph = len(phase_table_rows) or len(phases)
    head = f'<p class="decision">{yv(yd.get("epic"), k)} · {lab("第")} {yv(yd.get("phase"), k)}/{n_ph} {lab("階段")} · {zpill(state)}{f" <span class=\"num\">{n}</span>" if n else ""}</p><p class="aim">{yv(yd.get("title"), k)}</p>'
    secs.append(('決策', head, f"{sval(yd.get('epic'))} · 第 {sval(yd.get('phase'))}/{n_ph} 階段 · {ZH[state]}{f' ({n})' if n else ''}\n\n{sval(yd.get('title'))}"))
    g_txt = '\n'.join(f"- {ZH[g]}: {ZH[st]}" + (f" — round {sval(d.get('round'))} {sval(d.get('verdict'))} C={sval((d.get('counts') or {}).get('C'))} H={sval((d.get('counts') or {}).get('H'))} M={sval((d.get('counts') or {}).get('M'))} L={sval((d.get('counts') or {}).get('L'))}" if d else '') for g, st, d, rel, _ in gate_rows(p))
    secs.append(('gate 條', None, g_txt))   # html None → not rendered on the page; the strip carries the gates
    bl = open_blockers(p); wu = waiting_union(p, s)
    items = [f'<li><label><input type="checkbox" data-check="{attr(k + "|" + sval(f.get("id")))}"> {zpill(f.get("severity"))} <a class="code" data-jump="{attr("finding--" + sval(f.get("id")))}" tabindex="0">{html.escape(sval(f.get("id")))}</a> {yv(f.get("summary"), k)}</label></li>' for rel, f in bl]
    def wlink(w):
        t = yv(w, k)
        return re.sub(r'QZ-1 到 QZ-7', f'<a class="code" data-jump="{attr(k + "--quiz")}" tabindex="0">QZ-1 到 QZ-7</a>', t)
    items += [f'<li><label><input type="checkbox" data-check="{attr(k + "|" + sval(w))}"> {wlink(w)} <a href="{attr(src)}" title="{attr(src)}">{lab("來源")}</a></label></li>' for src, w in wu]
    bl_html = f'<ul class="todo check">{capped(items)}</ul>' if items else f'<p class="placeholder">沒有阻擋項</p>'
    bl_txt = '\n'.join([f"- [ ] {sval(f.get('severity'))} {sval(f.get('id'))} {sval(f.get('summary'))}" for rel, f in bl] + [f"- [ ] {sval(w)} ({src})" for src, w in wu]) or '(none)'
    secs.append(('阻擋清單', bl_html, bl_txt))
    rel, d = newest_review(p, 'deliverable-review')
    acs = [a for r in yd.get('requirements') or [] if isinstance(r, dict) for a in (r.get('acs') or []) if isinstance(a, dict)]
    unv = [f for f in (d.get('findings') or [] if d else []) if isinstance(f, dict) and sval(f.get('status')) == 'unverified']
    qs = quiz_state()
    q = (yaml_dev or {}).get('quiz') if yaml_dev else {}
    qitems = [i for i in ((q.get('items') or []) if isinstance(q, dict) else []) if isinstance(i, dict)]
    qpass = sum(1 for i in qitems if sval(i.get('result')) == 'pass')
    v_html = (f'<p>{lab("驗收條件")} <span class="num">{len(acs)}</span> · {lab("未驗證")} <span class="num">{len(unv)}</span>'
              + (f' · {lab("最新交付審查")} {zh(d.get("verdict"))} <a href="{attr(rel)}" title="{attr(rel)}">{lab("紀錄")}</a>' if d else f' · {zpill("pending")}')
              + f'</p><p>{lab("理解測驗")} {zpill(qs)}' + (f' <span class="num">{qpass}/{len(qitems)}</span>' if qitems else '') + '</p>')
    if unv:
        def last_id(fp):
            ids = re.findall(r'\b((?:AC|REQ|INV|US)-\d+)\b', sval(fp)); return ids[-1] if ids else sval(fp)
        unv_sorted = sorted(unv, key=lambda f: (re.sub(r'\d+', lambda m: m.group(0).zfill(4), last_id(f.get('field')))))
        v_html += '<ul>' + capped([f'<li>{link_codes(last_id(f.get("field")), k)} {zpill("unverified")}</li>' for f in unv_sorted]) + '</ul>'
        v_html += collapsed(f'<span class="lead">{lab("未驗證詳情")}</span> <span class="num">{len(unv)}</span>', '<ul>' + ''.join(f'<li>{link_codes(last_id(f.get("field")), k)} · {yv(f.get("summary"), k)}</li>' for f in unv_sorted) + '</ul>')
    nb = sum(1 for i, st, l in ledger_stage_lines if st.startswith(('build', 'deliverable-review', 'phase-ship')))
    if nb:
        v_html += f'<p class="meta">{lab("建置帳")} <a class="code" data-jump="{attr(k + "--ledger")}" tabindex="0">{nb}</a> {lab("則（含每個 prose commit 的 m-skill-review 裁決）")}</p>'
    v_html += quiz_html(p)
    v_txt = f"ACs {len(acs)} · unverified {len(unv)}" + (f" · deliverable-review {sval(d.get('verdict'))}" if d else ' · deliverable-review pending') + f"\nquiz: {ZH[qs]}" + (f" {qpass}/{len(qitems)}" if qitems else '') + ''.join(f"\n- {sval(f.get('field'))} · {sval(f.get('summary'))}" for f in unv)
    if qs == 'n/a': v_txt += '\nquiz waived: zero delta'
    v_txt += ''.join(f"\n- {sval(i.get('id'))} · {sval(i.get('question'))}" for i in qitems)
    secs.append(('怎麼驗的', v_html, v_txt))
    dn = [e for e in (yaml_dev.get('entries') or []) if isinstance(e, dict)] if yaml_dev else []
    by_panel = {}
    for e in dn: by_panel.setdefault(sval(e.get('panel')), []).append(sval(e.get('id')))
    sc_html = f'<p>{lab("偏離契約")} <span class="num">{len(dn)}</span> · ' + ' · '.join(f'{zh(pn)} {" ".join(link_codes(i, k) for i in ids)}' for pn, ids in by_panel.items()) + f' · <a data-jump="{attr(k + "--structure")}" tabindex="0" class="code">結構變化</a></p>' if dn else f'<p>{lab("偏離契約")} <span class="num">0</span> · <a data-jump="{attr(k + "--structure")}" tabindex="0" class="code">結構變化</a></p>'
    sc_txt = '\n\n'.join(f"### {ZH.get(PANEL_OF[key], label)} — {'built ≠ planned' if dev_entries_for_panel(key) else 'as planned'}\n\n{sval(text)}" + ''.join(f"\n- {sval(e.get('id'))} · {sval(e.get('gap'))} · 處置: {sval(e.get('disposition'))}" for e in dev_entries_for_panel(key)) for (label, key), (_, text) in zip(YAML_PANELS, s['panels'] or []))
    secs[0] = ('決策', secs[0][1] + sc_html, secs[0][2] + '\n\n' + sc_txt)
    check = [(zh(g), zpill(st), '') for g, st, d, rel, _ in gate_rows(p)]
    ck_items = [f'<li>{zpill(st)} {zh(g)}</li>' for g, st, d, rel, _ in gate_rows(p) if st in ('fail', 'pending')]
    ck_items += [f'<li>{zpill(f.get("severity"))} {html.escape(sval(f.get("id")))}</li>' for rel, f in bl]
    ck_items += [f'<li>{zpill("pending")} {yv(w, k)}</li>' for src, w in wu]
    footer = zpill('approvable') if state == 'approvable' else f'{zpill("blocked")} <span class="num">{n}</span>' if state == 'blocked' else zpill('not-reviewed')
    ck_html = f'<ol class="checklist">{capped(ck_items)}</ol><p class="footer">{lab("結論")} {footer}</p>'
    ck_txt = '\n'.join(f"- [ ] {ZH[g]}: {ZH[st]}" for g, st, *_ in gate_rows(p) if st in ('fail', 'pending')) + ''.join(f"\n- [ ] {sval(f.get('severity'))} {sval(f.get('id'))}" for rel, f in bl) + ''.join(f"\n- [ ] {sval(w)}" for src, w in wu) + f"\n\n結論: {ZH[state]}{f' ({n})' if n else ''}"
    secs.append(('檢查表', ck_html, ck_txt))
    return secs

LEDGER_STAGE_RE = re.compile(r'^- ((?:Q|A|C|R|B)-\d+) \(([^)]*stage: ([^),]+)[^)]*)\)')
ledger_stage_lines = []   # (id, stage, line) — ledger rows tagged with a stage, in file order
for rel in files:
    if os.path.basename(rel).startswith('assay-') and rel.endswith('.md'):
        for line in read(os.path.join(epic_dir, rel)).splitlines():
            m = LEDGER_STAGE_RE.match(line)
            if m: ledger_stage_lines.append((m.group(1), m.group(3).strip(), line[2:].strip()))

# 首頁
front = []
pr_body_text = None
if current:
    s0 = specs[current['spec']]
    secs = front_sections(current, s0)
    front.append('<article class="front">' + ''.join(f'<section class="fs"><h3>{html.escape(l)}</h3>{h}</section>' for l, h, _ in secs if h is not None) + '</article>')
    pr_body_text = '\n\n'.join(f'## {l}\n\n{t}' for l, _, t in secs) + '\n'
else:
    waiting = []
    for sp in spec_files:
        st = specs[sp]['fm'].get('status', '')
        if st and st.lower() != 'accepted' and not os.path.basename(sp).startswith('assay-'):
            waiting.append(f'{lab("接受 spec")} <code>{html.escape(os.path.basename(sp))}</code> — {zpill(st)}')
        if specs[sp]['markers']:
            waiting.append(f'{specs[sp]["markers"]} <code>[NEEDS CLARIFICATION]</code> / <code>[unverified]</code> <code>{html.escape(os.path.basename(sp))}</code>')
    for q in bullets(index_sections.get('Open Questions', '')):
        if not q.startswith('*('): waiting.append(inline(q, 'epic'))
    front.append('<article class="front"><section class="fs"><h3>阻擋清單</h3>' + (f'<ul class="todo">{capped([f"<li>{w}</li>" for w in waiting])}</ul>' if waiting else '<p class="placeholder">沒有阻擋項</p>') + '</section></article>')
tab['首頁']['epic'] = front

# 契約 — the newest YAML phase open, older phases and legacy md folded; epic-level: aim, foundation, ledger, ADRs (folded)
for p in phases:
    s = specs[p['spec']]
    if 'yaml' in s:
        card = yaml_contract_card(p, s)
        if p is not current:
            card = f'<article><h3 class="file-title">{yv(s["yaml"].get("title"), p["key"])}</h3>{collapsed("<span class=\"lead\">" + lab("契約全文") + "</span>", card)}</article>'
        tab['契約'][p['key']].append(card); continue
    parts = [f'<h3 class="file-title">{html.escape(s["title"])}</h3>', meta_line(s['fm'], f'{fspan(p["spec"])}')]
    for flab in ('Intention', 'Aim', 'Out of scope'):
        v = field(s['foundation'], flab)
        if v: parts.append(f'<p><strong>{flab}.</strong> {inline(v, p["key"])}</p>')
    if s['stories']:
        parts.append('<h4>User stories</h4><ul>' + ''.join(f'<li>{inline(b, p["key"])}</li>' for b in s['stories']) + '</ul>')
    if s['reqs']:
        rows = ''
        for rid, headline in s['reqs']:
            acs = [c[1] for c in s['ac_rows'] if c[0] == rid]
            rows += f'<tr><td class="num">{link_codes(rid, p["key"])}</td><td>{inline(headline, p["key"])}</td><td class="num">{" ".join(link_codes(a, p["key"]) for a in acs)}</td></tr>'
        parts.append(f'<h4>Requirements</h4><div class="tbl"><table><tr><th>REQ</th><th>SHALL</th><th>驗收條件</th></tr>{rows}</table></div>')
    full = md_to_html(s['body'], p['key'], define=True)
    parts.append(collapsed('<span class="lead">Full spec text</span> <span class="muted">(' + str(s['body'].count(chr(10)) + 1) + ' lines; the AC and REQ anchors live here)</span>', full))
    legacy_summ = '<span class="lead">' + lab('舊版 markdown spec') + '</span> ' + html.escape(s['title'])
    tab['契約'][p['key']].append(f'<article>{collapsed(legacy_summ, "".join(parts))}</article>')
epic_parts = []
if aim: epic_parts.append(f'<p class="aim">{inline(aim, "epic")}</p>' + meta_line(index_fm))
if bullets(index_sections.get('Foundation', '')):
    epic_parts.append(collapsed(f'<span class="lead">{lab("基礎")}</span>', md_to_html(index_sections['Foundation'], 'epic')))
for h in ('Pivots', 'Open Questions'):
    if h in index_sections and index_sections[h].strip() and not index_sections[h].strip().startswith('*('):
        epic_parts.append(f'<h4>{lab(LAB_ZH.get(h, h))}</h4>' + md_to_html(index_sections[h], 'epic'))
if phase_table_rows:
    rows = [f'<tr><td class="num">{html.escape(r[0])}</td><td>{inline(r[1], "epic")}</td><td>{zpill(r[4].lower())}</td></tr>' for r in phase_table_rows]
    epic_parts.append(collapsed(f'<span class="lead">{lab("epic 歷史")}</span> <span class="num">{len(rows)}</span>', f'<div class="tbl"><table><tr><th>#</th><th>標題</th><th>狀態</th></tr>{"".join(rows)}</table></div>'))
if epic_parts: tab['契約']['epic'].append('<article>' + ''.join(epic_parts) + '</article>')
adr_lines = []
for kk in sorted(adr_files, key=lambda x: int(x.split('--')[1])):
    fm, body = frontmatter(read(adr_files[kk]))
    n = kk.split('--')[1]
    forms = sorted(c for c in adr_cited if adr_key(c) == kk)
    code = f'ADR-{int(n):04d}'
    cite = ''
    for c in forms + [code]:
        cite = sentence_citing(c, texts_for_citation)
        if cite: break
    relpath = os.path.relpath(adr_files[kk], epic_dir)
    adr_lines.append(f'<li id="{kk}"><span class="num"><a class="code" href="{attr(relpath)}">{html.escape(code)}</a></span> <strong>{html.escape(first_h1(body) or os.path.basename(adr_files[kk]))}</strong> {zpill(fm.get("status", "").lower())}'
                     + (f'<br><span class="cite">{inline(cite, "epic")}</span>' if cite else '') + '</li>')
if adr_lines:
    tab['契約']['epic'].append('<article>' + collapsed(f'<span class="lead">{lab("ADR")}</span> <span class="num">{len(adr_lines)}</span>', f'<ul class="adr">{"".join(adr_lines)}</ul>') + '</article>')

# 結構變化 — picture first, then the four panels with D-n badges (entries folded), legacy lines folded
def dev_badge(key):
    hits = dev_entries_for_panel(key)
    return f'<span class="pill warn">{zh("built-ne-planned")} · {len(hits)}</span>' if hits else zpill('as-planned', 'ok')
for p in phases:
    s = specs[p['spec']]
    devs = dev_lines_for(p)
    if 'yaml' in s:
        d = s['yaml'].get('delta') if isinstance(s['yaml'].get('delta'), dict) else {}
        blocks = [b for b in d.get('blocks') or [] if isinstance(b, dict)]; edges = [e for e in d.get('edges') or [] if isinstance(e, dict)]
        pic = structure_svg(blocks, edges) if blocks else '<p class="placeholder">no structural delta declared</p>'
        ov = [f for f in files if os.path.basename(f) == 'structure-overlay.html']
        if ov: pic += f'<p class="meta">{lab("互動疊圖")} <a href="{attr(ov[0])}">{fspan(ov[0])}</a></p>'
        cards = ''
        if s['panels']:
            for (label, key), (_, text) in zip(YAML_PANELS, s['panels']):
                hits = dev_entries_for_panel(key)
                body = f'<p>{yv(text, p["key"])}</p>'
                if hits:
                    body += collapsed(f'<span class="lead">{lab("偏離")}</span> <span class="num">{len(hits)}</span>', '<ul>' + ''.join(dev_entry_html(e, p['key']) for e in hits) + '</ul>')
                cards += f'<section class="panel"><h4>{zh(PANEL_OF[key])} {dev_badge(key)}</h4>{body}</section>'
        other = dev_entries_for_panel('none')
        if other:
            cards += f'<section class="panel"><h4>{zh("none")}</h4><ul>' + ''.join(dev_entry_html(e, p['key']) for e in other) + '</ul></section>'
        if devs:
            cards += collapsed(f'<span class="lead">{lab("舊版偏離行")}</span> <span class="num">{len(devs)}</span>', '<ul>' + ''.join(f'<li>{inline(x, p["key"])}</li>' for x in devs) + '</ul>')
        tab['結構變化'][p['key']].append(f'<article id="{attr(p["key"] + "--structure")}"><h3 class="file-title">{yv(s["yaml"].get("title"), p["key"])}</h3>{pic}<div class="panels">{cards}</div></article>')
        continue
    if s['panels'] is None:
        tab['結構變化'][p['key']].append(f'<article><h3 class="file-title">{html.escape(s["title"])}</h3><p class="placeholder">no phase map in this spec</p></article>')
        continue
    cards = ''
    for label, md in s['panels']:
        key = label.split()[0].lower()
        hits = [d for d in devs if key in d.lower()]
        mark = zpill('built-ne-planned', 'warn') if hits else zpill('as-planned', 'ok')
        body = md_to_html(md, p['key'])
        if hits:
            body += '<p class="delta"><strong>Delta (deviation log):</strong></p><ul>' + ''.join(f'<li>{inline(d, p["key"])}</li>' for d in hits) + '</ul>'
        cards += f'<section class="panel"><h4>{html.escape(label)} {mark}</h4>{body}</section>'
    other = [d for d in devs if not any(l.split()[0].lower() in d.lower() for l, _ in s['panels'])]
    if other:
        cards += '<section class="panel"><h4>Other deviations</h4><ul>' + ''.join(f'<li>{inline(d, p["key"])}</li>' for d in other) + '</ul></section>'
    lp_summ = '<span class="lead">' + lab('舊版 phase map') + '</span> ' + html.escape(s['title'])
    lp_body = '<div class="panels">' + cards + '</div>'
    tab['結構變化'][p['key']].append(f'<article>{collapsed(lp_summ, lp_body)}</article>')
if not phases:
    tab['結構變化']['epic'].append('<p class="placeholder">no phase map in this epic (no spec carries a <code>## Phase map</code> section)</p>')
ed = dev_lines_for(EPIC)
if ed:
    tab['結構變化']['epic'].append('<article>' + collapsed(f'<span class="lead">{lab("偏離紀錄（epic 層）")}</span> <span class="num">{len(ed)}</span>', '<ul>' + ''.join(f'<li>{inline(d, "epic")}</li>' for d in ed) + '</ul>') + '</article>')

# 紀錄 — per YAML phase: round summary table first, findings folded, deviation entries folded; then md-era files; close sections at epic level
records = {}  # (phase key, dir) -> [rel]
for p in phases:
    s = specs[p['spec']]
    if 'yaml' not in s: continue
    k = p['key']
    rs = reviews_for(p)
    rows = ''
    raw_links = []
    for rel, d in rs:
        raw = [f for f in files if os.path.dirname(f) == os.path.dirname(rel) and f != rel]
        links = ' '.join(f'<a href="{attr(f)}"><span class="file">{html.escape(os.path.basename(f))}</span></a>' for f in raw)
        residual = sum(1 for f in d.get('findings') or [] if isinstance(f, dict) and sval(f.get('status')) in ('open', 'unverified'))
        rows += (f'<tr><td>{zh(d.get("gate"))}</td><td class="num">{yv(d.get("round"), k)}</td><td>{zpill(d.get("verdict"))}</td>'
                 f'<td>{counts_html(d, k)}</td><td class="num">{residual}</td><td>{lab(next_action(d))}</td></tr>')
        raw_links.append((rel, raw))
    summary = f'<div class="tbl"><table><tr><th>門</th><th>輪</th><th>裁決</th><th>發現</th><th>待處理</th><th>下一步</th></tr>{rows}</table></div>' if rs else '<p class="placeholder">no review.yaml for this phase yet</p>'
    folds = ''
    for rel, d in rs:
        fl = [f for f in d.get('findings') or [] if isinstance(f, dict)]
        items = ''
        for f in sorted(fl, key=lambda f: (SEV_ORDER.get(sval(f.get('severity')), 9), sval(f.get('id')))):
            loc = sval(f.get('field')) or (sval(f.get('file')) + (f":{f['line']}" if f.get('line') is not None else ''))
            items += f'<li id="{attr("finding--" + sval(f.get("id")))}">{zpill(f.get("severity"))} {zpill(f.get("status"))} {html.escape(sval(f.get("id")))} · {link_codes(loc, k) if sval(f.get("field")) else html.escape(loc)} · {yv(f.get("summary"), k)}<br><span class="muted">{lab("處置")} {yv(f.get("fix"), k)}</span></li>'
        raw = next((r for rr, r in raw_links if rr == rel), [])
        rawl = ''.join(f'<li><a href="{attr(f)}" title="{attr(f)}">{fspan(os.path.basename(f))}</a></li>' for f in raw)
        folds += collapsed(f'<span class="lead">{zh(d.get("gate"))} {lab("第")} {yv(d.get("round"), k)} {lab("輪")} · {lab("發現")} <span class="num">{len(fl)}</span> · {lab("原始檔")} <span class="num">{len(raw)}</span></span>', f'<ul class="files">{rawl}</ul><ul class="findings">{items}</ul>')
    if yaml_dev:
        dn = [e for e in (yaml_dev.get('entries') or []) if isinstance(e, dict)]
        folds += collapsed(f'<span class="lead">{lab("偏離紀錄")}</span> <span class="num">{len(dn)}</span>', '<ul>' + ''.join(dev_entry_html(e, k, anchor=False) for e in dn) + '</ul>')
    if ledger_stage_lines:
        items = ''.join(f'<li>{inline(l, k)}</li>' for i, st, l in ledger_stage_lines if st.startswith(('build', 'deliverable-review', 'phase-ship')))
        folds += collapsed(f'<span class="lead">{lab("建置帳")}</span> <span class="num">{sum(1 for i, st, l in ledger_stage_lines if st.startswith(("build", "deliverable-review", "phase-ship")))}</span>', f'<ul id="{attr(k + "--ledger")}">{items}</ul>')
    tab['紀錄'][k].append(f'<article><h3 class="file-title">{yv(s["yaml"].get("title"), k)}</h3>{summary}{folds}</article>')
for rel in files:
    if rel == 'index.md': continue
    p = phase_of(rel); st = stage_of(rel); path = os.path.join(epic_dir, rel)
    if st == 'record':
        records.setdefault((p['key'], os.path.dirname(rel).split('/')[0]), []).append(rel); continue
    if st == 'overlay' or os.path.basename(rel) == 'review.yaml' or os.path.basename(rel) == 'deviation.yaml': continue
    if st == '契約' and rel not in spec_files:
        fm, body = frontmatter(read(path))
        tab['契約']['epic' if p is EPIC else p['key']].append(file_card(rel, first_h1(body) or rel, fm, body, p['key']))
        continue
    if rel in spec_files and os.path.basename(rel).startswith('assay-'):
        fm, body = frontmatter(read(path))
        tab['契約'][p['key'] if p is not EPIC else 'epic'].append(file_card(rel, first_h1(body) or rel, fm, body, p['key'], ledger=True))
        continue
    if rel in spec_files: continue
    if st == 'Ship':
        if rel.endswith('.html'):
            raw = read(path); t = re.search(r'<title>(.*?)</title>', raw, re.DOTALL | re.IGNORECASE)
            inner = link_codes_in_html(html_body_inner(raw), p['key'])
            tab['紀錄'][p['key']].append(f'<article><h3 class="file-title">{html.escape(html.unescape(t.group(1).strip()) if t else rel)}</h3><p class="meta">{fspan(rel)}</p>{collapsed("<span class=\"lead\">" + lab("舊版 explainer") + "</span>", "<div class=\"embedded\">" + inner + "</div>")}</article>')
        else:
            fm, body = frontmatter(read(path))
            tab['紀錄'][p['key']].append(file_card(rel, first_h1(body) or rel, fm, body, p['key']))
        continue
    if st == 'Build':
        base = os.path.basename(rel).lower()
        fm, body = frontmatter(read(path))
        if base == 'review.md':
            v = verdict_lines(body)
            inner = (f'<ul class="verdict">{"".join(f"<li>{inline(l, p[chr(107)+chr(101)+chr(121)])}</li>" for l in v)}</ul>' if v else '<p class="muted">no verdict line found in review.md</p>') + collapsed('<span class="lead">Synthesis</span> <span class="muted">(review.md)</span>', md_to_html(body, p["key"]))
            lr_summ = '<span class="lead">' + lab('舊版審查') + '</span> <span class="file">' + html.escape(rel) + '</span>'
            tab['紀錄'][p['key']].append(f'<article>{collapsed(lr_summ, inner)}</article>')
        elif base.startswith('deviation'):
            continue
        else:
            tab['紀錄'][p['key']].append(file_card(rel, first_h1(body) or rel, fm, body, p['key']))
for p in phases:
    if 'yaml' in specs[p['spec']]: continue
    d = dev_lines_for(p)
    if d:
        tab['紀錄'][p['key']].insert(0, '<article><h3 class="file-title">Deviation log</h3><ul>' + ''.join(f'<li>{inline(x, p["key"])}</li>' for x in d) + '</ul></article>')
ev = index_sections.get('Evidence Reckoning', '').strip()
for (pk, d), rels in sorted(records.items()):
    items = ''.join(f'<li><a href="{attr(r)}">{fspan(r)}</a></li>' for r in rels)
    summ = f'<span class="lead">{lab("審查原始檔")}</span> <span class="muted">{html.escape(d)} · <span class="num">{len(rels)}</span></span>'
    tab['紀錄'][pk].append(f'<article>{collapsed(summ, f"<ul class=\"files\">{items}</ul>")}</article>')
close_parts = []
present = [h for h in ('Retrospective', 'Evidence Reckoning', 'Disposition') if h in index_sections and index_sections[h].strip() and not index_sections[h].strip().startswith('*(')]
gm_hits = []
if root:
    gm = os.path.join(root, '.touchstone', 'gate-miss.md')
    if os.path.isfile(gm):
        gm_hits = [l for l in read(gm).splitlines() if slug in l]
close_parts.append(f'<p class="meta">{lab("結案帳")} · ' + ' · '.join(f'{lab(LAB_ZH.get(h, h))} {zpill("pass" if h in present else "pending")}' for h in ('Retrospective', 'Evidence Reckoning', 'Disposition')) + f' · {lab("漏抓帳")} <span class="num">{len(gm_hits)}</span></p>')
for h in ('Retrospective', 'Evidence Reckoning', 'Disposition'):
    if h in index_sections:
        close_parts.append(collapsed(f'<span class="lead">{lab(LAB_ZH.get(h, h))}</span>', md_to_html(index_sections[h], 'epic')))
if root and os.path.isfile(os.path.join(root, '.touchstone', 'gate-miss.md')):
    items = ''.join(f'<li>{inline(l.lstrip("- ").strip(), "epic")}</li>' for l in gm_hits)
    close_parts.append(collapsed(f'<span class="lead">{lab("漏抓帳 gate-miss.md")}</span> <code>{html.escape(slug)}</code> <span class="num">{len(gm_hits)}</span>', f'<ul>{items}</ul>' if gm_hits else '<p class="muted">none</p>'))
tab['紀錄']['epic'].append('<article>' + ''.join(close_parts) + '</article>')

# ---------- render page ----------
CSS = """
:root{--bg:#f6f8f6;--panel:#ffffff;--ink:#1b2422;--muted:#5e6b67;--line:#d6ddd9;--accent:#1e6f6a;--accent-ink:#ffffff;--ok:#2f7d4f;--ok-bg:#e3f1e8;--warn:#9a6a12;--warn-bg:#f6ecd4;--crit:#a63a3a;--crit-bg:#f5dede;--code:#eef2ef;--fold:#f0f3f1}
:root[data-theme="dark"]{--bg:#131817;--panel:#1b2220;--ink:#e6ece9;--muted:#93a09c;--line:#2b3532;--accent:#63c4b9;--accent-ink:#0f1a18;--ok:#7fd39f;--ok-bg:#1d3327;--warn:#e2b45b;--warn-bg:#3a2f16;--crit:#f08a8a;--crit-bg:#3b1f1f;--code:#222b28;--fold:#1f2725}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#131817;--panel:#1b2220;--ink:#e6ece9;--muted:#93a09c;--line:#2b3532;--accent:#63c4b9;--accent-ink:#0f1a18;--ok:#7fd39f;--ok-bg:#1d3327;--warn:#e2b45b;--warn-bg:#3a2f16;--crit:#f08a8a;--crit-bg:#3b1f1f;--code:#222b28;--fold:#1f2725}}
*{box-sizing:border-box}html{font-size:16px}
body{margin:0;background:var(--bg);color:var(--ink);font-family:"Avenir Next","Segoe UI",system-ui,-apple-system,sans-serif;line-height:1.55}
.top{position:sticky;top:0;z-index:2;background:var(--bg);border-bottom:1px solid var(--line);padding:.6rem 1.25rem;display:flex;align-items:baseline;gap:1.25rem;flex-wrap:wrap}
.top h1{font-family:"Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;font-weight:600;font-size:1.25rem;margin:0;text-wrap:balance}
.top .slug{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-size:.8rem;color:var(--muted)}
.tabs{display:flex;gap:.25rem;flex-wrap:wrap}.tabs button{font:inherit;font-size:.85rem;letter-spacing:.02em;background:transparent;color:var(--muted);border:0;border-bottom:2px solid transparent;padding:.35rem .6rem;cursor:pointer}
.tabs button:hover{color:var(--ink)}.tabs button[aria-selected="true"]{color:var(--accent);border-bottom-color:var(--accent)}
.tabs button:focus-visible,.theme:focus-visible,summary:focus-visible,a:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.theme{margin-left:auto;font:inherit;font-size:.8rem;background:transparent;border:1px solid var(--line);color:var(--muted);border-radius:999px;padding:.2rem .7rem;cursor:pointer}
main{max-width:76ch;margin:0 auto;padding:1.25rem 1.25rem 4rem}.tab{display:none}.tab.active{display:block}
.phase{margin:1.5rem 0 2.5rem}.phase>h2{font-family:"Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;font-weight:600;font-size:1.35rem;margin:0 0 .25rem;display:flex;align-items:baseline;gap:.6rem;flex-wrap:wrap;text-wrap:balance}
.phase>.meta{margin:0 0 1rem}
article{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:1rem 1.25rem;margin:0 0 1rem}
article>h3.file-title{font-size:1.05rem;margin:0 0 .15rem;font-weight:600}h3{font-size:1rem;margin:1.25rem 0 .4rem}h4{font-size:.9rem;margin:1rem 0 .3rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);font-weight:600}
h5,h6{font-size:.95rem;margin:.9rem 0 .3rem}
p{margin:.45rem 0}.aim{font-family:"Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;font-size:1.25rem;line-height:1.4;margin:.25rem 0 .5rem;text-wrap:balance}
.meta{font-size:.8rem;color:var(--muted);margin:.1rem 0 .75rem}.meta .file,.file{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-size:.78rem}
.muted{color:var(--muted)}.lead{font-weight:500}.placeholder{color:var(--muted);font-style:italic}
.pill{display:inline-block;white-space:nowrap;font-size:.72rem;font-weight:600;letter-spacing:.03em;padding:.05rem .5rem;border-radius:999px;vertical-align:middle;border:1px solid transparent}
.pill.ok{color:var(--ok);background:var(--ok-bg)}.pill.warn{color:var(--warn);background:var(--warn-bg)}.pill.crit{color:var(--crit);background:var(--crit-bg)}.pill.accent{color:var(--accent);border-color:var(--accent)}.pill.muted{color:var(--muted);border-color:var(--line)}
ul,ol{padding-left:1.3rem;margin:.35rem 0}li{margin:.2rem 0}ul.todo li{margin:.4rem 0}ul.adr{list-style:none;padding:0}ul.adr li{padding:.5rem 0;border-top:1px solid var(--line)}ul.adr li:first-child{border-top:0}
.cite{font-size:.9rem;color:var(--muted)}ul.verdict{list-style:none;padding:0}ul.verdict li{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-size:.82rem;padding:.15rem 0}
ul.files{list-style:none;padding:0;font-size:.82rem}
pre{background:var(--code);padding:.75rem .9rem;border-radius:4px;overflow-x:auto;font-size:.82rem;line-height:1.45}code{font-family:ui-monospace,"SF Mono",Menlo,monospace;background:var(--code);padding:.05rem .3rem;border-radius:3px;font-size:.86em}pre code{background:none;padding:0}
.tbl{overflow-x:auto;margin:.5rem 0}table{border-collapse:collapse;width:100%;font-size:.9rem}th,td{border-bottom:1px solid var(--line);padding:.35rem .6rem;text-align:left;vertical-align:top}th{font-size:.75rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);font-weight:600}
td.num,.num,a.code,.undef{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-variant-numeric:tabular-nums;font-size:.85rem}
a{color:var(--accent)}a.code,[data-jump]{color:var(--accent);cursor:pointer;text-decoration:none;border-bottom:1px dotted var(--accent)}
.undef{color:var(--crit);background:var(--crit-bg);border-radius:3px;padding:0 .25rem;cursor:help}.undef::after{content:" (undefined)";font-size:.75em}
details.fold{border-top:1px solid var(--line);margin-top:.75rem;padding-top:.5rem}details.fold>summary{cursor:pointer;color:var(--muted);list-style:none}details.fold>summary::before{content:"▸ ";color:var(--accent)}details.fold[open]>summary::before{content:"▾ "}.fold-body{margin-top:.75rem}
.panels{display:grid;gap:.75rem}.panel{background:var(--fold);border-radius:4px;padding:.75rem 1rem}.panel h4{margin:0 0 .4rem;display:flex;gap:.5rem;align-items:baseline}.delta{margin-top:.6rem}
.notes{color:var(--muted);font-size:.85rem;border:1px dashed var(--line);padding:.5rem .75rem;border-radius:4px;margin-bottom:1rem}
.strip{position:sticky;top:3.1rem;z-index:1;background:var(--panel);border-bottom:1px solid var(--line);padding:.4rem 1.25rem;display:flex;gap:1rem;flex-wrap:wrap;align-items:center;font-size:.85rem}.strip .decision{font-weight:600}.strip .g{white-space:nowrap}.decision{font-family:"Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;font-size:1.3rem;margin:.2rem 0}section.fs{margin:0 0 1.25rem}section.fs>h3{font-size:.8rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin:0 0 .4rem}ul.check{list-style:none;padding:0}ul.check li{margin:.4rem 0}ul.check input{margin-right:.4rem}ol.checklist{padding-left:1.3rem}.footer{font-size:1.05rem;margin-top:.6rem}abbr.enum{text-decoration:none;border-bottom:1px dotted var(--muted)}table.gates td{vertical-align:middle}ul.findings li{margin:.5rem 0}details.inl{display:inline}details.inl>summary{display:inline;cursor:pointer;color:var(--muted);font-size:.8rem}.figure{margin:.5rem 0}.figure svg{width:100%;height:auto;max-width:720px;display:block;margin:0 auto}.embedded{border-left:3px solid var(--line);padding-left:1rem}.label{font-size:.72rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);font-weight:600}.waiver{color:var(--warn);background:var(--warn-bg);padding:.4rem .7rem;border-radius:4px}section.ship{margin:0 0 1.25rem}tr.ac td{font-size:.85rem;color:var(--muted)}ol.quiz li{margin:.5rem 0}blockquote{margin:.5rem 0;padding-left:.9rem;border-left:3px solid var(--line);color:var(--muted)}
[id]{scroll-margin-top:4.5rem}:target,.flash{outline:2px solid var(--accent);outline-offset:4px;border-radius:3px}
@media (prefers-reduced-motion: no-preference){details.fold>summary{transition:color .15s}}
body{overflow-wrap:anywhere}.top>*,.strip>*,.tabs{min-width:0}.tabs{flex:1 1 auto}.top h1{flex:1 1 100%}.file,code,a.code,[data-jump]{overflow-wrap:anywhere;word-break:break-word}
.strip .g{white-space:normal}.panels{grid-template-columns:1fr}svg.structure{max-width:100%}
@media (max-width:640px){html{font-size:15px}.top{padding:.5rem .75rem;gap:.5rem}.strip{top:auto;position:static;padding:.4rem .75rem;font-size:.8rem}main{padding:.75rem .6rem 3rem}article{padding:.75rem .8rem}.decision{font-size:1.1rem}.aim{font-size:1.05rem}.tbl table{font-size:.82rem}th,td{padding:.3rem .4rem}}
"""
JS = """
(function(){var root=document.documentElement;var key='dossier-theme';
try{var t=localStorage.getItem(key);if(t)root.setAttribute('data-theme',t);}catch(e){}
function show(id){document.querySelectorAll('.tab').forEach(function(s){s.classList.toggle('active',s.id==='tab-'+id)});
document.querySelectorAll('.tabs button').forEach(function(b){b.setAttribute('aria-selected',b.dataset.tab===id?'true':'false')});}
document.querySelectorAll('.tabs button').forEach(function(b){b.addEventListener('click',function(){show(b.dataset.tab);try{localStorage.setItem('dossier-tab',b.dataset.tab)}catch(e){}})});
var initial='0';try{initial=localStorage.getItem('dossier-tab')||'0'}catch(e){}
function reveal(el){var tab=el.closest('.tab');if(tab)show(tab.id.replace('tab-',''));var d=el.closest('details');while(d){d.open=true;d=d.parentElement&&d.parentElement.closest('details');}}
function jump(id){var el=document.getElementById(id);if(!el)return false;reveal(el);el.scrollIntoView({block:'start'});el.classList.remove('flash');void el.offsetWidth;el.classList.add('flash');return true;}
show(initial);
if(location.hash){jump(decodeURIComponent(location.hash.slice(1)));}
document.querySelectorAll('[data-jump]').forEach(function(a){function go(e){e.preventDefault();jump(a.getAttribute('data-jump'));}a.addEventListener('click',go);a.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' ')go(e);});});
window.addEventListener('hashchange',function(){jump(decodeURIComponent(location.hash.slice(1)));});
document.querySelectorAll('input[data-check]').forEach(function(c){var key='dossier-check:'+c.getAttribute('data-check');try{c.checked=localStorage.getItem(key)==='1'}catch(e){}c.addEventListener('change',function(){try{localStorage.setItem(key,c.checked?'1':'0')}catch(e){}})});
document.querySelector('.theme').addEventListener('click',function(){var cur=root.getAttribute('data-theme');var dark=cur?cur==='dark':window.matchMedia('(prefers-color-scheme: dark)').matches;var next=dark?'light':'dark';root.setAttribute('data-theme',next);try{localStorage.setItem(key,next)}catch(e){}});
})();
"""

def phase_header(g):
    if g is EPIC:
        return '<h2>Epic 層</h2>'
    s = specs[g['spec']]
    title = f'第 {sval(s["yaml"].get("phase"))} 階段 · {sval(s["yaml"].get("title"))}' if 'yaml' in s else g['title']
    return f'<h2>{html.escape(title)}</h2><p class="meta">{fspan(g["spec"])}</p>'

def render_tab(i, t):
    parts = []
    for g in groups:
        items = tab[t][g['key']]
        if not items: continue
        hdr = '' if t == '首頁' else phase_header(g)
        parts.append(f'<section class="phase" data-phase="{attr(g["key"])}">{hdr}{"".join(items)}</section>')
    if not parts:
        parts.append('<p class="muted">nothing in this stage yet</p>')
    return f'<section class="tab" id="tab-{i}">{"".join(parts)}</section>'

buttons = ''.join(f'<button data-tab="{i}" aria-selected="false">{html.escape(t)}</button>' for i, t in enumerate(TABS))
tabs_html = ''.join(render_tab(i, t) for i, t in enumerate(TABS))
notes_html = f'<div class="notes">{" ".join(html.escape(n) for n in notes)}</div>' if notes else ''
def strip_gate(g, st, rel):
    tail = ''
    if st in ('fail', 'pending'):
        tail = ' · ' + zh(GATE_OWNER.get(g, ''))
        if rel:
            tail += ' · <a href="' + attr(rel) + '" title="' + attr(rel) + '">' + lab('紀錄') + '</a>'
    return '<span class="g">' + zh(g) + ' ' + zpill(st) + tail + '</span>'
if current:
    st, n = decision(current, specs[current['spec']])
    strip_html = f'<div class="strip"><span class="decision">{html.escape(sval(specs[current["spec"]]["yaml"].get("epic")))} · 第 {html.escape(sval(specs[current["spec"]]["yaml"].get("phase")))}/{len(phase_table_rows) or len(phases)} 階段 · {zpill(st)}{f" <span class=\"num\">{n}</span>" if n else ""}</span>' + ''.join(strip_gate(g, s_, rel_) for g, s_, d_, rel_, _ in gate_rows(current)) + '</div>'
else:
    strip_html = '<div class="strip"><span class="placeholder">尚無 YAML phase</span></div>'
page = f"""<!doctype html>
<!-- GENERATED by scripts/dossier-render.sh — do not hand-edit; edit the markdown sources and regenerate -->
<html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(epic_title)}</title><style>{CSS}</style></head>
<body><div class="top"><h1>{html.escape(epic_title)}</h1><span class="slug">{html.escape(slug)}</span><nav class="tabs">{buttons}</nav><button class="theme" type="button">主題</button></div>
{strip_html}<main>{notes_html}{tabs_html}</main><script>{JS}</script></body></html>
"""
if want_pr_body and pr_body_text is None:
    print('dossier-render.sh: --pr-body needs a YAML phase (*.spec.yaml) — none found; nothing written', file=sys.stderr); sys.exit(1)
with open(os.path.join(epic_dir, 'dossier.html'), 'w', encoding='utf-8') as fh:
    fh.write(page)
print(os.path.join(epic_dir, 'dossier.html'))
if want_pr_body:
    with open(os.path.join(epic_dir, 'pr-body.md'), 'w', encoding='utf-8') as fh:
        fh.write(pr_body_text)
    print(os.path.join(epic_dir, 'pr-body.md'))
PYTHON_EOF
