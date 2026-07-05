#!/usr/bin/env bash
# install.sh — the ONLY component that writes under .touchstone/checker/.
# Minimal rail: guards -> copy the accepted checker into place -> one
# installed fact. Liveness is observed post-hoc from the raw fire-log
# (reconcile.sh), not proven at install time.
# Usage: install.sh <proposal-id>
#        install.sh --revoke <proposal-id>
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/proposal-lib.sh"

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
for f in draft-check.sh proposal.md; do
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

# refuse to overwrite an existing check at the target path — another mechanism
# owns it (possibly git-tracked); a duplicate proposal must be rejected, or the
# existing install revoked first. Caught live: the first insight run silently
# overwrote a shipped check before this guard existed.
if [ -e "$ROOT/.touchstone/checker/$STAGE/check-$CNAME.sh" ]; then
  echo "install: refusing — .touchstone/checker/$STAGE/check-$CNAME.sh already exists (another mechanism owns this path; reject the duplicate proposal, pick a different check_name, or revoke the existing install first)" >&2
  exit 1
fi

# --- copy + one installed fact ---
TGT_REL=".touchstone/checker/$STAGE/check-$CNAME.sh"
TGT="$ROOT/$TGT_REL"
# shellcheck disable=SC2015
mkdir -p "$(dirname "$TGT")" \
  && cp "$SDIR/draft-check.sh" "$TGT" \
  && chmod 755 "$TGT" \
  || { rm -f "$TGT"; echo "install: cannot write the check into $TGT_REL (cleaned up)" >&2; exit 1; }

FACT="$(jq -c -n --arg pid "$PID" --arg ts "$(now)" --arg path "$TGT_REL" \
  --argjson eids "$(echo "$P" | jq -c '.benefit_witness')" \
  '{schema:"resolution/v1", ts:$ts, proposal_id:$pid, entry_ids:$eids, kind:"installed",
    proof:{installed_path:$path}}')"
append_resolution "$FACT" || { rm -f "$TGT"; echo "install: fact append failed; rolled back" >&2; exit 1; }
echo "installed: $TGT_REL"
exit 0
