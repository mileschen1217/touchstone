---
name: insight
description: On-demand efficiency report for the auto-run gate skills (design-spec / design-review / anvil) — per-run tokens / USD / wall-clock, harvested from durable logs. Invoking it also bounds the last still-open run at report time.
allowed-tools: [Bash, Read]
user-invocable: true
kind: workflow
---

# /touchstone:insight — auto-run gate efficiency report

Run the reporter and present its output. Do this and nothing more.

1. `sid="${CLAUDE_SESSION_ID:?run inside a Claude Code session}"` — the session whose runs you are reporting; it must match the OTel sink's `session.id`.
2. If an otelcol file sink is configured (README § OTel setup), its path is in `TOUCHSTONE_OTEL_EXPORT`. If that var is unset, omit `--otel`: CC-subagent cells then print `[unverified]` (Codex cost does not need OTel — it comes from `~/.codex/sessions`).
3. From the repo root:
   ```bash
   scripts/metrics-report.sh --session-id "$sid" ${TOUCHSTONE_OTEL_EXPORT:+--otel "$TOUCHSTONE_OTEL_EXPORT"}
   ```
   Append `--session <transcript.jsonl>` to also get the main-loop + session-wallclock summary.
4. Present the tool's output as-is. **Never** replace an `[unverified: <reason>]` cell with a number or a zero — the marker is the honest answer.
5. If the output carries Codex figures, add one caveat when presenting them: Codex cost is reliable only if at most one session ran in this working directory at a time (concurrent same-cwd sessions cross-attribute).
