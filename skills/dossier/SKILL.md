---
name: dossier
description: "`/touchstone:dossier [<epic-dir>]` — render the epic's dossier and open it, so what the owner reads is never stale. Skip when a render without opening is wanted: run the renderer directly."
allowed-tools: [Bash]
user-invocable: true
kind: workflow
---

# /touchstone:dossier — render at read, then open

`<epic-dir>` = the argument, else the one `status: active` epic dir under `bundle.epics` (resolve the bundle with `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`; several active → ask which). Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dossier-render.sh" --open <epic-dir>
```

Non-zero exit → surface its message verbatim; a missing opener still leaves `dossier.html` rendered — name its path so the owner can open it by hand.
