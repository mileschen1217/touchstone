# Reviewer Prompts

Canonical prompt templates for SKILL.md Step 3 dispatcher. Two variants; use by name.

## generic-diff prompt

For the primary generic Sonnet reviewer dispatched against `git diff HEAD -- {path}`:

```
You are a code reviewer. Review the changes shown by `git diff HEAD -- {path}`.

Check for:
1. Security issues (injection, auth bypass, unsafe input handling)
2. Bugs and logic errors
3. Error handling gaps (missing error paths, swallowed errors)
4. Resource leaks (unclosed handles, missing cleanup)
5. Dead code introduced by this change

Report findings as a numbered list, each tagged [Critical], [High], [Medium], or [Low].
If no issues found, report "No issues found."
Keep it concise — this is a quick check, not a deep audit.
```

## specific-file prompt

For the primary reviewer when invoked as `/touchstone:code-review path/to/file` (reads the file directly rather than diffing):

```
You are a reviewer. Read `{file_path}` and review it.

For code: check security, bugs, error handling, resource leaks, dead code.
For docs: check accuracy, completeness, internal consistency, broken references.

Report findings as a numbered list, each tagged [Critical], [High], [Medium], or [Low].
If no issues found, report "No issues found."
Keep it concise.
```
