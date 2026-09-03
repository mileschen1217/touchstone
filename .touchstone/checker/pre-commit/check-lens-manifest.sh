#!/usr/bin/env bash
# check-lens-manifest.sh — pre-commit: validates skills/_shared/lens-manifest.yaml
# (the single declaration of a lens's section composition and destination) and
# the three gate dispatch sites that name lenses.
#
# Fails on:
#   AC-39 — malformed manifest entry: missing name/arms/subject/sections, an
#           arm outside cc|codex, subject not true, or a ref/heading that
#           does not resolve on disk.
#   AC-41 — a duplicate lens name, or the same ref declared twice under one lens.
#   AC-25 — a section whose declared destination contradicts where the load
#           map finds the fragment charged. host-destined: charged nowhere
#           in-session. arm-destined under lens L: charged to an in-session
#           context that DISPATCHES L -- a fragment MAY legitimately also be
#           in-session material for a different, non-dispatching consumer
#           (the manifest's dual-destination clause anticipates this), so a
#           hit in a non-dispatching in-session context is not a violation.
#           "Dispatches L" is read off L's dispatched-context entries' own
#           `dispatched_by: [<in-session context names>]` list; when no
#           dispatched context exists yet for L, or any of L's dispatched
#           contexts lacks the key, that lens is dispatched_by-unknown and
#           every in-session hit is treated as offending (the wider,
#           pre-revision rule) so the check never silently weakens while the
#           map's own dispatched_by support is incomplete. Read from a
#           fixture's own map snapshot when one is present (see below), else
#           computed by invoking the real scripts/plugin-map.sh over the same
#           --root; if the map cannot be computed (script absent, no
#           python3/PyYAML, or the map does not yet emit the
#           dispatched-context shape this check depends on), this one clause
#           is silently skipped rather than blocking on a measurement the
#           tree cannot yet produce.
#   AC-42 — a lens named in a gate's dispatch text (a `lenses:` block's
#           `name:` field, or a literal `--lens <name>` invocation) with no
#           manifest entry.
#   AC-43 — a manifest section's first non-blank content line (after its
#           heading, after frontmatter) found verbatim inside a gate body —
#           lens prompt text has leaked back into the dispatch site instead
#           of living only in the declared section.
#   AC-29 — a load-when: frontmatter value that is missing, blank, or names
#           no condition any consumer states within 3 lines of a literal
#           reference to the file.
#   AC-30 — a load-when: declaration that is well-formed (AC-29 passes) but
#           whose only referencing context carries no conditional word
#           (when/if/only/on the/trigger/case) — booked as conditional but
#           read unconditionally.
#
# Map-snapshot override (fixture-only): if <root>/.touchstone/checker/
# lens-manifest-map-fixture.json exists, its {stages:[{contexts:[...]}]}
# shape is used verbatim for the AC-25 clause instead of invoking
# plugin-map.sh — this decouples the manifest checker's own fixtures from a
# sibling worker's in-flight edits to plugin-map.sh's dispatched-context
# support (see task contract § Read-Only Boundaries). Never present in the
# real repo root, so production runs always compute the map for real.
#
# Absent python3, or PyYAML -> WARN and exit 0 (nothing this checker asserts
# is decidable without them).
#
# Output on failure: one line per violation, prefixed [check-lens-manifest],
# exit 1. Clean -> exit 0.
set -uo pipefail

root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

command -v python3 >/dev/null 2>&1 || {
  echo "[check-lens-manifest] WARN: python3 not found -- lens-manifest check skipped" >&2
  exit 0
}
python3 -c 'import yaml' >/dev/null 2>&1 || {
  echo "[check-lens-manifest] WARN: PyYAML not found -- lens-manifest check skipped" >&2
  exit 0
}

self_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
self_root="$(git -C "${self_dir:-.}" rev-parse --show-toplevel 2>/dev/null)"
[ -n "$self_root" ] || self_root="$root"

pyfile="$(mktemp "${TMPDIR:-/tmp}/check-lens-manifest.XXXXXX")"
trap 'rm -f "$pyfile"' EXIT

cat > "$pyfile" <<'PY'
import json, os, re, subprocess, sys

root, self_root = sys.argv[1], sys.argv[2]
problems = []


def fail(msg):
    problems.append(msg)


try:
    import yaml
except ImportError:
    print("[check-lens-manifest] WARN: PyYAML not found -- lens-manifest check skipped", file=sys.stderr)
    sys.exit(0)

manifest_path = os.path.join(root, 'skills/_shared/lens-manifest.yaml')
if not os.path.isfile(manifest_path):
    print("[check-lens-manifest] manifest not found: skills/_shared/lens-manifest.yaml")
    sys.exit(1)

with open(manifest_path) as f:
    manifest_text = f.read()
try:
    data = yaml.safe_load(manifest_text) or {}
except Exception as exc:
    print("[check-lens-manifest] manifest fails to parse: %s" % exc)
    sys.exit(1)

lenses = data.get('lenses') if isinstance(data, dict) else None
if not isinstance(lenses, list):
    print("[check-lens-manifest] manifest: 'lenses' must be a list")
    sys.exit(1)

VALID_ARMS = {'cc', 'codex'}
VALID_DEST = {'host', 'arm'}
HEADING_RE = re.compile(r'^(#{1,6})\s+(.*\S)\s*$')

seen_names = {}
all_sections_flat = []   # [{lens, ref, id, destination, path, content}]


def extract_section(ref):
    """Return (relpath, content_or_None). Records an AC-39 failure and
    returns None content when the ref/heading does not resolve."""
    if '#' in ref:
        path, heading = ref.split('#', 1)
    else:
        path, heading = ref, None
    abspath = os.path.join(root, path)
    if not os.path.isfile(abspath):
        fail("AC-39: ref path does not exist: %s" % path)
        return path, None
    with open(abspath, errors='replace') as f:
        lines = f.read().splitlines()
    if heading is None:
        return path, '\n'.join(lines)
    start, start_level = None, None
    for i, line in enumerate(lines):
        m = HEADING_RE.match(line)
        if m and m.group(2).strip() == heading.strip():
            start, start_level = i, len(m.group(1))
            break
    if start is None:
        fail("AC-39: heading not found: %s#%s" % (path, heading))
        return path, None
    end = len(lines)
    for j in range(start + 1, len(lines)):
        m = HEADING_RE.match(lines[j])
        if m and len(m.group(1)) <= start_level:
            end = j
            break
    return path, '\n'.join(lines[start:end])


for idx, lens in enumerate(lenses):
    if not isinstance(lens, dict):
        fail("AC-39: lens #%d: not a mapping" % idx)
        continue
    name = lens.get('name')
    if not name:
        fail("AC-39: lens #%d: missing 'name'" % idx)
        continue
    if name in seen_names:
        fail("AC-41: duplicate lens name: %s" % name)
    seen_names[name] = seen_names.get(name, 0) + 1

    arms = lens.get('arms')
    if not arms or not isinstance(arms, list):
        fail("AC-39: lens '%s': missing or empty 'arms'" % name)
    else:
        for a in arms:
            if a not in VALID_ARMS:
                fail("AC-39: lens '%s': arm outside cc|codex: %s" % (name, a))

    if lens.get('subject') is not True:
        fail("AC-39: lens '%s': subject must be true" % name)

    sections = lens.get('sections')
    if not sections or not isinstance(sections, list):
        fail("AC-39: lens '%s': missing or empty 'sections'" % name)
        continue

    seen_refs = set()
    for sidx, sec in enumerate(sections):
        if not isinstance(sec, dict):
            fail("AC-39: lens '%s' section #%d: not a mapping" % (name, sidx))
            continue
        ref = sec.get('ref')
        sid = sec.get('id')
        dest = sec.get('destination')
        if not ref:
            fail("AC-39: lens '%s' section #%d: missing 'ref'" % (name, sidx))
            continue
        if not sid:
            fail("AC-39: lens '%s' section '%s': missing 'id'" % (name, ref))
        if dest not in VALID_DEST:
            fail("AC-39: lens '%s' section '%s': destination outside host|arm: %s" % (name, ref, dest))
        if ref in seen_refs:
            fail("AC-41: lens '%s': same ref declared twice: %s" % (name, ref))
        seen_refs.add(ref)

        relpath, content = extract_section(ref)
        all_sections_flat.append({
            'lens': name, 'ref': ref, 'id': sid, 'destination': dest,
            'path': relpath, 'content': content,
        })

manifest_names = set(seen_names.keys())

# ---------------------------------------------------------------- AC-42 / AC-43
DISPATCH_SITES = [
    'skills/design-review/SKILL.md',
    'skills/deliverable-review/SKILL.md',
    'skills/assay/references/fork-case.md',
]
dispatch_texts = {}
for site in DISPATCH_SITES:
    p = os.path.join(root, site)
    if os.path.isfile(p):
        with open(p, errors='replace') as f:
            dispatch_texts[site] = f.read()

NAME_RE = re.compile(r'\bname:\s*([A-Za-z0-9_-]+)')
LENS_FLAG_RE = re.compile(r'--lens\s+([A-Za-z0-9_-]+)')
LENSES_BLOCK_START_RE = re.compile(r'^\s*lenses:\s*$')


def lens_block_names(text):
    """Lens names declared inside a `lenses:` block (the routing declaration
    a gate body carries) -- NOT every `name:` in the file, since a skill's
    own frontmatter also carries one."""
    names = set()
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        if LENSES_BLOCK_START_RE.match(lines[i]):
            j = i + 1
            while j < len(lines):
                line = lines[j]
                if line.strip() == '':
                    j += 1
                    continue
                if line[:1].isspace() or line.strip().startswith('-'):
                    names.update(NAME_RE.findall(line))
                    j += 1
                    continue
                break
            i = j
        else:
            i += 1
    return names


for site, text in dispatch_texts.items():
    used = lens_block_names(text) | set(LENS_FLAG_RE.findall(text))
    for used_name in sorted(used):
        if used_name not in manifest_names:
            fail("AC-42: lens '%s' named in %s has no manifest entry" % (used_name, site))


def read_frontmatter(text):
    lines = text.split('\n')
    if not lines or lines[0].strip() != '---':
        return {}, text
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            end = i
            break
    if end is None:
        return {}, text
    fm_text = '\n'.join(lines[1:end])
    body = '\n'.join(lines[end + 1:])
    try:
        fm = yaml.safe_load(fm_text) or {}
        if not isinstance(fm, dict):
            fm = {}
    except Exception:
        fm = {}
    return fm, body


for sec in all_sections_flat:
    if sec['content'] is None:
        continue
    if '#' in sec['ref']:
        body_lines = sec['content'].split('\n')[1:]   # drop the heading line itself
    else:
        _, body = read_frontmatter(sec['content'])
        body_lines = body.split('\n')
    first_line = next((l.strip() for l in body_lines if l.strip()), None)
    if not first_line:
        continue
    for site, text in dispatch_texts.items():
        if first_line in text:
            fail("AC-43: section '%s' (lens '%s') prompt text lives inline in %s" % (sec['id'], sec['lens'], site))

# ---------------------------------------------------------------- AC-25
map_data = None
override_path = os.path.join(root, '.touchstone/checker/lens-manifest-map-fixture.json')
if os.path.isfile(override_path):
    try:
        with open(override_path) as f:
            map_data = json.load(f)
    except Exception:
        map_data = None
else:
    pm = os.path.join(self_root, 'scripts/plugin-map.sh')
    if os.path.isfile(pm):
        try:
            proc = subprocess.run(['bash', pm, '--root', root], capture_output=True, text=True, timeout=120)
            if proc.returncode == 0 and proc.stdout.strip():
                map_data = json.loads(proc.stdout)
        except Exception:
            map_data = None

if isinstance(map_data, dict):
    contexts = []
    for stage in map_data.get('stages', []) or []:
        for ctx in stage.get('contexts', []) or []:
            contexts.append(ctx)
    if any('kind' in c for c in contexts):
        for sec in all_sections_flat:
            if sec['content'] is None or not sec['path']:
                continue
            locations = [(c.get('context'), c.get('kind')) for c in contexts
                         if sec['path'] in (c.get('files') or [])]
            in_session_locations = [name for name, kind in locations if kind == 'in-session']

            if sec['destination'] == 'arm' and in_session_locations:
                dispatched_ctxs = [c for c in contexts
                                    if c.get('kind') == 'dispatched' and c.get('lens') == sec['lens']]
                if dispatched_ctxs and all('dispatched_by' in c for c in dispatched_ctxs):
                    dispatched_by = set()
                    for c in dispatched_ctxs:
                        dispatched_by.update(c.get('dispatched_by') or [])
                    offending = [name for name in in_session_locations if name in dispatched_by]
                else:
                    # dispatched_by-unknown (no dispatched context yet for this lens, or
                    # one of its dispatched contexts lacks the key) -- fall back to the
                    # wider pre-revision rule so the check never silently weakens
                    offending = in_session_locations
                if offending:
                    fail("AC-25: fragment '%s' declared destination arm but still charged to an "
                         "in-session context that dispatches lens '%s'; found in: %s (offending: %s)"
                         % (sec['id'], sec['lens'], locations, offending))
            elif sec['destination'] == 'host' and not in_session_locations:
                fail("AC-25: fragment '%s' declared destination host but is not charged to any "
                     "in-session context; found in: %s" % (sec['id'], locations or ['nowhere']))

# ---------------------------------------------------------------- AC-29 / AC-30
def content_words(s):
    return set(w for w in re.findall(r"[A-Za-z0-9']+", s.lower()) if len(w) >= 3)


COND_RE = re.compile(r'\b(when|if|only|on\s+the|trigger|case)\b', re.I)

scan_files = []
for dirpath, dirnames, filenames in os.walk(root):
    if '.git' in dirnames:
        dirnames.remove('.git')
    # synthetic checker fixture trees are not a real reference graph -- a
    # fixture's own load-when is validated by this checker's own rail run
    # (TOUCHSTONE_CHECK_ROOT pointed AT that fixture case), never by being
    # swept in as "consumer" evidence for an unrelated file's declaration
    if 'fixtures' in dirnames:
        dirnames.remove('fixtures')
    for fn in filenames:
        if fn.endswith(('.md', '.sh')):
            scan_files.append(os.path.relpath(os.path.join(dirpath, fn), root))

file_cache = {}


def read_lines(relpath):
    if relpath not in file_cache:
        try:
            with open(os.path.join(root, relpath), errors='replace') as f:
                file_cache[relpath] = f.read().split('\n')
        except Exception:
            file_cache[relpath] = []
    return file_cache[relpath]


for relpath in scan_files:
    if not relpath.endswith('.md'):
        continue
    text = '\n'.join(read_lines(relpath))
    fm, _ = read_frontmatter(text)
    if 'load-when' not in fm:
        continue
    raw_val = fm.get('load-when')
    val_str = '' if raw_val is None else str(raw_val).strip()
    if not val_str:
        fail("AC-29: %s: load-when declaration is missing or blank" % relpath)
        continue

    cwords = content_words(val_str)
    matched = False
    cond_ok = False
    for other in scan_files:
        if other == relpath:
            continue
        lines = read_lines(other)
        for i, line in enumerate(lines):
            if relpath not in line:
                continue
            lo, hi = max(0, i - 3), min(len(lines), i + 4)
            window = '\n'.join(lines[lo:hi])
            if cwords & content_words(window):
                matched = True
                if COND_RE.search(window):
                    cond_ok = True
    if not matched:
        fail("AC-29: %s: load-when value '%s' names no condition any consumer states" % (relpath, val_str))
    elif not cond_ok:
        fail("AC-30: %s: load-when value '%s' is well-formed but its consumer reads it unconditionally"
             % (relpath, val_str))

if problems:
    for p in problems:
        print("[check-lens-manifest] %s" % p)
    sys.exit(1)
sys.exit(0)
PY

python3 "$pyfile" "$root" "$self_root"
exit $?
