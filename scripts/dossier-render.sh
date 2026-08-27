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

def is_spec(rel):
    if rel == 'index.md':
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
        stem = os.path.splitext(os.path.basename(sp))[0]
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
    if (base == 'review.md' and 'review' in rel.lower()) or base == 'evidence.md' \
       or base.startswith('deviation') or base.startswith('task-') or 'plan' in base:
        return 'Build'
    return '契約'  # unmatched → 契約 epic group, never dropped

# ---------- definitions (anchors) ----------
defs = {}  # code -> [(owner_key, anchor_id)]
def add_def(code, owner, anchor):
    defs.setdefault(code, []).append((owner, anchor))

for sp in spec_files:
    stem = os.path.splitext(os.path.basename(sp))[0]
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
    text = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)', r'<a href="\2">\1</a>', text)
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
    inner = re.sub(r'<(script|style)[^>]*>.*?</\1>', '', inner, flags=re.DOTALL | re.IGNORECASE)
    return inner

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

# ---------- assemble tabs ----------
groups = [EPIC] + phases if phases else [EPIC]
tab_content = {t: {g['key']: [] for g in groups} for t in TABS}
notes = []
if not root:
    notes.append('No project root (`.touchstone/` ancestor) found — gate-miss and ADR lookups skipped.')

# 位置 + Close from index.md
pos_parts, close_parts = [fm_table(index_fm)], []
for title, text in sections(index_body):
    rendered = md_to_html(text, 'epic')
    if title == '':
        pos_parts.append(rendered); continue
    block = f'<section><h3>{html.escape(title)}</h3>{rendered}</section>'
    if title in CLOSE_SECTIONS:
        close_parts.append(block)
    elif title == 'Deviation log':
        tab_content['Map']['epic'].append(f'<section><h3>Deviation log</h3>{rendered}</section>')
        pos_parts.append(block)
    else:
        pos_parts.append(block)
tab_content['位置']['epic'].append(article(epic_title, 'index.md', ''.join(pos_parts)))
if root:
    gm = os.path.join(root, '.touchstone', 'gate-miss.md')
    if os.path.isfile(gm):
        hits = [l for l in read(gm).splitlines() if slug in l]
        items = ''.join(f'<li>{inline(l.lstrip("- ").strip(), "epic")}</li>' for l in hits)
        close_parts.append(f'<section><h3>gate-miss.md lines for <code>{html.escape(slug)}</code></h3>'
                           + (f'<ul>{items}</ul>' if hits else '<p class="muted">none</p>') + '</section>')
if not close_parts:
    close_parts.append('<p class="muted">no close sections yet</p>')
tab_content['Close']['epic'].append(article('Close', 'index.md', ''.join(close_parts)))

# per-file placement
for rel in files:
    if rel == 'index.md':
        continue
    p = phase_of(rel)
    stage = stage_of(rel)
    path = os.path.join(epic_dir, rel)
    if rel.endswith('.html'):
        inner = link_codes_in_html(html_body_inner(read(path)), p['key'])
        title = re.search(r'<title>(.*?)</title>', read(path), re.DOTALL | re.IGNORECASE)
        title = html.unescape(title.group(1).strip()) if title else rel
        tab_content[stage][p['key']].append(article(title, rel, f'<div class="embedded">{inner}</div>'))
        continue
    fm, body = frontmatter(read(path))
    is_sp = rel in spec_files
    owner = os.path.splitext(os.path.basename(rel))[0] if is_sp else p['key']
    rendered = fm_table(fm) + md_to_html(body, owner, define=is_sp)
    tab_content[stage][p['key']].append(article(first_h1(body) or rel, rel, rendered))
    if is_sp and p is not EPIC:
        pm = [t for h, t in sections(body) if h == 'Phase map']
        if pm:
            tab_content['Map'][p['key']].append(article('Phase map', rel, md_to_html(pm[0], owner)))
        else:
            tab_content['Map'][p['key']].append(article('Phase map', rel, '<p class="placeholder">no phase map in this spec</p>'))

# cited ADRs → 契約 epic group
for k in sorted(adr_files):
    fm, body = frontmatter(read(adr_files[k]))
    title = first_h1(body) or os.path.basename(adr_files[k])
    rel = os.path.relpath(adr_files[k], root)
    tab_content['契約']['epic'].append(article(title, rel, fm_table(fm) + md_to_html(body, 'epic'), anchor=f' id="{k}"'))

if not any(tab_content['Map'][g['key']] for g in groups):
    tab_content['Map']['epic'].append('<p class="placeholder">no phase map in this epic (no spec carries a <code>## Phase map</code> section)</p>')

# ---------- render page ----------
CSS = """
:root{--bg:#ffffff;--fg:#1f2328;--muted:#6b7280;--line:#d0d7de;--panel:#f6f8fa;--accent:#0969da;--undef:#b91c1c;--undef-bg:#fee2e2;--code:#f0f2f5}
:root[data-theme="dark"]{--bg:#0d1117;--fg:#e6edf3;--muted:#9aa4b2;--line:#30363d;--panel:#161b22;--accent:#58a6ff;--undef:#ff7b72;--undef-bg:#3b1d1d;--code:#1f242c}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#0d1117;--fg:#e6edf3;--muted:#9aa4b2;--line:#30363d;--panel:#161b22;--accent:#58a6ff;--undef:#ff7b72;--undef-bg:#3b1d1d;--code:#1f242c}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif}
.top{display:flex;align-items:center;gap:1rem;padding:.75rem 1.25rem;border-bottom:1px solid var(--line);position:sticky;top:0;background:var(--bg);z-index:2;flex-wrap:wrap}
.top h1{font-size:1.1rem;margin:0}.top .slug{color:var(--muted);font-family:ui-monospace,Menlo,monospace}
.tabs{display:flex;gap:.25rem;flex-wrap:wrap}.tabs button{background:var(--panel);color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:.35rem .8rem;cursor:pointer}
.tabs button[aria-selected="true"]{background:var(--accent);color:#fff;border-color:var(--accent)}
.theme{margin-left:auto;background:none;border:1px solid var(--line);color:var(--fg);border-radius:6px;padding:.3rem .6rem;cursor:pointer}
main{max-width:1100px;margin:0 auto;padding:1rem 1.25rem}.tab{display:none}.tab.active{display:block}
.group{border:1px solid var(--line);border-radius:8px;margin:1rem 0;background:var(--panel)}
.group>summary{padding:.6rem 1rem;font-weight:600;cursor:pointer;list-style:none}.group>summary::before{content:"▸ ";color:var(--muted)}.group[open]>summary::before{content:"▾ "}
article{background:var(--bg);border-top:1px solid var(--line);padding:1rem 1.25rem}article header .file{font-family:ui-monospace,Menlo,monospace;font-size:.8rem;color:var(--muted)}
article h2{font-size:1.15rem;margin:.25rem 0 .75rem}h3{font-size:1.05rem;margin:1.2rem 0 .4rem}h4,h5,h6{font-size:1rem;margin:1rem 0 .3rem}
pre{background:var(--code);padding:.75rem;border-radius:6px;overflow-x:auto;font-size:.85rem}code{background:var(--code);padding:.1rem .3rem;border-radius:4px;font-size:.88em}pre code{background:none}
.tbl{overflow-x:auto}table{border-collapse:collapse;min-width:40%}th,td{border:1px solid var(--line);padding:.3rem .6rem;text-align:left;vertical-align:top}th{background:var(--panel)}
a{color:var(--accent)}a.code{font-family:ui-monospace,Menlo,monospace;text-decoration:none;border-bottom:1px dotted var(--accent)}
.undef{font-family:ui-monospace,Menlo,monospace;color:var(--undef);background:var(--undef-bg);border-radius:4px;padding:0 .25rem;cursor:help}
.undef::after{content:" (undefined)";font-size:.75em}.placeholder,.muted{color:var(--muted);font-style:italic}
.notes{color:var(--muted);font-size:.85rem;border:1px dashed var(--line);padding:.5rem .75rem;border-radius:6px}
:target{outline:2px solid var(--accent);outline-offset:4px;border-radius:4px}
.embedded{border-left:3px solid var(--line);padding-left:1rem}
"""
JS = """
(function(){var root=document.documentElement;var key='dossier-theme';
try{var t=localStorage.getItem(key);if(t)root.setAttribute('data-theme',t);}catch(e){}
function show(id){document.querySelectorAll('.tab').forEach(function(s){s.classList.toggle('active',s.id==='tab-'+id)});
document.querySelectorAll('.tabs button').forEach(function(b){b.setAttribute('aria-selected',b.dataset.tab===id?'true':'false')});}
document.querySelectorAll('.tabs button').forEach(function(b){b.addEventListener('click',function(){show(b.dataset.tab);try{localStorage.setItem('dossier-tab',b.dataset.tab)}catch(e){}})});
var initial='0';try{initial=localStorage.getItem('dossier-tab')||'0'}catch(e){}
if(location.hash){var el=document.getElementById(location.hash.slice(1));if(el){var tab=el.closest('.tab');if(tab)initial=tab.id.replace('tab-','')}}
show(initial);
document.querySelectorAll('a.code').forEach(function(a){a.addEventListener('click',function(){var el=document.getElementById(a.getAttribute('href').slice(1));if(el){var tab=el.closest('.tab');if(tab){show(tab.id.replace('tab-',''));var d=el.closest('details');if(d)d.open=true;}}})});
window.addEventListener('hashchange',function(){var el=document.getElementById(location.hash.slice(1));if(el){var tab=el.closest('.tab');if(tab)show(tab.id.replace('tab-',''));var d=el.closest('details');if(d)d.open=true;el.scrollIntoView();}});
document.querySelector('.theme').addEventListener('click',function(){var cur=root.getAttribute('data-theme');var dark=cur?cur==='dark':window.matchMedia('(prefers-color-scheme: dark)').matches;var next=dark?'light':'dark';root.setAttribute('data-theme',next);try{localStorage.setItem(key,next)}catch(e){}});
})();
"""

def render_tab(i, t):
    parts = []
    for g in groups:
        items = tab_content[t][g['key']]
        if not items:
            continue
        parts.append(f'<details class="group" open><summary>{html.escape(g["title"])}</summary>{"".join(items)}</details>')
    if not parts:
        parts.append('<p class="muted">nothing in this stage yet</p>')
    return f'<section class="tab" id="tab-{i}">{"".join(parts)}</section>'

buttons = ''.join(f'<button data-tab="{i}" aria-selected="false">{html.escape(t)}</button>' for i, t in enumerate(TABS))
tabs_html = ''.join(render_tab(i, t) for i, t in enumerate(TABS))
notes_html = f'<div class="notes">{" ".join(html.escape(n) for n in notes)}</div>' if notes else ''
page = f"""<!doctype html>
<!-- GENERATED by scripts/dossier-render.sh — do not hand-edit; edit the markdown sources and regenerate -->
<html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(epic_title)} — dossier</title><style>{CSS}</style></head>
<body><div class="top"><h1>{html.escape(epic_title)}</h1><span class="slug">{html.escape(slug)}</span><nav class="tabs">{buttons}</nav><button class="theme" type="button">theme</button></div>
<main>{notes_html}{tabs_html}</main><script>{JS}</script></body></html>
"""
with open(os.path.join(epic_dir, 'dossier.html'), 'w', encoding='utf-8') as fh:
    fh.write(page)
print(os.path.join(epic_dir, 'dossier.html'))
PYTHON_EOF
