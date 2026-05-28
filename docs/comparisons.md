# Comparisons (internal)

> Working notes comparing touchstone against neighbouring tools / plugins.
> Not yet ready to surface in the public README — the comparisons need
> hands-on validation across at least one shared scenario (e.g., "draft
> a spec for feature X in each tool, compare the artifacts").
>
> Treat every characterisation here as **first-pass research**, subject
> to revision after actual usage.

## Spec-frameworks neighbourhood

Tools that treat the spec as a primary artifact, regardless of whether
code or spec wins on drift.

| Tool | One-line | Source |
|---|---|---|
| [GitHub Spec-Kit](https://github.com/github/spec-kit) | Spec-driven, artifact-first. Refinement pipeline (constitution → plan → tasks → analysis) generates implementation. | https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/ |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | Living-spec via delta proposals. Archive step syncs delta → canonical `specs/` tree. | https://github.com/Fission-AI/OpenSpec/blob/main/docs/workflows.md |
| AWS Kiro | Spec-as-contract (not yet researched in depth). | — |

### Honest read

- **Spec-Kit**: reductively summarising as "spec-as-generator" undersells
  the pipeline. The README claim that "intent is the source of truth" is
  in their blog post, but their actual toolkit covers refinement /
  constitution / analysis steps. Comparison needs more nuance than a
  one-liner.
- **OpenSpec**: "dual-SoT risk" is a fair operational critique but loaded.
  The intended workflow is delta-proposal-driven, so direct code edits
  are out-of-band by design. Honest framing: *discipline cost*, not
  *broken authority model*.

## Claude Code skill-pack neighbourhood

Tools that ship multiple skills / agents / commands as a Claude Code or
Claude-adjacent plugin. This is the **actual competitive set** — readers
already on Claude Code compare against these first.

| Tool | One-line | Source |
|---|---|---|
| `superpowers` plugin | Stage primitives (writing-plans, subagent-driven-development, brainstorming, etc.). No opinion on spec / epic shape or doc lifecycle. **touchstone consumes superpowers, not replaces.** | https://github.com/anthropics/superpowers |
| `claude-flow` / Ruflo | 137+ skills, memory, orchestration, dual CC + Codex mode, prebuilt feature / security / refactor pipelines. | https://github.com/ruvnet/claude-flow |
| `agent-os` | Installs standards, workflows, commands, profiles. v3 emphasises discovering / injecting standards and syncing back to profiles. Claude Code Skills integration. | https://github.com/buildermethods/agent-os |
| BMAD method | AI workflow phases from planning through architecture, epics / stories, sprint / build, code review. | https://github.com/bmadcode/bmad-method |

### Honest read

- **`superpowers`** is the most important boundary statement: touchstone
  *calls into* superpowers (for `writing-plans` /
  `subagent-driven-development` / `brainstorming`). It is not a competitor.
  Need to draft a clear "Relationship to superpowers" subsection for the
  public README once cross-project portability is verified.
- **`claude-flow`** has wider scope and more skills; touchstone is narrower
  (12 vs 137+) and more opinionated. Honest pitch: touchstone is the small
  end of the spectrum; claude-flow is the kitchen-sink end. No direct
  competition.
- **`agent-os`** is the closest functional neighbour. Both install
  per-project standards via a config + adopt-discipline pattern. Their
  v3 spec-injection mechanism is parallel to touchstone's runtime
  CONTEXT.md Read. Need hands-on comparison.
- **BMAD** is full lifecycle (planning → build → review); touchstone only
  covers stages 2–7. Different scope.

## Open questions before this goes public

1. **Has anyone tried adopting two of these tools in the same project**?
   Or do they conflict on adopter-config files / skill namespaces / agent
   names? Need to verify.
2. **What's the actual marginal benefit of `touchstone` over `agent-os` +
   superpowers**? Without a real side-by-side test on a non-author project,
   the answer is guesswork.
3. **`source-as-truth` discipline vs Spec-Kit constitution** — are these
   the same primitive at different points in the workflow? Spec-Kit's
   constitution loads at session start; source-as-truth loads at skill
   Step 0. The mechanics are similar; the philosophical orientation
   (code-first vs spec-first) is the actual difference.

## Surfacing plan

- After cross-project portability gate (AC-7b) passes on at least 2
  unrelated projects, draft a "Relationship to ..." section for the
  public README — but ONE neighbour at a time, with a concrete
  side-by-side artifact comparison. No table-of-strawmen.
- Until then, keep this doc internal. Linking from README would invite
  scrutiny the comparisons can't yet survive.
