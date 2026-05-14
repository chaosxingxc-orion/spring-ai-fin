#!/usr/bin/env bash
# Thin bash wrapper around gate/build_architecture_graph.py.
#
# Exists so existing gate machinery (gate/check_architecture_sync.sh) can
# invoke "bash gate/build_architecture_graph.sh" without knowing whether the
# generator is Python, Go, or anything else.
#
# Authority: CLAUDE.md Rule 34, ADR-0068.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${SCRIPT_DIR}/build_architecture_graph.py"

if ! command -v python3 >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
  else
    echo "ERROR: python3 / python not on PATH" >&2
    exit 2
  fi
else
  PYTHON_BIN="python3"
fi

exec "${PYTHON_BIN}" "${PY}" "$@"
