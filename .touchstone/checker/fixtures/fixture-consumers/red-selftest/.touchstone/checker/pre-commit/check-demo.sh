#!/usr/bin/env bash
# fixture — declares --self-test but the sibling run-smoke.sh never invokes it.
[ "${1:-}" = "--self-test" ] && exit 0
exit 0
