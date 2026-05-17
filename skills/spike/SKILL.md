---
name: spike
description: R4 / userConfig verification probe v3. Reports CLAUDE_PLUGIN_ROOT mechanism + userConfig scope (per-project vs user-global) + where values are stored. Trigger phrases — "run the spike", "/m-workflow:spike".
kind: workflow
---

# m-workflow:spike v3 — userConfig scope probe

v2 settled `${CLAUDE_PLUGIN_ROOT}` mechanism (load-time text sub, points at install path). v3 settles whether userConfig is per-project or user-global, and where the values land.

## Pre-rendered values (Claude Code expanded at load time)

- Plugin root: `${CLAUDE_PLUGIN_ROOT}`
- Project dir: `${CLAUDE_PROJECT_DIR}`
- Skill dir: `${CLAUDE_SKILL_DIR}`
- Plugin data: `${CLAUDE_PLUGIN_DATA}`
- Session: `${CLAUDE_SESSION_ID}`
- user_config.specs_dir: `${user_config.specs_dir}`
- user_config.adopt_source_as_truth: `${user_config.adopt_source_as_truth}`

Each line above should show a real expanded value when this skill body loads. Any `${...}` left as literal = NOT expanded for that variable.

## Probes

### Probe 1 — confirm all six variables expanded above

Report which of the six bullet values is a real path / value vs unexpanded `${...}` literal.

### Probe 2 — userConfig scope: where stored

Run Bash:

```bash
echo "=== USER-GLOBAL settings ==="
test -f ~/.claude/settings.json && \
  jq '.pluginConfigs // {} | to_entries | map(select(.key | contains("m-workflow")))' ~/.claude/settings.json \
  || echo "no user-global settings.json"

echo "=== PROJECT-LOCAL settings ==="
test -f "${CLAUDE_PROJECT_DIR}/.claude/settings.json" && \
  jq '.pluginConfigs // {} | to_entries | map(select(.key | contains("m-workflow")))' "${CLAUDE_PROJECT_DIR}/.claude/settings.json" \
  || echo "no project-local settings.json"
```

Expected: one or both locations show m-workflow options block. Reports which.

### Probe 3 — runtime env var for userConfig

```bash
env | grep -i CLAUDE_PLUGIN_OPTION
```

Expected: `CLAUDE_PLUGIN_OPTION_SPECS_DIR` and `CLAUDE_PLUGIN_OPTION_ADOPT_SOURCE_AS_TRUTH` (per docs, userConfig also exported as env vars to subprocesses).

### Probe 4 — Plugin data dir

```bash
ls -la "${CLAUDE_PLUGIN_DATA}" 2>&1 | head -5
echo "DATA path: ${CLAUDE_PLUGIN_DATA}"
```

Reports whether the dir auto-exists or is empty until first write.

### Probe 5 — Plugin root mode (copy or symlink to source)

```bash
ls -la "${CLAUDE_PLUGIN_ROOT}" | head -10
# Compare with source
ls -la /home/moxa/projects/m-workflow/.claude-plugin/plugin.json
ls -la "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
stat -c '%i %N' /home/moxa/projects/m-workflow/.claude-plugin/plugin.json "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
```

If inodes match → source-linked (local marketplace shortcut). If different → cached copy.

## Output

For each probe report PASS/FAIL with verbatim outcome.

Summary table:

| Question | Answer |
|---|---|
| userConfig stored in | user-global / project-local / both |
| `${user_config.*}` expanded in SKILL.md body | yes / no |
| CLAUDE_PLUGIN_OPTION_* env vars exported | yes / no |
| `${CLAUDE_PLUGIN_DATA}` auto-created | yes / no |
| Plugin root = source repo (inode match) | yes / no |

## Do not

- No file modification beyond `/tmp/`.
- Quote actual values verbatim.
- All 5 probes must run before summary.
