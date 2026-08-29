#!/usr/bin/env bash
# fixture — names fixtures/used so check-fixture-consumers.sh's rule (a) hits.
# It runs an unrelated script's --self-test, never the checker's, and never
# globs a checker stage dir — the defect this red fixture exercises.
echo "fixtures/used"
bash ./unrelated.sh --self-test
