#!/usr/bin/env bash
# scripts/check-artifact.sh — validate a YAML stage artifact against its schema.
#
# Usage: check-artifact.sh <spec|review|deviation|quiz|assay|explore|epic> <file> [--root <dir>]
#   exit 0 → valid (warnings, prefixed `warn:`, never change the exit code)
#   exit 1 → one line per violation: `<field-path>: <rule>`
#   exit 2 → usage / missing dependency (PyYAML: `pip install pyyaml`)
#
# Schemas: skills/_shared/schemas/<kind>.schema.yaml (single home of every field set and
# id family; the keyword legend is in spec.schema.yaml's header). Checks: required keys,
# enums, unknown keys, id uniqueness per family, in-file references (traces_to, edges),
# ledger references (basis / why_ref / consensus / rulings — an id resolves iff the ledger
# has a line starting `- <id>` or `| <id>`, or, for a `.yaml` ledger, a structured lookup
# across its term_sheet/alignment/extraction ids), field-path grammar on review findings and
# quiz anchors (field paths resolve into a target spec only where resolves is target — a
# quiz anchor gets the grammar check only), path-free phase_map,
# degraded_reason when degraded, `pattern` on a string value, `minItems` on an array,
# `spec_ref` resolution (below), and per-kind rules: a review finding with no locator
# (field/file/refs all absent or empty); a review finding whose lens is conformance and
# status is covered (coverage rows belong in coverage[], not findings[]); a deviation
# entry whose refs is empty without `derived: true`; a deviation metrics list with a
# duplicate phase; a quiz item whose answer is present without a result; an explore
# document whose plateau is false without a reach_under_determined reason; kind epic's
# cross-file close gate (run with --root <epic-dir>): a done epic with an AC of an
# accepted *.spec.yaml under --root carrying no reckoning[] row; a reckoning row with
# none of covered_by/unverified/waiver set; a live_bearing reckoning row whose
# covered_by carries no live-artifact provenance, or that sets unverified/waiver; an
# unverified/waived reckoning row with no issue; a done epic with an empty
# retrospective; a phases[].n that does not match its linked spec's top-level phase;
# an epic dir carrying both epic.yaml and a hand-written index.md with no
# generated-projection marker.
#
# spec_ref resolution — the value of a `refs`-shaped field must name a US/REQ/AC/INV id
# defined in a *resolution target*, picked by the schema's own top-level `resolves`
# declaration (`self|target|phase|none` — no kind-specific branch here): `self` → the file
# itself (kind spec); `target` → the `target` spec named in the document (kind review);
# `phase` → the `*.spec.yaml` directly under --root whose top-level `phase` equals the
# enclosing item's own `phase` (cached per phase; kinds deviation and quiz); `none` → this
# kind carries no spec_ref field. No resolution target found → one `warn:` line per
# occurrence, exit unchanged.
#
# --root <dir>: directory the ledger (spec `facts_source.record`) and a review's `target`
# resolve against; default = the artifact's own directory.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kind="${1:-}"; file="${2:-}"; root=""
[ "${3:-}" = "--root" ] && root="${4:-}"
case "$kind" in spec|review|deviation|quiz|assay|explore|epic) ;; *) echo "usage: check-artifact.sh <spec|review|deviation|quiz|assay|explore|epic> <file> [--root <dir>]" >&2; exit 2 ;; esac
[ -f "$file" ] || { echo "check-artifact.sh: no such file: $file" >&2; exit 2; }
schema="$here/../skills/_shared/schemas/$kind.schema.yaml"
[ -f "$schema" ] || { echo "check-artifact.sh: schema missing: $schema" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "check-artifact.sh: python3 not found" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "check-artifact.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }

python3 - "$kind" "$file" "$schema" "$root" <<'PY'
import sys, os, re, yaml, datetime, glob

kind, path, schema_path, root = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
root = os.path.abspath(root) if root else os.path.dirname(os.path.abspath(path))
schema = yaml.safe_load(open(schema_path, encoding='utf-8'))
try:
    doc = yaml.safe_load(open(path, encoding='utf-8'))
except yaml.YAMLError as e:
    print(f"(file): not parseable YAML — {e}"); sys.exit(1)
if not isinstance(doc, dict):
    print("(file): top level must be a mapping"); sys.exit(1)

# kind deviation composes: metrics.schema.yaml carries the `metrics` subtree — pop it out
# before validating doc against deviation.schema.yaml (which no longer declares that
# property) and validate it separately below, once the deviation walk is done.
metrics_present = kind == 'deviation' and 'metrics' in doc
metrics_val = doc.pop('metrics', None) if metrics_present else None

errors, warns = [], []
ids = {}        # family -> {id: path}
refs = []       # (path, family, value)
ledger_refs = []  # (path, value)
field_paths = []  # (path, value)
spec_refs = []    # (path, value, phase) — spec_ref-tagged refs-list values

def type_ok(v, t):
    return {'string': lambda: isinstance(v, str), 'date': lambda: isinstance(v, (str, datetime.date)), 'integer': lambda: isinstance(v, int) and not isinstance(v, bool),
            'number': lambda: isinstance(v, (int, float)) and not isinstance(v, bool),
            'boolean': lambda: isinstance(v, bool), 'array': lambda: isinstance(v, list),
            'object': lambda: isinstance(v, dict)}.get(t, lambda: True)()

def walk(v, s, p, phase=None, parent=None):
    if 'oneOf' in s:
        for alt in s['oneOf']:
            n = len(errors); walk(v, alt, p, phase, parent)
            if len(errors) == n: return
            del errors[n:]
        errors.append(f"{p}: matches none of the allowed forms"); return
    t = s.get('type')
    if t and not type_ok(v, t):
        errors.append(f"{p}: expected {t}"); return
    if 'enum' in s and v not in s['enum']:
        # a review finding's lens=conformance + status=covered names a distinct rule (coverage
        # rows belong in coverage[]), not the generic "not in enum" message
        if kind == 'review' and v == 'covered' and re.fullmatch(r'findings\[[^\]]+\]\.status', p) and isinstance(parent, dict) and parent.get('lens') == 'conformance':
            errors.append(f"{p}: covered rows belong in coverage[]")
        else:
            errors.append(f"{p}: '{v}' not in {s['enum']}")
    if t == 'array' and 'minItems' in s and len(v) < s['minItems']:
        errors.append(f"{p}: minItems {s['minItems']}")
    fam = s.get('id')
    if fam and isinstance(v, str):
        if fam in ('US', 'REQ', 'AC', 'INV', 'F', 'D', 'QZ', 'W') and not re.fullmatch(fam + r'-\d+', v):
            errors.append(f"{p}: id must be {fam}-<n>")
        if v in ids.setdefault(fam, {}):
            errors.append(f"{p}: duplicate id {v} (first at {ids[fam][v]})")
        else:
            ids[fam][v] = p
    if s.get('ref'):
        for x in (v if isinstance(v, list) else [v]): refs.append((p, s['ref'], x))
    if s.get('ledger_ref'):
        for x in (v if isinstance(v, list) else [v]): ledger_refs.append((p, x))
    if s.get('field_path') and isinstance(v, str): field_paths.append((p, v))
    if s.get('pattern') and isinstance(v, str) and not re.fullmatch(s['pattern'], v):
        errors.append(f"{p}: '{v}' does not match pattern {s['pattern']}")
    if s.get('spec_ref') and isinstance(v, str):
        spec_refs.append((p, v, phase))
    if s.get('path_free') and isinstance(v, str):
        m = re.search(r'\S+/\S+|\b\w+\.(md|sh|yaml|yml|json|py|js|html|txt|jsonl)\b', v)
        if m: errors.append(f"{p}: human-facing panel carries a path-like token '{m.group(0)}'")
    if t == 'object':
        props = s.get('properties', {})
        for k in s.get('required', []):
            if k not in v: errors.append(f"{p + '.' if p else ''}{k}: required")
        new_phase = phase
        if isinstance(v, dict) and isinstance(v.get('phase'), int) and not isinstance(v.get('phase'), bool):
            new_phase = v['phase']
        ap = s.get('additionalProperties')
        for k, x in v.items():
            if k in props: walk(x, props[k], f"{p}.{k}" if p else k, new_phase, v)
            elif ap is False: errors.append(f"{p + '.' if p else ''}{k}: unknown key")
            elif isinstance(ap, dict): walk(x, ap, f"{p}.{k}" if p else k, new_phase, v)
    elif t == 'array' and 'items' in s:
        it = s['items']
        for i, x in enumerate(v):
            sel = x.get('id') if isinstance(x, dict) and isinstance(x.get('id'), str) else str(i)
            walk(x, it, f"{p}[{sel}]", phase, parent)

walk(doc, schema, '')

if metrics_present:
    mschema_path = os.path.join(os.path.dirname(schema_path), 'metrics.schema.yaml')
    if os.path.isfile(mschema_path):
        mschema = yaml.safe_load(open(mschema_path, encoding='utf-8'))
        walk({'metrics': metrics_val}, mschema, '')
    else:
        errors.append("metrics: metrics.schema.yaml missing")

for p, fam, x in refs:
    if x not in ids.get(fam, {}): errors.append(f"{p}: '{x}' names no {fam} id defined in this file")

# ---- field-path grammar + resolution
PATH_RE = re.compile(r'^[A-Za-z_]\w*(\[[^\]]+\])?(\.[A-Za-z_]\w*(\[[^\]]+\])?)*$')
def resolve(node, fp):
    """Return True iff fp addresses something in node ([*] = any element for the rest of the path)."""
    segs = re.findall(r'([A-Za-z_]\w*)(?:\[([^\]]+)\])?', fp)
    def walk(node, i):
        if i == len(segs): return True
        key, sel = segs[i]
        if not isinstance(node, dict) or key not in node: return False
        node = node[key]
        if not sel: return walk(node, i + 1)
        if not isinstance(node, list): return False
        if sel == '*':
            return any(walk(e, i + 1) for e in node)
        if sel.isdigit():
            return int(sel) < len(node) and walk(node[int(sel)], i + 1)
        hit = [e for e in node if isinstance(e, dict) and e.get('id') == sel]
        return bool(hit) and walk(hit[0], i + 1)
    return walk(node, 0)

def under_root(rel, label):
    """A --root-relative artifact path must stay inside root (no absolute path, no `..`)."""
    if not isinstance(rel, str) or not rel: return None
    full = os.path.abspath(os.path.join(root, rel))
    if os.path.isabs(rel) or os.path.commonpath([root, full]) != root:
        errors.append(f"{label}: '{rel}' escapes the --root directory"); return None
    return full

# ---- resolution target, picked by the schema's own declared `resolves` value — no
# kind-specific branch here: self|target|phase|none
resolves = schema.get('resolves')
if resolves not in ('self', 'target', 'phase', 'none'):
    print(f"(schema): resolves declaration {resolves!r} must be one of self|target|phase|none", file=sys.stderr); sys.exit(2)

target_doc = None
target_path = None
if resolves == 'target':
    tp = under_root(doc.get('target'), 'target') or ''
    if tp and os.path.isfile(tp):
        target_path = tp
        try: target_doc = yaml.safe_load(open(tp, encoding='utf-8'))
        except yaml.YAMLError: target_doc = None
for p, fp in field_paths:
    if not PATH_RE.match(fp): errors.append(f"{p}: '{fp}' does not parse as a field path"); continue
    if resolves == 'target' and target_doc is not None and not resolve(target_doc, fp):
        errors.append(f"{p}: '{fp}' resolves to nothing in the target spec")
    elif resolves == 'target' and target_doc is None:
        warns.append(f"{p}: target spec not found under --root; field path unresolved")

# ---- spec_ref resolution (US/REQ/AC/INV ids on refs-list values)
def spec_ids_for(d):
    out = {'US': set(), 'REQ': set(), 'AC': set(), 'INV': set()}
    if not isinstance(d, dict): return out
    for us in d.get('user_stories') or []:
        if isinstance(us, dict) and isinstance(us.get('id'), str): out['US'].add(us['id'])
    for r in d.get('requirements') or []:
        if not isinstance(r, dict): continue
        if isinstance(r.get('id'), str): out['REQ'].add(r['id'])
        for a in r.get('acs') or []:
            if isinstance(a, dict) and isinstance(a.get('id'), str): out['AC'].add(a['id'])
    for inv in d.get('invariants') or []:
        if isinstance(inv, dict) and isinstance(inv.get('id'), str): out['INV'].add(inv['id'])
    return out

def resolves_id(x, id_sets):
    fam = x.split('-', 1)[0]
    return fam in id_sets and x in id_sets[fam]

# resolves == 'phase' target: the *.spec.yaml directly under --root whose top-level phase
# equals ph (cached per phase). Used by the generic spec_ref resolution below for any kind
# declaring resolves: phase (deviation entries[].refs, quiz items[].refs).
_phase_cache = {}
def spec_for_phase(ph):
    if ph in _phase_cache: return _phase_cache[ph]
    found = None
    for f in sorted(glob.glob(os.path.join(root, '*.spec.yaml'))):
        try: d = yaml.safe_load(open(f, encoding='utf-8'))
        except yaml.YAMLError: continue
        if isinstance(d, dict) and d.get('phase') == ph:
            found = (f, spec_ids_for(d)); break
    _phase_cache[ph] = found
    return found

if spec_refs:
    if resolves == 'self':
        self_ids = spec_ids_for(doc)
        base = os.path.basename(path)
        for p, x, ph in spec_refs:
            if not resolves_id(x, self_ids):
                errors.append(f"{p}: '{x}' resolves to no id in {base}")
    elif resolves == 'target':
        if target_doc is not None:
            tids = spec_ids_for(target_doc)
            tbase = os.path.basename(target_path)
            for p, x, ph in spec_refs:
                if not resolves_id(x, tids):
                    errors.append(f"{p}: '{x}' resolves to no id in {tbase}")
        else:
            warned = set()
            for p, x, ph in spec_refs:
                key = p.rsplit('[', 1)[0]
                if key in warned: continue
                warned.add(key)
                warns.append(f"{key}: target spec not found under --root; refs unresolved")
    elif resolves == 'phase':
        warned = set()
        for p, x, ph in spec_refs:
            key = p.rsplit('[', 1)[0]
            if ph is None:
                if key in warned: continue
                warned.add(key); warns.append(f"{key}: no phase on this item; refs unresolved")
                continue
            found = spec_for_phase(ph)
            if found is None:
                if key in warned: continue
                warned.add(key); warns.append(f"{key}: no spec for phase {ph} found under --root; refs unresolved")
                continue
            f, tids = found
            if not resolves_id(x, tids):
                errors.append(f"{p}: '{x}' resolves to no id in {os.path.basename(f)}")

# ---- ledger resolution
ledger = None
if resolves == 'self':
    rec = (doc.get('facts_source') or {}).get('record') if isinstance(doc.get('facts_source'), dict) else None
    if rec: ledger = under_root(rec, 'facts_source.record')
elif resolves == 'target' and isinstance(target_doc, dict):
    rec = (target_doc.get('facts_source') or {}).get('record')
    if rec: ledger = under_root(rec, 'target facts_source.record')
if ledger_refs:
    if ledger and os.path.isfile(ledger):
        if ledger.lower().endswith(('.yaml', '.yml')):
            # structured lookup into an assay .yaml record — id families T/A/B/Q/R
            try: ld = yaml.safe_load(open(ledger, encoding='utf-8'))
            except yaml.YAMLError: ld = None
            ledger_ids = set()
            if isinstance(ld, dict):
                for coll in ('term_sheet', 'alignment', 'extraction'):
                    for it in ld.get(coll) or []:
                        if isinstance(it, dict) and isinstance(it.get('id'), str):
                            ledger_ids.add(it['id'])
            def ledger_resolves(i): return str(i) in ledger_ids
        else:
            lines = open(ledger, encoding='utf-8').read().splitlines()
            def ledger_resolves(i):
                pat = re.compile(r'^(?:- |\| )' + re.escape(str(i)) + r'(?=[\s|]|$)')
                return any(pat.match(l) for l in lines)
        for p, x in ledger_refs:
            if not ledger_resolves(str(x)): errors.append(f"{p}: '{x}' resolves to no ledger line ('- {x}' / '| {x}') in {os.path.basename(ledger)}")
    else:
        warns.append(f"ledger not found ({ledger or 'no facts_source.record'}); {len(ledger_refs)} ledger reference(s) unresolved")

# ---- per-kind rules
if kind == 'spec':
    for r in doc.get('requirements') or []:
        if not isinstance(r, dict): continue
        for a in r.get('acs') or []:
            if not isinstance(a, dict): continue
            then = str(a.get('then', ''))
            stripped = re.sub(r'\b[A-Z]+-\d+\b|\bexit \d+\b', '', then)
            if re.search(r'\b\d+\b', stripped) and not a.get('basis'):
                warns.append(f"requirements[{r.get('id')}].acs[{a.get('id')}].then: numeric literal with no basis — reviewer decides")
elif kind == 'review':
    if doc.get('degraded') is True and not doc.get('degraded_reason'):
        errors.append("degraded_reason: required when degraded is true")
    lens_arms = {}
    for pv in doc.get('providers') or []:
        if isinstance(pv, dict) and isinstance(pv.get('lens'), str):
            lens_arms.setdefault(pv['lens'], set()).update(a for a in (pv.get('arms') or []) if isinstance(a, str))
    for f in doc.get('findings') or []:
        if not isinstance(f, dict): continue
        if not f.get('field') and not f.get('file') and not f.get('refs'):
            errors.append(f"findings[{f.get('id')}]: no locator (field, file or refs)")
        # an arm a finding credits must be an arm that ran that lens (providers is the record of what ran)
        if isinstance(f.get('lens'), str) and isinstance(f.get('found_by'), list):
            for a in f['found_by']:
                if a not in lens_arms.get(f['lens'], set()):
                    errors.append(f"findings[{f.get('id')}].found_by: '{a}' is not an arm of lens '{f['lens']}' in providers")
elif kind == 'deviation':
    for e in doc.get('entries') or []:
        if not isinstance(e, dict): continue
        refs_v = e.get('refs')
        if isinstance(refs_v, list) and len(refs_v) == 0 and e.get('derived') is not True:
            errors.append(f"entries[{e.get('id')}].refs: empty refs require derived: true")

    seen_phases = set()
    for mi, m in enumerate(metrics_val or []):
        if not isinstance(m, dict): continue
        ph = m.get('phase')
        if ph in seen_phases:
            errors.append(f"metrics: duplicate phase {ph}")
        else:
            seen_phases.add(ph)
        st = m.get('stage_tokens')
        if isinstance(st, list):
            stages = sorted(x.get('stage') for x in st if isinstance(x, dict) and isinstance(x.get('stage'), int))
            if stages != [0, 1, 2, 3, 4, 5] or len(st) != 6:
                errors.append(f"metrics[{mi}].stage_tokens: stages 0-5 each exactly once")
elif kind == 'quiz':
    for it in doc.get('items') or []:
        if not isinstance(it, dict): continue
        iid = it.get('id')
        if 'answer' in it and 'result' not in it:
            errors.append(f"items[{iid}].result: required once answered")
elif kind == 'explore':
    if doc.get('plateau') is False and not doc.get('reach_under_determined'):
        errors.append("reach_under_determined: required when plateau is false")
elif kind == 'epic':
    # dual hand-written form: an index.md beside epic.yaml with no generated-projection
    # marker is an error naming the dual form (epic.yaml is the single authored source)
    GEN_MARKER = '<!-- generated: projection of epic.yaml -->'
    idx_path = os.path.join(root, 'index.md')
    if os.path.isfile(idx_path):
        idx_text = open(idx_path, encoding='utf-8').read()
        if GEN_MARKER not in idx_text:
            errors.append(f"(root): index.md present beside epic.yaml with no generated-projection marker ({GEN_MARKER!r}) — dual hand-written form")

    # phases[].n <-> its linked spec's top-level phase — cross-file consistency
    for ph in doc.get('phases') or []:
        if not isinstance(ph, dict): continue
        sp = ph.get('spec')
        if not sp: continue
        sp_path = os.path.join(root, sp)
        if not os.path.isfile(sp_path):
            warns.append(f"phases[{ph.get('n')}].spec: '{sp}' not found under --root; phase consistency unresolved")
            continue
        try: sd = yaml.safe_load(open(sp_path, encoding='utf-8'))
        except yaml.YAMLError: sd = None
        if isinstance(sd, dict) and sd.get('phase') != ph.get('n'):
            errors.append(f"phases[{ph.get('n')}].n: {ph.get('n')} does not match {sp}'s top-level phase ({sd.get('phase')!r})")

    # close-time evidence honesty floor — checked on every reckoning row present, not
    # only at status: done, so an epic.yaml can be validated at any point in its life
    reckoning_acs = {}
    for r in doc.get('reckoning') or []:
        if isinstance(r, dict) and isinstance(r.get('ac'), str):
            reckoning_acs[r['ac']] = r
    for ac, row in reckoning_acs.items():
        live = row.get('live_bearing') is True
        covered = str(row.get('covered_by') or '').strip()
        unverified = bool(row.get('unverified'))
        waiver = str(row.get('waiver') or '').strip()
        issue = str(row.get('issue') or '').strip()
        if live:
            if unverified:
                errors.append(f"reckoning[{ac}].unverified: illegal on a live-bearing row")
            if waiver:
                errors.append(f"reckoning[{ac}].waiver: illegal on a live-bearing row")
            if not covered or not re.search(r'\(via:|\b[0-9a-fA-F]{7,40}\b', covered):
                errors.append(f"reckoning[{ac}].covered_by: live-bearing row requires live-artifact provenance (a '(via:' citation or a commit token) — proxy-only coverage is rejected")
        else:
            if (unverified or waiver) and not issue:
                errors.append(f"reckoning[{ac}].issue: required when unverified or waiver is set")
            if not covered and not unverified and not waiver:
                errors.append(f"reckoning[{ac}]: no covered_by, no unverified mark, and no waiver — blocks close")

    # status: done ⇒ every AC of every accepted *.spec.yaml under --root is reckoned, and
    # the retrospective is non-empty
    if doc.get('status') == 'done':
        if not str(doc.get('retrospective') or '').strip():
            errors.append("retrospective: required (non-empty) when status is done")
        for f in sorted(glob.glob(os.path.join(root, '*.spec.yaml'))):
            try: sd = yaml.safe_load(open(f, encoding='utf-8'))
            except yaml.YAMLError: continue
            if not isinstance(sd, dict) or sd.get('status') != 'accepted': continue
            for r in sd.get('requirements') or []:
                if not isinstance(r, dict): continue
                for a in r.get('acs') or []:
                    if not isinstance(a, dict): continue
                    aid = a.get('id')
                    if aid and aid not in reckoning_acs:
                        errors.append(f"reckoning: {aid} in {os.path.basename(f)} has no reckoning[] row")

for w in warns: print(f"warn: {w}")
for e in errors: print(e)
sys.exit(1 if errors else 0)
PY
