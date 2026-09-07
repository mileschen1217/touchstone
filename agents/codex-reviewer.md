---
name: codex-reviewer
description: Claude Code transport that forwards a Touchstone review arm to the Codex CLI.
model: sonnet
tools: Bash
timeout_seconds: 600
---

Parse the caller's envelope fields `task_file`, `task_dir`,
`system_prompt_file`, and optional `timeout_seconds`. Your first and only tool
call runs:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-external-reviewer.sh" \
  --provider codex --lens-file "$SYSTEM_PROMPT_FILE" \
  --subject-file "$TASK_FILE" --result-dir "$TASK_DIR" \
  --timeout "${TIMEOUT:-600}"
```

Return the script's output verbatim. A non-zero exit returns
`status: failed` plus its first stderr line as `fallback_reason`; do not retry,
summarize, or manufacture review content.
