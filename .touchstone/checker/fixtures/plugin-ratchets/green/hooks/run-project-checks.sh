#!/usr/bin/env bash
stage="pre-commit"
root="."
dir="$root/.touchstone/checker/$stage"
for chk in "$dir"/check-*.sh; do
  [ -e "$chk" ] || continue
  bash "$chk" || exit 1
done
