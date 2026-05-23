# Signals

## 1. Skill usage (from Claude Code session JSONL)

```bash
WINDOW_DAYS=${1:-7}
CUTOFF=$(date -v-${WINDOW_DAYS}d +%s 2>/dev/null || date -d "${WINDOW_DAYS} days ago" +%s)
SESSIONS_DIR="$HOME/.claude/projects"

# Count Skill tool invocations per skill name in recent sessions
find "$SESSIONS_DIR" -name "*.jsonl" -newer <(date -r $CUTOFF) -print0 2>/dev/null \
  | xargs -0 grep -hE '"type":"tool_use","name":"Skill"' 2>/dev/null \
  | grep -oE '"skill":"[^"]+"' | sort | uniq -c | sort -rn
```

Surface:
- **Top 10 most-invoked** — which skills earn their keep
- **Bottom 10 (zero or single-digit invocations over 30d)** — dead-skill candidates
- **Trend vs prior window** (if 30d window) — skills growing / declining

## 2. Custom-skill coverage

List every skill under `~/.claude/skills/` prefixed `m-`, `ai-`, and
project-local `.claude/skills/`, then cross-reference with invocation counts.

A custom skill with 0 invocations in 30 days is a **dead-skill candidate**.
Offer options:
- Remove (if confirmed unused)
- Relocate to project-level (if only one project uses it)
- Add to CLAUDE.md routing (if it's being forgotten rather than unneeded)

## 3. Hook fire / fail signal (from session JSONL)

Grep for hook output markers in recent session logs:

```bash
# Hook fires
find "$SESSIONS_DIR" -name "*.jsonl" -newer <(date -r $CUTOFF) -print0 2>/dev/null \
  | xargs -0 grep -hcE 'user-prompt-submit-hook|PreToolUse hook|PostToolUse hook' 2>/dev/null \
  | awk '{sum+=$1} END {print "Hook fires:", sum}'

# Hook failures (blocked, error, rejected)
find "$SESSIONS_DIR" -name "*.jsonl" -newer <(date -r $CUTOFF) -print0 2>/dev/null \
  | xargs -0 grep -hE 'hook.*(blocked|rejected|error|failed)' 2>/dev/null | head -20
```

Flag:
- **High fire / low fail rate** — hook working well
- **High fire / high fail rate** — hook is noisy (false positives); investigate
- **Zero fires** — hook not wired or broken; check settings.json

## 4. Agent delegation patterns (from `~/.claude/agent_delegation.log`)

The `log-agent-delegation.sh` PostToolUse hook appends one JSONL line per Agent() dispatch:

```json
{"ts":"...","subagent_type":"codex-implementer","description":"...",
 "prompt_chars":1234,"run_in_background":false,"is_error":false,
 "cwd":"...","session_id":"..."}
```

The log rotates at 10 MB (configurable via `AGENT_LOG_MAX_BYTES`); one prior generation kept at `agent_delegation.log.1`. To cover the full audit window even when rotation just happened, read both files:

```bash
LOG="$HOME/.claude/agent_delegation.log"
LOG_PREV="$HOME/.claude/agent_delegation.log.1"
( [ -f "$LOG" ] || [ -f "$LOG_PREV" ] ) || { echo "No agent_delegation.log yet — hook not fired."; }

CUTOFF_ISO=$(date -u -v-${WINDOW_DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -d "${WINDOW_DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ)

# Helper: cat both generations (oldest first), tolerate either being missing
agent_log_concat() { cat "$LOG_PREV" 2>/dev/null; cat "$LOG" 2>/dev/null; }

# Total dispatches in window
total=$(agent_log_concat | jq -c "select(.ts >= \"$CUTOFF_ISO\")" 2>/dev/null | wc -l)

# Top agents by call count
agent_log_concat | jq -r "select(.ts >= \"$CUTOFF_ISO\") | .subagent_type" 2>/dev/null \
  | sort | uniq -c | sort -rn | head -10

# Vendor breakdown (Codex / CC / Gemini / general-purpose)
agent_log_concat | jq -r "select(.ts >= \"$CUTOFF_ISO\") |
  if (.subagent_type | test(\"^codex\")) then \"codex\"
  elif (.subagent_type | test(\"^gemini\")) then \"gemini\"
  elif (.subagent_type == \"general-purpose\") then \"general-purpose\"
  else \"cc\" end" 2>/dev/null | sort | uniq -c | sort -rn

# Error rate
errors=$(agent_log_concat | jq -c "select(.ts >= \"$CUTOFF_ISO\") | select(.is_error)" 2>/dev/null | wc -l)
echo "Error rate: $errors / $total"

# Per-project view (filter by cwd)
agent_log_concat | jq -r "select(.ts >= \"$CUTOFF_ISO\") | .cwd" 2>/dev/null \
  | sort | uniq -c | sort -rn | head -10
```

Surface:
- **Top 10 agents by dispatch count** — which backends earn their keep
- **Vendor split (Codex / CC / Gemini / general)** — confirms cross-vendor workflow is firing as designed; Codex agents at 0 over a 30d window after Phase 2 is a workflow-drift signal
- **Error rate by agent** — high errors on `codex-*` agents likely means quota / auth / sandbox issues; flag for investigation
- **Background vs foreground dispatch ratio** — sanity check (foreground should dominate; high background may indicate eager parallelization)
- **Zero dispatches** in window despite active sessions → hook not firing; check `settings.json` PostToolUse `Agent` matcher

## 5. ADR adherence sweep (`--adr` mode)

```bash
ADR_DIR="${ADR_DIR:-$HOME/claude_code/claude_code_config/docs/adr}"
ls "$ADR_DIR"/[0-9]*.md 2>/dev/null | while read f; do
  TITLE=$(head -1 "$f")
  DECISION=$(awk '/^## Decision/,/^## /' "$f" | head -20)
  echo "=== $TITLE ==="
  echo "$DECISION"
done
```

For each ADR:
1. Extract the decision (what was committed to)
2. Check the described implementation exists — file paths, skill names,
   commands referenced in the ADR should resolve
3. Flag **drifted** ADRs (referenced file missing, skill not found, etc.)

Use AI judgment, not regex. Output: list of ADRs with status
{in-force, drifted, superseded, stale}.

## 6. auto-memory health

Auto-memory is per-project (keyed by CWD). Audit the memory for the project
you invoked the skill in. Derive the project key from CWD:

```bash
PROJECT_KEY=$(pwd | sed 's|/|-|g' | sed 's|^-||')
MEM_DIR="$HOME/.claude/projects/-$PROJECT_KEY/memory"
[ -d "$MEM_DIR" ] || { echo "No auto-memory for this project yet."; exit 0; }
ls "$MEM_DIR"/*.md 2>/dev/null | wc -l      # entry count
wc -l "$MEM_DIR"/MEMORY.md 2>/dev/null      # index size
```

If the user wants to audit auto-memory across all projects, pass `--all-memory`
and iterate `~/.claude/projects/*/memory/` directories.

Flag:
- **Index >200 lines** — truncation risk; prune
- **Entries >30 days stale with no updates** — consider archiving
