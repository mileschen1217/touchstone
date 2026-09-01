---
name: init
description: |
  One-time per-project setup for touchstone plugin. Trigger phrases: "set up
  touchstone", "init touchstone", "/touchstone:init".
kind: workflow
user-invocable: true
---

# touchstone:init

## Argument grammar

```
/touchstone:init                              # interactive (default)
/touchstone:init --workspace-root <path>      # override workspace root (default .touchstone)
/touchstone:init --reset                      # overwrite existing yaml (prior copied to .bak)
```

**Live-user note:** default interactive mode (Step 1) prompts for the workspace root; pass `--workspace-root` to run non-interactively without a live user. Disciplines are not elected: `source-as-truth` is always on.

## Step 1 — Collect paths

Prompt the user for the workspace root (or accept the matching flag if present):

| Flag | Prompt | Default |
|---|---|---|
| `--workspace-root <path>` | Workspace root? | `.touchstone` |

Values are taken verbatim. **Sharp edge: path escape (`../../...`) is NOT rejected.**

## Step 2 — Run the deterministic bootstrap

The touchstone.yaml idempotence table, the seven workspace subpath dirs, the checker scaffold + `.gitignore` carve, the yaml write, and the verification summary are all mechanical — one script call does the rest:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-checker-scaffold.sh" --project-root "${CLAUDE_PROJECT_DIR}" --workspace-root <value> [--reset]
```

Print the script's own stdout/stderr to the user as-is; its exit code decides what happened (`--help` documents the four states). Do not hand-write `${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml` yourself.
