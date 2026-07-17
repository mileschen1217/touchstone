---
injected-by: [cross-provider-reviewer, code-review]
kind: bridge
---

# Reviewer witness lines (single home)

A review verdict MUST carry read/run witness lines; the intake rejects a verdict
lacking them before acting on its findings. A consumer loads this file into its
dispatch envelope and carries only its own delta.

**Witness line format** (in the verdict, one line per act):
```
READ: <path> | first heading: "<quoted first heading>"
RUN:  <command> | <key output line>
```

Presence is a Tier A format check (≥ 1 READ line + format validity — run
`scripts/check-witness-lines.sh`); count-adequacy against claimed acts, and
authenticity, are Tier B/C spot-checks. The same format doubles as the injection
attestation sample (attestation-ledger).

**Minimum witness set mirrors claimed acts:** one READ line per artifact the
verdict asserts about; one RUN line per execution result it cites; no claimed run
→ no RUN line required. The ≥ 1 READ floor is unconditional — a review verdict
always asserts about the artifact under review, so mirroring can waive RUN lines
only, never the READ floor.

**Fabrication consequence.** A witness line found fabricated by an authenticity
spot-check voids the whole verdict (findings untrusted), triggers one
re-dispatch, and logs the incident for the human — same class as false-green. A
fabricated witness in the re-dispatched verdict escalates straight to the blocked
path (the re-dispatch allowance is spent; repeated fabrication is itself a
class-level signal for the human).

**Succession clause.** Witness lines are the producer-written interim form of
provenance — forgeable in principle, kept because today's harness gives tools
without attesting their use. When harness-pulled provenance becomes available
(orchestrator reads the subagent's real tool-call transcript, or a harness-native
attestation), it supersedes and retires these lines; the format never graduates
into a permanent institution on its own.
