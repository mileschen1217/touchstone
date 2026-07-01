---
name: metrics
description: On-demand efficiency report for the auto-run gate skills (design-spec / design-review / anvil). Harvests each run's token/cost/wall-clock from durable logs (OTel for CC subagents, ~/.codex/sessions for Codex) and prints a per-run + session rollup. Invoking it also bounds the last still-open run at report time. Pull-on-demand; capture itself is always-on via a hook.
allowed-tools: [Bash, Read]
user-invocable: true
kind: workflow
---

# /touchstone:metrics — auto-run gate efficiency report

Prints how much each recent **design-spec / design-review / anvil** run cost — tokens, USD, and
wall-clock — by harvesting durable logs after the fact. These three are the only skills profiled:
they are the ones where the AI *auto-runs a defined procedure*, so cost/time is a comparable
efficiency signal. Discussion-driven skills (brainstorm, grill-with-docs, keystone) are deliberately
excluded — their cost tracks the conversation, not the procedure.

Capture is **passive and always-on**: a `UserPromptExpansion` hook stamps a run-manifest per gate to
`${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}/runs`. THIS skill is the on-demand *read*. There
is no on/off mode. Invoking it also defines the **end of the last still-open run** (the run with no
successor gate is bounded at report-invocation time).

**Scope limit — read before trusting the Codex numbers.** Codex cost is attributed by working
directory + time window (`~/.codex/sessions` rollouts, `originator=codex_exec`). It is reliable only
when **at most one active session runs per literal cwd at a time**. Separate git worktrees have
distinct cwds and are fine; two sessions in the *same directory path* at once are out of scope and
their Codex costs may cross-attribute.

## Procedure

1. **Session id** — `sid="${CLAUDE_SESSION_ID:?run inside a Claude Code session}"`. This must match the
   OTel sink's `session.id` and the run-manifests' `session_id`.
2. **OTel export (optional)** — if you have the otelcol file sink from `README § OTel setup`, set its
   path in `TOUCHSTONE_OTEL_EXPORT`. Without it, CC-subagent figures print `[unverified]` honestly
   (Codex figures do not need OTel — they come from `~/.codex/sessions`).
3. **Run the reporter** (from the repo root):
   ```bash
   otel="${TOUCHSTONE_OTEL_EXPORT:-}"
   scripts/metrics-report.sh --session-id "$sid" ${otel:+--otel "$otel"}
   ```
   Optionally add `--session <transcript.jsonl>` for the main-loop / session-wallclock summary.
4. **Present the output verbatim.** Every cell the tool marks `[unverified: <reason>]` is an honest
   gap — never replace one with a fabricated number or a silent zero.

## Not here — the insight layer

Turning these numbers (plus this-run / epic session history) into a *touchstone improvement insight*
— which gate was inefficient, what lens or lint to install — is LLM analysis over the metrics, and
it belongs to the **self-evolving-workflow-loop** epic, not this lean reporter. This skill is the
seam that layer will plug into.
