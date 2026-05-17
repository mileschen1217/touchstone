---
task_id: <id>
epic: <slug>
role: <role-name>
runtime: <cc | codex | gemini>
status: pending
created: YYYY-MM-DD
---

# Task Contract: <title>

## Scope
- <repos / directories / modules the implementer may freely modify to satisfy AC>
- Globs and individual files are both legal. Implementer may create new files inside Scope without listing them upfront.
- Examples:
  - `dl/plugin_moxa_port/framework/src/**` (whole subtree)
  - `dl/plugins_moxa_framework/src/sys_config.rs` (single file)

## Read-Only Boundaries
- <existing contracts the implementer reads but must not modify>
- Typical: cross-team APIs, public traits, schema definitions, vendored deps in this repo.
- If AC appears to require modifying anything here, implementer must fail with `risks` naming the path and the AC that conflicts.

## Do Not Touch
- <hard safety boundary; off-limits even if technically reachable>
- Stronger than Read-Only — implementer should not even read these for context.
- Typical: `.git/`, sibling-team directories, vendored crates outside Scope.

## Acceptance Criteria
- <testable outcomes; load-bearing source of truth for "done">
- ACs from the spec/plan; implementer's job is to satisfy these, not to match a file list.

## Commands to Run
- <verification commands; exit codes captured in result.json>

## Owned Files (optional)
- Use ONLY when you need to pin exact files — e.g., parallel implementer dispatch with non-overlapping ownership, or an intentionally narrow refactor.
- When present, narrows Scope further: implementer must touch only these files.
- Default: omit. Scope + AC + Read-Only Boundaries + Do Not Touch are sufficient for most contracts.

## Expected Output
- result.json (schema version 1) at this task-dir
- (optional) review.md if cross-provider review attached

---

**Implementer behavioral contract** (applies to all runtimes; codex-* agent role prompts mirror this):

1. **Free movement within Scope** — create, modify, or delete files inside Scope without consulting the planner, as long as AC is met. Every path actually written goes into `files_changed`.
2. **Hard stop at Read-Only Boundaries and Do Not Touch** — if AC appears to require modifying any of these, do **not** modify. Set `status: failed` with `risks` naming the path and the AC that conflicts.
3. **Outside-scope necessity → blocked** — if AC requires touching a path outside Scope but not listed in Read-Only Boundaries / Do Not Touch (i.e., the planner missed it), set `status: blocked`, name the path in `handoff_notes`, and return. The orchestrator widens Scope and re-dispatches.
4. **Use `observations`** for any context that doesn't fit summary/risks/handoff_notes — unexpected codebase shape, ambiguities resolved by judgment, related issues out of scope, design questions, anything you'd tell the next implementer if you could chat. Don't pre-filter; the orchestrator skims.
