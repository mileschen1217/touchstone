# design-review — maintainer notes

Orientation for maintainers. The executable procedure lives in `SKILL.md`.

## Invocation

```
/touchstone:design-review <path>            # one doc
/touchstone:design-review <glob>            # multiple docs in one pass
```

## Pattern

Pattern A composite — dispatches `touchstone:cross-provider-reviewer`, which owns the review
procedure end-to-end (parallel CC + Codex review, divergence-labeled synthesis, CC-only
fallback when Codex is unavailable).

## History — renamed from `m-deep-review`

The previous `m-deep-review` covered both doc review AND per-batch code review. Per-batch code
review now lives at `/touchstone:code-review batch` (Pattern B). The old `m-deep-review`
registry name no longer resolves.
