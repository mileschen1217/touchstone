#!/usr/bin/env bash
# sweep-run.sh — epic-close sweep orchestration: collect -> classify ->
# validate-candidates -> stage -> finalize -> report. Each phase is a
# SEPARATE invocation (`sweep-run.sh <phase> [args]`); state between phases
# lives in files under $TOUCHSTONE_LEDGER_DIR (or <git-toplevel>/.touchstone/ledger).
#
# Incremental scan state is a SINGLE timestamp: $LDIR/.last-sweep holds the
# collect-start time of the last sweep whose finalize succeeded. collect
# passes it to the extractors as --since (extract-git gets it shifted back
# by the pairing window so a new fix whose anchor predates the sweep still
# surfaces its chain); finalize promotes this run's collect-start stamp to
# .last-sweep ONLY after a successful append. Records re-emitted across
# sweeps (timestamp overlap is deliberate over-emission, never data loss)
# are deduped by ledger-append.sh's refs_overlap check.
#
# Phases:
#   collect               runs extract-transcript.sh / extract-git.sh /
#                          extract-firelog.sh / extract-reckoning.sh,
#                          concatenating their digest/v1 output into
#                          .digest.jsonl. A source is attempted only when its
#                          env var is set (LEDGER_TRANSCRIPTS_DIR /
#                          LEDGER_GIT_REPO / LEDGER_EPIC_DIR — firelog needs
#                          none, it reads $LDIR/fire-log.jsonl directly); an
#                          unset var means the source is not configured for
#                          this sweep — it is recorded in
#                          .sweep-skipped-unconfigured (not a failure) and
#                          `report` prints it as "sources skipped
#                          (unconfigured): <list>". A CONFIGURED source whose
#                          extractor exits non-zero is the skip-and-report
#                          path: the source is skipped, the other sources
#                          proceed, ".sweep incomplete: <src>" is recorded
#                          for `report`.
#   prefilter              deterministic recall-preserving pre-classify filter:
#                          drops only structurally-empty transcript records
#                          (blank text / bare slash-commands) into
#                          .prefilter-dropped.jsonl, leaving survivors in
#                          .digest-classify.jsonl; fail-open to the full digest;
#                          NEVER drops on "already-covered" (that is recurrence
#                          signal). A standalone phase so the epic-close
#                          procedure — which dispatches the L1 classifier as
#                          Agents, not via $LEDGER_L1_CMD — chunks the survivor
#                          file instead of the raw digest. classify() runs it
#                          internally too, so the script path needs no separate
#                          call.
#   classify               runs prefilter (above) then chunks the survivors
#                          into approx <=200KB pieces (line-safe; a single line
#                          is never split) and
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
#                          ledger-append.sh. On success: promotes this run's
#                          collect-start stamp to .last-sweep and deletes
#                          .staging.jsonl. On ANY failure (including
#                          ledger-append.sh's whole-batch schema rejection):
#                          .staging.jsonl is discarded and .last-sweep is
#                          left untouched — the timestamp advances ONLY
#                          after a successful append.
#   report                  prints sources consumed, sources skipped
#                          (unconfigured), every recorded "sweep incomplete:
#                          <x>" line, and entries.jsonl's line count + byte
#                          size.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "${TOUCHSTONE_LEDGER_DIR:-}" ]; then
  LDIR="$TOUCHSTONE_LEDGER_DIR"
else
  TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$TOPLEVEL" ]; then
    echo "sweep-run: not inside a git repo; set TOUCHSTONE_LEDGER_DIR" >&2
    exit 1
  fi
  LDIR="$TOPLEVEL/.touchstone/ledger"
fi
mkdir -p "$LDIR" || { echo "sweep-run: cannot create ledger dir $LDIR" >&2; exit 1; }

DIGEST_FILE="$LDIR/.digest.jsonl"
CLASSIFY_INPUT_FILE="$LDIR/.digest-classify.jsonl"
PREFILTER_LOG="$LDIR/.prefilter-dropped.jsonl"
CANDIDATES_FILE="$LDIR/.candidates-log.jsonl"
STAGING_FILE="$LDIR/.staging.jsonl"
CONSUMED_FILE="$LDIR/.sweep-consumed"
INCOMPLETE_FILE="$LDIR/.sweep-incomplete"
SKIPPED_FILE="$LDIR/.sweep-skipped-unconfigured"
LAST_SWEEP_FILE="$LDIR/.last-sweep"
STARTED_FILE="$LDIR/.sweep-started"

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
  : > "$CLASSIFY_INPUT_FILE"
  : > "$PREFILTER_LOG"
  : > "$CONSUMED_FILE"
  : > "$INCOMPLETE_FILE"
  : > "$CANDIDATES_FILE"
  : > "$SKIPPED_FILE"

  # stamp collect-start BEFORE scanning: records written while the sweep
  # runs land after this stamp, so the next sweep re-reads them (over-
  # emission is deduped; a later stamp would silently skip them).
  date -u +%Y-%m-%dT%H:%M:%SZ > "$STARTED_FILE"

  local since="" git_since=""
  if [ -f "$LAST_SWEEP_FILE" ]; then
    since="$(cat "$LAST_SWEEP_FILE")"
  fi
  if [ -n "$since" ]; then
    # extract-git's since is shifted back by the pairing window so a new fix
    # whose anchor predates the last sweep still surfaces its chain (the
    # already-swept portion of that chain dedupes on the git:<anchor> ref).
    git_since="$(jq -rn --arg t "$since" --argjson w "$((${LEDGER_GIT_WINDOW_DAYS:-14} * 86400))" \
      '$t | fromdateiso8601 - $w | todateiso8601' 2>/dev/null)"
    [ -n "$git_since" ] || git_since="$since"
  fi

  if [ -n "${LEDGER_TRANSCRIPTS_DIR:-}" ]; then
    if [ -n "$since" ]; then
      run_source transcript "$SCRIPT_DIR/extract-transcript.sh" --dir "$LEDGER_TRANSCRIPTS_DIR" --since "$since"
    else
      run_source transcript "$SCRIPT_DIR/extract-transcript.sh" --dir "$LEDGER_TRANSCRIPTS_DIR"
    fi
  else
    echo transcript >> "$SKIPPED_FILE"
  fi
  if [ -n "${LEDGER_GIT_REPO:-}" ]; then
    if [ -n "$git_since" ]; then
      run_source git "$SCRIPT_DIR/extract-git.sh" --repo "$LEDGER_GIT_REPO" --since "$git_since"
    else
      run_source git "$SCRIPT_DIR/extract-git.sh" --repo "$LEDGER_GIT_REPO"
    fi
  else
    echo git >> "$SKIPPED_FILE"
  fi
  if [ -n "${LEDGER_EPIC_DIR:-}" ]; then
    run_source reckoning "$SCRIPT_DIR/extract-reckoning.sh" --epic-dir "$LEDGER_EPIC_DIR"
  else
    echo reckoning >> "$SKIPPED_FILE"
  fi
  if [ -n "$since" ]; then
    run_source firelog "$SCRIPT_DIR/extract-firelog.sh" --since "$since"
  else
    run_source firelog "$SCRIPT_DIR/extract-firelog.sh"
  fi

  return 0
}

# prefilter_digest — deterministic, recall-preserving pre-classify filter.
# Drops ONLY structurally-empty transcript records: a user turn whose authored
# text is blank (a tool-result envelope) or a bare slash-command invocation
# (e.g. `/compact`). Neither can carry a describable gate-miss, so the drop
# cannot lose recall. It filters on STRUCTURE only — a record is NEVER dropped
# for looking "already covered", because a covered class re-appearing is
# recurrence signal insight reads. Non-transcript sources (git/reckoning/
# firelog) always pass — they are high-signal by construction. Survivors go to
# CLASSIFY_INPUT_FILE (what classify chunks); dropped records are logged to
# PREFILTER_LOG for audit. FAIL-OPEN: any jq error classifies the FULL digest
# (over-emit is safe; under-emit would silently lose a miss).
prefilter_digest() {
  local pred='(.source=="transcript") and (
      ((.payload.text // "") | gsub("^\\s+|\\s+$";"") | length) == 0
      or ((.payload.text // "") | test("^\\s*/[A-Za-z][A-Za-z0-9:_-]*\\s*$")) )'
  local tmp="$CLASSIFY_INPUT_FILE.tmp"
  if jq -c "select(($pred) | not)" "$DIGEST_FILE" > "$tmp" 2>/dev/null \
     && mv "$tmp" "$CLASSIFY_INPUT_FILE"; then
    # drop log is advisory (best-effort); its failure never blocks classify.
    jq -c "select($pred)" "$DIGEST_FILE" > "$PREFILTER_LOG" 2>/dev/null || : > "$PREFILTER_LOG"
    return 0
  fi
  # fail-open: pre-filter unavailable -> classify the WHOLE digest (over-emit is
  # safe; under-emit would silently lose a miss). If even the fallback copy
  # fails, fail CLOSED — record an l1 failure and return non-zero rather than
  # let classify build on a partial/empty survivor set. Recall is never lost
  # silently in either direction.
  rm -f "$tmp"
  : > "$PREFILTER_LOG"
  if ! cp "$DIGEST_FILE" "$CLASSIFY_INPUT_FILE"; then
    echo "sweep incomplete: l1" >> "$INCOMPLETE_FILE"
    return 1
  fi
  return 0
}

# prefilter phase — standalone entry point so the epic-close procedure (which
# chunks + dispatches the L1 classifier as Agents, not via classify()'s
# $LEDGER_L1_CMD) can run the SAME recall-preserving pre-filter and then chunk
# the survivor file $CLASSIFY_INPUT_FILE instead of the raw digest. classify()
# also calls prefilter_digest internally, so the script path stays self-
# contained; running this phase first is idempotent.
prefilter_phase() {
  if [ ! -s "$DIGEST_FILE" ]; then
    : > "$CLASSIFY_INPUT_FILE"; : > "$PREFILTER_LOG"
    echo "pre-filter: 0 classified, 0 dropped (empty digest)"
    return 0
  fi
  if ! prefilter_digest; then
    echo "pre-filter: FAILED — could not produce a survivor set; recorded 'sweep incomplete: l1'" >&2
    return 1
  fi
  local dropped kept
  dropped="$(grep -c . "$PREFILTER_LOG" 2>/dev/null || true)"; [ -n "$dropped" ] || dropped=0
  kept="$(grep -c . "$CLASSIFY_INPUT_FILE" 2>/dev/null || true)"; [ -n "$kept" ] || kept=0
  echo "pre-filter: $kept classified, $dropped dropped as non-signal (blank / bare-command transcript records)"
  return 0
}

# chunk the pre-filtered digest into approx <=200KB pieces (character-length
# approximation, not the byte-exact bound the fire-log atomicity contract
# uses — this is a dispatch-batching heuristic, never splitting a line) and
# pipe each chunk through $LEDGER_L1_CMD, appending candidate/v1 output.
classify() {
  [ -s "$DIGEST_FILE" ] || return 0
  : "${LEDGER_L1_CMD:?sweep-run classify: LEDGER_L1_CMD must be set}"

  # prefilter fails CLOSED only when it can neither filter nor fall back to the
  # full digest (it records the l1 line itself) — classifying a partial set is
  # never safe, so propagate the failure.
  prefilter_digest || return 1
  # an all-noise window leaves nothing to classify — a clean empty result,
  # not a failure (the L1 contract binds surviving records only).
  [ -s "$CLASSIFY_INPUT_FILE" ] || return 0

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
  done < "$CLASSIFY_INPUT_FILE"

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

finalize() {
  if prior_stage_failure l1 || prior_stage_failure l2; then
    echo "sweep-run finalize: refusing — a prior l1/l2 stage failure was recorded for this run" >&2
    return 1
  fi
  if [ ! -f "$STAGING_FILE" ]; then
    # nothing staged (stage phase never ran, or produced no incidents) —
    # nothing to append, nothing to advance.
    return 0
  fi
  local rc before after
  before="$(grep -c . "$LDIR/entries.jsonl" 2>/dev/null || true)"; [ -n "$before" ] || before=0
  bash "$SCRIPT_DIR/ledger-append.sh" < "$STAGING_FILE" >"$LDIR/.finalize-out" 2>"$LDIR/.finalize-err"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$STAGING_FILE"
    echo "sweep incomplete: finalize" >> "$INCOMPLETE_FILE"
    # failed finalize: nothing archived, .last-finalize/.last-sweep untouched.
    return 1
  fi
  after="$(grep -c . "$LDIR/entries.jsonl" 2>/dev/null || true)"; [ -n "$after" ] || after=0
  # raw-bundle retention — BEFORE the staging cleanup below: this run's
  # staging + L1 candidates log + a finalize-written summary (appended
  # count + this run's since bound). L1 input chunks are mktemp-local in
  # classify() and excluded by construction. ledger-append.sh has ALREADY
  # succeeded at this point, so a failure anywhere in this archival sequence
  # must fail closed WITHOUT touching .last-finalize/.last-sweep/cleanup —
  # staging stays put and the next finalize retries (re-extraction is
  # idempotent via the writer's dedupe, so a retry is safe).
  local run_ts runs_dir summary_rc archive_rc started
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
    # the pre-filter's dropped-record audit trail travels with the run bundle.
    if [ -f "$PREFILTER_LOG" ]; then
      cp "$PREFILTER_LOG" "$runs_dir/prefilter-dropped.jsonl" || archive_rc=1
    else
      : > "$runs_dir/prefilter-dropped.jsonl" || archive_rc=1
    fi
  fi

  if [ "$archive_rc" -eq 0 ]; then
    started="$(cat "$STARTED_FILE" 2>/dev/null || echo "")"
    jq -n --argjson appended "$((after - before))" \
      --arg since "$(cat "$LAST_SWEEP_FILE" 2>/dev/null || echo "")" \
      --arg started "$started" \
      '{schema:"sweep-run-summary/v1", appended:$appended, since:$since, collected_at:$started}' \
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
  # advance the single scan-state timestamp: next sweep's --since = this
  # run's collect-start. Promoted ONLY here (successful append + archive).
  if [ -s "$STARTED_FILE" ]; then
    cp "$STARTED_FILE" "$LAST_SWEEP_FILE"
  fi
  rm -f "$STAGING_FILE"
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
  if [ -f "$PREFILTER_LOG" ]; then
    local dropped kept
    dropped="$(grep -c . "$PREFILTER_LOG" 2>/dev/null || true)"; [ -n "$dropped" ] || dropped=0
    kept="$(grep -c . "$CLASSIFY_INPUT_FILE" 2>/dev/null || true)"; [ -n "$kept" ] || kept=0
    echo "pre-filter: $kept classified, $dropped dropped as non-signal (blank / bare-command transcript records)"
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
  prefilter) prefilter_phase; exit $? ;;
  classify) classify; exit $? ;;
  validate-candidates) validate_candidates; exit $? ;;
  stage) stage; exit $? ;;
  finalize) finalize; exit $? ;;
  report) report; exit $? ;;
  *)
    echo "sweep-run: usage: sweep-run.sh <collect|prefilter|classify|validate-candidates|stage|finalize|report>" >&2
    exit 1
    ;;
esac
