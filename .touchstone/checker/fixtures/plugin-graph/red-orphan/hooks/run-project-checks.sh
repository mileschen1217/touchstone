#!/usr/bin/env bash
# shellcheck disable=SC2154  # root/stage set by the real hook's main(); this fixture only mirrors the glob shape
dir="$root/.touchstone/checker/$stage"
for chk in "$dir"/check-*.sh; do
  bash "$chk"
done
