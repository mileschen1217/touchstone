#!/usr/bin/env bash
# Simulates a worker killed before emitting output (SIGKILL, empty stdout).
kill -9 $$
