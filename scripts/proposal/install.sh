#!/usr/bin/env bash
# install.sh — the ONLY component that writes under .touchstone/checker/.
# Installs an accepted checker proposal with a TWO-SIDED liveness self-proof
# through the real runtime hook path, or revokes an installed check.
# Usage: install.sh <proposal-id>
#        install.sh --revoke <proposal-id>
# Install sequence: guards -> fixture-fire-proof (real repo untouched until it
# passes) -> real write -> pass-proof -> installed fact. Any proof failure
# rolls back the real write and records kind=install-failed with a grounded
# triage. Both proof sides execute hooks/run-project-checks.sh by DIRECT exec
# (never `bash <path>`), payload on stdin, process cwd = payload cwd — the
# way Claude Code invokes it at runtime.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/proposal-lib.sh"
HOOK="$SCRIPT_DIR/../../hooks/run-project-checks.sh"

REVOKE=0
if [ "${1:-}" = "--revoke" ]; then REVOKE=1; shift; fi
PID="${1:-}"
[ -n "$PID" ] || { echo "install: usage: install.sh [--revoke] <proposal-id>" >&2; exit 1; }

DIR="$(proposal_lib_resolve_dir)" || exit 1
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)"
[ -n "$ROOT" ] || { echo "install: ledger dir is not inside a git repo" >&2; exit 1; }
PROPS="$DIR/proposals.jsonl"
RES="$DIR/resolutions.jsonl"

P="$(jq -c --arg id "$PID" 'select(.id==$id)' "$PROPS" 2>/dev/null | tail -1)"
[ -n "$P" ] || { echo "install: unknown proposal: $PID" >&2; exit 1; }

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
append_resolution() { printf '%s\n' "$1" | bash "$SCRIPT_DIR/facts-append.sh" resolution; }

# --- revoke path ---
if [ "$REVOKE" -eq 1 ]; then
  LAST="$(jq -c --arg id "$PID" 'select(.proposal_id==$id and (.kind=="installed" or .kind=="revoked"))' \
    "$RES" 2>/dev/null | tail -1)"
  KIND="$(printf '%s' "$LAST" | jq -r '.kind // empty' 2>/dev/null)"
  if [ "$KIND" != "installed" ]; then
    echo "install: no un-revoked kind=installed fact for $PID (never installed, or already revoked)" >&2
    exit 1
  fi
  IPATH="$(printf '%s' "$LAST" | jq -r '.proof.installed_path')"
  rm -f "$ROOT/$IPATH"
  FACT="$(jq -c -n --arg pid "$PID" --arg ts "$(now)" \
    --argjson eids "$(printf '%s' "$LAST" | jq -c '.entry_ids // []')" \
    '{schema:"resolution/v1", ts:$ts, proposal_id:$pid, entry_ids:$eids,
      kind:"revoked", note:"revoked via install.sh --revoke"}')"
  append_resolution "$FACT" || exit 1
  echo "revoked: $IPATH"
  exit 0
fi

# --- mechanical boundary guards: refuse = exit non-zero, nothing written, no fact ---
SCOPE="$(echo "$P" | jq -r '.scope')"
UT="$(echo "$P" | jq -r '.unit_type')"
[ "$SCOPE" = "local" ] || { echo "install: refusing scope=$SCOPE — the install rail is local-only" >&2; exit 1; }
[ "$UT" = "checker" ]  || { echo "install: refusing unit_type=$UT — the install rail is checker-only" >&2; exit 1; }

# accepted fact is the producer-side precondition (the skill appends it on
# explicit human accept, BEFORE invoking install). Gate on the LATEST
# accept/reject decision (sorted by ts), never on "any historical accepted
# fact ever exists" — an accept -> reject history must block install even
# though an older accepted fact is still sitting in resolutions.jsonl.
LATEST_DECISION="$(jq -c --arg id "$PID" \
  'select(.proposal_id==$id and (.kind=="accepted" or .kind=="rejected"))' "$RES" 2>/dev/null \
  | jq -s -c 'sort_by(.ts) | last // empty')"
LATEST_KIND="$(printf '%s' "$LATEST_DECISION" | jq -r '.kind // empty' 2>/dev/null)"
[ "$LATEST_KIND" = "accepted" ] \
  || { echo "install: refusing — no accepted resolution fact for $PID (latest decision: ${LATEST_KIND:-none}; accept first)" >&2; exit 1; }

SDIR="$DIR/proposals/$PID"
for f in draft-check.sh fire-fixture.sh proposal.md; do
  [ -f "$SDIR/$f" ] || { echo "install: sidecar incomplete — missing $f in $SDIR" >&2; exit 1; }
done
fm() { sed -n '/^---$/,/^---$/p' "$SDIR/proposal.md" | awk -F': *' -v k="$1" '$1==k {print $2; exit}'; }
STAGE="$(fm stage)"
CNAME="$(fm check_name)"
case "$STAGE" in
  pre-commit|pre-push) ;;
  *) echo "install: sidecar stage must be pre-commit|pre-push (got '$STAGE')" >&2; exit 1 ;;
esac
[ -n "$CNAME" ] || { echo "install: sidecar proposal.md missing check_name" >&2; exit 1; }

case "$STAGE" in
  pre-commit) CMD="git commit -m proposal-selfproof" ;;
  pre-push)   CMD="git push origin main" ;;
esac

# hook_run <cwd> — direct exec with process cwd = payload cwd (runtime parity)
HOOK_RC=0; HOOK_OUT=""
hook_run() {
  local payload
  payload="$(jq -nc --arg c "$CMD" --arg w "$1" '{tool_input:{command:$c}, cwd:$w}')"
  HOOK_OUT="$(cd "$1" && printf '%s' "$payload" | "$HOOK" 2>&1)"
  HOOK_RC=$?
}

# the exact triage mapping: the hook's MISCONFIGURED block carries this
# literal stderr phrase; anything else is a class-definition problem.
triage_for() {
  if printf '%s' "$1" | grep -qF 'is not executable (chmod +x it)'; then
    echo infra
  else
    echo class-definition-wrong
  fi
}

fail_fact() { # <triage> <note>
  local fact
  fact="$(jq -c -n --arg pid "$PID" --arg ts "$(now)" --arg tr "$1" --arg note "$2" \
    --argjson eids "$(echo "$P" | jq -c '.benefit_witness')" \
    '{schema:"resolution/v1", ts:$ts, proposal_id:$pid, entry_ids:$eids,
      kind:"install-failed", triage:$tr, note:$note}')"
  append_resolution "$fact"
}

# --- fire side FIRST: the real repo is untouched until this passes ---
# A fire-fixture.sh that fails to run (bad script, no output, etc.) is treated
# as an incomplete sidecar: guard refusal, no fact — by design, same class as
# the sidecar-file-presence checks above.
FIX="$(bash "$SDIR/fire-fixture.sh")" || { echo "install: fire-fixture.sh failed" >&2; exit 1; }
git -C "$FIX" rev-parse --show-toplevel >/dev/null 2>&1 \
  || { echo "install: fire-fixture.sh did not print a git toplevel (got '$FIX')" >&2; exit 1; }
# shellcheck disable=SC2015
mkdir -p "$FIX/.touchstone/checker/$STAGE" \
  && cp "$SDIR/draft-check.sh" "$FIX/.touchstone/checker/$STAGE/check-$CNAME.sh" \
  && chmod 755 "$FIX/.touchstone/checker/$STAGE/check-$CNAME.sh" \
  || { echo "install: cannot place the check copy into the fixture checker dir" >&2; exit 1; }
hook_run "$FIX"
FIRE_RC=$HOOK_RC
if [ "$FIRE_RC" -ne 2 ]; then
  # fire-side triage never selects infra: the failing observable is "the check
  # did not bite its own failing fixture", a class-definition problem by
  # definition. spec-violation-fixed requires semantic judgment no exit code
  # can supply — it enters only via the skill's human-grounded facts.
  TR="class-definition-wrong"
  if fail_fact "$TR" "fire-side proof failed: hook exit $FIRE_RC (expected 2 — the check did not bite the failing fixture); hook output: $HOOK_OUT"; then
    echo "install: fire-side proof failed (hook exit $FIRE_RC, expected 2); real repo untouched; install-failed fact recorded (triage=$TR)" >&2
  else
    echo "install: fire-side proof failed (hook exit $FIRE_RC, expected 2); real repo untouched; WARNING: install-failed fact could NOT be appended (facts-append failed)" >&2
  fi
  exit 1
fi

# --- real write + pass side ---
TGT_REL=".touchstone/checker/$STAGE/check-$CNAME.sh"
TGT="$ROOT/$TGT_REL"
# shellcheck disable=SC2015
mkdir -p "$(dirname "$TGT")" \
  && cp "$SDIR/draft-check.sh" "$TGT" \
  && chmod 755 "$TGT" \
  || { rm -f "$TGT"; echo "install: cannot write the check into $TGT_REL (cleaned up)" >&2; exit 1; }
# test-only tamper seam: lets the suite reproduce the exec-bit-death scenario
# on the REAL installed target between the write and the pass-side proof
# (target path handed over as $1). Unset in every production path.
if [ -n "${TOUCHSTONE_INSTALL_TEST_TAMPER:-}" ]; then
  bash -c "$TOUCHSTONE_INSTALL_TEST_TAMPER" _ "$TGT" || true
fi
hook_run "$ROOT"
PASS_RC=$HOOK_RC
if [ "$PASS_RC" -ne 0 ]; then
  rm -f "$TGT"   # rollback: no observable half-installed state
  rmdir "$(dirname "$TGT")" 2>/dev/null || true   # only removes an empty stage dir
  # NOTE: by the time we get here, the hook's own fire_log() has already
  # appended a phantom fire-event to the REAL repo's fire-log.jsonl for this
  # failed pass-side run (the hook ran against $ROOT, not a scratch fixture).
  # This is NOT purged: fire-log.jsonl is append-only (no component ever
  # rewrites or deletes a line), and reconcile.sh time-filters fire
  # counts to each installed fact's [installed-fact ts, revoke ts) interval —
  # a phantom predating any kind=installed fact for this check never falls
  # inside that interval, so it never counts. Truncating here would violate
  # the append-only invariant for a residual that downstream already excludes.
  TR="$(triage_for "$HOOK_OUT")"
  if fail_fact "$TR" "pass-side proof failed: hook exit $PASS_RC on the clean repo; hook output: $HOOK_OUT"; then
    echo "install: pass-side proof failed (hook exit $PASS_RC); rolled back; install-failed fact recorded (triage=$TR)" >&2
  else
    echo "install: pass-side proof failed (hook exit $PASS_RC); rolled back; WARNING: install-failed fact could NOT be appended (facts-append failed)" >&2
  fi
  exit 1
fi

TS="$(now)"
FACT="$(jq -c -n --arg pid "$PID" --arg ts "$TS" --arg path "$TGT_REL" \
  --argjson eids "$(echo "$P" | jq -c '.benefit_witness')" \
  --argjson fe "$FIRE_RC" --argjson pe "$PASS_RC" \
  '{schema:"resolution/v1", ts:$ts, proposal_id:$pid, entry_ids:$eids, kind:"installed",
    proof:{fire_exit:$fe, pass_exit:$pe, checked_at:$ts, installed_path:$path}}')"
append_resolution "$FACT" || { rm -f "$TGT"; echo "install: fact append failed; rolled back" >&2; exit 1; }
echo "installed: $TGT_REL (fire_exit=$FIRE_RC pass_exit=$PASS_RC)"
exit 0
