#!/usr/bin/env bash
# scripts/phase-metrics.sh — print one phase's metrics entry (delta.contracts[metrics-entry],
# 2026-08-31-phase4-workflow-diet.spec.yaml REQ-7 / AC-21) on stdout as a single, two-space-
# indented YAML list item, ready to paste under deviation.yaml's `metrics:` list.
#
# Usage: phase-metrics.sh <epic-dir> <transcript.jsonl>... --phase N
#          [--range <base>..<head>] [--churn <shape_driven_lines>,<other_lines>] [--self-test]
#   --range   defaults to `$(git merge-base HEAD main)..HEAD`. Both ends are resolved to full
#             commit shas and their committer timestamps; every transcript event this script
#             reads is bounded to (base_ts, head_ts] — a session that runs past a phase's ship
#             commit into the next phase's work (no idle gap at the seam to detect it by) is
#             excluded past that seam. This bound is applied generally, not just for phase 3.
#   --churn   the one manual input (hand-classified at phase-ship, AC-23); default 0,0.
#   exit 0 → entry printed · 1 → git/parse error (message on stderr) · 2 → usage error
#
# Field derivation (task-contract build-p4/T3, quoting spec AC-21's `then`):
#   human_turns  — main-thread (`type: user`, not isSidechain) transcript lines whose content is
#                  not a tool_result block and is not a local-command / system-reminder-only echo
#                  (`<local-command-caveat>`, `<command-name>`, `<command-message>`,
#                  `<local-command-stdout/stderr>`, `Base directory for this skill:`,
#                  `<system-reminder>`, or an interrupt notice) — counted RAW, one per JSONL line
#                  (not deduped by promptId: Claude Code batches several queued inbound messages,
#                  including teammate/task-notification relays, under one promptId, and time.md's
#                  own per-session counts only reproduce when each line counts once — verified
#                  against this epic's own phase-3 sessions: 43 + 40 = 83 vs time.md's 43 + 39).
#                  A task-notification or a relayed teammate message is not literally typed by the
#                  human but is not a tool_result or an echo either, so it counts under this rule.
#   wall_clock_h — main-thread (`user` + `assistant`, not isSidechain) events, sorted, summed as
#                  the total of every consecutive gap ≤ 30 minutes (a gap > 30 min is idle and
#                  excluded, per discovery time.md's own method note) — rounded to 0.1h. Verified
#                  by --self-test's synthetic 45-minute gap.
#   dispatches   — assistant `tool_use` blocks named `Agent` (also `Task`, the legacy tool name).
#   lens_h       — every review.yaml under <epic-dir> (recursive) whose `target` resolves (first
#                  relative to the review file's own directory, then to <epic-dir>) to a
#                  *.spec.yaml whose top-level `phase` == the --phase argument; for each
#                  `severity: H` finding in a matched file, lens_h[finding.lens] += 1; lenses with
#                  0 H are omitted. (Commander ruling 2026-08-31 on this task's own build-p4/T3
#                  risk report: the sha-in-<base>..<head> predicate this replaced spuriously
#                  matched a later phase's own design-review when this epic's PRs are squash-
#                  merged — a phase-N review can share its sha with phase N-1's ship commit. The
#                  target-spec phase join disambiguates by content instead of by history shape.
#                  --range is no longer used for this field; it still bounds measured_at and the
#                  human_turns/wall_clock_h/dispatches transcript window below.)
#   stage_tokens — `bash scripts/plugin-map.sh` JSON; for each stage 0..5, the byte size of the
#                  UNION of that stage's contexts[].files, ÷ 4 (integer division) — same rule as
#                  .touchstone/checker/pre-push/check-plugin-ratchets.sh's max_stage_load_tokens,
#                  computed per stage instead of maxed across stages.
#   false_edges  — len(map.false_edges).
#   measured_at  — <head> resolved to its full 40-hex commit sha.
set -uo pipefail

# --------------------------------------------------------------- self-test
if [ "${1:-}" = "--self-test" ]; then
  command -v python3 >/dev/null 2>&1 || { printf 'phase-metrics.sh: python3 not found\n' >&2; exit 1; }
  python3 -c 'import yaml' 2>/dev/null || { printf 'phase-metrics.sh: PyYAML not installed\n' >&2; exit 1; }
  _self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  python3 - "$_self" <<'SELFTEST_EOF'
import json, os, re, shutil, subprocess, sys, tempfile
from datetime import datetime, timedelta, timezone
import yaml

self_path = sys.argv[1]
fails = 0

def report(ok, label, detail=''):
    global fails
    print('%s %s%s' % ('PASS' if ok else 'FAIL', label, '' if ok else ' — ' + detail))
    if not ok:
        fails += 1

tmp = tempfile.mkdtemp(prefix='phase-metrics-selftest.')
try:
    def git(*args, env=None):
        return subprocess.run(['git'] + list(args), cwd=tmp, capture_output=True, text=True, env=env)

    git('init', '-q')
    git('config', 'user.email', 'selftest@example.com')
    git('config', 'user.name', 'selftest')

    t0 = datetime(2026, 1, 1, 0, 0, 0, tzinfo=timezone.utc)

    def iso(dt):
        return dt.strftime('%Y-%m-%dT%H:%M:%S.000Z')

    def commit(name, dt):
        open(os.path.join(tmp, name + '.txt'), 'w').write(name)
        git('add', '.')
        env = dict(os.environ)
        gitdate = dt.strftime('%Y-%m-%dT%H:%M:%S+00:00')
        env['GIT_AUTHOR_DATE'] = gitdate
        env['GIT_COMMITTER_DATE'] = gitdate
        r = git('commit', '-q', '-m', name, env=env)
        if r.returncode != 0:
            report(False, 'setup commit %s' % name, r.stderr)
        return git('rev-parse', 'HEAD').stdout.strip()

    base_full = commit('base', t0)
    head_full = commit('head', t0 + timedelta(hours=2))

    t_human1 = t0 + timedelta(minutes=5)
    t_dispatch = t_human1 + timedelta(seconds=5)
    t_toolresult = t_dispatch + timedelta(seconds=5)
    t_assistant1 = t_toolresult + timedelta(seconds=5)
    t_human2 = t_assistant1 + timedelta(minutes=45)   # the 45-minute gap
    t_assistant2 = t_human2 + timedelta(seconds=5)

    def uline(ts, content):
        return json.dumps({'type': 'user', 'isSidechain': False, 'timestamp': iso(ts),
                            'message': {'role': 'user', 'content': content}})

    def aline(ts, content):
        return json.dumps({'type': 'assistant', 'isSidechain': False, 'timestamp': iso(ts),
                            'message': {'role': 'assistant', 'content': content}})

    lines = [
        uline(t_human1, 'first message'),
        aline(t_dispatch, [{'type': 'tool_use', 'name': 'Agent', 'id': 'toolu_1', 'input': {}}]),
        uline(t_toolresult, [{'type': 'tool_result', 'tool_use_id': 'toolu_1', 'content': 'ok'}]),
        aline(t_assistant1, [{'type': 'text', 'text': 'ack'}]),
        uline(t_human2, 'second message'),
        aline(t_assistant2, [{'type': 'text', 'text': 'done'}]),
    ]
    transcript_path = os.path.join(tmp, 'transcript.jsonl')
    open(transcript_path, 'w').write('\n'.join(lines) + '\n')

    epic_dir = os.path.join(tmp, 'epic')
    os.makedirs(epic_dir, exist_ok=True)

    # x.spec.yaml is phase 0 (the phase under test); y.spec.yaml is phase 1 (a later phase whose
    # own review must NOT contribute to phase 0's lens_h, even though both specs and both
    # reviews sit under the same epic dir and both reviews' sha could equally be HEAD).
    open(os.path.join(epic_dir, 'x.spec.yaml'), 'w').write(
        yaml.safe_dump({'id': 'SPEC-x', 'phase': 0, 'status': 'accepted'}, sort_keys=False))
    open(os.path.join(epic_dir, 'y.spec.yaml'), 'w').write(
        yaml.safe_dump({'id': 'SPEC-y', 'phase': 1, 'status': 'accepted'}, sort_keys=False))

    def review_doc(target, lens):
        return {
            'gate': 'design-review', 'target': target, 'sha': head_full, 'round': 1,
            'providers': [{'lens': lens, 'arms': ['cc']}],
            'degraded': False, 'verdict': 'approve',
            'counts': {'C': 0, 'H': 1, 'M': 0, 'L': 0}, 'rulings': [],
            'findings': [{'id': 'F-1', 'lens': lens, 'type': 'real-defect', 'provenance': 'original',
                          'severity': 'H', 'summary': 'x', 'fix': 'x', 'status': 'open', 'found_by': ['cc'],
                          'file': 'x.md'}],
            'waiting_on_human': [],
        }
    open(os.path.join(epic_dir, 'review.yaml'), 'w').write(
        yaml.safe_dump(review_doc('x.spec.yaml', 'challenger'), sort_keys=False))
    os.makedirs(os.path.join(epic_dir, 'other-phase-review'), exist_ok=True)
    open(os.path.join(epic_dir, 'other-phase-review', 'review.yaml'), 'w').write(
        yaml.safe_dump(review_doc('y.spec.yaml', 'quality'), sort_keys=False))

    range_arg = '%s..%s' % (base_full, head_full)
    r = subprocess.run(['bash', self_path, epic_dir, transcript_path, '--phase', '0', '--range', range_arg],
                        cwd=tmp, capture_output=True, text=True)
    lbl = 'fixture run: exit 0'
    report(r.returncode == 0, lbl, 'rc=%d stderr=%s' % (r.returncode, r.stderr.strip()[:500]))
    if r.returncode == 0:
        try:
            entry = (yaml.safe_load(r.stdout) or [{}])[0]
        except yaml.YAMLError as exc:
            entry = {}
            report(False, 'fixture output parses as YAML', str(exc))
        report(entry.get('human_turns') == 2, 'human_turns == 2', repr(entry.get('human_turns')))
        report(entry.get('dispatches') == 1, 'dispatches == 1', repr(entry.get('dispatches')))
        wch = entry.get('wall_clock_h')
        report(isinstance(wch, (int, float)) and wch < 0.1,
               'wall_clock_h reflects the 45-minute gap excluded (< 0.1h)', repr(wch))
        report(entry.get('lens_h') == {'challenger': 1},
               "lens_h == {'challenger': 1} (phase-1 review's 'quality' H excluded by target-spec phase join)",
               repr(entry.get('lens_h')))
        ma = str(entry.get('measured_at') or '')
        report(re.fullmatch(r'[0-9a-f]{40}', ma) is not None, 'measured_at is 40-hex', repr(ma))
        st = entry.get('stage_tokens') or []
        report(sorted(x.get('stage') for x in st) == [0, 1, 2, 3, 4, 5] and all(x.get('tokens', 0) > 0 for x in st),
               'stage_tokens has stages 0-5 from the plugin root, each > 0', repr(st))
        report(isinstance(entry.get('false_edges'), int), 'false_edges is an integer', repr(entry.get('false_edges')))
        report(entry.get('phase') == 0, 'phase == 0', repr(entry.get('phase')))
finally:
    shutil.rmtree(tmp, ignore_errors=True)

sys.exit(1 if fails else 0)
SELFTEST_EOF
  exit $?
fi

# --------------------------------------------------------------- arg parsing
epic_dir=""
transcripts=()
phase=""
range=""
churn="0,0"
while [ $# -gt 0 ]; do
  case "$1" in
    --phase)  [ $# -ge 2 ] || { printf 'phase-metrics.sh: --phase needs a value\n' >&2; exit 2; }
              phase="$2"; shift 2 ;;
    --range)  [ $# -ge 2 ] || { printf 'phase-metrics.sh: --range needs a value\n' >&2; exit 2; }
              range="$2"; shift 2 ;;
    --churn)  [ $# -ge 2 ] || { printf 'phase-metrics.sh: --churn needs a value\n' >&2; exit 2; }
              churn="$2"; shift 2 ;;
    -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
    --*)      printf 'phase-metrics.sh: unknown flag %s\n' "$1" >&2; exit 2 ;;
    *)        if [ -z "$epic_dir" ]; then epic_dir="$1"; else transcripts+=("$1"); fi; shift ;;
  esac
done

case "$phase" in ''|*[!0-9]*) printf 'phase-metrics.sh: --phase must be a non-negative integer\n' >&2; exit 2 ;; esac
[ -n "$epic_dir" ] || { printf 'phase-metrics.sh: missing <epic-dir>\n' >&2; exit 2; }
[ -d "$epic_dir" ] || { printf 'phase-metrics.sh: no such directory: %s\n' "$epic_dir" >&2; exit 2; }
[ "${#transcripts[@]}" -ge 1 ] || { printf 'phase-metrics.sh: at least one transcript.jsonl is required\n' >&2; exit 2; }
for t in "${transcripts[@]}"; do
  [ -f "$t" ] || { printf 'phase-metrics.sh: no such transcript file: %s\n' "$t" >&2; exit 2; }
done
case "$churn" in
  *,*) shape_driven_lines="${churn%%,*}"; other_lines="${churn##*,}" ;;
  *)   printf 'phase-metrics.sh: --churn needs <shape_driven_lines>,<other_lines>\n' >&2; exit 2 ;;
esac
case "$shape_driven_lines" in ''|*[!0-9]*) printf 'phase-metrics.sh: --churn shape_driven_lines must be an integer\n' >&2; exit 2 ;; esac
case "$other_lines" in ''|*[!0-9]*) printf 'phase-metrics.sh: --churn other_lines must be an integer\n' >&2; exit 2 ;; esac

command -v python3 >/dev/null 2>&1 || { printf 'phase-metrics.sh: python3 not found\n' >&2; exit 1; }
python3 -c 'import yaml' 2>/dev/null || { printf 'phase-metrics.sh: PyYAML not installed — run: python3 -m pip install pyyaml\n' >&2; exit 1; }

if [ -z "$range" ]; then
  base_ref="$(git merge-base HEAD main 2>/dev/null)"
  [ -n "$base_ref" ] || { printf 'phase-metrics.sh: cannot compute default range (git merge-base HEAD main failed) — pass --range\n' >&2; exit 1; }
  head_ref="HEAD"
else
  base_ref="${range%%..*}"
  head_ref="${range##*..}"
fi
base_full="$(git rev-parse --verify -q "${base_ref}^{commit}" 2>/dev/null)"
[ -n "$base_full" ] || { printf 'phase-metrics.sh: cannot resolve range base: %s\n' "$base_ref" >&2; exit 1; }
head_full="$(git rev-parse --verify -q "${head_ref}^{commit}" 2>/dev/null)"
[ -n "$head_full" ] || { printf 'phase-metrics.sh: cannot resolve range head: %s\n' "$head_ref" >&2; exit 1; }
base_ts="$(git log -1 --format=%cI "$base_full")"
head_ts="$(git log -1 --format=%cI "$head_full")"

here="$(cd "$(dirname "$0")" && pwd)"
pm="$here/plugin-map.sh"
[ -f "$pm" ] || { printf 'phase-metrics.sh: sibling tool missing: %s\n' "$pm" >&2; exit 1; }

python3 - "$epic_dir" "$phase" "$base_full" "$head_full" "$base_ts" "$head_ts" \
         "$shape_driven_lines" "$other_lines" "$pm" -- "${transcripts[@]}" <<'PYTHON_EOF'
import sys, os, json, glob, subprocess
from datetime import datetime

args = sys.argv[1:]
sep = args.index('--')
(epic_dir, phase_s, base_full, head_full, base_ts_s, head_ts_s,
 shape_driven_s, other_s, pm) = args[:sep]
transcripts = args[sep + 1:]
phase = int(phase_s)

def parse_ts(s):
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00'))
    except ValueError:
        return None

base_ts = parse_ts(base_ts_s)
head_ts = parse_ts(head_ts_s)

def in_bound(ts):
    if ts is None:
        return False
    if base_ts is not None and ts <= base_ts:
        return False
    if head_ts is not None and ts > head_ts:
        return False
    return True

# ------------------------------------------------------------- turn classify
ECHO_PREFIXES = (
    '<local-command-caveat>', '<command-name>', '<command-message>',
    '<local-command-stdout>', '<local-command-stderr>',
    'Base directory for this skill:', '<system-reminder>',
)
ECHO_EXACT = ('[Request interrupted by user for tool use]', '[Request interrupted by user]')

def is_echo(txt):
    t = txt.strip()
    if t in ECHO_EXACT:
        return True
    return any(txt.startswith(p) for p in ECHO_PREFIXES)

def load_lines(path):
    out = []
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except ValueError:
                continue
    return out

human_turns = 0
dispatches = 0
main_events = []   # (ts,) for wall-clock, across all given transcripts, bounded

for path in transcripts:
    for d in load_lines(path):
        if d.get('isSidechain'):
            continue
        typ = d.get('type')
        ts = parse_ts(d.get('timestamp'))
        if typ == 'user':
            if not in_bound(ts):
                continue
            main_events.append(ts)
            msg = d.get('message') or {}
            content = msg.get('content')
            if isinstance(content, str):
                if not is_echo(content):
                    human_turns += 1
            elif isinstance(content, list):
                if any(isinstance(b, dict) and b.get('type') == 'tool_result' for b in content):
                    continue
                txt = ''
                for b in content:
                    if isinstance(b, dict) and b.get('type') == 'text':
                        txt = b.get('text', '')
                        break
                if not is_echo(txt):
                    human_turns += 1
        elif typ == 'assistant':
            if not in_bound(ts):
                continue
            main_events.append(ts)
            msg = d.get('message') or {}
            content = msg.get('content')
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get('type') == 'tool_use' and b.get('name') in ('Agent', 'Task'):
                        dispatches += 1

# ------------------------------------------------------------- wall_clock_h
main_events.sort()
GAP = 30 * 60
active_seconds = 0.0
if main_events:
    cur_start = main_events[0]
    prev = main_events[0]
    for t in main_events[1:]:
        gap = (t - prev).total_seconds()
        if gap > GAP:
            active_seconds += (prev - cur_start).total_seconds()
            cur_start = t
        prev = t
    active_seconds += (prev - cur_start).total_seconds()
wall_clock_h = round(active_seconds / 3600.0, 1)

# ------------------------------------------------------------- lens_h
# A review.yaml counts for --phase N iff its `target` resolves (first relative to the review
# file's own directory, then to <epic-dir>) to a *.spec.yaml whose top-level `phase` == N. Not
# sha-in-range: two different phases' reviews can share a sha under a squash-merge workflow
# (a phase-N review commonly runs at the same tip phase N-1's squash-merge produced), so history
# shape can't disambiguate phases but the reviewed spec's own declared phase always can.
import yaml

def resolve_target(rv, target):
    if not isinstance(target, str) or not target:
        return None
    for base in (os.path.dirname(rv), epic_dir):
        cand = os.path.normpath(os.path.join(base, target))
        if os.path.isfile(cand):
            return cand
    return None

spec_phase_cache = {}

def spec_phase(spec_path):
    if spec_path not in spec_phase_cache:
        try:
            sdoc = yaml.safe_load(open(spec_path, encoding='utf-8'))
        except (OSError, yaml.YAMLError):
            sdoc = None
        spec_phase_cache[spec_path] = sdoc.get('phase') if isinstance(sdoc, dict) else None
    return spec_phase_cache[spec_path]

lens_h = {}
matched, excluded = [], []
for rv in sorted(glob.glob(os.path.join(epic_dir, '**', 'review.yaml'), recursive=True)):
    try:
        doc = yaml.safe_load(open(rv, encoding='utf-8'))
    except (OSError, yaml.YAMLError):
        excluded.append((rv, None, 'unparsable'))
        continue
    if not isinstance(doc, dict):
        excluded.append((rv, None, 'not a mapping'))
        continue
    target_raw = doc.get('target')
    spec_path = resolve_target(rv, target_raw)
    ph = spec_phase(spec_path) if spec_path else None
    if spec_path and ph == phase:
        matched.append(rv)
        for f in doc.get('findings') or []:
            if isinstance(f, dict) and f.get('severity') == 'H' and isinstance(f.get('lens'), str):
                lens_h[f['lens']] = lens_h.get(f['lens'], 0) + 1
    else:
        reason = ('target does not resolve under this review\'s directory or <epic-dir>: %r' % target_raw
                  if not spec_path else 'target spec phase %r != --phase %d' % (ph, phase))
        excluded.append((rv, target_raw, reason))

sys.stderr.write('phase-metrics.sh: review.yaml matched=%d excluded=%d\n' % (len(matched), len(excluded)))
for rv in matched:
    sys.stderr.write('  matched: %s\n' % rv)
for rv, raw, reason in excluded:
    sys.stderr.write('  excluded: %s (target=%r reason=%s)\n' % (rv, raw, reason))

# ------------------------------------------------------------- stage_tokens / false_edges
# the plugin root is this script's own tree (scripts/..), never the caller's cwd
map_root = os.path.dirname(os.path.dirname(os.path.abspath(pm)))
map_out = subprocess.run(['bash', pm, '--root', map_root], capture_output=True, text=True)
if map_out.returncode != 0:
    sys.stderr.write('phase-metrics.sh: plugin-map.sh failed (rc=%d): %s\n' % (map_out.returncode, map_out.stderr[:2000]))
    sys.exit(1)
map_doc = json.loads(map_out.stdout)
if sorted(st.get('stage') for st in map_doc.get('stages', [])) != [0, 1, 2, 3, 4, 5]:
    sys.stderr.write('phase-metrics.sh: plugin-map.sh returned no stages 0-5 for root %s\n' % map_root)
    sys.exit(1)

stage_tokens = []
for st in map_doc.get('stages', []):
    files = set()
    for ctx in st.get('contexts', []):
        files.update(ctx.get('files', []))
    total_bytes = 0
    for f in files:
        try:
            total_bytes += os.path.getsize(os.path.join(map_root, f))
        except OSError:
            pass
    stage_tokens.append({'stage': st['stage'], 'tokens': total_bytes // 4})

false_edges = len(map_doc.get('false_edges') or [])

# ------------------------------------------------------------- output
lines = []
lines.append('  - phase: %d' % phase)
lines.append('    wall_clock_h: %s' % wall_clock_h)
lines.append('    human_turns: %d' % human_turns)
lines.append('    dispatches: %d' % dispatches)
if lens_h:
    lines.append('    lens_h:')
    for k in sorted(lens_h):
        lines.append('      %s: %d' % (k, lens_h[k]))
else:
    lines.append('    lens_h: {}')
lines.append('    stage_tokens:')
for st in stage_tokens:
    lines.append('      - {stage: %d, tokens: %d}' % (st['stage'], st['tokens']))
lines.append('    false_edges: %d' % false_edges)
lines.append('    instrument_churn: {shape_driven_lines: %d, other_lines: %d}' % (int(shape_driven_s), int(other_s)))
lines.append('    measured_at: %s' % head_full)

sys.stdout.write('\n'.join(lines) + '\n')
PYTHON_EOF
