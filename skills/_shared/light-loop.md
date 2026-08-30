---
kind: bridge
referenced-by: [anvil, crucible]
---

# Light loop (single home)

The no-orchestrator build path: anvil's fallback when conductor is absent, and the build form of a PRD+seams light contract.

- **Main-thread build.** You (the building session) do the work directly, dispatching a worker only for a contained item; there is no commander/worker split to maintain.
- **TDD where testable.** An item with a runnable check writes the failing check first, then the change that turns it green.
- **Lint and test at every step.** The project's lint and test commands run after each item, never only at the end.
- **Blocked → next item.** An item you cannot finish is marked blocked with the reason, and you move to the next; the blocked list is handed to the human at the end, never silently dropped.
- **Deviation entries.** Where what you build departs from the contract, write a `D-n` entry into the epic's `deviation.yaml` at once (the record anvil's deviation duty writes; the schema lists every field): with the schema's other fields it carries `phase`, `refs` (which AC/REQ it departs from), `gap` and `disposition` each as `{title, detail}`, and `derived: true` in place of refs only for a process-only note.
- **Every write under the epic dir re-renders the dossier** through the shipped hook; render by hand only when it did not fire.
