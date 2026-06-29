#!/usr/bin/env bash
# persist-dispatch.sh — owned writer: persist a finished dispatch as a <run_id> codex+meta pair.
# Usage: persist-dispatch.sh (<raw_codex_path> | --no-codex [--fallback-reason <str>]) <collection_dir> <stage> <model> <started_at> <ended_at>
set -euo pipefail

raw=""; no_codex=0; fallback_reason=""
if [ "${1:-}" = "--no-codex" ]; then
  no_codex=1; shift
  if [ "${1:-}" = "--fallback-reason" ]; then fallback_reason="$2"; shift 2; fi
else
  raw="$1"; shift
fi
collection_dir="$1"; stage="$2"; model="$3"; started_at="$4"; ended_at="$5"

mkdir -p "$collection_dir"
run_id="$(date +%s%N)-$$-$RANDOM"

# Build the meta with jq so quoted / newline-containing stage|model|fallback_reason
# can never produce invalid JSON (no heredoc interpolation).
if [ "$no_codex" -eq 1 ]; then
  [ -z "$fallback_reason" ] && fallback_reason="cc-only fallback"
  jq -n --arg id "$run_id" --arg stage "$stage" --arg model "$model" \
        --arg s "$started_at" --arg e "$ended_at" --arg fb "$fallback_reason" \
    '{run_id:$id, codex_artifact_path:null, stage:$stage, model:$model,
      started_at:$s, ended_at:$e, providers_used:["cc"], fallback_reason:$fb}' \
    > "$collection_dir/$run_id.meta.json"
else
  cp "$raw" "$collection_dir/$run_id.codex.jsonl"
  jq -n --arg id "$run_id" --arg cp "$run_id.codex.jsonl" --arg stage "$stage" --arg model "$model" \
        --arg s "$started_at" --arg e "$ended_at" \
    '{run_id:$id, codex_artifact_path:$cp, stage:$stage, model:$model,
      started_at:$s, ended_at:$e, providers_used:["cc","codex"], fallback_reason:null}' \
    > "$collection_dir/$run_id.meta.json"
fi

# Emit the SOLE stdout hand-off record — exactly one line, no other stdout.
jq -nc --arg id "$run_id" --arg dir "$collection_dir" '{run_id:$id, collection_dir:$dir}'
