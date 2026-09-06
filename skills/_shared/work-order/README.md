# Work-order format standard

File contracts for judgment-free dispatch: planning judgment is spent once,
upstream, into artifacts; execution is scripts plus the cheapest capable
worker tier. No file here instructs a model to load rules — the dispatch
layer is artifact-driven and spends zero model tokens itself.

Every normative rule in these files names the script or test that consumes
it; a rule line with no consumer is a defect (INV-6 of the governing spec).

| file | role | consumers |
|---|---|---|
| `templates/task-contract.md` | contract template: Target Interface, Dependency Contracts, Seam Convention, Caps, Verbatim Check Command, Executor Write Protocol | `scripts/dispatch.py` (renders instances), executors, `scripts/check_scope.py` |
| `templates/integration-gate.md` | cross-unit residual work order; always instantiated, empty sections explicit | `scripts/make_gate.py`, `scripts/reconcile.py` leg 4, `scripts/report.py` |
| `schemas/expansion-record.schema.json` | per-AC expansion record shape (v1) | `scripts/check_expansion.py`, `scripts/reconcile.py`, `scripts/make_gate.py`, `scripts/report.py` |
| `schemas/dispatch-ledger.schema.json` | per-attempt ledger row shape (v1), append-only, engine-only writer | `scripts/dispatch.py` (writer), `scripts/report.py` (reader) |
| `idiom-registry.json` | sanctioned seam conventions, exactly one per task class | `scripts/dispatch.py` render |
| `scripts/check_expansion.py` | expansion record validator | expansion authoring, fixtures |
| `scripts/reconcile.py` | four-leg mechanical trace check | acceptance, fixtures |
| `scripts/dispatch.py` | dispatch engine: render → spawn → check → ledger; budget fuse + tier-list escalation; freeze gate | operators, fixtures |
| `scripts/check_scope.py` | Executor Write Protocol enforcement | `scripts/dispatch.py` |
| `scripts/make_gate.py` | integration-gate instantiation | operators, fixtures |
| `scripts/report.py` | ledger → per-unit + per-AC mutation cost tables | acceptance, fixtures |
| `tests/run-fixtures.sh` | the offline check-artifact suite (zero model tokens) | CI / regression gate |
| `tests/live-ac7.sh` | one real cheap-tier dispatch through the default worker path | evidence collection |

Boundary enforcement model: an executor's Scope / Read-Only / Do Not Touch
compliance is checked by the unit's Verbatim Check Command (the ruler owns a
scope leg) and by the acceptor's harvest review — the contract binds the
executor, the ruler and acceptor check it; no unattended enforcement is
claimed anywhere in the template (INV-6).

Position-independent by construction: scripts locate templates relative to
their own tree, contracts carry no repo-specific paths, and the whole
directory moves as a unit (`tests/run-fixtures.sh` must pass unchanged
after a move — that is the portability check).
