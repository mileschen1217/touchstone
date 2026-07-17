---
injected-by: [cross-provider-reviewer, code-review]
kind: bridge
---

# Reviewer witness lines (single home)

A review verdict MUST carry read/run witness lines; the intake rejects a verdict lacking them before acting on its findings (`scripts/check-witness-lines.sh` — presence + format). Format, one line per act:
```
READ: <path> | first heading: "<quoted first heading>"
RUN:  <command> | <key output line>
```
Presence is a Tier A format check; count-adequacy vs claimed acts and authenticity are Tier B/C spot-checks. This same format doubles as the injection attestation sample.

**Minimum set mirrors claimed acts:** one READ per artifact the verdict asserts about, one RUN per execution result it cites; no claimed run → no RUN line. The ≥1 READ floor is unconditional (a verdict always asserts about the artifact under review) — mirroring waives RUN lines only, never the READ floor.

**Fabrication** (found by an authenticity spot-check) voids the whole verdict (findings untrusted), triggers one re-dispatch, and logs the incident — same class as false-green. A fabricated witness in the re-dispatched verdict escalates straight to the blocked path.

**Succession:** these lines are the producer-written interim form of provenance — forgeable in principle, kept because today's harness gives tools without attesting their use. Harness-pulled provenance (the orchestrator reading the subagent's real tool-call transcript) supersedes and retires them; the format never graduates into a permanent institution on its own.
