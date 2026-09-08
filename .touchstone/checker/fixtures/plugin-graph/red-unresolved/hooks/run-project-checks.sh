#!/usr/bin/env bash
# fixture hook: runs .touchstone/checker/pre-commit/check-*.sh
for c in .touchstone/checker/pre-commit/check-*.sh; do bash "$c"; done
