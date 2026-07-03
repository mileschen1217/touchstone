# Transcript-shape probe — fixture provenance (AC-22 live artifact)

- **Probe session:** `af9bfd86-f458-403c-bac3-1b8a415ed2c7` (dir `-Users-miles-claude-code-claude-code-config`), performed live 2026-07-02 ~14:37–14:42 UTC by the operator; observed from session `a3b7eedf-353c-4fe8-b464-095bb6da7517` (the build session).
- **Operator actions performed:** greeting → long-answer question → Esc interrupt mid-response → correction message → `/compact` → exit → `claude --resume` (same session) → final message ("bye").
- **Capture date:** 2026-07-02. CC version in records: 2.1.198.

## Verified answers (were `[假設]` in the spec's Risks; all three now OBSERVED)

1. **Interrupt sentinel shape:** a `type:"user"` record whose `message.content` is an ARRAY containing `{type:"text", text:"[Request interrupted by user]"}`; the record additionally carries `interruptedMessageId`. The operator's correction arrives as the NEXT `type:"user"` record. (Verbatim records: `interrupt-sample.jsonl` lines 1–2.)
2. **Compact behavior:** `/compact` APPENDS a `{"type":"system","subtype":"compact_boundary"}` record (line 3 of the sample) into the SAME file; all pre-compact records remain present; inode (39763377) and birth time (22:37:13 local) unchanged across the compact → append, not rewrite, not a new file.
3. **Resume behavior:** `claude --resume` continued the SAME session file (same sessionId, same inode); the post-resume records ("Continue from where you left off.", "bye") sit after the compact records in the same file.

## Field-name confirmation (consumed by extract-transcript.sh)

- `.timestamp` — ISO8601 with milliseconds+Z (e.g. `2026-07-02T14:38:18.425Z`) on user records. Confirmed.
- `.message.content` — either a STRING or an ARRAY of typed blocks (`{type:"text",text:...}`, tool_result blocks, …); user text = the string form or the join of `type=="text"` blocks. Confirmed.
- `.type=="user"` marks operator-side records (includes tool_result carriers and harness-injected continuation records — the extractor treats them uniformly as user-side text; L1 filters relevance).

## Implication for REQ-2 (per-file byte cursor)

Compact and resume both APPEND to the same file → tail-only cursoring is sufficient for these lifecycle events; reset-on-shrink remains a defensive guard, not an expected path.
