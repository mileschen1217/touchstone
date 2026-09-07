---
kind: workflow
adr_id: 0045
status: accepted
date: 2026-09-07
supersedes: plugin-review's fixed dual-vendor arm configuration
---

# ADR-0045: Risk-triggered plugin review with one independent reviewer

- **Status:** accepted
- **Date:** 2026-09-07
- **Deciders:** miles (owner)
- **Related:** ADR-0042 (lens × arm review)
- **Revisit when:** a second vendor repeatedly contributes unique Critical/High findings that the full-lens primary reviewer misses.

## Context

Plugin review detects semantic instruction defects that format validators and
shell tests cannot: contradictory rules in one load set, rules without a
consumer, declared routing that differs from the live map, and unhandled
workflow outcomes. That assurance remains valuable when shipped agent behaviour
changes.

The local gate nevertheless coupled this need to a fixed transport shape:
Codex reviewed all four lenses while Claude reviewed two again. This repeated
work regardless of risk and contradicted ADR-0042's existing conclusion that
lens coverage and builder/reviewer independence are the invariants; vendor
diversity is only one possible arm configuration.

## Decision

Plugin review remains a C+H=0 gate when a diff changes shipped agent behaviour:
skill or agent instructions, workflow routing, hook enforcement, or scripts
executed by those surfaces. Packaging/version-only changes, fixtures, checkers,
and reader documentation do not trigger it unless they also change that
behaviour.

One explicitly selected fresh reviewer independent from the builder runs the
complete four-lens rubric. `plugin-review.sh` accepts
`--reviewer codex|claude-code`, dispatches only that reviewer, and records that
arm for every lens. Absence of a second vendor is not degradation.

A second reviewer is optional escalation, not a gate requirement. Consider it
when the plugin-review machinery itself changed, before overruling or waiving a
disputed Critical/High finding, or when the owner requests it. Cross-harness
support is proved separately: Claude Code and Codex must each pass their own
package validation and live smoke checks. Two reviewer vendors cannot
substitute for those runtime observations.

## Consequences

- Normal plugin review performs one semantic pass instead of overlapping vendor passes.
- The gate still blocks unresolved Critical/High findings.
- Reviewer choice is visible and must be independent from the builder.
- Vendor diversity can still be added where risk or observed unique-findings data justifies its cost.
