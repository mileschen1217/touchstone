#!/usr/bin/env bash
# scripts/roadmap-render.sh — Generate <project-root>/ROADMAP.md as a projection
# over the epics dir. ROADMAP.md is a VIEW, never a home: regenerate it, never
# hand-edit it (see the generated header this script writes). Output is
# deterministic (no timestamps, no random ids) so re-runs on an unchanged epics
# dir are byte-identical — the freshness checker (check-roadmap-fresh.sh)
# leans on that.
#
# Usage: roadmap-render.sh [--root <project-root>] [--epics-dir <dir>] [--out <file>] [--audit]
#   root       = --root arg, else $CLAUDE_PROJECT_DIR, else pwd
#   epics-dir  = --epics-dir arg, else the `epics=` line of
#                `resolve-config.sh --root <root>` (workspace_root default:
#                .touchstone, exactly as resolve-config.sh resolves it)
#   out        = --out arg, else <root>/ROADMAP.md
#   exit 0 → (no --audit) <out> written atomically (temp file + rename):
#             Active Epics table (status not done/cancelled) + Completed
#             Epics table (status done/cancelled), each row sorted by epic
#             dir name, plus a generated header naming this script, the
#             source epics dir, and a sha256 of the rendered body.
#           → (--audit) findings printed instead of writing anything:
#             staleness (an active epic's dir untouched >30 days by
#             `git log -1 --format=%cs`, falling back to the newest file
#             mtime under the dir when git has nothing tracked there) and
#             invalid epic dirs (neither epic.yaml nor index.md, or an
#             epic.yaml that is not parseable YAML / not a mapping); no
#             findings → nothing printed, exit 0; any findings → exit 1.
#             Status-drift and broken-link audits are gone by construction —
#             a generated table cannot drift from its own source and never
#             hand-authors a link.
#   exit 1 → --root not a directory, resolve-config.sh failed, or (only when
#            an epic.yaml is present) PyYAML missing — cause on stderr.
#
# Per-epic-dir read precedent (mirrors dossier-render.sh / ADR-0043): epic.yaml
# present → slug/status/landed/aim/phases from it, index.md in that dir is never
# read; else index.md frontmatter (slug/status/landed) + the `**Aim:**` line +
# the `## Phases` table's Status column (header-keyed, not positional).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

project_root=""; epics_dir_arg=""; out_arg=""; audit=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ -n "${2:-}" ] || { printf 'roadmap-render.sh: --root needs a directory\n' >&2; exit 1; }
      project_root="$2"; shift 2 ;;
    --epics-dir)
      [ -n "${2:-}" ] || { printf 'roadmap-render.sh: --epics-dir needs a directory\n' >&2; exit 1; }
      epics_dir_arg="$2"; shift 2 ;;
    --out)
      [ -n "${2:-}" ] || { printf 'roadmap-render.sh: --out needs a file\n' >&2; exit 1; }
      out_arg="$2"; shift 2 ;;
    --audit) audit=1; shift ;;
    *) printf 'usage: roadmap-render.sh [--root <project-root>] [--epics-dir <dir>] [--out <file>] [--audit]\n' >&2; exit 1 ;;
  esac
done
[ -n "$project_root" ] || project_root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$project_root" ] || project_root="$(pwd)"
[ -d "$project_root" ] || { printf 'roadmap-render.sh: --root is not a directory: %s\n' "$project_root" >&2; exit 1; }
project_root="$(cd "$project_root" && pwd)"

if [ -n "$epics_dir_arg" ]; then
  epics_dir="$epics_dir_arg"
else
  epics_line="$(bash "$here/resolve-config.sh" --root "$project_root" 2>&1 | grep '^epics=')" \
    || { printf 'roadmap-render.sh: resolve-config.sh failed to resolve epics dir\n' >&2; exit 1; }
  epics_rel="${epics_line#epics=}"
  case "$epics_rel" in
    /*) epics_dir="$epics_rel" ;;
    *) epics_dir="$project_root/$epics_rel" ;;
  esac
fi

out_file="${out_arg:-$project_root/ROADMAP.md}"

command -v python3 >/dev/null 2>&1 || { printf 'roadmap-render.sh: python3 not found\n' >&2; exit 1; }
if [ -d "$epics_dir" ] && find "$epics_dir" -mindepth 2 -maxdepth 2 -name 'epic.yaml' 2>/dev/null | grep -q . \
   && ! python3 -c 'import yaml' 2>/dev/null; then
  printf 'roadmap-render.sh: PyYAML not installed and %s holds epic.yaml artifacts — run: python3 -m pip install pyyaml\n' "$epics_dir" >&2
  exit 1
fi

python3 - "$project_root" "$epics_dir" "$out_file" "$audit" <<'PYTHON_EOF'
import sys, os, re, hashlib, tempfile, datetime, subprocess
try:
    import yaml
except ImportError:
    yaml = None

project_root, epics_dir, out_file, audit = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == '1'
DONE_STATUSES = {'done', 'cancelled'}
STALE_DAYS = 30

def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()

def sval(v):
    return '' if v is None else str(v).strip()

def frontmatter(text):
    m = re.match(r'^---\s*\n(.*?)\n---\s*\n?', text, re.DOTALL)
    fm = {}
    if not m:
        return fm, text
    for line in m.group(1).splitlines():
        if ':' in line:
            k, v = line.split(':', 1)
            fm[k.strip()] = v.split('#')[0].strip()
    return fm, text[m.end():]

def parse_phases_table(body):
    """[{'n','title','status'}] from a legacy index.md's `## Phases` markdown
    table — columns are located by header text, never by position."""
    rows, in_phases, header = [], False, None
    for line in body.splitlines():
        if line.startswith('## '):
            in_phases = line[3:].strip() == 'Phases'
            header = None
            continue
        if not in_phases or not line.strip().startswith('|'):
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if all(re.fullmatch(r':?-+:?', c) for c in cells if c):
            continue
        if header is None:
            header = [c.lower() for c in cells]
            continue
        rowd = dict(zip(header, cells))
        if rowd.get('#'):
            rows.append({'n': rowd.get('#', ''), 'title': rowd.get('title', ''), 'status': rowd.get('status', '')})
    return rows

def load_epic(dirpath):
    """(record, None) or (None, reason). record: slug/status/landed/aim/phases[]."""
    yaml_path = os.path.join(dirpath, 'epic.yaml')
    idx_path = os.path.join(dirpath, 'index.md')
    if os.path.isfile(yaml_path):
        if yaml is None:
            return None, 'PyYAML not installed'
        try:
            d = yaml.safe_load(read(yaml_path))
        except Exception as e:
            return None, f'epic.yaml not parseable YAML: {e}'
        if not isinstance(d, dict):
            return None, 'epic.yaml is not a mapping'
        phases = [{'n': sval(p.get('n')), 'title': sval(p.get('title')), 'status': sval(p.get('status'))}
                  for p in (d.get('phases') or []) if isinstance(p, dict)]
        return {'slug': sval(d.get('slug')) or os.path.basename(dirpath), 'status': sval(d.get('status')) or 'proposed',
                'landed': sval(d.get('landed')), 'aim': sval(d.get('aim')), 'phases': phases}, None
    if os.path.isfile(idx_path):
        fm, body = frontmatter(read(idx_path))
        aim_m = re.search(r'\*\*Aim:\*\*\s*(.+)', body)
        return {'slug': fm.get('slug') or os.path.basename(dirpath), 'status': fm.get('status') or 'proposed',
                'landed': fm.get('landed', ''), 'aim': aim_m.group(1).strip() if aim_m else '',
                'phases': parse_phases_table(body)}, None
    return None, 'neither epic.yaml nor index.md'

def progress(e):
    total = len(e['phases'])
    done = sum(1 for p in e['phases'] if p['status'] == 'done')
    return f'{done}/{total}'

def last_touch_date(dirpath):
    rel = os.path.relpath(dirpath, project_root)
    try:
        out = subprocess.run(['git', '-C', project_root, 'log', '-1', '--format=%cs', '--', rel],
                              capture_output=True, text=True, timeout=10)
        d = out.stdout.strip()
        if d:
            return d
    except Exception:
        pass
    latest = None
    for dp, _dns, fns in os.walk(dirpath):
        for fn in fns:
            try:
                mt = os.path.getmtime(os.path.join(dp, fn))
            except OSError:
                continue
            if latest is None or mt > latest:
                latest = mt
    return datetime.date.fromtimestamp(latest).isoformat() if latest is not None else None

# ---------- inventory ----------
epics, invalid = [], []  # invalid: [(dirname, reason)]
if os.path.isdir(epics_dir):
    for name in sorted(os.listdir(epics_dir)):
        dp = os.path.join(epics_dir, name)
        if not os.path.isdir(dp):
            continue
        rec, err = load_epic(dp)
        if rec is None:
            invalid.append((name, err))
            continue
        rec['dir'] = name
        epics.append(rec)

if audit:
    findings = []
    for name, err in invalid:
        findings.append(f'INVALID: {name} — {err}')
    for e in epics:
        if e['status'] != 'active':
            continue
        d = last_touch_date(os.path.join(epics_dir, e['dir']))
        if d is None:
            continue
        age = (datetime.date.today() - datetime.date.fromisoformat(d)).days
        if age > STALE_DAYS:
            findings.append(f"STALE: {e['slug']} ({e['dir']}) — last touched {d}, {age} days ago")
    for line in findings:
        print(line)
    sys.exit(1 if findings else 0)

# ---------- render ----------
def esc(s):
    return (s or '').replace('|', '\\|').replace('\n', ' ').strip() or '—'

out_dir = os.path.dirname(os.path.abspath(out_file)) or '.'
def epic_link(dirname):
    return os.path.relpath(os.path.join(epics_dir, dirname), out_dir)

active = [e for e in epics if e['status'] not in DONE_STATUSES]
completed = [e for e in epics if e['status'] in DONE_STATUSES]

lines = ['# ROADMAP', '', '## Active Epics', '', '| Slug | Aim | Status | 進度 (done/total) | Epic |', '|---|---|---|---|---|']
for e in active:
    lines.append(f"| {esc(e['slug'])} | {esc(e['aim'])} | {esc(e['status'])} | {progress(e)} | [epic]({epic_link(e['dir'])}) |")
lines += ['', '## Completed Epics', '', '| Slug | Landed | Epic |', '|---|---|---|']
for e in completed:
    lines.append(f"| {esc(e['slug'])} | {esc(e['landed'])} | [epic]({epic_link(e['dir'])}) |")
lines.append('')

body = '\n'.join(lines) + '\n'
digest = hashlib.sha256(body.encode('utf-8')).hexdigest()
try:
    epics_display = os.path.relpath(epics_dir, project_root)
except ValueError:
    epics_display = epics_dir
header = (f'<!-- GENERATED by scripts/roadmap-render.sh — source: {epics_display} — sha256:{digest} -->\n'
          f'<!-- hand edits will be overwritten — regenerate via scripts/roadmap-render.sh -->\n')
full = header + body

os.makedirs(out_dir, exist_ok=True)
fd, tmp_path = tempfile.mkstemp(prefix='.roadmap-render.', dir=out_dir)
try:
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(full)
    os.replace(tmp_path, out_file)
except Exception:
    try:
        os.unlink(tmp_path)
    except OSError:
        pass
    raise
print(f'roadmap-render.sh: wrote {out_file}')
PYTHON_EOF
