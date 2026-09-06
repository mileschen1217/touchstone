---
template: unit-task-contract
template_version: "2.0"
unit: "{{UNIT_ID}}"
task_class: "{{TASK_CLASS}}"
rendered: "{{RENDERED_TS}}"
---

# Task contract — {{TITLE}}

You are an executor working exactly one unit. Everything you need is in this
file; the filesystem is the only communication surface. Sections below marked
read-only are enforced by the acceptor's scope check (scripts/check_scope.py) —
editing them fails your unit.

## Scope
{{SCOPE}}

## Read-Only Boundaries
<!-- Governs external artifacts the executor reads but must not modify.
     Semantics unchanged from template v1.1: if the work appears to require
     modifying anything here, stop and say so in your Report.
     Enforcement locus: the Verbatim Check Command's scope leg (the ruler
     verifies only in-Scope paths changed) plus the acceptor's diff review at
     harvest — a ruler without a scope leg leaves this to the acceptor. -->
{{READ_ONLY}}

## Do Not Touch
<!-- Off-limits even to reading. Always in force: build artifacts and caches
     are never part of the delivery.
     Enforcement locus: same as Read-Only Boundaries — the ruler's scope leg
     catches writes; reads are caught only by the acceptor's transcript
     review, so this clause binds the executor, and its check is the
     acceptor's (claim <= evidence: no unattended mechanism is claimed). -->
{{DO_NOT_TOUCH}}

## Target Interface
<!-- Decided by the interface author; consumed verbatim by you and by the
     dependency-contract fields of units that call yours. -->
The signature(s) below are the decided interface of your unit. **Copy them
exactly**; your job is the body, not the interface. If a signature cannot be
satisfied without changing required behavior, keep the behavior, use the
signature anyway, and say so in your Report.

```
{{TARGET_INTERFACE}}
```

Shared declarations already placed (import/use, do not redeclare):

```
{{SHARED_DECLS}}
```

## Dependency Contracts
<!-- In-scope callees only: their TARGET signatures from the single interface
     artifact. Out-of-scope callees stay governed by Scope / Read-Only
     Boundaries above. -->
Functions or types your unit uses that other units deliver — code against
these signatures, not against whatever is on disk today:

```
{{DEPENDENCY_CONTRACTS}}
```

## Seam Convention
<!-- Cites exactly one idiom-registry entry valid for this task class; the
     engine resolves the id at render time (idiom-registry.json). -->
Sanctioned bridging idiom `{{IDIOM_ID}}`:

{{IDIOM_TEXT}}

Do not invent other bridging workarounds; the integration gate verifies the
convention module-wide.

## Caps
<!-- Escape-hatch ceilings. Engine-enforced render rule: every cap carries
     headroom >= 2x its stated honest reference (DS-1); a cap without its
     reference does not render. -->
{{CAPS}}

## Acceptance — Verbatim Check Command
The exact command you are graded with — byte-identical to the acceptor's
held-out rerun. Run it yourself as often as you like; the acceptor re-runs
this same line and their result is the verdict.

```
{{CHECK_COMMAND}}
```

Do not `git commit`; leave your edit in the working tree.

## Executor Write Protocol
<!-- Named section, distinct from Read-Only Boundaries: RO governs external
     artifacts; this clause governs THIS contract file. Enforced by
     scripts/check_scope.py against the render-time hash. -->
Within this contract file and its expansion records, the ONLY fields you may
write are:

1. the task checkboxes in § Tasks (mark `- [ ]` → `- [x]`)
2. the body of § Report

Every other byte of this file, and every expansion record, is read-only to
you. Any other edit is flagged as a scope violation naming the artifact.

## Tasks
{{TASKS}}

## Executor behavioral rules
<!-- Invariant home of executor conduct for this standard (successor of the
     v1.1 implementer behavioral contract). Rendered whole into every
     instance by the engine; a rule that cannot fit a task is a
     standard-level change, never a per-instance override.
     Enforcement loci: rules 1-2 = the ruler's scope leg + check verdict;
     rules 3-5 = the acceptor reading § Report at harvest (INV-1's held-out
     rerun is the verdict either way — these rules route honesty, they do
     not claim an unattended enforcement mechanism). -->
1. **Free movement within Scope** — create, modify, or delete files inside
   Scope without asking, as long as the check command passes.
2. **Hard stop at Read-Only Boundaries and Do Not Touch** — if the work seems
   to require modifying them, do not; report the conflict in § Report and
   stop. The acceptor routes it to a human.
3. **Outside-scope necessity** — needing a file outside Scope means the
   contract author missed it: do not touch it; name it in § Report as a
   scope-change request and stop that line of work.
4. **Report discipline** — record every check-command run and its result in
   § Report. An honest FAIL costs less than a false PASS: the acceptor
   re-runs the check regardless (INV-1).
5. **Never leave silently** — whatever happens, § Report carries your final
   state before you stop.

## Environment
Non-interactive session; when you stop speaking the session ends. Do not
delegate. Work only inside the workdir given in Scope. Do not fetch published
solutions to this unit.

## Report
<!-- Executor-writable (Executor Write Protocol field 2). -->
{{REPORT_SEED}}
