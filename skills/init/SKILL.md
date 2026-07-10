---
name: init
description: |
  One-time per-project setup for touchstone plugin. Writes
  ${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml with paths and adopted
  disciplines. Idempotent without --reset. Trigger phrases: "set up
  touchstone", "init touchstone", "/touchstone:init".
kind: workflow
---

# touchstone:init

## Argument grammar

```
/touchstone:init                              # interactive (default)
/touchstone:init --adopt <discipline>         # repeatable
/touchstone:init --workspace-root <path>      # override workspace root (default .touchstone)
/touchstone:init --reset                      # overwrite existing yaml (prior copied to .bak)
/touchstone:init --migrate                    # migrate schema-1 yaml to schema-2
```

`--adopt` is repeatable (one per discipline). Each flag's behaviour is detailed in the step that consumes it (`--reset` Step 1, `--migrate` Step 1, `--workspace-root` Step 2, `--adopt` Step 3).

**Live-user note:** default interactive mode (Steps 2–3) prompts for workspace root and discipline adoption; pass `--workspace-root` and `--adopt` to run non-interactively without a live user.

## Step 1 — Idempotence check

Read `${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml` and determine the action from this table:

| File state | `--reset`? | Action |
|---|---|---|
| Missing | either | Proceed to Step 2. |
| Exists, malformed YAML | either | Print error (file name + parse-error line). Exit non-zero. Do NOT silently overwrite. |
| Exists, parseable; `--reset` passed | yes | Copy existing file to `${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml.bak`; print "Preserved prior yaml at .bak". Proceed to Step 2. |
| Exists, parseable; `source-as-truth` already adopted | no | Print current config. Print "Run /touchstone:init --reset to overwrite." Exit 0. |
| Exists, parseable; `source-as-truth` not yet adopted; TTY present | no | Print current config. Show incremental-add menu (see `references/init-ui.md`). Accept answer or `--adopt source-as-truth` flag. Merge into `adopted_disciplines` without touching paths. Write updated yaml (Step 5 write logic, paths unchanged). Print verification summary (Step 6). Exit 0. |
| Exists, parseable; `source-as-truth` not yet adopted; no TTY | no | Print non-interactive message (see `references/init-ui.md`). Exit 0. |

Note: `adopted_disciplines` key missing is treated as an empty list.

`--migrate` flag: read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` with the Read tool and follow it exactly. The config resolver's §3 migration steps handle reading old schema-1 keys, deriving `workspace_root`, writing new schema-2 yaml, and printing a diff summary. Do not duplicate that logic here.

## Step 2 — Collect paths

Prompt the user for the workspace root (or accept the matching flag if present):

| Flag | Prompt | Default |
|---|---|---|
| `--workspace-root <path>` | Workspace root? | `.touchstone` |

Values are taken verbatim. **Sharp edge: path escape (`../../...`) is NOT rejected.**

## Step 3 — Collect adopted disciplines

For each entry in the supported discipline list (currently: `source-as-truth`), prompt: "Adopt <discipline>? [Y/n]". Skip prompt if `--adopt <discipline>` was passed.

Supported disciplines (MVP):
- `source-as-truth` — the description shown to the user lives in `references/init-ui.md` (do not restate it here).

## Step 4 — Create target dirs

Create all six derived subpaths under `workspace_root`:

```bash
mkdir -p "${CLAUDE_PROJECT_DIR}/<workspace_root>/specs"
mkdir -p "${CLAUDE_PROJECT_DIR}/<workspace_root>/docs/adr"
mkdir -p "${CLAUDE_PROJECT_DIR}/<workspace_root>/epics"
mkdir -p "${CLAUDE_PROJECT_DIR}/<workspace_root>/plans"
mkdir -p "${CLAUDE_PROJECT_DIR}/<workspace_root>/archive/specs"
mkdir -p "${CLAUDE_PROJECT_DIR}/<workspace_root>/research"
```

If `mkdir` fails (permission, invalid path), print error naming the path, exit non-zero.

## Step 4b — Bootstrap checker scaffold

Run the deterministic scaffold bootstrap (idempotent; converges any partial state):

    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-checker-scaffold.sh" "${CLAUDE_PROJECT_DIR}"

## Step 5 — Write yaml

Write `${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml`:

```yaml
# written by /touchstone:init vX.Y.Z. Hand-editable.
schema_version: 2  # current schema; legacy schema 1 is handled by --migrate
workspace_root: <answer or .touchstone>
adopted_disciplines: [<comma-separated answers>]
```

## Step 6 — Verification summary

Print:

```
✓ Wrote ${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml
  workspace_root:      <value>
  adopted_disciplines: [<values>]

Next: try /touchstone:design-spec <feature-name>
```
