# Claude Code harness adapter

- `resolve_plugin_root`: use `${CLAUDE_PLUGIN_ROOT}`.
- `resolve_project_root`: use `${CLAUDE_PROJECT_DIR}` when set; otherwise run
  `git rev-parse --show-toplevel` from the working directory.
- `invoke_skill(name, args)`: invoke the installed `touchstone:<name>` skill
  with the Skill tool and pass `args` unchanged.
- `dispatch_review_arm(...)`: for `claude-code`, invoke the registered
  Touchstone reviewer agent with one Agent call. For `codex`, invoke the
  registered Codex forwarding agent, which runs
  `scripts/run-external-reviewer.sh`. Pass file paths, role, and result
  directory; do not paste lens or subject content into the prompt. The owning
  workflow validates returned liveness and provenance.

Treat `Agent` and `Skill` as Claude transport names, never as portable runtime
terms.
