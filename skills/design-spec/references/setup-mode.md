# Setup Mode

Triggered when `.claude/design-spec.yaml` does not exist in the current project.

## Interactive flow

1. Ask: "Where should design specs live in this project?"
   - Default: `docs/specs/`
   - Validate: directory can be created or already exists under the project root
2. Write `.claude/design-spec.yaml`:
   ```yaml
   specs_dir: docs/specs
   template: ~/.claude/skills/m-design-spec/template.md
   ```
3. Create `specs_dir` if missing
4. Confirm setup complete, proceed to Draft Mode

## Design decisions

- One question, not a wall — only the specs directory needs configuration
- Project-local config, not global — each project can use its own convention
- Template path stays defaulted to the skill's own copy; project can override
  if they need a custom template
