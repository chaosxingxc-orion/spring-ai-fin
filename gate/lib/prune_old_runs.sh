#!/usr/bin/env bash
# gate/lib/prune_old_runs.sh -- retain only the N newest run directories.
#
# Invoked by gate/check_parallel.sh (and future PR-E5 orchestrator) at the END
# of a gate run, AFTER aggregate_summary has written summary.json:
#
#   bash gate/lib/prune_old_runs.sh
#
# Reads two env vars (loaded by gate/lib/load_config.sh from gate/config.yaml):
#   GATE_LOGGING_RETENTION_MAX_RUNS  int   -- keep last N (0 = unlimited, never prune)
#   GATE_LOGGING_RETENTION_AUTO_PRUNE bool -- "true" to prune at run end
#
# Sort strategy: modification time (newest first). On systems where stat(1)
# differs (GNU vs BSD), we use `ls -t` which is POSIX and portable.
#
# Authority: PR-E2 plan (gate-script efficiency wave) + CLAUDE.md Rule 10.

set -uo pipefail
export LC_ALL=C

_repo_root="${GATE_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RUNS_DIR="${GATE_LOG_RUNS_DIR:-${_repo_root}/gate/log/runs}"

_auto_prune="${GATE_LOGGING_RETENTION_AUTO_PRUNE:-true}"
_max_runs="${GATE_LOGGING_RETENTION_MAX_RUNS:-100}"

if [[ "$_auto_prune" != "true" ]]; then exit 0; fi
if ! [[ "$_max_runs" =~ ^[0-9]+$ ]]; then exit 0; fi
if [[ "$_max_runs" -le 0 ]]; then exit 0; fi
if [[ ! -d "$RUNS_DIR" ]]; then exit 0; fi

# Enumerate immediate subdirs of $RUNS_DIR newest-first by mtime, drop the
# first $_max_runs, delete the rest. `ls -1t` is POSIX-portable on git-bash
# + GNU + BSD. We do NOT use `find -printf` (BSD-incompatible).
mapfile -t _all_runs < <(ls -1t "$RUNS_DIR" 2>/dev/null | while IFS= read -r _name; do
  [[ -d "${RUNS_DIR}/${_name}" ]] && printf '%s\n' "$_name"
done)

_total="${#_all_runs[@]}"
if (( _total <= _max_runs )); then exit 0; fi

# Slice the tail past max_runs and remove.
for (( i = _max_runs; i < _total; i++ )); do
  _victim="${RUNS_DIR}/${_all_runs[i]}"
  rm -rf -- "$_victim" 2>/dev/null || true
done

exit 0
