# Codex harness adapter

- `resolve_plugin_root`: use the installed skill path exposed by Codex and
  ascend to the plugin root. Hook commands may use `${PLUGIN_ROOT}`; Codex also
  supplies `${CLAUDE_PLUGIN_ROOT}` for compatible plugin hooks.
- `resolve_project_root`: use `git rev-parse --show-toplevel` from the task cwd.
- `invoke_skill(name, args)`: explicitly invoke the installed Touchstone skill
  by name and pass `args` unchanged.
- `dispatch_review_arm(...)`: for `codex`, use `spawn_agent` to create a fresh
  context whose task names the shared reviewer skill, role, lens file, subject
  file, and result directory. For `claude-code`, run
  `scripts/run-external-reviewer.sh`. The child or external process reads the
  files itself; the owning workflow validates liveness and provenance.

Treat `spawn_agent` and Codex skill mention syntax as Codex transport names,
never as portable runtime terms.
