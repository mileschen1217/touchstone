---
name: init
description: |
  One-time per-project setup for m-workflow plugin. Writes
  ${CLAUDE_PROJECT_DIR}/.claude/m-workflow.yaml with paths and adopted
  disciplines. Idempotent without --reset. Trigger phrases: "set up
  m-workflow", "init m-workflow", "/m-workflow:init".
kind: workflow
---

# m-workflow:init

Writes `.claude/m-workflow.yaml` in the current project, configuring paths and adopted disciplines for the m-workflow plugin's stage skills.

## Step 1 — Idempotence check

Read `${CLAUDE_PROJECT_DIR}/.claude/m-workflow.yaml`. If it exists and the user did not pass `--reset`:

- Print the current config (paths + adopted disciplines).
- Print "Run /m-workflow:init --reset to overwrite."
- Exit 0.

If it does not exist OR `--reset` was passed, continue to Step 2.

## Step 2 — Collect paths

Prompt the user for each path (or accept the matching `--<dir>-name` flag if present):

| Flag | Prompt | Default |
|---|---|---|
| `--specs-dir <path>` | Where do design specs live? | `.swarm/specs` |
| `--adr-dir <path>` | Where do ADRs live? | `.swarm/docs/adr` |
| `--epics-dir <path>` | Where do epic trackers live? | `.swarm/epics` |
| `--plans-dir <path>` | Where do plans live? | `.swarm/plans` |
| `--archive-specs-dir <path>` | Where do retired specs go? | `.swarm/archive/specs` |

Values are taken verbatim. **MVP sharp edge: path escape (`../../...`) is NOT rejected.** Production hardening (reject paths outside `${CLAUDE_PROJECT_DIR}`) is deferred.

## Step 3 — Collect adopted disciplines

For each entry in the supported discipline list (currently: `source-as-truth`), prompt: "Adopt <discipline>? [Y/n]". Skip prompt if `--adopt <discipline>` was passed.

Supported disciplines (MVP):
- `source-as-truth` — enables Bridge content audit + kill-on lifecycle + standing-vs-transient classification in stage skills that support it.

## Step 4 — Create target dirs

For each collected path (`specs_dir`, `adr_dir`, `epics_dir`, `plans_dir`, `archive_specs_dir`):

```bash
mkdir -p "${CLAUDE_PROJECT_DIR}/<path>"
```

If `mkdir` fails (permission, invalid path), print error naming the path, exit non-zero.

## Step 5 — Write yaml

Write `${CLAUDE_PROJECT_DIR}/.claude/m-workflow.yaml`:

```yaml
# Written by /m-workflow:init. Hand-editable.

# Required
schema_version: 1
created_by_plugin_version: 0.1.0
specs_dir: <answer>
adr_dir: <answer>
epics_dir: <answer>
plans_dir: <answer>
archive_specs_dir: <answer>

# Optional
adopted_disciplines: [<comma-separated answers>]
```

If overwriting (`--reset` mode), first copy the existing file to `${CLAUDE_PROJECT_DIR}/.claude/m-workflow.yaml.bak`. Print "Preserved prior yaml at .bak".

## Step 6 — Verification summary

Print:

```
✓ Wrote ${CLAUDE_PROJECT_DIR}/.claude/m-workflow.yaml
  specs_dir:        <value>
  adr_dir:          <value>
  epics_dir:        <value>
  plans_dir:        <value>
  archive_specs_dir: <value>
  adopted_disciplines: [<values>]

Next: try /m-workflow:design-spec <feature-name>
```

## Argument grammar

```
/m-workflow:init                              # interactive (default)
/m-workflow:init --adopt <discipline>         # repeatable
/m-workflow:init --specs-dir <path>
/m-workflow:init --adr-dir <path>
/m-workflow:init --epics-dir <path>
/m-workflow:init --plans-dir <path>
/m-workflow:init --archive-specs-dir <path>
/m-workflow:init --reset                      # overwrite existing yaml
```
