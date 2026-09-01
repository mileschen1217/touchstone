# Config Resolver (shared, single home)

Reads `touchstone.yaml` and derives the path bundle. Callers invoke it
with the pinned phrase; they do NOT inline its logic.

## 1-2. Read config + derive the path bundle

Run `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-config.sh --root <project-root>`
and use its six `key=value` lines as the bundle (`bundle.specs`,
`bundle.adr`, `bundle.epics`, `bundle.plans`, `bundle.archive`,
`bundle.research`); non-zero exit means malformed config — surface its
message and stop.

**Epic-scoped placement rule.** When the caller names an epic, that work's
artifacts (specs, research, plans) live in the epic's own dir
`bundle.epics/<epic-dir>/` (dir = `YYYY-MM-DD-<slug>` for new epics;
grandfathered dirs may be undated) — they travel with the epic through
close's Disposition pass. `bundle.specs` / `bundle.research` / `bundle.plans` are
the standalone fallback for work with no epic.
