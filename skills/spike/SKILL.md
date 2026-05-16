---
name: spike
description: R4 verification probe — run after installing the m-workflow plugin to verify Claude Code's path-resolution semantics from inside a skill. Reports which Read-paths resolve and whether plugin-root is reachable. Use when verifying plugin install behavior. Trigger phrases — "run the spike", "/m-workflow:spike", "plugin path probe".
kind: workflow
---

# m-workflow:spike — R4 path-resolution probe

You are running the R4 verification probe for the m-workflow plugin. Your job is to determine, by trying each Read, which file paths Claude Code resolves when a skill runs from inside an installed plugin.

## Procedure

Execute each probe in order. Report the outcome of each: success (which marker line appeared) or failure (Read tool returned an error, and what the error was).

### Probe A — sibling file (bare filename)

Read `sibling.md`. If success, expect to see the marker `SKILL_SIBLING_VISIBLE_2026_05_17`.

### Probe B — sibling file (explicit ./)

Read `./sibling.md`. Same expected marker.

### Probe C — plugin-root file via `../../`

Read `../../CONTEXT.md`. If success, expect to see `PLUGIN_ROOT_CONTEXT_VISIBLE_2026_05_17`.

### Probe D — plugin-root templates via `../../templates/`

Read `../../templates/probe.md`. If success, expect to see `PLUGIN_ROOT_TEMPLATE_VISIBLE_2026_05_17`.

### Probe E — absolute path (control)

Read `/home/moxa/projects/m-workflow/CONTEXT.md`. Should always work; serves as a control for the other probes.

### Probe F — environment variable for plugin root

Run via Bash: `env | grep -iE 'plugin|claude' | head`. Report any variable that looks like it exposes the plugin's install location (e.g. `CLAUDE_PLUGIN_ROOT`, `CLAUDE_CODE_PLUGIN_PATH`).

### Probe G — process working directory at skill-invocation time

Run via Bash: `pwd`. Report the result. This tells us whether the skill executes in the user's project cwd or in the plugin's cache directory.

### Probe H — Glob into plugin cache

Use Glob with pattern `~/.claude/plugins/cache/**/m-workflow/**/CONTEXT.md`. Report how many matches and whether they include the installed version.

## Output format

Print one line per probe in this shape:

```
Probe X (<short label>): <PASS|FAIL> — <one-line outcome>
```

Then a one-paragraph summary:

```
Summary:
  Sibling Read works: <yes/no>
  Plugin-root via ../../: <yes/no>
  Plugin-root via env var: <yes — VAR_NAME / no>
  Plugin-root via Glob fallback: <yes — N matches / no>
  Recommended mechanism for init template-copy: <answer based on above>
```

## Do not

- Do not modify any files.
- Do not invent results — if a probe errors out, report the actual error verbatim.
- Do not skip probes; all eight must run before the summary.
