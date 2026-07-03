#!/usr/bin/env bash
# facts-append.sh — the SINGLE writer of proposals.jsonl and resolutions.jsonl
# (sibling of scripts/ledger/ledger-append.sh; same lock / gitignore-self-heal /
# symlink-refusal design — the ledger writer hard-validates catch-miss/v1 only,
# so this sibling owns the proposal/resolution schemas).
# Usage: facts-append.sh {proposal|resolution}     (JSONL batch on stdin)
# Exit 0 = every line appended. Exit 1 = ANY line invalid / lock contention /
# symlink refusal / self-heal failure — nothing is written in any of these.
# Derived fields (recurrence, latest_entry_ts, auto_install_eligible) are
# ALWAYS recomputed; caller-supplied values are overwritten.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/proposal-lib.sh"

MODE="${1:-}"
case "$MODE" in
  proposal|resolution) ;;
  *) echo "facts-append: usage: facts-append.sh {proposal|resolution}" >&2; exit 1 ;;
esac

DIR="$(proposal_lib_resolve_dir)" || exit 1
case "$MODE" in
  proposal)   TARGET="$DIR/proposals.jsonl" ;;
  resolution) TARGET="$DIR/resolutions.jsonl" ;;
esac
ENTRIES="$DIR/entries.jsonl"
PROPS="$DIR/proposals.jsonl"
LOCK="$DIR/.lock"
LOCK_TIMEOUT="${TOUCHSTONE_LEDGER_LOCK_TIMEOUT:-5}"

UNIT_TYPES="checker claude-md-rule memory lens inject-fragment skill-edit"
SCOPES="local upstream"
RES_KINDS="accepted rejected installed install-failed completed revoked"
TRIAGES="spec-violation-fixed class-definition-wrong infra"

PARENT_DIR="$(dirname "$DIR")"
if [ -L "$DIR" ] || [ -L "$PARENT_DIR" ]; then
  echo "facts-append: refusing symlinked ledger path ($DIR)" >&2
  exit 1
fi

in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

# validation errors name the offending line AND field — LINE_NO is set by the
# batch loop before each validator call.
LINE_NO=0
verr() { echo "facts-append: line $LINE_NO: $1" >&2; }

# CLAIMED accumulates witness ids validated earlier in THIS batch so two
# lines of one batch cannot claim the same entry.
CLAIMED=""

validate_proposal() {
  local e="$1"
  echo "$e" | jq -e . >/dev/null 2>&1 || { verr "not valid JSON"; return 1; }
  local schema; schema="$(echo "$e" | jq -r '.schema // empty')"
  [ "$schema" = "proposal/v1" ] || { verr "schema must be proposal/v1 (got '$schema') (field: schema)"; return 1; }
  local scope; scope="$(echo "$e" | jq -r '.scope // empty')"
  # shellcheck disable=SC2086
  in_list "$scope" $SCOPES || { verr "invalid scope: '$scope' (field: scope)"; return 1; }
  local ut; ut="$(echo "$e" | jq -r '.unit_type // empty')"
  # shellcheck disable=SC2086
  in_list "$ut" $UNIT_TYPES || { verr "invalid unit_type: '$ut' (field: unit_type)"; return 1; }
  local f
  for f in title class_desc body_ref; do
    [ -n "$(echo "$e" | jq -r --arg k "$f" '.[$k] // empty')" ] \
      || { verr "missing/empty field: $f (field: $f)"; return 1; }
  done
  local bw_ok
  bw_ok="$(echo "$e" | jq -r '(.benefit_witness // []) | (type=="array") and (length>=1) and all(type=="string" and length>0)')"
  [ "$bw_ok" = "true" ] || { verr "benefit_witness must be a non-empty array of entry ids (field: benefit_witness)"; return 1; }
  local cw_ok
  cw_ok="$(echo "$e" | jq -r '
    (.cost_witness // {}) |
    if .kind=="replay" then ((.fires|type)=="number") and ((.hits|type)=="number") and (.fires>=0) and (.hits>=0)
    elif .kind=="declared" then ((.note // "")|length>0)
    else false end')"
  [ "$cw_ok" = "true" ] || { verr "cost_witness must be kind=replay (numeric fires/hits) or kind=declared (non-empty note) (field: cost_witness)"; return 1; }
  # referential: every witness id must be currently OPEN (exists, unresolved,
  # not pending-claimed) and unclaimed by an earlier line of this batch.
  # `unique` first: a duplicate id inside ONE line's own witness array is not
  # a cross-line double-claim (fill_proposal dedupes it the same way).
  local id
  for id in $(echo "$e" | jq -r '.benefit_witness | unique | .[]'); do
    printf '%s\n' "$OPEN_IDS" | grep -qxF "$id" \
      || { verr "benefit_witness id not open (missing, resolved, or pending-claimed): '$id' (field: benefit_witness)"; return 1; }
    if printf '%s\n' "$CLAIMED" | grep -qxF "$id"; then
      verr "benefit_witness id claimed twice in batch: '$id' (field: benefit_witness)"; return 1
    fi
  done
  CLAIMED="$CLAIMED
$(echo "$e" | jq -r '.benefit_witness | unique | .[]')"
  return 0
}

validate_resolution() {
  local e="$1"
  echo "$e" | jq -e . >/dev/null 2>&1 || { verr "not valid JSON"; return 1; }
  local schema; schema="$(echo "$e" | jq -r '.schema // empty')"
  [ "$schema" = "resolution/v1" ] || { verr "schema must be resolution/v1 (got '$schema') (field: schema)"; return 1; }
  local kind; kind="$(echo "$e" | jq -r '.kind // empty')"
  # shellcheck disable=SC2086
  in_list "$kind" $RES_KINDS || { verr "invalid kind: '$kind' (field: kind)"; return 1; }
  local pid; pid="$(echo "$e" | jq -r '.proposal_id // empty')"
  [ -n "$pid" ] || { verr "missing field: proposal_id (field: proposal_id)"; return 1; }
  local prop
  prop="$(jq -c --arg id "$pid" 'select(.id==$id)' "$PROPS" 2>/dev/null | tail -1)"
  [ -n "$prop" ] || { verr "proposal_id not found: '$pid' (field: proposal_id)"; return 1; }
  local sub_ok
  sub_ok="$(jq -n --argjson e "$e" --argjson p "$prop" \
    '($e.entry_ids // []) | (type=="array") and all(. as $x | ($p.benefit_witness | index($x)) != null)')"
  [ "$sub_ok" = "true" ] || { verr "entry_ids must be a subset of the proposal benefit_witness (field: entry_ids)"; return 1; }
  local has_proof; has_proof="$(echo "$e" | jq -r 'has("proof")')"
  if [ "$kind" = "installed" ]; then
    local proof_ok
    proof_ok="$(echo "$e" | jq -r '(.proof // {}) | has("fire_exit") and has("pass_exit") and has("checked_at") and has("installed_path")')"
    [ "$proof_ok" = "true" ] || { verr "kind=installed requires proof {fire_exit,pass_exit,checked_at,installed_path} (field: proof)"; return 1; }
  else
    [ "$has_proof" = "false" ] || { verr "proof is forbidden unless kind=installed (field: proof)"; return 1; }
  fi
  local has_triage; has_triage="$(echo "$e" | jq -r 'has("triage")')"
  if [ "$kind" = "install-failed" ]; then
    local triage; triage="$(echo "$e" | jq -r '.triage // empty')"
    # shellcheck disable=SC2086
    in_list "$triage" $TRIAGES || { verr "kind=install-failed requires triage in {spec-violation-fixed,class-definition-wrong,infra} (field: triage)"; return 1; }
  else
    [ "$has_triage" = "false" ] || { verr "triage is forbidden unless kind=install-failed (field: triage)"; return 1; }
  fi
  local ut; ut="$(echo "$prop" | jq -r '.unit_type')"
  if [ "$kind" = "completed" ] && [ "$ut" = "checker" ]; then
    verr "kind=completed is reserved for non-checker units (proposal unit_type=checker) (field: kind)"; return 1
  fi
  if [ "$kind" = "installed" ] && [ "$ut" != "checker" ]; then
    verr "kind=installed is checker-only (proposal unit_type=$ut) (field: kind)"; return 1
  fi
  return 0
}

fill_proposal() {
  local e="$1" id ts
  id="$(echo "$e" | jq -r '.id // empty')"
  ts="$(echo "$e" | jq -r '.ts // empty')"
  [ -n "$id" ] || id="p-$(date -u +%Y%m%dT%H%M%SZ)-$(printf '%04x' $((RANDOM % 65536)))"
  [ -n "$ts" ] || ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -c -n --argjson e "$e" --arg id "$id" --arg ts "$ts" \
    --slurpfile es <(cat "$ENTRIES" 2>/dev/null) '
    ($e.benefit_witness | unique) as $w
    | ([ $es[] | select(.id as $i | ($w | index($i)) != null) ]) as $we
    | $e
    | .id=$id | .ts=$ts
    | .recurrence = ($w | length)
    | .latest_entry_ts = ([ $we[].ts ] | max // "")
    | .auto_install_eligible =
        ( (.cost_witness.kind=="replay")
          and (.cost_witness.fires == .cost_witness.hits)
          and (.cost_witness.fires >= 1)
          and (.unit_type=="checker")
          and (.scope=="local") )'
}

fill_resolution() {
  local e="$1" id ts
  id="$(echo "$e" | jq -r '.id // empty')"
  ts="$(echo "$e" | jq -r '.ts // empty')"
  [ -n "$id" ] || id="r-$(date -u +%Y%m%dT%H%M%SZ)-$(printf '%04x' $((RANDOM % 65536)))"
  [ -n "$ts" ] || ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "$e" | jq -c --arg id "$id" --arg ts "$ts" '.id=$id | .ts=$ts'
}

acquire_lock() {
  local start now elapsed holder
  start="$(date +%s)"
  while ! mkdir "$LOCK" 2>/dev/null; do
    now="$(date +%s)"
    elapsed=$((now - start))
    if [ "$elapsed" -ge "$LOCK_TIMEOUT" ]; then
      if [ -f "$LOCK/pid" ]; then
        holder="$(cat "$LOCK/pid" 2>/dev/null)"
        if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
          echo "facts-append: lock contention (holder pid $holder alive)" >&2
          return 1
        fi
      fi
      rm -rf "$LOCK" 2>/dev/null
      start="$(date +%s)"
      continue
    fi
    sleep 0.1
  done
  echo $$ > "$LOCK/pid"
  return 0
}

# shellcheck disable=SC2329  # invoked via trap
release_lock() { rm -rf "$LOCK" 2>/dev/null; }

LINES=()
while IFS= read -r rawline || [ -n "$rawline" ]; do
  [ -n "$rawline" ] || continue
  LINES+=("$rawline")
done
[ "${#LINES[@]}" -eq 0 ] && exit 0

mkdir -p "$DIR" || { echo "facts-append: cannot create ledger dir $DIR" >&2; exit 1; }
acquire_lock || exit 1
trap 'release_lock' EXIT

# nested gitignore self-heal, inside the lock, before validation reads state:
# the ledger dir carries its own `*` .gitignore so the whole fact family
# (entries, proposals, resolutions, sidecars, runs/) stays untrackable.
# DELIBERATE divergence from ledger-append.sh (which appends a
# `.touchstone/ledger/` line to the repo's top-level .gitignore): the nested
# form heals the dir it owns without editing a file outside the ledger family,
# and covers repos whose root .gitignore lacks the ledger line. The two heals
# are compatible — either one makes check-ignore pass, and this branch only
# fires when neither protection is in place.
if ! git -C "$DIR" check-ignore -q "$TARGET" 2>/dev/null; then
  if git -C "$DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    printf '*\n' > "$DIR/.gitignore" 2>/dev/null \
      || { echo "facts-append: cannot self-heal $DIR/.gitignore" >&2; exit 1; }
  fi
fi

# open set computed once per batch, inside the lock (referential checks).
OPEN_IDS="$(open_entries "$DIR" | jq -r '.id')"

LINE_NO=0
for ln in "${LINES[@]}"; do
  LINE_NO=$((LINE_NO + 1))
  case "$MODE" in
    proposal)   validate_proposal "$ln"   || exit 1 ;;
    resolution) validate_resolution "$ln" || exit 1 ;;
  esac
done

for ln in "${LINES[@]}"; do
  case "$MODE" in
    proposal)   FILLED="$(fill_proposal "$ln")" ;;
    resolution) FILLED="$(fill_resolution "$ln")" ;;
  esac
  printf '%s\n' "$FILLED" >> "$TARGET"
done
exit 0
