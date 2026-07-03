#!/usr/bin/env bash
# sweep-run.sh — epic-close sweep orchestration: collect -> classify ->
# validate-candidates -> stage -> finalize -> report. Each phase is a
# SEPARATE invocation (`sweep-run.sh <phase> [args]`); state between phases
# lives in files under $TOUCHSTONE_LEDGER_DIR (or <git-toplevel>/.touchstone/ledger
# — same resolution as ledger-append.sh / the extractors, via cursor-lib.sh).
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
#                          the source is not configured for this sweep — it
#                          is recorded in .sweep-skipped-unconfigured (not a
#                          failure) and `report` prints it as "sources
#                          skipped (unconfigured): <list>". A CONFIGURED
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
#                          per-run classification artifact. Every chunk
#                          invocation is checked two ways: its exit status,
#                          AND the count of lines it appended to
#                          .candidates-log.jsonl against the chunk's input
#                          line count (the L1 contract is one candidate line
#                          per input record, so any shortfall — including an
#                          exit-0-zero-output command — is a failure too). If
#                          ANY chunk fails either check, ".sweep incomplete:
#                          l1" is recorded and classify exits non-zero — the
#                          same L1 STAGE FAILURE outcome as a
#                          validate-candidates rejection below, so finalize's
#                          phase-sequencing guard refuses either way.
#   validate-candidates    jq shape check over .candidates-log.jsonl:
#                          candidate/v1 shape, and — when is_miss:true —
#                          caught_by/should_have present and gap_class in the
#                          catch-miss/v1 enum. Any violation is an L1 STAGE
#                          FAILURE: non-zero exit, ".sweep incomplete: l1"
#                          recorded, no staging is created.
#   stage                  refuses (non-zero exit, no staging) when this
#                          run's .sweep-incomplete already carries an "l1"
#                          entry — a phase-sequencing guard, not a new
#                          check: validate-candidates already failed this
#                          run, so its output is not safe to build on.
#                          Otherwise builds enriched candidates (is_miss:true
#                          lines from .candidates-log.jsonl, joined with
#                          their digest/v1 record by ref) and pipes them
#                          through $LEDGER_L2_CMD, capturing the result to
#                          .staging.jsonl. On $LEDGER_L2_CMD failure:
#                          .staging.jsonl is never left behind and
#                          ".sweep incomplete: l2" is recorded.
#   finalize                refuses (non-zero exit) when this run's
#                          .sweep-incomplete already carries an "l1" or "l2"
#                          entry (same phase-sequencing guard as stage).
#                          Otherwise pipes .staging.jsonl into
#                          ledger-append.sh. On success: merges every
#                          .propose-<src>.json into scan-state.json
#                          (temp+mv, per cursor-lib.sh) and deletes
#                          .staging.jsonl + the propose files. On ANY
#                          failure (including ledger-append.sh's
#                          whole-batch schema rejection): .staging.jsonl is
#                          discarded and scan-state.json is left untouched —
#                          cursor commit happens ONLY after a successful
#                          append.
#   report                  prints sources consumed, sources skipped
#                          (unconfigured), every recorded "sweep incomplete:
#                          <x>" line, and entries.jsonl's line count + byte
#                          size.
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
SKIPPED_FILE="$LDIR/.sweep-skipped-unconfigured"

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
  : > "$SKIPPED_FILE"
  rm -f "$LDIR"/.propose-*.json

  if [ -n "${LEDGER_TRANSCRIPTS_DIR:-}" ]; then
    run_source transcript "$SCRIPT_DIR/extract-transcript.sh" --dir "$LEDGER_TRANSCRIPTS_DIR" --propose-cursors "$LDIR/.propose-transcript.json"
  else
    echo transcript >> "$SKIPPED_FILE"
  fi
  if [ -n "${LEDGER_GIT_REPO:-}" ]; then
    run_source git "$SCRIPT_DIR/extract-git.sh" --repo "$LEDGER_GIT_REPO" --propose-cursors "$LDIR/.propose-git.json"
  else
    echo git >> "$SKIPPED_FILE"
  fi
  if [ -n "${LEDGER_EPIC_DIR:-}" ]; then
    run_source reckoning "$SCRIPT_DIR/extract-reckoning.sh" --epic-dir "$LEDGER_EPIC_DIR"
  else
    echo reckoning >> "$SKIPPED_FILE"
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

  local f rc had_failure=0 in_lines out_before out_after out_delta
  for f in "$chunkdir"/chunk-*; do
    [ -s "$f" ] || continue
    in_lines="$(grep -c . "$f" 2>/dev/null || true)"; [ -n "$in_lines" ] || in_lines=0
    out_before="$(grep -c . "$CANDIDATES_FILE" 2>/dev/null || true)"; [ -n "$out_before" ] || out_before=0
    bash -c "$LEDGER_L1_CMD" < "$f" >> "$CANDIDATES_FILE"
    rc=$?
    out_after="$(grep -c . "$CANDIDATES_FILE" 2>/dev/null || true)"; [ -n "$out_after" ] || out_after=0
    out_delta=$((out_after - out_before))
    # the L1 contract is one candidate line per input record — an exit-0
    # command that appends fewer lines than it was given is a shortfall
    # (including the zero-output case), same failure class as a non-zero rc.
    if [ "$rc" -ne 0 ] || [ "$out_delta" -lt "$in_lines" ]; then
      had_failure=1
    fi
  done
  rm -rf "$chunkdir"
  if [ "$had_failure" -ne 0 ]; then
    echo "sweep incomplete: l1" >> "$INCOMPLETE_FILE"
    return 1
  fi
  return 0
}

# prior_stage_failure <label> — true when this run's INCOMPLETE_FILE
# already carries "sweep incomplete: <label>" (phase-sequencing guard for
# stage/finalize: a prior l1/l2 failure means their input is not safe to
# build on).
prior_stage_failure() {
  [ -s "$INCOMPLETE_FILE" ] && grep -qxF "sweep incomplete: $1" "$INCOMPLETE_FILE"
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
  if prior_stage_failure l1; then
    echo "sweep-run stage: refusing — validate-candidates (l1) failed for this run; fix and re-run validate-candidates first" >&2
    return 1
  fi
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
  if prior_stage_failure l1 || prior_stage_failure l2; then
    echo "sweep-run finalize: refusing — a prior l1/l2 stage failure was recorded for this run" >&2
    return 1
  fi
  if [ ! -f "$STAGING_FILE" ]; then
    # nothing staged (stage phase never ran, or produced no incidents) —
    # nothing to append, nothing to commit.
    return 0
  fi
  local rc before after
  before="$(grep -c . "$LDIR/entries.jsonl" 2>/dev/null || true)"; [ -n "$before" ] || before=0
  bash "$SCRIPT_DIR/ledger-append.sh" < "$STAGING_FILE" >"$LDIR/.finalize-out" 2>"$LDIR/.finalize-err"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$STAGING_FILE"
    echo "sweep incomplete: finalize" >> "$INCOMPLETE_FILE"
    # failed finalize: nothing archived, .last-finalize untouched.
    return 1
  fi
  after="$(grep -c . "$LDIR/entries.jsonl" 2>/dev/null || true)"; [ -n "$after" ] || after=0
  # raw-bundle retention — BEFORE the staging/propose cleanup below: this
  # run's staging + L1 candidates log + a finalize-written summary (appended
  # count + cursor movements). L1 input chunks are mktemp-local in classify()
  # and excluded by construction. ledger-append.sh has ALREADY succeeded at
  # this point, so a failure anywhere in this archival sequence must fail
  # closed WITHOUT touching .last-finalize/cursors/cleanup — staging + the
  # propose files stay put and the next finalize retries (re-extraction is
  # idempotent via the writer's dedupe, so a retry is safe).
  local run_ts runs_dir cursors cursors_rc summary_rc archive_rc
  run_ts="$(date -u +%Y%m%dT%H%M%SZ)"
  runs_dir="$LDIR/runs/$run_ts"
  archive_rc=0

  mkdir -p "$runs_dir" || archive_rc=1

  if [ "$archive_rc" -eq 0 ]; then
    cp "$STAGING_FILE" "$runs_dir/staging.jsonl" || archive_rc=1
  fi

  if [ "$archive_rc" -eq 0 ]; then
    if [ -f "$CANDIDATES_FILE" ]; then
      cp "$CANDIDATES_FILE" "$runs_dir/candidates-log.jsonl" || archive_rc=1
    else
      : > "$runs_dir/candidates-log.jsonl" || archive_rc=1
    fi
  fi

  if [ "$archive_rc" -eq 0 ]; then
    cursors="$(jq -n \
      --argjson t "$(cat "$LDIR/.propose-transcript.json" 2>/dev/null || echo null)" \
      --argjson g "$(cat "$LDIR/.propose-git.json" 2>/dev/null || echo null)" \
      --argjson f "$(cat "$LDIR/.propose-firelog.json" 2>/dev/null || echo null)" \
      '{transcripts:$t, git:$g, firelog:$f}')"
    cursors_rc=$?
    [ "$cursors_rc" -eq 0 ] && [ -n "$cursors" ] || archive_rc=1
  fi

  if [ "$archive_rc" -eq 0 ]; then
    jq -n --argjson appended "$((after - before))" --argjson cursors "$cursors" \
      '{schema:"sweep-run-summary/v1", appended:$appended, cursor_movements:$cursors}' \
      > "$runs_dir/summary.json"
    summary_rc=$?
    [ "$summary_rc" -eq 0 ] && [ -s "$runs_dir/summary.json" ] || archive_rc=1
  fi

  if [ "$archive_rc" -ne 0 ]; then
    echo "sweep-run finalize: archive failed — staging retained" >&2
    echo "sweep incomplete: archive" >> "$INCOMPLETE_FILE"
    rm -rf "$runs_dir"
    return 1
  fi

  # freshness stamp: written ONLY on a successful finalize; report.sh sources
  # freshness solely from this file.
  date -u +%Y-%m-%dT%H:%M:%SZ > "$LDIR/.last-finalize"
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
  if [ -s "$SKIPPED_FILE" ]; then
    echo "sources skipped (unconfigured): $(tr '\n' ' ' < "$SKIPPED_FILE" | sed 's/ *$//')"
  fi
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
  if [ -d "$LDIR/runs" ]; then
    echo "runs/: $(du -sk "$LDIR/runs" 2>/dev/null | awk '{print $1 "KB"}')"
  else
    echo "runs/: none"
  fi
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
