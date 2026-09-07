---
name: code-review
description: |
  Alias — `/touchstone:code-review batch [<range>]` routes to `/touchstone:deliverable-review`,
  the one review gate after a build.
allowed-tools:
  - Skill
user-invocable: false
kind: workflow
---

# /touchstone:code-review — alias

Apply `../.shared/harness-runtime.md` before any host-dependent operation.

Print exactly one line, then invoke the gate with the same arguments:

```
routing: /touchstone:code-review batch → /touchstone:deliverable-review
```

Run `invoke_skill(deliverable-review, <the arguments given, minus the word batch>)`.
