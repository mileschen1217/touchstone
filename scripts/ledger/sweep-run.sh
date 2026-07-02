#!/usr/bin/env bash
# sweep-run.sh — epic-close sweep orchestration: collect -> classify ->
# validate-candidates -> stage -> finalize -> report. Each phase is a
# SEPARATE invocation (`sweep-run.sh <phase> [args]`); state between phases
# lives in files under $TOUCHSTONE_LEDGER_DIR (or <git-toplevel>/.touchstone/ledger
# — same resolution as ledger-append.sh / the extractors, via cursor-lib.sh).
# See .touchstone/specs/2026-07-02-catch-attribution-ledger-design.md (REQ-6).
#
# Phases:
#   collect               runs extract-transcript.sh / extract-git.sh /
#                          extract-firelog.sh (each --propose-cursors, never
#                          committing scan-state directly) and
#                          extract-reckoning.sh (no cursor), concatenating
#                          their digest/v1 output into .digest.jsonl. A
#                          source is attempted only when its env var is set
#                          (LEDGER_TRANSCRIPTS_DIR / LEDGER_GIT_REPO /
#                          LEDGER_EPIC_DIR — firelog needs none, it reads
#                          $LDIR/fire-log.jsonl directly); an unset var means
#                          the source is not configured for this sweep and is
#                          silently skipped (not a failure). A CONFIGURED
#                          source whose extractor exits non-zero is the
#                          skip-and-report path: the source is skipped, the
#                          other sources proceed, ".sweep incomplete: <src>"
#                          is recorded for `report`.
#   classify               chunks .digest.jsonl into approx <=200KB pieces
#                          (line-safe; a single line is never split) and
#                          pipes each chunk through $LEDGER_L1_CMD (a shell
#                          command string run via `bash -c`), appending its
#                          candidate/v1 output to .candidates-log.jsonl —
#                          RETAINED (never deleted) as the inspectable
#                          per-run classification artifact.
#   validate-candidates    jq shape check over .candidates-log.jsonl:
#                          candidate/v1 shape, and — when is_miss:true —
#                          caught_by/should_have present and gap_class in the
#                          catch-miss/v1 enum. Any violation is an L1 STAGE
#                          FAILURE: non-zero exit, ".sweep incomplete: l1"
#                          recorded, no staging is created.
#   stage                  builds enriched candidates (is_miss:true lines
#                          from .candidates-log.jsonl, joined with their
#                          digest/v1 record by ref) and pipes them through
#                          $LEDGER_L2_CMD, capturing the result to
#                          .staging.jsonl. On $LEDGER_L2_CMD failure:
#                          .staging.jsonl is never left behind and
#                          ".sweep incomplete: l2" is recorded.
#   finalize                pipes .staging.jsonl into ledger-append.sh. On
#                          success: merges every .propose-<src>.json into
#                          scan-state.json (temp+mv, per cursor-lib.sh) and
#                          deletes .staging.jsonl + the propose files. On
#                          ANY failure (including ledger-append.sh's
#                          whole-batch schema rejection): .staging.jsonl is
#                          discarded and scan-state.json is left untouched —
#                          cursor commit happens ONLY after a successful
#                          append.
#   report                  prints sources consumed, every recorded
#                          "sweep incomplete: <x>" line, and entries.jsonl's
#                          line count + byte size.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/cursor-lib.sh"

LDIR="$(cursor_lib_resolve_ledger_dir sweep-run)" || exit 1
mkdir -p "$LDIR" || { echo "sweep-run: cannot create ledger dir $LDIR" >&2; exit 1; }

DIGEST_FILE="$LDIR/.digest.jsonl"
CANDIDATES_FILE="$LDIR/.candidates-log.jsonl"
STAGING_FILE="$LDIR/.staging.jsonl"
CONSUMED_FILE="$LDIR/.sweep-consumed"
INCOMPLETE_FILE="$LDIR/.sweep-incomplete"

GAP_CLASSES_JSON='["missing-AC","false-green","no-gate"]'

# run_source <name> <extract-cmd...> — runs an extractor, appends its
# stdout to DIGEST_FILE and its name to CONSUMED_FILE on success (exit 0);
# on non-zero exit, records the skip-and-report line and does neither.
run_source() {
  local name="$1"; shift
  local out rc
  out="$("$@" 2>"$LDIR/.collect-err-$name")"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "sweep incomplete: $name" >> "$INCOMPLETE_FILE"
    return 0
  fi
  [ -n "$out" ] && printf '%s\n' "$out" >> "$DIGEST_FILE"
  echo "$name" >> "$CONSUMED_FILE"
  return 0
}

collect() {
  # start-of-sweep-run bookkeeping: .candidates-log.jsonl is truncated HERE
  # (not preserved across separate sweep runs) so it stays in lockstep with
  # the freshly-truncated .digest.jsonl for stage()'s by-ref join — it is
  # still "RETAINED" relative to .staging.jsonl in the sense that matters
  # (never deleted mid-run, survives past finalize/report as the run's
  # inspectable classification artifact).
  : > "$DIGEST_FILE"
  : > "$CONSUMED_FILE"
  : > "$INCOMPLETE_FILE"
  : > "$CANDIDATES_FILE"
  rm -f "$LDIR"/.propose-*.json

  if [ -n "${LEDGER_TRANSCRIPTS_DIR:-}" ]; then
    run_source transcript "$SCRIPT_DIR/extract-transcript.sh" --dir "$LEDGER_TRANSCRIPTS_DIR" --propose-cursors "$LDIR/.propose-transcript.json"
  fi
  if [ -n "${LEDGER_GIT_REPO:-}" ]; then
    run_source git "$SCRIPT_DIR/extract-git.sh" --repo "$LEDGER_GIT_REPO" --propose-cursors "$LDIR/.propose-git.json"
  fi
  if [ -n "${LEDGER_EPIC_DIR:-}" ]; then
    run_source reckoning "$SCRIPT_DIR/extract-reckoning.sh" --epic-dir "$LEDGER_EPIC_DIR"
  fi
  run_source firelog "$SCRIPT_DIR/extract-firelog.sh" --propose-cursors "$LDIR/.propose-firelog.json"

  return 0
}

# chunk .digest.jsonl into approx <=200KB pieces (character-length
# approximation, not the byte-exact bound the fire-log atomicity contract
# uses — this is a dispatch-batching heuristic, never splitting a line) and
# pipe each chunk through $LEDGER_L1_CMD, appending candidate/v1 output.
classify() {
  [ -s "$DIGEST_FILE" ] || return 0
  : "${LEDGER_L1_CMD:?sweep-run classify: LEDGER_L1_CMD must be set}"

  local chunkdir; chunkdir="$(mktemp -d)"
  local chunk_idx=0 chunk_file="$chunkdir/chunk-0" chunk_bytes=0 line_bytes
  : > "$chunk_file"
  while IFS= read -r line || [ -n "$line" ]; do
    line_bytes=$(( ${#line} + 1 ))
    if [ "$chunk_bytes" -gt 0 ] && [ $((chunk_bytes + line_bytes)) -gt 200000 ]; then
      chunk_idx=$((chunk_idx + 1))
      chunk_file="$chunkdir/chunk-$chunk_idx"
      : > "$chunk_file"
      chunk_bytes=0
    fi
    printf '%s\n' "$line" >> "$chunk_file"
    chunk_bytes=$((chunk_bytes + line_bytes))
  done < "$DIGEST_FILE"

  local f
  for f in "$chunkdir"/chunk-*; do
    [ -s "$f" ] || continue
    bash -c "$LEDGER_L1_CMD" < "$f" >> "$CANDIDATES_FILE"
  done
  rm -rf "$chunkdir"
  return 0
}

validate_candidates() {
  [ -s "$CANDIDATES_FILE" ] || return 0
  local result rc
  result="$(jq -s --argjson gcs "$GAP_CLASSES_JSON" '
    [ .[] |
      ( .schema=="candidate/v1"
        and (.ref? != null) and ((.ref|type)=="string") and ((.ref|length)>0)
        and ( if .is_miss == true then
                ((.caught_by? // "")|length>0)
                and ((.should_have? // "")|length>0)
                and ((.gap_class // "") as $g | ($gcs | index($g)) != null)
              else true end )
      )
    ] | all
  ' "$CANDIDATES_FILE" 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ] || [ "$result" != "true" ]; then
    echo "sweep incomplete: l1" >> "$INCOMPLETE_FILE"
    return 1
  fi
  return 0
}

# build_enriched_candidates — is_miss:true lines from CANDIDATES_FILE,
# joined with their digest/v1 record (by ref) for source/ts/payload; the
# join is best-effort (a candidate whose digest record is no longer
# available falls back to a stub payload rather than failing the stage).
build_enriched_candidates() {
  jq -c -n \
    --slurpfile cands <(jq -c 'select(.is_miss==true)' "$CANDIDATES_FILE" 2>/dev/null) \
    --slurpfile dig <(cat "$DIGEST_FILE" 2>/dev/null) '
    ($dig | map({key: .ref, value: {source, ts, payload}}) | from_entries) as $dmap
    | $cands[]
    | . as $c
    | ($dmap[$c.ref] // {source:"unknown", ts:"", payload:{}}) as $d
    | {schema:"candidate-enriched/v1", ref:$c.ref, is_miss:true,
       caught_by:$c.caught_by, should_have:$c.should_have, gap_class:$c.gap_class,
       note:($c.note // null),
       source:$d.source, ts:$d.ts, payload:$d.payload}
  '
}

stage() {
  : "${LEDGER_L2_CMD:?sweep-run stage: LEDGER_L2_CMD must be set}"
  rm -f "$STAGING_FILE"

  local enriched
  enriched="$(build_enriched_candidates)"
  if [ -z "$enriched" ]; then
    : > "$STAGING_FILE"
    return 0
  fi

  local tmp="$STAGING_FILE.tmp"
  printf '%s\n' "$enriched" | bash -c "$LEDGER_L2_CMD" > "$tmp" 2>"$LDIR/.stage-err"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$tmp"
    echo "sweep incomplete: l2" >> "$INCOMPLETE_FILE"
    return 1
  fi
  mv "$tmp" "$STAGING_FILE"
  return 0
}

# merge_cursor_proposals — commits every .propose-<src>.json into
# scan-state.json's matching section (temp+mv, via cursor-lib.sh), reloading
# the on-disk state between commits since cursor_lib_commit_section writes
# directly rather than returning the merged state.
merge_cursor_proposals() {
  if [ -f "$LDIR/.propose-transcript.json" ]; then
    cursor_lib_commit_section "$LDIR" "$(cursor_lib_load_state "$LDIR")" transcripts "$(cat "$LDIR/.propose-transcript.json")"
  fi
  if [ -f "$LDIR/.propose-git.json" ]; then
    cursor_lib_commit_section "$LDIR" "$(cursor_lib_load_state "$LDIR")" git "$(cat "$LDIR/.propose-git.json")"
  fi
  if [ -f "$LDIR/.propose-firelog.json" ]; then
    cursor_lib_commit_section "$LDIR" "$(cursor_lib_load_state "$LDIR")" firelog "$(cat "$LDIR/.propose-firelog.json")"
  fi
}

finalize() {
  if [ ! -f "$STAGING_FILE" ]; then
    # nothing staged (stage phase never ran, or produced no incidents) —
    # nothing to append, nothing to commit.
    return 0
  fi
  local rc
  bash "$SCRIPT_DIR/ledger-append.sh" < "$STAGING_FILE" >"$LDIR/.finalize-out" 2>"$LDIR/.finalize-err"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$STAGING_FILE"
    echo "sweep incomplete: finalize" >> "$INCOMPLETE_FILE"
    return 1
  fi
  merge_cursor_proposals
  rm -f "$STAGING_FILE"
  rm -f "$LDIR"/.propose-*.json
  return 0
}

report() {
  local consumed=""
  if [ -s "$CONSUMED_FILE" ]; then
    consumed="$(tr '\n' ' ' < "$CONSUMED_FILE" | sed 's/ *$//')"
  fi
  echo "sources consumed: ${consumed:-none}"
  if [ -s "$INCOMPLETE_FILE" ]; then
    cat "$INCOMPLETE_FILE"
  fi
  local entries_file="$LDIR/entries.jsonl" count=0 bytes=0
  if [ -f "$entries_file" ]; then
    count="$(grep -c . "$entries_file" 2>/dev/null || true)"
    [ -n "$count" ] || count=0
    bytes="$(wc -c < "$entries_file" | tr -d ' ')"
  fi
  echo "entries: $count ($bytes bytes)"
  return 0
}

PHASE="${1:-}"
[ $# -gt 0 ] && shift

case "$PHASE" in
  collect) collect; exit $? ;;
  classify) classify; exit $? ;;
  validate-candidates) validate_candidates; exit $? ;;
  stage) stage; exit $? ;;
  finalize) finalize; exit $? ;;
  report) report; exit $? ;;
  *)
    echo "sweep-run: usage: sweep-run.sh <collect|classify|validate-candidates|stage|finalize|report>" >&2
    exit 1
    ;;
esac
