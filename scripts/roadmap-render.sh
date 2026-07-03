#!/usr/bin/env bash
# scripts/roadmap-render.sh — Generate ROADMAP.html + ROADMAP.md from epic indexes.
# Usage: roadmap-render.sh [--root <dir>] [--out <dir>]
#   --root   project root (default: .)  — epics at <root>/.touchstone/epics/*/index.md
#   --out    output directory (default: <root>)
# Outputs are idempotent for the same inputs; the HTML timestamp line is the only
# non-deterministic piece (excluded from ROADMAP.md to avoid diff noise).
set -uo pipefail

root="."
out_dir=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="$2"; shift 2 ;;
    --out)  out_dir="$2"; shift 2 ;;
    *) printf 'roadmap-render.sh: unknown arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done
[ -z "$out_dir" ] && out_dir="$root"

mkdir -p "$out_dir"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'roadmap-render.sh: python3 not found\n' >&2
  exit 1
fi

python3 - "$root" "$out_dir" <<'PYTHON_EOF'
import sys
import os
import re
import glob
from datetime import datetime, timezone

STATUS_ORDER = {'active': 0, 'proposed': 1, 'paused': 2, 'done': 3, 'cancelled': 4}
STATUS_VOCAB = set(STATUS_ORDER.keys())

STATUS_BADGE_CSS = {
    'active':    ('badge-active',    '#155724', '#d4edda'),
    'proposed':  ('badge-proposed',  '#495057', '#e9ecef'),
    'paused':    ('badge-paused',    '#856404', '#fff3cd'),
    'done':      ('badge-done',      '#004085', '#cce5ff'),
    'cancelled': ('badge-cancelled', '#721c24', '#f8d7da'),
}

CHIP_CSS = {
    'active':    ('chip-active',    '#155724', '#28a745', 'none'),
    'proposed':  ('chip-proposed',  '#666',    '#aaa',    'none'),
    'paused':    ('chip-paused',    '#856404', '#ffc107', 'none'),
    'done':      ('chip-done',      '#004085', '#007bff', 'none'),
    'cancelled': ('chip-cancelled', '#721c24', '#dc3545', 'line-through'),
}


def parse_epic(idx_path):
    """Parse one epic index.md; return dict or None on fatal error."""
    epic = {
        'slug': '', 'status': '', 'started': '', 'landed': '',
        'aim': '', 'phases': [], 'path': idx_path,
    }
    try:
        with open(idx_path, 'r', encoding='utf-8') as fh:
            content = fh.read()
    except OSError as exc:
        print(f'WARNING: cannot read {idx_path}: {exc}', file=sys.stderr)
        return None

    # --- frontmatter (first ---...--- block) ---
    fm_m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if fm_m:
        for line in fm_m.group(1).splitlines():
            for field in ('slug', 'status', 'started', 'landed'):
                if line.startswith(field + ':'):
                    val = line[len(field) + 1:].strip()
                    val = val.split('#')[0].strip()  # strip inline YAML comments
                    epic[field] = val

    if not epic['slug']:
        epic['slug'] = os.path.basename(os.path.dirname(idx_path))
        print(f'WARNING: no slug in frontmatter for {idx_path}; using directory name',
              file=sys.stderr)

    if not epic['status']:
        print(f'WARNING: no status in frontmatter for {idx_path}', file=sys.stderr)

    # --- Aim ---
    aim_m = re.search(r'^\*\*Aim:\*\*\s*(.+)', content, re.MULTILINE)
    if aim_m:
        epic['aim'] = aim_m.group(1).strip()
    else:
        print(f'WARNING: no **Aim:** line in {idx_path}', file=sys.stderr)

    # --- Phases table ---
    ph_m = re.search(r'^## Phases\b(.*?)(?=^## |\Z)', content, re.MULTILINE | re.DOTALL)
    if ph_m:
        for line in ph_m.group(1).splitlines():
            phase = _parse_phase_row(line)
            if phase:
                epic['phases'].append(phase)

    return epic


def _parse_phase_row(line):
    """Return {'num', 'title', 'status'} for a valid phase row, else None."""
    if not line.startswith('|'):
        return None
    segs = [s.strip() for s in line.split('|')]
    # strip the leading/trailing empty segments from `| ... |` format
    if segs and segs[0] == '':
        segs = segs[1:]
    if segs and segs[-1] == '':
        segs = segs[:-1]
    if len(segs) < 3:
        return None
    pnum = segs[0]
    if not pnum.isdigit():
        return None  # separator or header row

    # status: scan from end, first exact match against STATUS_VOCAB
    pstatus = ''
    for seg in reversed(segs):
        if seg in STATUS_VOCAB:
            pstatus = seg
            break

    # title: first segment after the phase number (segs[1])
    ptitle = segs[1]
    ptitle = re.sub(r'\*\*', '', ptitle)
    ptitle = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', ptitle)
    ptitle = re.sub(r'`[^`]*`', '', ptitle).strip()
    if len(ptitle) > 30:
        ptitle = ptitle[:30] + '...'

    return {'num': pnum, 'title': ptitle, 'status': pstatus}


def _html_escape(text):
    return (text
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;'))


def _badge_html(status):
    cfg = STATUS_BADGE_CSS.get(status, ('badge-unknown', '#333', '#eee'))
    cls, color, bg = cfg
    extra = ' style="text-decoration:line-through"' if status == 'cancelled' else ''
    return (f'<span class="badge {cls}"'
            f' style="color:{color};background:{bg}"{extra}>'
            f'{_html_escape(status) if status else "?"}</span>')


def _chip_html(phase):
    st = phase['status']
    cfg = CHIP_CSS.get(st, ('chip-unknown', '#333', '#aaa', 'none'))
    cls, color, border, td = cfg
    label = _html_escape(f'P{phase["num"]} {phase["title"]}')
    return (f'<span class="chip {cls}"'
            f' style="color:{color};border-color:{border};text-decoration:{td}">'
            f'{label}</span>')


def _card_html(ep):
    slug = _html_escape(ep['slug'])
    aim = _html_escape(ep['aim']) if ep['aim'] else '<em>no aim set</em>'
    st = ep['status'] or 'unknown'
    started = ep['started'] if ep['started'] else '—'
    landed = ep['landed'] if ep['landed'] else '—'
    badge = _badge_html(st)
    meta = f'started: {started}'
    if ep['landed']:
        meta += f' · landed: {landed}'
    chips = ''.join(_chip_html(p) for p in ep['phases'])
    phases_html = (f'\n    <div class="phases">{chips}</div>'
                   if chips else '')
    aim_td = ' style="text-decoration:line-through;color:#999"' if st == 'cancelled' else ''
    return (
        f'  <div class="card">\n'
        f'    <div class="card-header">'
        f'<code class="slug">{slug}</code> {badge}</div>\n'
        f'    <div class="aim"{aim_td}>{aim}</div>\n'
        f'    <div class="meta">{_html_escape(meta)}</div>'
        f'{phases_html}\n'
        f'  </div>'
    )


def _section_label(label):
    return f'  <div class="section-label">{label}</div>'


def generate_html(epics, brainstorm_bullets, ts):
    css = '''
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      background: #f4f4f4; color: #222; padding: 1.5rem;
      max-width: 880px; margin: 0 auto;
    }
    h1 { font-size: 1.4rem; font-weight: 700; margin-bottom: 0.2rem; }
    .ts { color: #888; font-size: 0.8rem; margin-bottom: 2rem; }
    .section-label {
      font-size: 0.72rem; font-weight: 700; letter-spacing: 0.08em;
      text-transform: uppercase; color: #888; margin: 1.4rem 0 0.5rem;
    }
    .card {
      background: #fff; border-radius: 8px; padding: 0.9rem 1.1rem;
      margin-bottom: 0.6rem; box-shadow: 0 1px 3px rgba(0,0,0,0.07);
    }
    .card-header { display: flex; align-items: center; gap: 0.6rem; margin-bottom: 0.35rem; }
    .slug { font-size: 0.92rem; font-weight: 600; }
    .badge {
      padding: 0.15rem 0.45rem; border-radius: 4px;
      font-size: 0.7rem; font-weight: 700;
    }
    .aim { font-size: 0.88rem; color: #333; margin-bottom: 0.3rem; }
    .meta { font-size: 0.75rem; color: #999; margin-bottom: 0.4rem; }
    .phases { display: flex; flex-wrap: wrap; gap: 0.3rem; }
    .chip {
      padding: 0.1rem 0.35rem; border-radius: 4px;
      font-size: 0.68rem; border: 1px solid;
    }
    .backlog { background: #fff; border-radius: 8px; padding: 0.9rem 1.1rem;
               margin-bottom: 0.6rem; box-shadow: 0 1px 3px rgba(0,0,0,0.07); }
    .backlog ul { padding-left: 1.2rem; color: #aaa; }
    .backlog li { font-size: 0.82rem; margin-bottom: 0.2rem; }
'''
    parts = [
        '<!DOCTYPE html>',
        '<html lang="en">',
        '<head>',
        '<meta charset="UTF-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
        '<title>ROADMAP</title>',
        f'<style>{css}</style>',
        '</head>',
        '<body>',
        '<h1>ROADMAP</h1>',
        f'<div class="ts">Generated: {ts}</div>',
    ]

    # Group by section
    active_epics    = [e for e in epics if e['status'] == 'active']
    proposed_epics  = [e for e in epics if e['status'] == 'proposed']
    paused_epics    = [e for e in epics if e['status'] == 'paused']
    closed_epics    = [e for e in epics if e['status'] in ('done', 'cancelled')]

    def emit_section(label, group):
        if not group:
            return
        parts.append(_section_label(label))
        for ep in group:
            parts.append(_card_html(ep))

    emit_section('Active', active_epics)
    emit_section('Proposed', proposed_epics)
    emit_section('Paused', paused_epics)
    emit_section('Done · Cancelled', closed_epics)

    # Backlog section
    if brainstorm_bullets:
        parts.append(_section_label('Backlog candidates'))
        items = '\n'.join(f'      <li>{_html_escape(b)}</li>'
                          for b in brainstorm_bullets)
        parts.append(
            f'  <div class="backlog">\n'
            f'    <ul>\n{items}\n    </ul>\n'
            f'  </div>'
        )

    parts.extend(['</body>', '</html>', ''])
    return '\n'.join(parts)


def generate_md(epics, root):
    lines = [
        '<!-- GENERATED by scripts/roadmap-render.sh'
        ' — do not hand-edit; edit epic index.md files instead -->',
        '',
        '| slug | aim | status | phases done/total | index path |',
        '|---|---|---|---|---|',
    ]
    for ep in epics:
        slug  = ep['slug']
        aim   = ep['aim'] or ''
        if len(aim) > 80:
            aim = aim[:80] + '...'
        st    = ep['status'] or ''
        phases = ep['phases']
        done_c = sum(1 for p in phases if p['status'] == 'done')
        total  = len(phases)
        ph_str = f'{done_c}/{total}' if total else '—'
        rpath  = os.path.relpath(ep['path'], root)
        slug   = slug.replace('|', '\\|')
        aim    = aim.replace('|', '\\|')
        rpath  = rpath.replace('|', '\\|')
        lines.append(f'| {slug} | {aim} | {st} | {ph_str} | {rpath} |')
    lines.append('')
    return '\n'.join(lines)


def main():
    root    = sys.argv[1]
    out_dir = sys.argv[2]

    epics_dir      = os.path.join(root, '.touchstone', 'epics')
    brainstorm_path = os.path.join(epics_dir, '_draft-brainstorm.md')

    # Collect epics
    epics = []
    if os.path.isdir(epics_dir):
        for idx_path in sorted(glob.glob(os.path.join(epics_dir, '*/index.md'))):
            # Skip files that live inside _draft-brainstorm.md (shouldn't exist, safety)
            if '_draft-brainstorm' in idx_path:
                continue
            ep = parse_epic(idx_path)
            if ep is not None:
                epics.append(ep)
    else:
        print(f'WARNING: epics dir not found: {epics_dir}', file=sys.stderr)

    epics.sort(key=lambda e: (STATUS_ORDER.get(e['status'], 99), e['slug']))

    # Brainstorm bullets (first-level only)
    brainstorm_bullets = []
    if os.path.isfile(brainstorm_path):
        with open(brainstorm_path, 'r', encoding='utf-8') as fh:
            for line in fh:
                s = line.rstrip()
                if s.startswith('- ') or s.startswith('* '):
                    brainstorm_bullets.append(s[2:])

    ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    # Write ROADMAP.md
    md_path = os.path.join(out_dir, 'ROADMAP.md')
    md_content = generate_md(epics, root)
    with open(md_path, 'w', encoding='utf-8') as fh:
        fh.write(md_content)
    print(f'wrote {md_path}')

    # Write ROADMAP.html
    html_path = os.path.join(out_dir, 'ROADMAP.html')
    html_content = generate_html(epics, brainstorm_bullets, ts)
    with open(html_path, 'w', encoding='utf-8') as fh:
        fh.write(html_content)
    print(f'wrote {html_path}')


main()
PYTHON_EOF
