---
name: spike
description: R4 verification probe v2 — verify ${CLAUDE_PLUGIN_ROOT} injection in Bash + Read tools from inside an installed m-workflow skill. Run after installing the plugin. Trigger phrases — "run the spike", "/m-workflow:spike", "plugin path probe".
kind: workflow
---

# m-workflow:spike v2 — ${CLAUDE_PLUGIN_ROOT} verification

You are running R4 verification probe v2 for the m-workflow plugin. v1 missed `${CLAUDE_PLUGIN_ROOT}` because Probe F only inspected session-global env (`env | grep`) — the variable is injected per-invocation inside Bash/Read calls fired from a skill, not as a session-wide var. v2 tests that hypothesis directly.

Background: nos-cc-skill uses `${CLAUDE_PLUGIN_ROOT}/skills/<name>/<script>` pattern (verified in `~/.claude/plugins/cache/nos-cc-skill/nos-cc-skill/1.3.3/skills/nos-commit/SKILL.md:37,45` and `skills/nos-gitlab-workflow/SKILL.md:29`). m-workflow's plugin.json is structurally same shape (name/version/description/author/keywords). Goal: prove injection mechanism is plugin-agnostic.

## Run all probes. Report each PASS/FAIL with verbatim outcome.

### Probe 1 — Bash sees ${CLAUDE_PLUGIN_ROOT}

```bash
echo "ROOT=${CLAUDE_PLUGIN_ROOT:-UNSET}"
```

Expect: a path under `~/.claude/plugins/cache/m-workflow-dev/m-workflow/0.0.1/` or similar.

### Probe 2 — Bash can ls plugin root

```bash
ls -la "${CLAUDE_PLUGIN_ROOT}"
```

Expect: see `CONTEXT.md`, `README.md`, `.claude-plugin/`, `skills/`, `templates/`.

### Probe 3 — Bash can cat plugin-root file

```bash
cat "${CLAUDE_PLUGIN_ROOT}/CONTEXT.md"
```

Expect marker line: `PLUGIN_ROOT_CONTEXT_VISIBLE_2026_05_17`.

### Probe 4 — Bash can cat plugin templates dir

```bash
cat "${CLAUDE_PLUGIN_ROOT}/templates/probe.md"
```

Expect marker line: `PLUGIN_ROOT_TEMPLATE_VISIBLE_2026_05_17`.

### Probe 5 — Bash can cp template to project (the init use-case)

```bash
mkdir -p /tmp/spike-out && cp "${CLAUDE_PLUGIN_ROOT}/templates/probe.md" /tmp/spike-out/copied.md && head -3 /tmp/spike-out/copied.md
```

Expect: copy succeeds, head shows marker line.

### Probe 6 — Read tool expansion of ${CLAUDE_PLUGIN_ROOT}

Use Read tool with `file_path: "${CLAUDE_PLUGIN_ROOT}/CONTEXT.md"`.

Expect: either resolves (var expanded by Read) or fails (var NOT expanded by Read — only Bash). This determines whether SKILL.md procedures can use Read directly or must shell out via Bash to cat into stdout.

### Probe 7 — Read tool with literal absolute path from Bash output

First run via Bash: `echo "${CLAUDE_PLUGIN_ROOT}"`. Capture the literal path. Then use Read tool with that captured absolute path + `/CONTEXT.md` appended.

Expect: PASS — read should always work on a real absolute path. Establishes that the workaround (Bash echo → capture → Read) is viable if Probe 6 fails.

### Probe 8 — Variable visibility across Bash invocations

```bash
echo "${CLAUDE_PLUGIN_ROOT}" > /tmp/spike-root1.txt
```

Then in a separate Bash call:

```bash
cat /tmp/spike-root1.txt; echo "---"; echo "in-second-call=${CLAUDE_PLUGIN_ROOT:-UNSET}"
```

Expect: same value both times (proves injection is consistent per skill, not random).

## Output

For each probe:

```
Probe N (<label>): PASS|FAIL — <verbatim outcome / error>
```

Then summary table:

| Mechanism | Works? | Notes |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` in Bash | yes/no | exact value |
| `${CLAUDE_PLUGIN_ROOT}` in Read | yes/no | expanded or literal |
| Bash cat | yes/no | |
| Bash cp (init use-case) | yes/no | |
| Cross-invocation consistency | yes/no | |
| Recommended init template-copy mechanism | one line | |

## Do not

- No file modification beyond `/tmp/spike-out/` scratch dir
- No invented results — quote actual error verbatim
- No skipped probes
