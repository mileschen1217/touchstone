# init UI copy

Display strings used by Step 1 of `touchstone:init`. Step 1 references this file; do not duplicate these strings in SKILL.md.

## Incremental-add menu (TTY, source-as-truth not yet adopted)

```
Current config:
  workspace_root:      .touchstone (or the current value)
  adopted_disciplines: [] (or the current list)

Disciplines:
  ○ source-as-truth — enables Bridge content audit + kill-on lifecycle + standing-vs-transient classification in stage skills that support it.

Adopt source-as-truth? [Y/n]
```

Print each already-adopted discipline with a `✓` prefix and each not-yet-adopted one with `○`.

## Non-interactive message (no TTY, source-as-truth not yet adopted)

```
[touchstone:init] Non-interactive: source-as-truth available but not adopted.
Re-run interactively or pass --adopt source-as-truth to add.
```

Exit 0 (not an error; the existing config is valid).
