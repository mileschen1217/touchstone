---
name: code-review
description: |
  Alias — `/touchstone:code-review batch [<range>]` routes to `/touchstone:deliverable-review`, the one review gate after a build (spec conformance + cross-vendor code quality, one review.yaml).
allowed-tools:
  - Skill
user-invocable: false
kind: workflow
---

# /touchstone:code-review — alias

Print exactly one line, then invoke the gate with the same arguments:

```
routing: /touchstone:code-review batch → /touchstone:deliverable-review
```

`Skill(skill: "touchstone:deliverable-review", args: <the arguments given, minus the word batch>)`.
