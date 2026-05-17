#!/usr/bin/env bash
# Quick fork-overhead benchmark. Runs N grep subshells and times the loop.
set -uo pipefail
N=${1:-1000}
T0=$(date +%s%N)
for ((i=0; i<N; i++)); do
  echo test | grep -q test
done
T1=$(date +%s%N)
elapsed_ms=$(( (T1 - T0) / 1000000 ))
echo "spawns=$N elapsed_ms=$elapsed_ms per_spawn_ms=$(awk -v t="$elapsed_ms" -v n="$N" 'BEGIN{printf "%.3f", t/n}')"
