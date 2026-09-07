#!/usr/bin/env python3
"""scripts/ruler.py — the ruler tool: one script, five subcommands. The mechanical home of
ruler-before-code (red-first), the frozen ruler (freeze), the two-way AC ↔ node trace
(check), the one executor every node goes through (run) and the independent verdict
(held-out). Field sets: the ruler / verdict schemas under skills/_shared/schemas/ (node
forms, aggregation, the disputes file and the files_sha recipe are documented there, once).

  ruler.py check     --ruler <ruler.yaml> --spec <spec.yaml> [--root <repo>]
      every spec AC has ≥1 existing node (or status unverified with a reason); every ruler
      row names a spec AC; every node exists (a smoke label against
      scripts/tests-smoke/run-smoke.sh under --root, never a cached list) and its
      check_command is the runner form verbatim. Last stdout line on success:
      `files_sha: <sha>` — the ruler revision.
  ruler.py run       --ruler <ruler.yaml> <node> [--root <tree>]
      the executor: imports a .py file and calls the named function, sources a .sh file and
      calls the named function, or runs the smoke harness and reads the label's line. Needs
      only the standard library. Exit 0 = pass; else 1, last line `ruler.py run: fail —
      <reason>` (reason `not-run` when the function / label / file does not exist).
  ruler.py red-first --ruler <ruler.yaml> --tree <pre-build worktree> [--root <repo>]
                     [--log <json>] [--timeout <s>]
      runs every ruled / regression node in <tree> through `run`, writes the log (default
      <build>/red-first.json, bound to the ruler files_sha); exit 1 when a ruled node passes.
  ruler.py freeze    --ruler <ruler.yaml> [--root <repo>] [--red-first <json>] [--out <freeze.json>]
      refuses unless the red-first log binds to the current files_sha (naming any file that
      changed since), every ruled node failed there, no freeze.json exists and the log records
      no earlier freeze of this build; else writes freeze.json {files, files_sha, commit,
      red_first, frozen_at} once and stamps frozen_at into the red-first log.
  ruler.py held-out  --ruler <ruler.yaml> [--freeze <freeze.json>] [--out <verdict.yaml>]
                     [--root <repo>] [--scratch <dir>] [--disputes <yaml>] [--timeout <s>]
                     [--plugin-revision <sha>] [--clean]
      sha-checks every frozen file (a difference → verdict with sha_check: violated, exit 1),
      validates build/disputes.yaml, then a fresh detached worktree at HEAD under --scratch,
      the frozen ruler files copied in read-only, a venv when a python node exists
      (populated only by deps.install_cmd), every node re-run through `run` with a sha and
      porcelain re-check before each, and verdict.yaml written. Exit 0 once written.

Exit codes: 0 ok · 1 a named refusal / violation / failing node · 2 usage or a missing
dependency. Every node runs with the tree root as cwd, a per-node timeout of 300 s by
default (--timeout), and TOUCHSTONE_BUILD_DIR set to the directory above the ruler
directory (the epic's build/). --root defaults to the tree the ruler's own `spec:` path
resolves under (its build/ parent, the git toplevel, or the cwd).
"""
import argparse
import datetime as _dt
import hashlib
import json
import os
import re
import shlex
import signal
import shutil
import subprocess
import sys
import tempfile

NODE_RE = re.compile(r'^(?:smoke::(?P<label>.+)|(?P<path>[^:\s]+\.(?P<ext>py|sh))::(?P<name>[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*))$')
SMOKE_HARNESS = 'scripts/tests-smoke/run-smoke.sh'
STATUSES = ('ruled', 'regression', 'unverified')
DISPUTE_FIELDS = ('ac', 'test', 'asserts', 'spec_says', 'conflict')
RUN_LINE = re.compile(r'^ruler\.py run: (pass|fail)(?: — (.*))?$', re.M)


# ----------------------------------------------------------------- helpers
def die(msg, code=2):
    print(f"ruler.py: {msg}", file=sys.stderr)
    sys.exit(code)


def need_yaml():
    try:
        import yaml  # noqa: F401
        return yaml
    except ImportError:
        die("PyYAML not installed — run: python3 -m pip install pyyaml")


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()


def load_yaml(p):
    yaml = need_yaml()
    try:
        with open(p, encoding='utf-8') as f:
            return yaml.safe_load(f)
    except (OSError, yaml.YAMLError) as e:
        die(f"cannot read {p}: {e}")


def rel_to(root, p):
    """repo-relative path when p lies under root, else the absolute path."""
    ap = os.path.realpath(p)
    rr = os.path.realpath(root)
    try:
        if os.path.commonpath([ap, rr]) == rr:
            return os.path.relpath(ap, rr).replace(os.sep, '/')
    except ValueError:
        pass
    return ap


def now():
    return _dt.datetime.now(_dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def git(root, *args):
    p = subprocess.run(['git', '-C', root, *args], capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def build_dir_of(ruler_path):
    parent = os.path.dirname(os.path.realpath(ruler_path))
    return os.path.dirname(parent) if os.path.basename(parent) == 'ruler' else parent


def spec_line(ruler_path):
    """The ruler's `spec:` value read as text (no YAML dependency)."""
    try:
        for line in open(ruler_path, encoding='utf-8', errors='replace'):
            m = re.match(r'^spec:\s*(.+?)\s*$', line)
            if m:
                return m.group(1).strip('\'"')
    except OSError:
        pass
    return ''


def infer_root(ruler_path, given=None):
    """The tree root a ruler belongs to: --root when given; else the first of the ruler's
    build/ parent, its build/ dir, the git toplevel above it and the cwd under which the
    ruler's own `spec:` path resolves; else the cwd."""
    if given:
        return os.path.abspath(given)
    rp = os.path.realpath(ruler_path)
    if os.path.isdir(rp):
        rp = os.path.join(rp, 'ruler.yaml')
    bd = build_dir_of(rp)
    cands = [os.path.dirname(bd), bd]
    rc, top, _ = git(os.path.dirname(rp), 'rev-parse', '--show-toplevel')
    if rc == 0 and top:
        cands.append(top)
    cands.append(os.getcwd())
    sp = spec_line(rp)
    for c in cands:
        if sp and (os.path.isabs(sp) or os.path.isfile(os.path.join(c, sp))):
            return os.path.realpath(c)
    return os.getcwd()


class Ruler:
    """The ruler = ruler.yaml + every file under its test directory. Two layouts resolve:
    `<build>/ruler.yaml` beside `<build>/ruler/` (the epic layout) and
    `<build>/ruler/ruler.yaml` inside the test directory (a fixture layout). `--ruler` may
    name the yaml or the directory."""

    def __init__(self, path, root):
        p = os.path.realpath(path)
        if os.path.isdir(p):
            cand = os.path.join(p, 'ruler.yaml')
            if not os.path.isfile(cand):
                cand = os.path.join(os.path.dirname(p), 'ruler.yaml')
            p = cand
        if not os.path.isfile(p):
            die(f"ruler not found: {path}", 1)
        self.path = p
        self.root = os.path.realpath(root)
        self.build_dir = build_dir_of(p)
        self.dir = os.path.join(self.build_dir, 'ruler')
        self.doc = load_yaml(self.path)
        if not isinstance(self.doc, dict) or self.doc.get('kind') != 'ruler':
            die(f"{path}: not a ruler (kind: ruler)", 1)
        self.acs = [a for a in (self.doc.get('acs') or []) if isinstance(a, dict)]

    def files(self):
        """[(key relative to <build>, absolute path)] — ruler.yaml + every file under the
        test directory."""
        out = [(os.path.relpath(self.path, self.build_dir).replace(os.sep, '/'), self.path)]
        for dp, dns, fns in os.walk(self.dir):
            dns[:] = sorted(d for d in dns if d != '__pycache__')
            for fn in sorted(fns):
                ap = os.path.join(dp, fn)
                if fn.endswith('.pyc') or ap == self.path:
                    continue
                out.append((os.path.relpath(ap, self.build_dir).replace(os.sep, '/'), ap))
        return sorted(out)

    def files_sha(self):
        lines = [f"{rel}:{sha256_file(ap)}" for rel, ap in self.files()]
        return hashlib.sha256(('\n'.join(lines) + '\n').encode()).hexdigest()

    def file_shas(self):
        return {rel_to(self.root, ap): sha256_file(ap) for rel, ap in self.files()}

    def nodes(self, statuses=('ruled', 'regression')):
        for a in self.acs:
            if a.get('status') in statuses:
                for n in a.get('nodes') or []:
                    if isinstance(n, dict):
                        yield a, n

    def deps(self):
        d = self.doc.get('deps') if isinstance(self.doc.get('deps'), dict) else {}
        return str(d.get('manifest') or 'none'), str(d.get('install_cmd') or 'none')

    def spec_path(self):
        sp = str(self.doc.get('spec') or '')
        return sp if os.path.isabs(sp) else os.path.join(self.root, sp)

    def rel_path(self):
        return rel_to(self.root, self.path)


def spec_acs(spec_path):
    d = load_yaml(spec_path)
    out, live = [], {}
    if isinstance(d, dict):
        for r in d.get('requirements') or []:
            if not isinstance(r, dict):
                continue
            for a in r.get('acs') or []:
                if isinstance(a, dict) and isinstance(a.get('id'), str):
                    out.append(a['id'])
                    live[a['id']] = bool(a.get('live_bearing'))
    return out, live


def ac_num(ac):
    m = re.search(r'(\d+)$', str(ac))
    return int(m.group(1)) if m else 0


# ----------------------------------------------------------------- node existence
def py_defines(src, dotted):
    for part in dotted.split('::'):
        if not re.search(r'^\s*(?:async\s+def|def|class)\s+' + re.escape(part) + r'\b', src, re.M):
            return False
    return True


def sh_defines(src, name):
    return re.search(r'^\s*(?:function\s+)?' + re.escape(name) + r'\s*\(\)\s*\{', src, re.M) is not None


def smoke_labels(root):
    p = os.path.join(root, SMOKE_HARNESS)
    if not os.path.isfile(p):
        return None
    src = open(p, encoding='utf-8', errors='replace').read()
    return set(re.findall(r'expect_(?:exit|out)\s+"([^"]+)"', src))


def node_exists(root, test):
    """None when the node resolves, else the reason it does not."""
    m = NODE_RE.match(test)
    if not m:
        return 'not one of the three node forms'
    if m.group('label'):
        labels = smoke_labels(root)
        if labels is None:
            return f'{SMOKE_HARNESS} not found under the root'
        return None if m.group('label') in labels else f'label not in {SMOKE_HARNESS}'
    fp = os.path.join(root, m.group('path'))
    if not os.path.isfile(fp):
        return f'{m.group("path")} not found'
    src = open(fp, encoding='utf-8', errors='replace').read()
    if m.group('ext') == 'py':
        return None if py_defines(src, m.group('name')) else f'{m.group("name")} not defined in {m.group("path")}'
    return None if sh_defines(src, m.group('name')) else f'{m.group("name")}() not defined in {m.group("path")}'


def command_form_error(r, test, cmd):
    """None when cmd is `python3 <…/ruler.py> run --ruler <this ruler> <node>`, else why not."""
    required = f"python3 scripts/ruler.py run --ruler {r.rel_path()} {test}"
    try:
        toks = shlex.split(cmd)
    except ValueError:
        return f"unparsable check_command; required: {required}"
    if len(toks) < 6 or toks[0] != 'python3' or os.path.basename(toks[1]) != 'ruler.py' or toks[2] != 'run' or toks[3] != '--ruler':
        return f"check_command {cmd!r} is not the runner form; required: {required}"
    rarg = toks[4] if os.path.isabs(toks[4]) else os.path.join(r.root, toks[4])
    if os.path.realpath(rarg) != r.path:
        return f"check_command names ruler {toks[4]!r}, not this ruler; required: {required}"
    named = ' '.join(toks[5:])   # a smoke label with spaces may be quoted or bare
    if named != test:
        return f"check_command names node {named!r}, not {test!r}; required: {required}"
    return None


# ----------------------------------------------------------------- check
def cmd_check(a):
    r = Ruler(a.ruler, a.root)
    spec = a.spec or r.spec_path()
    if not os.path.isfile(spec):
        die(f"spec not found: {spec}", 1)
    ids, _ = spec_acs(spec)
    fails = []
    if not isinstance(r.doc.get('deps'), dict) or not all(k in r.doc['deps'] for k in ('manifest', 'install_cmd')):
        fails.append("deps: missing (manifest + install_cmd, or none / none)")
    rows = {}
    for row in r.acs:
        ac = str(row.get('ac'))
        rows[ac] = row
        if ac not in ids:
            fails.append(f"{ac}: names no AC of the governing spec (dangling)")
    for ac in ids:
        row = rows.get(ac)
        if row is None:
            fails.append(f"{ac}: no ruler row — no node and no unverified status")
            continue
        st = row.get('status')
        if st not in STATUSES:
            fails.append(f"{ac}: status {st!r} not in {list(STATUSES)}")
            continue
        if st == 'unverified':
            if not str(row.get('unverified_reason') or '').strip():
                fails.append(f"{ac}: unverified without unverified_reason")
            continue
        nodes = [n for n in (row.get('nodes') or []) if isinstance(n, dict)]
        if not nodes:
            fails.append(f"{ac}: status {st} with no node")
        for n in nodes:
            test = str(n.get('test') or '')
            why = node_exists(r.root, test)
            if why:
                fails.append(f"{ac}: node {test!r} — {why}")
            why = command_form_error(r, test, str(n.get('check_command') or ''))
            if why:
                fails.append(f"{ac}: node {test!r} — {why}")
        if st == 'ruled' and not [s for s in (row.get('interface') or []) if str(s).strip()]:
            fails.append(f"{ac}: ruled with no interface signature")
    for f in fails:
        print(f"FAIL {f}")
    if fails:
        return 1
    n = {s: sum(1 for x in r.acs if x.get('status') == s) for s in STATUSES}
    print(f"OK trace: {len(ids)} spec ACs ↔ {len(r.acs)} ruler rows (ruled {n['ruled']}, regression {n['regression']}, unverified {n['unverified']})")
    print(f"files_sha: {r.files_sha()}")
    return 0


# ----------------------------------------------------------------- run (the executor)
def marker_line(out, label):
    """'PASS' | 'FAIL' | None — the harness marker line for this label."""
    for line in out.splitlines():
        s = line.strip()
        for mk in ('FAIL', 'PASS'):
            pre = f"{mk}: {label}"
            if s.startswith(pre) and (len(s) == len(pre) or not s[len(pre)].isalnum()):
                return mk
    return None


def run_python(path, dotted):
    """(passed, reason) — import the file, call the named function / TestCase."""
    import importlib.util
    import traceback
    import unittest
    fp = os.path.abspath(path)
    if not os.path.isfile(fp):
        return False, f"not-run — {path} not found"
    for d in (os.path.dirname(fp), os.getcwd()):
        if d not in sys.path:
            sys.path.insert(0, d)
    try:
        spec = importlib.util.spec_from_file_location('_ruler_node_' + re.sub(r'\W', '_', path), fp)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    except BaseException as e:  # an import error is a failing node, never a crash of the tool
        traceback.print_exc()
        return False, f"{type(e).__name__}: {e}"
    obj = mod
    for part in dotted.split('::'):
        if not hasattr(obj, part):
            return False, f"not-run — {dotted} not defined in {path}"
        obj = getattr(obj, part)
    try:
        if isinstance(obj, type) and issubclass(obj, unittest.TestCase):
            res = unittest.TextTestRunner(stream=sys.stdout, verbosity=1).run(unittest.defaultTestLoader.loadTestsFromTestCase(obj))
            if res.testsRun == 0:
                return False, f"not-run — {dotted} has no test method"
            return res.wasSuccessful(), None if res.wasSuccessful() else f"{len(res.failures)} failure(s), {len(res.errors)} error(s)"
        parts = dotted.split('::')
        if len(parts) == 2 and isinstance(getattr(mod, parts[0]), type) and issubclass(getattr(mod, parts[0]), unittest.TestCase):
            res = unittest.TextTestRunner(stream=sys.stdout, verbosity=1).run(getattr(mod, parts[0])(parts[1]))
            return res.wasSuccessful(), None if res.wasSuccessful() else f"{len(res.failures)} failure(s), {len(res.errors)} error(s)"
        if not callable(obj):
            return False, f"not-run — {dotted} is not callable"
        obj()
        return True, None
    except BaseException as e:
        traceback.print_exc()
        return False, f"{type(e).__name__}: {e}"


def run_shell(path, name):
    if not os.path.isfile(path):
        return False, f"not-run — {path} not found"
    script = ('n="$1"; set --; source "$0" || exit 97; '
              'declare -F "$n" >/dev/null 2>&1 || { echo "not-run: $n not defined"; exit 98; }; "$n"')
    p = subprocess.run(['bash', '-c', script, path, name], capture_output=True, text=True)
    out = (p.stdout or '') + (p.stderr or '')
    sys.stdout.write(out)
    if p.returncode == 98:
        return False, f"not-run — {name}() not defined in {path}"
    if p.returncode == 97:
        return False, f"not-run — {path} could not be sourced"
    mk = marker_line(out, name)
    if p.returncode == 0 and mk == 'PASS':
        return True, None
    if mk is None:
        return False, f"not-run — no PASS/FAIL line for {name} (exit {p.returncode})"
    return False, f"{mk}: {name} (exit {p.returncode})"


def harness_output(cwd, timeout=None):
    cached = os.environ.get('RULER_HARNESS_OUT')
    if cached and os.path.isfile(cached):
        return open(cached, encoding='utf-8', errors='replace').read()
    if not os.path.isfile(os.path.join(cwd, SMOKE_HARNESS)):
        return None
    try:
        p = subprocess.run(['bash', SMOKE_HARNESS], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return ''
    return (p.stdout or '') + (p.stderr or '')


def run_smoke(label):
    out = harness_output(os.getcwd())
    if out is None:
        return False, f"not-run — {SMOKE_HARNESS} absent"
    mk = marker_line(out, label)
    for line in out.splitlines():
        if label in line:
            print(line)
    if mk == 'PASS':
        return True, None
    if mk is None:
        return False, f"not-run — the harness printed no line for label {label!r}"
    return False, f"FAIL: {label}"


def cmd_run(a):
    ruler = os.path.abspath(a.ruler)
    if not os.path.isfile(ruler):
        print(f"ruler.py run: fail — not-run — ruler not found: {a.ruler}")
        return 1
    node = a.node
    txt = open(ruler, encoding='utf-8', errors='replace').read()
    if node not in txt:
        print(f"ruler.py run: fail — not-run — node {node!r} is not in {a.ruler}")
        return 1
    os.environ.setdefault('TOUCHSTONE_BUILD_DIR', build_dir_of(ruler))
    os.environ.setdefault('PYTHONDONTWRITEBYTECODE', '1')
    sys.dont_write_bytecode = True   # a frozen ruler dir never gains a __pycache__
    os.chdir(infer_root(ruler, a.root))
    m = NODE_RE.match(node)
    if not m:
        print(f"ruler.py run: fail — not-run — {node!r} is none of the three node forms")
        return 1
    if m.group('label'):
        ok, why = run_smoke(m.group('label'))
    elif m.group('ext') == 'py':
        ok, why = run_python(m.group('path'), m.group('name'))
    else:
        ok, why = run_shell(m.group('path'), m.group('name'))
    sys.stdout.flush()
    print(f"ruler.py run: pass" if ok else f"ruler.py run: fail — {why}")
    return 0 if ok else 1


# ----------------------------------------------------------------- running nodes through `run`
def node_env(r, extra_path=None, harness_out=None):
    env = dict(os.environ)
    env['TOUCHSTONE_BUILD_DIR'] = r.build_dir
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    env.pop('RULER_HARNESS_OUT', None)
    if harness_out:
        env['RULER_HARNESS_OUT'] = harness_out
    if extra_path:
        env['PATH'] = extra_path + os.pathsep + env.get('PATH', '')
        env['PYTHONNOUSERSITE'] = '1'
        env['VIRTUAL_ENV'] = os.path.dirname(extra_path)
    return env


def exec_node(python, ruler_in_tree, test, tree, env, timeout):
    """(outcome, output) — outcome pass | fail | not-run | timeout, via a `run` subprocess."""
    cmd = [python, os.path.abspath(__file__), 'run', '--ruler', ruler_in_tree, test]
    try:
        p = subprocess.Popen(cmd, cwd=tree, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
    except OSError as e:
        return 'fail', f"ruler.py: cannot start the runner: {e}\n"
    try:
        out, _ = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        out, _ = p.communicate()
        return 'timeout', out.decode('utf-8', 'replace') + f"\nruler.py: timeout after {timeout}s\n"
    text = out.decode('utf-8', 'replace')
    m = None
    for m in RUN_LINE.finditer(text):
        pass
    if m is None:
        return 'fail', text + f"\nruler.py: the runner printed no outcome line (exit {p.returncode})\n"
    if m.group(1) == 'pass' and p.returncode == 0:
        return 'pass', text
    if (m.group(2) or '').startswith('not-run'):
        return 'not-run', text
    return 'fail', text


def materialize(r, tree, read_only=False):
    """Copy the ruler files into <tree> at their repo-relative paths (a ruler outside the
    root keeps its absolute path and needs no copy). Returns the ruler path to hand `run`."""
    for rel, ap in r.files():
        rr = rel_to(r.root, ap)
        if os.path.isabs(rr):
            continue
        dst = os.path.join(tree, rr)
        if os.path.realpath(dst) == os.path.realpath(ap):   # the tree IS the root (red-first in place)
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.isfile(dst) and not os.access(dst, os.W_OK):
            os.chmod(dst, 0o644)
        shutil.copy2(ap, dst)
        if read_only:
            os.chmod(dst, 0o444)
    return r.rel_path()


def prerun_harness(r, tree, env, timeout, scratch):
    """Run the smoke harness once per tree when any node is a smoke label; returns the
    output file for RULER_HARNESS_OUT, or None."""
    if not any(str(n.get('test', '')).startswith('smoke::') for _, n in r.nodes()):
        return None
    out_file = os.path.join(scratch, f'harness-{os.path.basename(tree)}.log')
    if os.path.isfile(os.path.join(tree, SMOKE_HARNESS)):
        try:
            p = subprocess.run(['bash', SMOKE_HARNESS], cwd=tree, env=env, capture_output=True, text=True, timeout=timeout)
            text = (p.stdout or '') + (p.stderr or '')
        except subprocess.TimeoutExpired:
            text = f"ruler.py: harness timeout after {timeout}s\n"
    else:
        text = ''
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(text)
    return out_file


def tail_of(out):
    """The node's last output line (the assertion / exception), plus the first import error the
    run printed when that line does not already carry it — the reason a verdict row shows."""
    lines = [l for l in out.strip().splitlines() if l.strip() and not l.startswith('ruler.py run:')]
    tail = lines[-1][:600] if lines else ''
    m = re.search(r"(?:ModuleNotFoundError|ImportError): [^\n]*", out)
    if m and m.group(0) not in tail:
        tail = (tail + ' [' + m.group(0)[:200] + ']') if tail else m.group(0)[:200]
    return tail


# ----------------------------------------------------------------- red-first
def cmd_red_first(a):
    r = Ruler(a.ruler, a.root)
    tree = os.path.abspath(a.tree)
    if not os.path.isdir(tree):
        die(f"pre-build tree not found: {tree}", 1)
    ruler_in_tree = materialize(r, tree)
    scratch = tempfile.mkdtemp(prefix='ruler-redfirst-')
    env = node_env(r)
    harness_out = prerun_harness(r, tree, env, a.timeout, scratch)
    env = node_env(r, harness_out=harness_out)
    results, bad = [], []
    for row, n in r.nodes():
        test = str(n.get('test') or '')
        outcome, out = exec_node(sys.executable, ruler_in_tree, test, tree, env, a.timeout)
        st = row.get('status')
        admissible = outcome != 'pass' or st == 'regression'
        results.append({'ac': row.get('ac'), 'test': test, 'outcome': outcome, 'admissible': admissible,
                        'detail': tail_of(out)})
        print(f"{'ok ' if admissible else 'NO '} {row.get('ac')} {test} → {outcome}" + ('' if admissible else ' — passes on the pre-build tree'))
        if not admissible:
            bad.append((row.get('ac'), test))
    log = {'kind': 'red-first', 'ruler': r.rel_path(), 'tree': tree, 'files_sha': r.files_sha(),
           'files': r.file_shas(), 'all_red': not bad, 'results': results, 'ran_at': now()}
    log_path = os.path.abspath(a.log) if a.log else os.path.join(r.build_dir, 'red-first.json')
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    with open(log_path, 'w', encoding='utf-8') as f:
        json.dump(log, f, indent=2)
    shutil.rmtree(scratch, ignore_errors=True)
    print(f"red-first log: {log_path} (all_red: {str(not bad).lower()})")
    for ac, test in bad:
        print(f"FAIL {ac} {test}: passes on the pre-build tree — a ruled node must fail before the build")
    return 1 if bad else 0


# ----------------------------------------------------------------- freeze
def changed_files(r, recorded):
    now_ = r.file_shas()
    return [rel for rel in sorted(set(recorded) | set(now_)) if recorded.get(rel) != now_.get(rel)]


def cmd_freeze(a):
    r = Ruler(a.ruler, a.root)
    cur = r.files_sha()
    out = os.path.abspath(a.out) if a.out else os.path.join(r.build_dir, 'freeze.json')
    refusals = []
    if os.path.exists(out):
        refusals.append(f"freeze.json already exists: {out} — written once per build, never rewritten")
    for row in r.acs:
        if row.get('status') == 'unverified' and not str(row.get('unverified_reason') or '').strip():
            refusals.append(f"{row.get('ac')}: unverified without a reason")
    log_path = os.path.abspath(a.red_first) if a.red_first else os.path.join(r.build_dir, 'red-first.json')
    log = None
    if not os.path.isfile(log_path):
        refusals.append(f"red-first log missing: {log_path}")
    else:
        try:
            log = json.load(open(log_path, encoding='utf-8'))
        except ValueError as e:
            refusals.append(f"red-first log unparsable: {e}")
    if log and log.get('frozen_at'):
        refusals.append(f"this build was already frozen at {log['frozen_at']} (recorded in {log_path}) — a missing freeze.json is a halt, never a re-freeze")
    if log:
        if log.get('files_sha') != cur:
            changed = changed_files(r, log.get('files') or {})
            refusals.append(f"stale red-first digest: log {str(log.get('files_sha'))[:12]} ≠ current {cur[:12]}"
                            + (f" — changed since red-first: {', '.join(changed)}" if changed else ''))
        status_of = {str(x.get('ac')): x.get('status') for x in r.acs}
        for res in log.get('results') or []:
            if res.get('outcome') == 'pass' and status_of.get(str(res.get('ac'))) != 'regression':
                refusals.append(f"{res.get('ac')} {res.get('test')}: passes on the pre-build tree")
        logged = {(str(x.get('ac')), str(x.get('test'))) for x in (log.get('results') or [])}
        for row, n in r.nodes():
            if (str(row.get('ac')), str(n.get('test'))) not in logged:
                refusals.append(f"{row.get('ac')} {n.get('test')}: not in the red-first log")
    if refusals:
        for x in refusals:
            print(f"REFUSED {x}")
        return 1
    _, commit, _ = git(r.root, 'rev-parse', 'HEAD')
    freeze = {'files': r.file_shas(), 'files_sha': cur, 'commit': commit or 'none',
              'red_first': {'files_sha': log['files_sha'], 'log': rel_to(r.root, log_path)}, 'frozen_at': now()}
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(freeze, f, indent=2)
    log['frozen_at'] = freeze['frozen_at']   # the red-first log remembers the freeze: a second freeze in this build refuses
    with open(log_path, 'w', encoding='utf-8') as f:
        json.dump(log, f, indent=2)
    print(f"OK frozen: {out} ({len(freeze['files'])} files, files_sha {cur[:12]}, commit {freeze['commit'][:8]})")
    return 0


# ----------------------------------------------------------------- held-out
def stdlib_names():
    return set(getattr(sys, 'stdlib_module_names', ())) | set(sys.builtin_module_names)


def undeclared_module(out):
    """The non-stdlib module a ModuleNotFoundError in the output names, or None."""
    for m in re.finditer(r"No module named '([A-Za-z_][\w.]*)'", out):
        top = m.group(1).split('.')[0]
        if top not in stdlib_names():
            return top
    return None


def load_disputes(path, r):
    """[(entry, index)] validated against the frozen ruler; exits 1 naming a bad entry."""
    if not os.path.isfile(path):
        return []
    doc = load_yaml(path)
    if doc is None:
        return []
    if not isinstance(doc, list):
        die(f"{path}: must be a list of entries", 1)
    nodes_of = {str(row.get('ac')): {str(n.get('test')) for n in (row.get('nodes') or []) if isinstance(n, dict)} for row in r.acs}
    seen = set()
    out = []
    for i, e in enumerate(doc, 1):
        where = f"{path} entry {i}"
        if not isinstance(e, dict):
            die(f"{where}: not a mapping", 1)
        for k in DISPUTE_FIELDS:
            if not str(e.get(k) or '').strip():
                die(f"{where}: missing field {k!r}", 1)
        ac, test = str(e['ac']), str(e['test'])
        if ac not in nodes_of:
            die(f"{where}: {ac} is not an AC of the frozen ruler", 1)
        if test not in nodes_of[ac]:
            die(f"{where}: node {test!r} is not a node of {ac} in the frozen ruler", 1)
        if test in seen:
            die(f"{where}: second entry for node {test!r}", 1)
        seen.add(test)
        out.append(e)
    return out


def dispute_reason(e):
    return f"asserts: {e['asserts']}\nspec_says: {e['spec_says']}\nconflict: {e['conflict']}"


def cmd_held_out(a):
    yaml = need_yaml()
    r = Ruler(a.ruler, a.root)
    freeze = load_yaml(a.freeze or os.path.join(r.build_dir, 'freeze.json'))
    if not isinstance(freeze, dict) or not isinstance(freeze.get('files'), dict):
        die(f"{a.freeze}: not a freeze record", 1)
    spec = r.spec_path()
    _, live = spec_acs(spec) if os.path.isfile(spec) else ([], {})
    manifest, install_cmd = r.deps()
    rc, commit, err = git(r.root, 'rev-parse', 'HEAD')
    if rc != 0:
        die(f"--root is not a git repository ({err})", 1)
    out_path = os.path.abspath(a.out) if a.out else os.path.join(r.build_dir, 'verdict.yaml')
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    disputes_path = os.path.abspath(a.disputes) if a.disputes else os.path.join(r.build_dir, 'disputes.yaml')

    def blank_nodes(row, outcome='not-run'):
        return [{'test': str(n.get('test')), 'outcome': outcome, 'output_ref': 'none'} for n in (row.get('nodes') or []) if isinstance(n, dict)]

    def verdict_doc(env, acs, violated):
        s = {'pass': 0, 'fail': 0, 'disputed': 0, 'unverified': 0}
        for x in acs:
            s[x['verdict'].lower()] += 1
        return {'kind': 'verdict', 'spec': rel_to(r.root, spec), 'freeze_sha': str(freeze.get('files_sha')),
                'sha_check': 'violated' if violated else 'ok', 'violated_files': violated,
                'environment': env, 'acs': sorted(acs, key=lambda x: ac_num(x['ac'])), 'summary': s}

    def write(doc):
        with open(out_path, 'w', encoding='utf-8') as f:
            yaml.safe_dump(doc, f, sort_keys=False, allow_unicode=True, width=200)

    # 1. sha check — before any node runs
    violated = []
    for rel, sha in freeze['files'].items():
        ap = rel if os.path.isabs(rel) else os.path.join(r.root, rel)
        if not os.path.isfile(ap):
            violated.append(f"{rel} (missing)")
        elif sha256_file(ap) != sha:
            violated.append(rel)
    for rel_key, ap in r.files():
        if rel_to(r.root, ap) not in freeze['files']:
            violated.append(f"{rel_to(r.root, ap)} (added after freeze)")
    if violated:
        acs = []
        for row in r.acs:
            if row.get('status') == 'unverified':
                acs.append({'ac': str(row['ac']), 'verdict': 'UNVERIFIED', 'reason': str(row.get('unverified_reason')), 'nodes': []})
            else:
                acs.append({'ac': str(row['ac']), 'verdict': 'FAIL', 'reason': 'sha-violated: ' + ', '.join(violated), 'nodes': blank_nodes(row)})
        env = {'worktree': 'none (refused before any node ran)', 'commit': commit, 'isolation': 'worktree-only', 'install_cmd': install_cmd}
        if a.plugin_revision:
            env['plugin_revision'] = a.plugin_revision
        write(verdict_doc(env, acs, violated))
        for v in violated:
            print(f"FAIL sha_check violated: {v}")
        print(f"verdict: {out_path} (sha_check: violated — no node ran)")
        return 1

    # 2. disputes — validated before any node runs
    disputes = {str(e['test']): e for e in load_disputes(disputes_path, r)}

    # 3. worktree
    scratch = os.path.abspath(a.scratch) if a.scratch else tempfile.mkdtemp(prefix='ruler-heldout-')
    os.makedirs(scratch, exist_ok=True)
    stamp = _dt.datetime.now(_dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    tree = os.path.join(scratch, f'held-out-{commit[:8]}-{stamp}')
    rc, _, err = git(r.root, 'worktree', 'add', '--detach', tree, commit)
    if rc != 0:
        die(f"git worktree add failed: {err}", 1)
    try:
        ruler_in_tree = materialize(r, tree, read_only=True)
        frozen_in_tree = {}
        for rel in freeze['files']:
            if not os.path.isabs(rel):
                frozen_in_tree[os.path.join(tree, rel)] = freeze['files'][rel]

        # 4. environment: a venv whenever a python node exists
        py_nodes = [n for _, n in r.nodes() if NODE_RE.match(str(n.get('test', ''))) and str(n.get('test', '')).split('::')[0].endswith('.py')]
        python, extra_path, isolation, install_fail = sys.executable, None, 'worktree-only', None
        if py_nodes:
            venv = os.path.join(scratch, f'venv-{commit[:8]}-{stamp}')
            p = subprocess.run([sys.executable, '-I', '-m', 'venv', venv], capture_output=True, text=True)
            if p.returncode != 0:
                install_fail = f"venv creation failed: {p.stderr.strip()[:300]}"
            else:
                extra_path = os.path.join(venv, 'bin')
                python = os.path.join(extra_path, 'python3')
                isolation = 'venv'
                if install_cmd != 'none':
                    ip = subprocess.run(install_cmd, shell=True, cwd=tree, env=node_env(r, extra_path), capture_output=True, text=True, timeout=a.timeout)
                    if ip.returncode != 0:
                        install_fail = ("install_cmd failed (%d): %s" % (ip.returncode, ((ip.stdout or '') + (ip.stderr or '')).strip().splitlines()[-1:] or ['']))[:300]
        env = node_env(r, extra_path)
        harness_out = prerun_harness(r, tree, env, a.timeout, scratch)
        env = node_env(r, extra_path, harness_out)
        _, baseline, _ = git(tree, 'status', '--porcelain')

        def contamination():
            """None when the tree and the frozen copies are as they were, else what changed."""
            for ap, sha in frozen_in_tree.items():
                if not os.path.isfile(ap):
                    return f"{rel_to(tree, ap)} missing"
                if sha256_file(ap) != sha:
                    return f"{rel_to(tree, ap)} sha changed"
            _, st, _ = git(tree, 'status', '--porcelain')
            if st != baseline:
                changed = sorted(set(st.splitlines()) - set(baseline.splitlines()))
                return 'worktree dirty: ' + ', '.join(l.strip() for l in changed)[:200]
            return None

        # 5. nodes
        acs, last_node, contaminated_by = [], None, None
        for row in r.acs:
            ac = str(row.get('ac'))
            nodes = [n for n in (row.get('nodes') or []) if isinstance(n, dict)]
            if row.get('status') == 'unverified':
                acs.append({'ac': ac, 'verdict': 'UNVERIFIED', 'reason': str(row.get('unverified_reason')), 'nodes': []})
                continue
            if install_fail:
                acs.append({'ac': ac, 'verdict': 'FAIL', 'reason': install_fail, 'nodes': blank_nodes(row)})
                continue
            node_out, reasons, undeclared = [], [], []
            for i, n in enumerate(nodes):
                test = str(n.get('test') or '')
                if contaminated_by is None:
                    what = contamination()
                    if what:
                        contaminated_by = f"contaminated-by: {last_node} ({what})"
                if contaminated_by:
                    node_out.append({'test': test, 'outcome': 'not-run', 'output_ref': 'none'})
                    reasons.append(contaminated_by)
                    continue
                outcome, out = exec_node(python, ruler_in_tree, test, tree, env, a.timeout)
                last_node = test
                sub = 'probes' if live.get(ac) else 'held-out'
                log_dir = os.path.join(r.build_dir, sub, ac)
                os.makedirs(log_dir, exist_ok=True)
                log_file = os.path.join(log_dir, f'held-out-{i}.log')
                with open(log_file, 'w', encoding='utf-8') as f:
                    f.write(f"$ python3 ruler.py run --ruler {ruler_in_tree} {test}\n# tree: {tree}\n# outcome: {outcome}\n{out}")
                # epic-relative (`build/probes/<AC>/…` or `build/held-out/<AC>/…`): a reader inside the
                # detached worktree resolves it from the build dir's parent, never from the repo root
                node_out.append({'test': test, 'outcome': outcome, 'output_ref': rel_to(os.path.dirname(r.build_dir), log_file)})
                if outcome != 'pass':
                    mod = undeclared_module(out) if outcome == 'fail' else None
                    if mod and manifest == 'none':
                        undeclared.append(mod)
                    reasons.append(f"{outcome}: {test} — {tail_of(out)}" if tail_of(out) else f"{outcome}: {test}")
            disputed = [n['test'] for n in node_out if n['test'] in disputes]
            if disputed:
                e = disputes[disputed[0]]
                acs.append({'ac': ac, 'verdict': 'DISPUTED', 'reason': dispute_reason(e), 'nodes': node_out})
            elif node_out and all(x['outcome'] == 'pass' for x in node_out):
                acs.append({'ac': ac, 'verdict': 'PASS', 'nodes': node_out})
            elif undeclared and len(undeclared) == sum(1 for x in node_out if x['outcome'] != 'pass'):
                acs.append({'ac': ac, 'verdict': 'UNVERIFIED', 'reason': 'no-dependency-declaration: ' + ', '.join(sorted(set(undeclared))), 'nodes': node_out})
            else:
                if not node_out:
                    reasons.append('not-run: no node')
                acs.append({'ac': ac, 'verdict': 'FAIL', 'reason': '; '.join(dict.fromkeys(reasons)), 'nodes': node_out})
        env_doc = {'worktree': tree, 'commit': commit, 'isolation': isolation, 'install_cmd': install_cmd}
        if a.plugin_revision:
            env_doc['plugin_revision'] = a.plugin_revision
        doc = verdict_doc(env_doc, acs, [])
        write(doc)
        s = doc['summary']
        for x in doc['acs']:
            print(f"{x['verdict']:<10} {x['ac']}" + (f" — {x['reason'].splitlines()[0][:160]}" if x.get('reason') else ''))
        print(f"verdict: {out_path} (PASS {s['pass']} / FAIL {s['fail']} / DISPUTED {s['disputed']} / UNVERIFIED {s['unverified']}; isolation {isolation}; commit {commit[:8]})")
        return 0
    finally:
        if a.clean:
            git(r.root, 'worktree', 'remove', '--force', tree)


# ----------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(prog='ruler.py', description=__doc__.split('\n\n')[0] + ' Every node runs with a per-node timeout of 300 s by default (--timeout on red-first and held-out).')
    sub = ap.add_subparsers(dest='cmd', required=True)

    def common(p):
        p.add_argument('--ruler', required=True)
        p.add_argument('--root', default=None)

    p = sub.add_parser('check', help='two-way AC ↔ node trace + runner-form check commands'); common(p); p.add_argument('--spec')
    p = sub.add_parser('run', help='the executor: run one node'); p.add_argument('--ruler', required=True); p.add_argument('node'); p.add_argument('--root')
    p = sub.add_parser('red-first', help='every node must fail on the pre-build tree'); common(p); p.add_argument('--tree', required=True); p.add_argument('--log'); p.add_argument('--timeout', type=int, default=300, help='per-node timeout in seconds (default 300)')
    p = sub.add_parser('freeze', help='write freeze.json once from a bound red-first log'); common(p); p.add_argument('--red-first'); p.add_argument('--out')
    p = sub.add_parser('held-out', help='re-run the frozen ruler in a clean worktree; write verdict.yaml'); common(p)
    p.add_argument('--freeze', help='default <build>/freeze.json'); p.add_argument('--out', help='default <build>/verdict.yaml'); p.add_argument('--scratch'); p.add_argument('--disputes')
    p.add_argument('--timeout', type=int, default=300, help='per-node timeout in seconds (default 300)'); p.add_argument('--plugin-revision'); p.add_argument('--clean', action='store_true', help='remove the held-out worktree afterwards (kept by default)')
    a = ap.parse_args(argv)
    if a.cmd == 'run':
        return cmd_run(a)
    a.root = infer_root(a.ruler, a.root)
    return {'check': cmd_check, 'red-first': cmd_red_first, 'freeze': cmd_freeze, 'held-out': cmd_held_out}[a.cmd](a)


if __name__ == '__main__':
    sys.exit(main())
