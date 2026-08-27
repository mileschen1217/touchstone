#!/usr/bin/env bash
# scripts/dossier-render.sh — Generate <epic-dir>/dossier.html from an epic dir's
# markdown/html sources. The dossier is a VIEW, never a home: regenerate it
# (phase-ship, epic close), never hand-edit it. Output is deterministic (no
# timestamps, no random ids) so re-runs on unchanged sources are byte-identical.
#
# Usage: dossier-render.sh [--root <dir>] <epic-dir>
#   exit 0 → <epic-dir>/dossier.html written
#   exit 1 → path missing / not a dir / no index.md / dir not writable (cause on stderr)
#
# Input-resolution contract (single home — the spec restates it only as the
# contract under test):
#   project root   = --root when given; else nearest ancestor of <epic-dir>
#                    containing a `.touchstone/` dir; none → gate-miss + ADR
#                    lookups skipped, noted in the page. Input set = epic dir +
#                    <root>/.touchstone/gate-miss.md + cited ADR files under
#                    <root>/docs/adr and <root>/.touchstone/docs/adr.
#   stage tabs     = 位置 (index.md minus close sections) · 契約 (assay-*.md,
#                    *-design.md, frontmatter type: spec|adr, cited project-root
#                    ADRs, and any file matching no pattern) · Map (each spec's
#                    `## Phase map` or a visible placeholder, + index `## Deviation
#                    log`) · Build (*review*/review.md, evidence.md, deviation*.md,
#                    task-*.md, *plan*.md) · Ship (*explainer*, *quiz*, *buyin*;
#                    .html inlined by <body> inner HTML, never iframed) · Close
#                    (index Retrospective / Evidence Reckoning / Disposition /
#                    Eval Reckon + gate-miss.md lines containing the slug).
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

root_override=""
if [ "${1:-}" = "--root" ]; then
  [ -n "${2:-}" ] || { printf 'dossier-render.sh: --root needs a directory\n' >&2; exit 1; }
  [ -d "$2" ] || { printf 'dossier-render.sh: --root is not a directory: %s\n' "$2" >&2; exit 1; }
  root_override="$2"; shift 2
fi
[ $# -eq 1 ] || { printf 'usage: dossier-render.sh [--root <dir>] <epic-dir>\n' >&2; exit 1; }
epic_dir="$1"
[ -e "$epic_dir" ] || { printf 'dossier-render.sh: path does not exist: %s\n' "$epic_dir" >&2; exit 1; }
[ -d "$epic_dir" ] || { printf 'dossier-render.sh: not a directory: %s\n' "$epic_dir" >&2; exit 1; }
[ -f "$epic_dir/index.md" ] || { printf 'dossier-render.sh: no index.md in %s\n' "$epic_dir" >&2; exit 1; }
[ -w "$epic_dir" ] || { printf 'dossier-render.sh: directory not writable: %s\n' "$epic_dir" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf 'dossier-render.sh: python3 not found\n' >&2; exit 1; }

python3 - "$epic_dir" "$root_override" <<'PYTHON_EOF'
import sys, os, re, html, glob

epic_dir = os.path.abspath(sys.argv[1])
root_override = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None
TABS = ['位置', '契約', 'Map', 'Build', 'Ship', 'Close']
CLOSE_SECTIONS = {'Retrospective', 'Evidence Reckoning', 'Disposition', 'Eval Reckon'}
CODE_RE = re.compile(r'(?<![\w-])((?:AC|REQ|US|ADR)-\d+(?:[a-z]+|/\d+[a-z]*)*)(?![\w-])')

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
    return re.sub(r'-design$', '', s)

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
    u = u.strip()
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
        if rel == 'dossier.html' or not (fn.endswith('.md') or fn.endswith('.html')):
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
    if base.endswith('-design.md') or base.startswith('assay-'):
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

spec_files = [f for f in files if is_spec(f) and f.endswith('.md')]
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
    if 'explainer' in base or 'quiz' in base or 'buyin' in base:
        return 'Ship'
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

for sp in spec_files:
    stem = stem_of(sp)
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

def resolve(code, owner):
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
            return f'<span class="undef" title="no definition for {code} in this epic">{code}</span>'
        t = f' title="also defined at: {", ".join(alts)}"' if alts else ''
        return f'<a class="code" href="#{anchor}"{t}>{code}</a>'
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

def md_to_html(body, owner, define=False):
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
            table.append('<tr>' + ''.join(f'<{tag}>{inline(c, owner)}</{tag}>' for c in cells) + '</tr>')
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
    head = f'<header><span class="file">{html.escape(rel)}</span></header>' if rel else ''
    return f'<article{anchor}>{head}<h2>{html.escape(title)}</h2>{inner}</article>'
# note: `anchor` is always built from slug_id()/adr_key() output — attribute-safe by construction.

# ---------- extraction (every visible sentence is taken from a source file) ----------
LONG_FILE = 200  # lines; longer files collapse behind a summary line

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

def meta_line(fm, extra=''):
    parts = []
    for k in ('status', 'date', 'kind', 'type', 'started', 'landed'):
        if fm.get(k):
            parts.append(pill(fm[k]) if k == 'status' else f'<span>{html.escape(k)} {html.escape(fm[k])}</span>')
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
           or line.startswith('STAGE-REVIEW-SUMMARY') or re.match(r'^\**Ready to merge', line) \
           or re.match(r'^providers_(used|expected)', line):
            out.append(line.strip().strip('*'))
    return out

def collapsed(summary_html, inner_html, open_=False):
    return f'<details class="fold"{" open" if open_ else ""}><summary>{summary_html}</summary><div class="fold-body">{inner_html}</div></details>'

def file_card(rel, title, fm, body, owner, define=False, force_open=False):
    """A source file: h2 + meta line; body inline if short, else collapsed behind its first paragraph."""
    n = body.count('\n') + 1
    rendered = md_to_html(body, owner, define=define)
    file_span = f'<span class="file">{html.escape(rel)}</span> · {n} lines'
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
for sp in spec_files:
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

def dev_lines_for(p):
    if p is EPIC:
        return [d for d in deviation_lines if not any(q['slug'] and (q['slug'] in d or f"phase {q['num']}" in d.lower()) for q in phases)]
    return [d for d in deviation_lines if (p['slug'] and p['slug'] in d) or f"phase {p['num']}" in d.lower()]
for i, p in enumerate(phases):
    p['num'] = next((r[0] for r in phase_table_rows if p['spec'] in r[2]), str(i + 1))

# ---------- build the six tabs ----------
groups = list(reversed(phases)) + [EPIC]   # newest phase first, epic-level last
tab = {t: {g['key']: [] for g in groups} for t in TABS}
notes = []
if not root:
    notes.append('No project root (`.touchstone/` ancestor) found — gate-miss and ADR lookups skipped.')

# 位置 — front page (derived)
waiting = []
for sp in spec_files:
    st = specs[sp]['fm'].get('status', '')
    if st and st.lower() != 'accepted' and not os.path.basename(sp).startswith('assay-'):
        waiting.append(f'Accept the spec <code>{html.escape(os.path.basename(sp))}</code> — status {pill(st)}')
    if specs[sp]['markers']:
        waiting.append(f'{specs[sp]["markers"]} unresolved <code>[NEEDS CLARIFICATION]</code> / <code>[unverified]</code> marker(s) in <code>{html.escape(os.path.basename(sp))}</code>')
for q in bullets(index_sections.get('Open Questions', '')):
    if not q.startswith('*('): waiting.append('Open question: ' + inline(q, 'epic'))
for d in deviation_lines:
    if re.search(r'human|rule on|ruling', d, re.I): waiting.append('Ruling needed: ' + inline(d, 'epic'))
for r in phase_table_rows:
    if r[4].lower() not in ('done', 'cancelled'):
        waiting.append(f'Ship phase {html.escape(r[0])} ({html.escape(r[1])}) — {pill(r[4])}')
dates = set(re.findall(r'\b(20\d\d-\d\d-\d\d)\b', ' '.join(files)))
for v in list(index_fm.values()) + [specs[s]['fm'].get('date', '') for s in spec_files]:
    dates |= set(re.findall(r'\b(20\d\d-\d\d-\d\d)\b', v or ''))
latest = max(dates) if dates else '—'
aim_html = inline(aim, 'epic') if aim else '<span class="muted">no **Aim:** line in index.md</span>'
front = [f'<p class="aim">{aim_html}</p>',
         meta_line(index_fm, f'latest source date {html.escape(latest)}')]
if phase_table_rows:
    rows = ''.join(f'<tr><td class="num">{html.escape(r[0])}</td><td>{inline(r[1], "epic")}</td><td>{inline(r[2], "epic")}</td><td>{pill(r[4])}</td><td class="num">{html.escape(r[5] if len(r) > 5 else "")}</td></tr>' for r in phase_table_rows)
    front.append(f'<h3>Phases</h3><div class="tbl"><table><tr><th>#</th><th>Title</th><th>Spec</th><th>Status</th><th>Landed</th></tr>{rows}</table></div>')
front.append('<h3>Waiting on the human</h3>' + (f'<ul class="todo">{"".join(f"<li>{w}</li>" for w in waiting)}</ul>' if waiting else '<p class="muted">nothing — every source reports done</p>'))
fnd = bullets(index_sections.get('Foundation', ''))
if fnd:
    front.append('<h3>Foundation</h3>' + md_to_html(index_sections['Foundation'], 'epic'))
for h in ('Pivots', 'Open Questions'):
    if h in index_sections and index_sections[h].strip() and not index_sections[h].strip().startswith('*('):
        front.append(f'<h3>{h}</h3>' + md_to_html(index_sections[h], 'epic'))
tab['位置']['epic'].append(f'<article>{"".join(front)}</article>')

# 契約 — spec digest per phase; assay + unmatched + ADR one-liners at epic level
for p in phases:
    s = specs[p['spec']]
    parts = [f'<h3 class="file-title">{html.escape(s["title"])}</h3>', meta_line(s['fm'], f'<span class="file">{html.escape(p["spec"])}</span>')]
    for lab in ('Intention', 'Aim', 'Out of scope'):
        v = field(s['foundation'], lab)
        if v: parts.append(f'<p><strong>{lab}.</strong> {inline(v, p["key"])}</p>')
    if s['stories']:
        parts.append('<h4>User stories</h4><ul>' + ''.join(f'<li>{inline(b, p["key"])}</li>' for b in s['stories']) + '</ul>')
    if s['reqs']:
        rows = ''
        for rid, headline in s['reqs']:
            acs = [c[1] for c in s['ac_rows'] if c[0] == rid]
            rows += f'<tr><td class="num">{link_codes(rid, p["key"])}</td><td>{inline(headline, p["key"])}</td><td class="num">{" ".join(link_codes(a, p["key"]) for a in acs)}</td></tr>'
        parts.append(f'<h4>Requirements</h4><div class="tbl"><table><tr><th>REQ</th><th>SHALL</th><th>ACs</th></tr>{rows}</table></div>')
    full = md_to_html(s['body'], p['key'], define=True)
    parts.append(collapsed('<span class="lead">Full spec text</span> <span class="muted">(' + str(s['body'].count(chr(10)) + 1) + ' lines; the AC and REQ anchors live here)</span>', full))
    tab['契約'][p['key']].append(f'<article>{"".join(parts)}</article>')

adr_lines = []
for k in sorted(adr_files, key=lambda x: int(x.split('--')[1])):
    fm, body = frontmatter(read(adr_files[k]))
    n = k.split('--')[1]
    forms = sorted(c for c in adr_cited if adr_key(c) == k)
    code = f'ADR-{int(n):04d}'
    cite = ''
    for c in forms + [code]:
        cite = sentence_citing(c, texts_for_citation)
        if cite: break
    relpath = os.path.relpath(adr_files[k], epic_dir)
    adr_lines.append(f'<li id="{k}"><span class="num"><a class="code" href="{attr(relpath)}">{html.escape(code)}</a></span> <strong>{html.escape(first_h1(body) or os.path.basename(adr_files[k]))}</strong> {pill(fm.get("status", ""))}'
                     + (f'<br><span class="cite">{inline(cite, "epic")}</span>' if cite else '<br><span class="muted cite">not cited in a spec sentence — reached through another ADR</span>') + '</li>')
if adr_lines:
    tab['契約']['epic'].append(f'<article><h3 class="file-title">Decisions this epic stands on</h3><p class="meta">{len(adr_lines)} ADR(s) resolved from the project root; each line links to the file</p><ul class="adr">{"".join(adr_lines)}</ul></article>')

# Map — the four panels per phase, deviation lines overlaid
for p in phases:
    s = specs[p['spec']]
    devs = dev_lines_for(p)
    if s['panels'] is None:
        tab['Map'][p['key']].append(f'<article><h3 class="file-title">{html.escape(s["title"])}</h3><p class="placeholder">no phase map in this spec</p></article>')
        continue
    cards = ''
    for label, md in s['panels']:
        key = label.split()[0].lower()
        hits = [d for d in devs if key in d.lower()]
        mark = f'<span class="pill warn">built ≠ planned</span>' if hits else '<span class="pill ok">as planned</span>'
        body = md_to_html(md, p['key'])
        if hits:
            body += '<p class="delta"><strong>Delta (deviation log):</strong></p><ul>' + ''.join(f'<li>{inline(d, p["key"])}</li>' for d in hits) + '</ul>'
        cards += f'<section class="panel"><h4>{html.escape(label)} {mark}</h4>{body}</section>'
    other = [d for d in devs if not any(l.split()[0].lower() in d.lower() for l, _ in s['panels'])]
    if other:
        cards += '<section class="panel"><h4>Other deviations</h4><ul>' + ''.join(f'<li>{inline(d, p["key"])}</li>' for d in other) + '</ul></section>'
    tab['Map'][p['key']].append(f'<article><h3 class="file-title">{html.escape(s["title"])}</h3><div class="panels">{cards}</div></article>')
if not phases:
    tab['Map']['epic'].append('<p class="placeholder">no phase map in this epic (no spec carries a <code>## Phase map</code> section)</p>')
ed = dev_lines_for(EPIC)
if ed:
    tab['Map']['epic'].append('<article><h3 class="file-title">Deviation log (epic-level)</h3><ul>' + ''.join(f'<li>{inline(d, "epic")}</li>' for d in ed) + '</ul></article>')

# Build — deviation log, evidence, review verdicts; raw records collapsed
records = {}  # (phase key, dir) -> [rel]
for rel in files:
    if rel == 'index.md': continue
    p = phase_of(rel); st = stage_of(rel); path = os.path.join(epic_dir, rel)
    if st == 'record':
        records.setdefault((p['key'], os.path.dirname(rel).split('/')[0]), []).append(rel); continue
    if st == '契約' and rel not in spec_files:
        fm, body = frontmatter(read(path))
        tab['契約']['epic' if p is EPIC else p['key']].append(file_card(rel, first_h1(body) or rel, fm, body, p['key']))
        continue
    if rel in spec_files and os.path.basename(rel).startswith('assay-'):
        fm, body = frontmatter(read(path))
        tab['契約'][p['key'] if p is not EPIC else 'epic'].append(file_card(rel, first_h1(body) or rel, fm, body, p['key']))
        continue
    if rel in spec_files: continue
    if st == 'Ship':
        if rel.endswith('.html'):
            raw = read(path); t = re.search(r'<title>(.*?)</title>', raw, re.DOTALL | re.IGNORECASE)
            inner = link_codes_in_html(html_body_inner(raw), p['key'])
            tab['Ship'][p['key']].append(f'<article><h3 class="file-title">{html.escape(html.unescape(t.group(1).strip()) if t else rel)}</h3><p class="meta"><span class="file">{html.escape(rel)}</span></p><div class="embedded">{inner}</div></article>')
        else:
            fm, body = frontmatter(read(path))
            tab['Ship'][p['key']].append(file_card(rel, first_h1(body) or rel, fm, body, p['key'], force_open=True))
        continue
    if st == 'Build':
        fm, body = frontmatter(read(path)); base = os.path.basename(rel).lower()
        if base == 'review.md':
            v = verdict_lines(body)
            head = f'<h3 class="file-title">Review — {html.escape(os.path.dirname(rel))}</h3><p class="meta"><span class="file">{html.escape(rel)}</span></p>' + (f'<ul class="verdict">{"".join(f"<li>{inline(l, p[chr(107)+chr(101)+chr(121)])}</li>" for l in v)}</ul>' if v else '<p class="muted">no verdict line found in review.md</p>')
            summ = '<span class="lead">Synthesis</span> <span class="muted">(review.md)</span>'
            tab['Build'][p['key']].append(f'<article>{head}{collapsed(summ, md_to_html(body, p["key"]))}</article>')
        elif base.startswith('deviation'):
            continue  # already merged into deviation_lines (Map + front page)
        else:
            tab['Build'][p['key']].append(file_card(rel, first_h1(body) or rel, fm, body, p['key']))
for p in phases:
    d = dev_lines_for(p)
    if d:
        tab['Build'][p['key']].insert(0, '<article><h3 class="file-title">Deviation log</h3><ul>' + ''.join(f'<li>{inline(x, p["key"])}</li>' for x in d) + '</ul></article>')
ev = index_sections.get('Evidence Reckoning', '').strip()
if ev and not ev.startswith('*('):
    tab['Build']['epic'].insert(0, f'<article><h3 class="file-title">Evidence reckoning</h3>{md_to_html(ev, "epic")}</article>')
for (pk, d), rels in sorted(records.items()):
    items = ''.join(f'<li><span class="file">{html.escape(r)}</span></li>' for r in rels)
    inner = ''
    for r in rels:
        if r.endswith('.md'):
            fm, body = frontmatter(read(os.path.join(epic_dir, r)))
            inner += f'<h4><span class="file">{html.escape(r)}</span></h4>' + md_to_html(body, pk)
    summ = f'<span class="lead">Review record</span> <span class="muted">{html.escape(d)} · {len(rels)} raw file(s)</span>'
    body_html = f'<ul class="files">{items}</ul>{inner}'
    tab['Build'][pk].append(f'<article>{collapsed(summ, body_html)}</article>')

# Ship placeholder + Close
for p in phases:
    if not tab['Ship'][p['key']]:
        tab['Ship'][p['key']].append(f'<article><h3 class="file-title">{html.escape(specs[p["spec"]]["title"])}</h3><p class="placeholder">Not shipped yet. This tab will carry the buy-in explainer (the phase map with planned-vs-built markers) and the comprehension quiz; gate: quiz passed → approve.</p></article>')
close_parts = []
for h in ('Retrospective', 'Evidence Reckoning', 'Disposition', 'Eval Reckon'):
    if h in index_sections:
        close_parts.append(f'<section><h3>{h}</h3>{md_to_html(index_sections[h], "epic")}</section>')
if root:
    gm = os.path.join(root, '.touchstone', 'gate-miss.md')
    if os.path.isfile(gm):
        hits = [l for l in read(gm).splitlines() if slug in l]
        items = ''.join(f'<li>{inline(l.lstrip("- ").strip(), "epic")}</li>' for l in hits)
        close_parts.append(f'<section><h3>gate-miss.md lines for <code>{html.escape(slug)}</code></h3>' + (f'<ul>{items}</ul>' if hits else '<p class="muted">none</p>') + '</section>')
tab['Close']['epic'].append('<article>' + (''.join(close_parts) or '<p class="muted">no close sections yet</p>') + '</article>')

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
.pill{display:inline-block;font-size:.72rem;font-weight:600;letter-spacing:.03em;padding:.05rem .5rem;border-radius:999px;vertical-align:middle;border:1px solid transparent}
.pill.ok{color:var(--ok);background:var(--ok-bg)}.pill.warn{color:var(--warn);background:var(--warn-bg)}.pill.crit{color:var(--crit);background:var(--crit-bg)}.pill.accent{color:var(--accent);border-color:var(--accent)}.pill.muted{color:var(--muted);border-color:var(--line)}
ul,ol{padding-left:1.3rem;margin:.35rem 0}li{margin:.2rem 0}ul.todo li{margin:.4rem 0}ul.adr{list-style:none;padding:0}ul.adr li{padding:.5rem 0;border-top:1px solid var(--line)}ul.adr li:first-child{border-top:0}
.cite{font-size:.9rem;color:var(--muted)}ul.verdict{list-style:none;padding:0}ul.verdict li{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-size:.82rem;padding:.15rem 0}
ul.files{list-style:none;padding:0;font-size:.82rem}
pre{background:var(--code);padding:.75rem .9rem;border-radius:4px;overflow-x:auto;font-size:.82rem;line-height:1.45}code{font-family:ui-monospace,"SF Mono",Menlo,monospace;background:var(--code);padding:.05rem .3rem;border-radius:3px;font-size:.86em}pre code{background:none;padding:0}
.tbl{overflow-x:auto;margin:.5rem 0}table{border-collapse:collapse;width:100%;font-size:.9rem}th,td{border-bottom:1px solid var(--line);padding:.35rem .6rem;text-align:left;vertical-align:top}th{font-size:.75rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);font-weight:600}
td.num,.num,a.code,.undef{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-variant-numeric:tabular-nums;font-size:.85rem}
a{color:var(--accent)}a.code{text-decoration:none;border-bottom:1px dotted var(--accent)}
.undef{color:var(--crit);background:var(--crit-bg);border-radius:3px;padding:0 .25rem;cursor:help}.undef::after{content:" (undefined)";font-size:.75em}
details.fold{border-top:1px solid var(--line);margin-top:.75rem;padding-top:.5rem}details.fold>summary{cursor:pointer;color:var(--muted);list-style:none}details.fold>summary::before{content:"▸ ";color:var(--accent)}details.fold[open]>summary::before{content:"▾ "}.fold-body{margin-top:.75rem}
.panels{display:grid;gap:.75rem}.panel{background:var(--fold);border-radius:4px;padding:.75rem 1rem}.panel h4{margin:0 0 .4rem;display:flex;gap:.5rem;align-items:baseline}.delta{margin-top:.6rem}
.notes{color:var(--muted);font-size:.85rem;border:1px dashed var(--line);padding:.5rem .75rem;border-radius:4px;margin-bottom:1rem}
.embedded{border-left:3px solid var(--line);padding-left:1rem}blockquote{margin:.5rem 0;padding-left:.9rem;border-left:3px solid var(--line);color:var(--muted)}
:target{outline:2px solid var(--accent);outline-offset:4px;border-radius:3px}
@media (prefers-reduced-motion: no-preference){details.fold>summary{transition:color .15s}}
"""
JS = """
(function(){var root=document.documentElement;var key='dossier-theme';
try{var t=localStorage.getItem(key);if(t)root.setAttribute('data-theme',t);}catch(e){}
function show(id){document.querySelectorAll('.tab').forEach(function(s){s.classList.toggle('active',s.id==='tab-'+id)});
document.querySelectorAll('.tabs button').forEach(function(b){b.setAttribute('aria-selected',b.dataset.tab===id?'true':'false')});}
document.querySelectorAll('.tabs button').forEach(function(b){b.addEventListener('click',function(){show(b.dataset.tab);try{localStorage.setItem('dossier-tab',b.dataset.tab)}catch(e){}})});
var initial='0';try{initial=localStorage.getItem('dossier-tab')||'0'}catch(e){}
function reveal(el){var tab=el.closest('.tab');if(tab)show(tab.id.replace('tab-',''));var d=el.closest('details');while(d){d.open=true;d=d.parentElement&&d.parentElement.closest('details');}}
if(location.hash){var el=document.getElementById(location.hash.slice(1));if(el){reveal(el);var tab=el.closest('.tab');if(tab)initial=tab.id.replace('tab-','')}}
show(initial);
document.querySelectorAll('a.code[href^="#"]').forEach(function(a){a.addEventListener('click',function(){var el=document.getElementById(a.getAttribute('href').slice(1));if(el)reveal(el)})});
window.addEventListener('hashchange',function(){var el=document.getElementById(location.hash.slice(1));if(el){reveal(el);el.scrollIntoView();}});
document.querySelector('.theme').addEventListener('click',function(){var cur=root.getAttribute('data-theme');var dark=cur?cur==='dark':window.matchMedia('(prefers-color-scheme: dark)').matches;var next=dark?'light':'dark';root.setAttribute('data-theme',next);try{localStorage.setItem(key,next)}catch(e){}});
})();
"""

def phase_header(g):
    if g is EPIC:
        return '<h2>Epic-level</h2>'
    s = specs[g['spec']]
    return f'<h2>{html.escape(g["title"])} {pill(s["fm"].get("status", ""))}</h2><p class="meta"><span class="file">{html.escape(g["spec"])}</span></p>'

def render_tab(i, t):
    parts = []
    for g in groups:
        items = tab[t][g['key']]
        if not items: continue
        parts.append(f'<section class="phase" data-phase="{attr(g["key"])}">{phase_header(g)}{"".join(items)}</section>')
    if not parts:
        parts.append('<p class="muted">nothing in this stage yet</p>')
    return f'<section class="tab" id="tab-{i}">{"".join(parts)}</section>'

buttons = ''.join(f'<button data-tab="{i}" aria-selected="false">{html.escape(t)}</button>' for i, t in enumerate(TABS))
tabs_html = ''.join(render_tab(i, t) for i, t in enumerate(TABS))
notes_html = f'<div class="notes">{" ".join(html.escape(n) for n in notes)}</div>' if notes else ''
page = f"""<!doctype html>
<!-- GENERATED by scripts/dossier-render.sh — do not hand-edit; edit the markdown sources and regenerate -->
<html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(epic_title)}</title><style>{CSS}</style></head>
<body><div class="top"><h1>{html.escape(epic_title)}</h1><span class="slug">{html.escape(slug)}</span><nav class="tabs">{buttons}</nav><button class="theme" type="button">theme</button></div>
<main>{notes_html}{tabs_html}</main><script>{JS}</script></body></html>
"""
with open(os.path.join(epic_dir, 'dossier.html'), 'w', encoding='utf-8') as fh:
    fh.write(page)
print(os.path.join(epic_dir, 'dossier.html'))
PYTHON_EOF
