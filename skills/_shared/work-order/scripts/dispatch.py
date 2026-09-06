#!/usr/bin/env python3
"""Dispatch engine — contracts from artifacts, one fresh worker session per
unit, budget fuse with automatic escalation up a configured tier list, one
locked ledger append per attempt. The dispatch layer itself makes zero model
calls (AC-10): model tokens occur only inside the worker sessions it spawns.

  dispatch.py render --config <config.json> --unit <unit-id>
  dispatch.py run    --config <config.json> --unit <unit-id>

config.json:
  tier_list        ordered [{"tier","model"}] — first attempt is ALWAYS
                   tier_list[0]; escalation is ALWAYS the next entry, never a
                   skip or repeat (AC-9); no field of the unit selects tier or
                   depth.
  budget_usd       per-unit budget fuse per attempt (stop-loss, INV-5)
  template         contract template path (templates/task-contract.md)
  idiom_registry   idiom-registry.json path
  task_class       task class for idiom resolution (DS-3)
  interface        interface artifact {"signatures":{name:sig},"shared":[...]}
  expansion_dir    expansion records dir
  freeze           freeze manifest {"accepted":true,"records":{path:sha256},
                   "interface":{path,sha256},"aux":{path:sha256}} — a run
                   without it, without accepted:true, or with any sha
                   mismatch is REFUSED (AC-16 refusal leg). aux MUST list the
                   units file (it carries the ruler invocation + caps/scope —
                   INV-4 freezes rulers, not just expansion records); listing
                   the template and idiom registry there is recommended.
  units            units.json: [{id,title,scope[],read_only[],do_not_touch[],
                   names[],callees_in_scope[],caps[{metric,cap,reference}],
                   check_command,workdir,tasks[],idiom_id?,out_dir}]
  ledger           ledger JSONL path (this engine is the only writer, DS-5)
  worker_cmd       optional argv-prefix override for fixtures; default is the
                   headless harness CLI. The override receives the same
                   contract path argument and must print the worker's JSON
                   result on stdout.
  reset_cmd        optional shell command run before each attempt (workdir reset)
  interface_revision_ref  optional string copied into rows (DS-14)

Verdict semantics (design ruling): the held-out check ALONE decides
PASS/FAIL — acceptance is the check (check author != code author), the budget
fuse is a per-unit stop-loss, never a validity criterion. A PASS whose row
records terminal_reason=budget_exhausted (or error) is therefore legal and
returns success: failing a check-green unit would waste the spend, and
escalating would re-buy accepted work. The ledger keeps the honest reason.

Path resolution: relative paths in the config (and workdir/out_dir in units)
resolve against base_dir, itself relative to the config file's directory
(default: the config file's directory) — configs work from any cwd.

Exit codes: 0 unit PASS; 1 tier list exhausted (unit routed to the
integration gate for human ruling, DS-2); 3 dispatch refused (freeze gate);
4 reset_cmd failed before the worker spawned (no attempt, no row).
"""
import datetime, fcntl, hashlib, json, os, re, subprocess, sys
from pathlib import Path

sys.dont_write_bytecode = True

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_scope

REFUSAL_PAT = re.compile(r"\b(i refuse|refuse to|cannot comply|will not comply|"
                         r"decline to (do|implement|proceed)|cannot assist with)\b", re.I)


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_file(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def die(msg, rc):
    print(msg)
    sys.exit(rc)


def load(cfg_path, unit_id):
    cfg = json.loads(Path(cfg_path).read_text())
    base = (Path(cfg_path).resolve().parent / cfg.get("base_dir", ".")).resolve()
    cfg["_base"] = base

    def ab(v):
        return v if Path(v).is_absolute() else os.path.normpath(str(base / v))
    for k in ("template", "idiom_registry", "interface", "expansion_dir", "freeze", "units", "ledger"):
        if cfg.get(k):
            cfg[k] = ab(cfg[k])
    if cfg.get("worker_cmd"):
        cfg["worker_cmd"] = [ab(x) if (base / x).exists() else x for x in cfg["worker_cmd"]]
    units = json.loads(Path(cfg["units"]).read_text())
    unit = next((u for u in units if u["id"] == unit_id), None)
    if unit is None:
        die(f"unknown unit {unit_id}", 2)
    for k in ("workdir", "out_dir"):
        if unit.get(k):
            unit[k] = ab(unit[k])
    return cfg, unit


def freeze_gate(cfg):
    """AC-16 refusal leg: no accepted+sha-verified freeze manifest, no dispatch.
    The manifest is a CLOSED set: a record in the expansion dir that the
    manifest does not list refuses dispatch (addition is drift too), and the
    interface artifact — a frozen input of every render — must be listed with
    a matching sha. Re-run before EVERY attempt, so inputs tampered during an
    attempt can never become the next attempt's baseline."""
    fz_path = cfg.get("freeze")
    if not fz_path or not Path(fz_path).exists():
        die("DISPATCH REFUSED: freeze manifest absent — expansion records are not frozen", 3)
    fz = json.loads(Path(fz_path).read_text())
    if fz.get("accepted") is not True:
        die("DISPATCH REFUSED: expansion records not human-accepted (freeze.accepted != true)", 3)
    base = cfg.get("_base", Path("."))

    def ab(v):
        return v if Path(v).is_absolute() else os.path.normpath(str(base / v))
    for rpath, rsha in fz.get("records", {}).items():
        rp = ab(rpath)
        if not Path(rp).exists():
            die(f"DISPATCH REFUSED: frozen record missing on disk: {rpath}", 3)
        if sha256_file(rp) != rsha:
            die(f"DISPATCH REFUSED: frozen record drifted: {rpath}", 3)
    if cfg.get("expansion_dir"):
        frozen = {ab(k) for k in fz.get("records", {})}
        for rp in sorted(Path(cfg["expansion_dir"]).glob("*.json")):
            if os.path.normpath(str(rp)) not in frozen:
                die(f"DISPATCH REFUSED: unfrozen expansion record present: {rp}", 3)
    if cfg.get("interface"):
        info = fz.get("interface") or {}
        if ab(info.get("path", "")) != cfg["interface"]:
            die("DISPATCH REFUSED: interface artifact not covered by the freeze manifest", 3)
        if sha256_file(cfg["interface"]) != info.get("sha256"):
            die(f"DISPATCH REFUSED: interface artifact drifted: {cfg['interface']}", 3)
    aux = {ab(k): v for k, v in (fz.get("aux") or {}).items()}
    if cfg.get("units") and cfg["units"] not in aux:
        die("DISPATCH REFUSED: units artifact (the ruler invocation + caps) not covered by the freeze manifest (INV-4)", 3)
    for apath, asha in aux.items():
        if not Path(apath).exists() or sha256_file(apath) != asha:
            die(f"DISPATCH REFUSED: frozen aux artifact drifted or missing: {apath}", 3)
    return fz


def render(cfg, unit, attempt=None):
    tmpl = Path(cfg["template"]).read_text()
    iface = json.loads(Path(cfg["interface"]).read_text()) if cfg.get("interface") else {"signatures": {}, "shared": []}
    sigs = iface.get("signatures", {})
    target = "\n".join(s for s in (sigs.get(n, "") for n in unit.get("names", [])) if s) or "(none decided — body-only unit)"
    missing = [n for n in unit.get("callees_in_scope", []) if n not in sigs]
    if missing:   # an in-scope callee the interface author never ruled on is an authoring error, never a silent drop
        die(f"RENDER REFUSED: callee(s) with no signature in the interface artifact: {', '.join(missing)}", 2)
    deps = [sigs[n] for n in unit.get("callees_in_scope", [])]
    dep_txt = "\n".join(deps) or "(none — this unit uses no other unit's deliveries)"

    # Seam Convention: exactly one registry entry, valid for the task class (DS-3)
    idiom_id, idiom_text = "n/a", "(no undelivered in-scope dependencies — no bridging idiom applies)"
    if unit.get("callees_in_scope"):
        reg = json.loads(Path(cfg["idiom_registry"]).read_text())
        want = unit.get("idiom_id") or next((e["id"] for e in reg["entries"]
                                             if e["task_class"] == cfg.get("task_class")), None)
        entry = next((e for e in reg["entries"] if e["id"] == want), None)
        if entry is None:
            die(f"RENDER REFUSED: idiom id {want!r} not in registry", 2)
        if entry["task_class"] != cfg.get("task_class"):
            die(f"RENDER REFUSED: idiom {entry['id']} is for task class {entry['task_class']!r}, run is {cfg.get('task_class')!r}", 2)
        idiom_id, idiom_text = entry["id"], entry["text"]

    # Caps: headroom >= 2x the stated honest reference (DS-1); no reference, no render
    cap_lines = []
    for c in unit.get("caps", []):
        if "reference" not in c or "cap" not in c:
            die(f"RENDER REFUSED: cap {c.get('metric', '?')!r} lacks cap/reference (DS-1)", 2)
        if float(c["reference"]) <= 0:
            die(f"RENDER REFUSED: cap {c['metric']!r} reference must be positive — "
                f"a zero-reference metric needs no cap; omit it or state a positive reference", 2)
        if float(c["cap"]) < 2 * float(c["reference"]):
            die(f"RENDER REFUSED: cap {c['metric']!r} = {c['cap']} has headroom < 2x reference {c['reference']} (DS-1)", 2)
        cap_lines.append(f"- {c['metric']}: cap {c['cap']} (reference {c['reference']}, "
                         f"headroom {float(c['cap']) / float(c['reference']):.1f}x)")
    tasks = unit.get("tasks") or ["satisfy the Verbatim Check Command"]
    fills = {
        "UNIT_ID": unit["id"], "TASK_CLASS": cfg.get("task_class", ""), "RENDERED_TS": now(),
        "TITLE": unit.get("title", unit["id"]),
        "SCOPE": "\n".join(f"- {s}" for s in unit.get("scope", [])) or "- (workdir)",
        "READ_ONLY": "\n".join(f"- {s}" for s in unit.get("read_only", [])) or "- none",
        "DO_NOT_TOUCH": "\n".join(f"- {s}" for s in unit.get("do_not_touch", [])) or "- none",
        "TARGET_INTERFACE": target, "SHARED_DECLS": "\n".join(iface.get("shared", [])) or "(none)",
        "DEPENDENCY_CONTRACTS": dep_txt, "IDIOM_ID": idiom_id, "IDIOM_TEXT": idiom_text,
        "CAPS": "\n".join(cap_lines) or "- none",
        "CHECK_COMMAND": unit["check_command"],
        "TASKS": "\n".join(f"- [ ] {t}" for t in tasks),
        "REPORT_SEED": "(empty — executor fills)",
    }
    out = tmpl
    for k, v in fills.items():
        out = out.replace("{{" + k + "}}", str(v))
    out_dir = Path(unit.get("out_dir", "."))
    out_dir.mkdir(parents=True, exist_ok=True)
    # per-attempt artifact: a ledger row's contract_ref must stay resolvable to
    # the exact bytes dispatched, so a later attempt never overwrites it
    suffix = f".a{attempt}" if attempt else ""
    cpath = out_dir / f"task-contract-{unit['id']}{suffix}.md"
    cpath.write_text(out)
    # Executor Write Protocol baseline (AC-19): normalized contract + raw record shas
    rec_files = sorted(str(p) for p in Path(cfg["expansion_dir"]).glob("*.json")) if cfg.get("expansion_dir") else []
    sidecar = out_dir / f"task-contract-{unit['id']}{suffix}.sha.json"
    check_scope.main(["record", "--contract", str(cpath), "--records", *rec_files, "--out", str(sidecar)])
    return cpath, sidecar


def append_row(ledger, row):
    """One locked append per attempt (DS-5): serialized, uninterleaved."""
    Path(ledger).parent.mkdir(parents=True, exist_ok=True)
    with open(ledger, "a") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        fh.write(json.dumps(row) + "\n")
        fh.flush()
        fcntl.flock(fh, fcntl.LOCK_UN)


def spawn(cfg, unit, model, budget, cpath, out_dir, attempt):
    # The worker runs with cwd = the unit's workdir; paths handed to it must
    # survive that, so the contract path and any worker_cmd file entries are
    # absolutized here.
    cabs = Path(cpath).resolve()
    if cfg.get("worker_cmd"):
        argv = [str(Path(x).resolve()) if Path(x).exists() else x for x in cfg["worker_cmd"]]
        argv.append(str(cabs))
    else:
        argv = ["claude", "-p", "--model", model, "--max-budget-usd", str(budget),
                "--allowedTools", "Bash,Read,Edit,Write,Glob,Grep", "--output-format", "json",
                f"Read {cabs} and execute it."]
    env = dict(os.environ)
    for k in ("CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT"):   # worker sessions are fresh, never nested
        env.pop(k, None)
    ofile = out_dir / f"attempt-{attempt}.output.json"
    timeout = float(cfg.get("worker_timeout_sec", 3600))
    with open(ofile, "w") as out, open(out_dir / f"attempt-{attempt}.stderr.log", "w") as err:
        try:
            p = subprocess.run(argv, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                               cwd=unit.get("workdir", "."), env=env, timeout=timeout)
            rc = p.returncode
        except subprocess.TimeoutExpired:
            rc = -9   # hung worker: the attempt still gets its ledger row (DS-6)
    return ofile, rc


def run_unit(cfg, unit):
    freeze_gate(cfg)
    fz_sha = sha256_file(cfg["freeze"])
    tiers = cfg["tier_list"]
    budget = float(cfg["budget_usd"])
    out_dir = Path(unit.get("out_dir", "."))
    ledger = cfg["ledger"]
    aux_timeout = float(cfg.get("check_timeout_sec", 900))
    prev_attempt = None
    for idx, t in enumerate(tiers):          # first attempt is ALWAYS tiers[0] (AC-9)
        attempt = idx + 1
        freeze_gate(cfg)   # every attempt: tampered inputs never become the next baseline
        if cfg.get("reset_cmd"):
            try:
                rp = subprocess.run(cfg["reset_cmd"], shell=True, cwd=unit.get("workdir", "."),
                                    timeout=aux_timeout)
                rrc = rp.returncode
            except subprocess.TimeoutExpired:
                rrc = -9
            if rrc != 0:   # a dirty workdir would corrupt the attempt; no worker spawned, no row owed
                die(f"RESET FAILED: reset_cmd rc={rrc} — worker not spawned", 4)
        cpath, sidecar = render(cfg, unit, attempt)
        csha = sha256_file(cpath)            # audit-chain hash: the contract AS DISPATCHED, pre-worker
        ofile, rc = spawn(cfg, unit, t["model"], budget, cpath, out_dir, attempt)
        crashed, o = False, {}
        try:
            o = json.loads(Path(ofile).read_text())
        except Exception:
            crashed = True                    # killed before emitting output (DS-6)
        cost = o.get("total_cost_usd")
        report_text = str(o.get("result", ""))

        verdict, check_file = "NONE", None
        if not crashed:
            check_file = out_dir / f"attempt-{attempt}.check.txt"
            try:
                sv = subprocess.run([sys.executable, str(Path(__file__).parent / "check_scope.py"),
                                     "verify", "--sidecar", str(sidecar)], capture_output=True, text=True,
                                    timeout=aux_timeout)
                ck = subprocess.run(unit["check_command"], shell=True, capture_output=True, text=True,
                                    cwd=unit.get("workdir", "."), timeout=aux_timeout)
                check_file.write_text(sv.stdout + sv.stderr + ck.stdout + ck.stderr)
                verdict = "PASS" if (sv.returncode == 0 and ck.returncode == 0) else "FAIL"
            except subprocess.TimeoutExpired:
                check_file.write_text("check timed out")
                verdict = "FAIL"

        exhausted = (cost is not None and cost >= budget) or \
                    ("budget" in str(o.get("terminal_reason", "")).lower())
        errored = crashed or rc != 0 or o.get("is_error") is True
        # DS-4 precedence: budget_exhausted > error > completed
        reason = "budget_exhausted" if exhausted else ("error" if errored else "completed")

        diff_file = out_dir / f"attempt-{attempt}.diff"
        if cfg.get("diff_cmd") and not crashed:
            try:   # a failing diff must never cost the attempt its ledger row
                d = subprocess.run(cfg["diff_cmd"], shell=True, capture_output=True, text=True,
                                   cwd=unit.get("workdir", "."), timeout=aux_timeout)
                diff_file.write_text(d.stdout)
            except (subprocess.TimeoutExpired, OSError):
                pass
        row = {"unit": unit["id"], "attempt": attempt, "tier": t["tier"], "model_id": t["model"],
               "budget": budget, "cost_usd": cost,
               "turns": o.get("num_turns"),
               "thinking_tokens": ((o.get("usage") or {}).get("output_tokens_details") or {}).get("thinking_tokens"),
               "terminal_reason": reason, "verdict": verdict, "escalated_from": prev_attempt,
               "contract_ref": {"path": str(cpath), "sha256": csha, "inputs_rev": fz_sha},
               "artifacts": {"diff": str(diff_file) if diff_file.exists() else None,
                             "check": str(check_file) if check_file else None,
                             "session_id": o.get("session_id")},
               "worker_refusal": bool(REFUSAL_PAT.search(report_text)),
               "interface_revision_ref": cfg.get("interface_revision_ref"),
               "check_cost_usd": 0 if not crashed else None,
               "ts": now()}
        append_row(ledger, row)
        print(f"{unit['id']} attempt {attempt} tier={t['tier']} verdict={verdict} reason={reason} cost={cost}")
        if verdict == "PASS":
            return 0
        prev_attempt = attempt               # escalate to the NEXT list entry, never a skip
    print(f"{unit['id']}: tier list exhausted — verdict FAIL; unit routed to the integration gate for human ruling "
          f"(manual step: add it via make_gate.py --residual-units {unit['id']})")
    return 1


def main(argv):
    if len(argv) < 1 or argv[0] not in ("render", "run"):
        print(__doc__)
        return 2
    mode = argv[0]
    args = argv[1:]
    cfg_path = args[args.index("--config") + 1]
    unit_id = args[args.index("--unit") + 1]
    cfg, unit = load(cfg_path, unit_id)
    if mode == "render":
        cpath, _ = render(cfg, unit)
        print(f"rendered: {cpath}")
        return 0
    return run_unit(cfg, unit)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
