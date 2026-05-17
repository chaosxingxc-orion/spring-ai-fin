#!/usr/bin/env bash
# gate/lib/scan_cache.sh -- pre-scan shared file lists ONCE per gate run.
#
# Currently each gate rule independently invokes find(1) over the source tree.
# Several patterns repeat (e.g. find . -name module-metadata.yaml happens 5x).
# This file is sourced by the orchestrator before fanning out workers; it
# populates env vars listing every match for the common patterns. Workers then
# iterate the env var instead of re-running find.
#
# Authority: docs/governance/rules/rule-70.md (always-loaded budget) +
#            token-optimization wave Phase 2 / PR-E3.
#
# Patterns provided (subject to GATE_SCAN_CACHE_PATTERNS):
#   _SCAN_MODULE_METADATA   newline-separated paths to every module-metadata.yaml
#   _SCAN_ACTIVE_DOCS       newline-separated paths to every active *.md / *.yaml
#   _SCAN_MIGRATION_SQL     newline-separated paths to every Flyway V*.sql migration
#   _SCAN_AGENT_JAVA_MAIN   newline-separated paths to every agent-*/src/main/*.java
#   _SCAN_SHIPPED_ROWS      TSV from extract_shipped_rows.sh — one row per
#                           (capability, field, value); fields: shipped, impl,
#                           test, l2_doc, latest_delivery, tests_marker,
#                           tests_count. Consumed by Rules 7, 19, 24 (replaces
#                           their per-line printf|grep loops over the 1388-line
#                           architecture-status.yaml; saves ~25 min of CPU per
#                           gate run on Git Bash for Windows).
#
# Each var is empty if GATE_SCAN_CACHE_ENABLED=false OR the pattern is not in
# GATE_SCAN_CACHE_PATTERNS. Consumers MUST handle the empty case.

set -uo pipefail
export LC_ALL=C

if [[ -z "${GATE_REPO_ROOT:-}" ]]; then
  GATE_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
cd "$GATE_REPO_ROOT"

gate_scan_cache_populate() {
  local _enabled="${GATE_SCAN_CACHE_ENABLED:-true}"
  local _patterns="${GATE_SCAN_CACHE_PATTERNS:-module_metadata active_docs migration_sql agent_java_main}"

  export _SCAN_MODULE_METADATA=""
  export _SCAN_ACTIVE_DOCS=""
  export _SCAN_MIGRATION_SQL=""
  export _SCAN_AGENT_JAVA_MAIN=""
  export _SCAN_SHIPPED_ROWS=""

  [[ "$_enabled" != "true" ]] && return 0

  if [[ " $_patterns " == *" module_metadata "* ]]; then
    _SCAN_MODULE_METADATA=$(find . -maxdepth 3 -name module-metadata.yaml \
      -not -path './target/*' \
      -not -path './.claude/*' \
      -not -path './.git/*' \
      2>/dev/null | sort)
  fi

  if [[ " $_patterns " == *" active_docs "* ]]; then
    _SCAN_ACTIVE_DOCS=$(find . \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) \
      -not -path './target/*' \
      -not -path './.claude/*' \
      -not -path './.git/*' \
      -not -path './docs/archive/*' \
      -not -path './docs/v6-rationale/*' \
      -not -path './gate/log/*' \
      2>/dev/null | sort)
  fi

  if [[ " $_patterns " == *" migration_sql "* ]]; then
    _SCAN_MIGRATION_SQL=$(find . -path '*/src/main/resources/db/migration/V*.sql' \
      -not -path './target/*' \
      2>/dev/null | sort)
  fi

  if [[ " $_patterns " == *" agent_java_main "* ]]; then
    _SCAN_AGENT_JAVA_MAIN=$(find . -path '*/agent-*/src/main/java/*' -name '*.java' \
      -not -path './target/*' \
      2>/dev/null | sort)
  fi

  if [[ " $_patterns " == *" shipped_rows "* ]]; then
    if [[ -x "$GATE_REPO_ROOT/gate/lib/extract_shipped_rows.sh" ]]; then
      _SCAN_SHIPPED_ROWS=$(bash "$GATE_REPO_ROOT/gate/lib/extract_shipped_rows.sh" \
        "$GATE_REPO_ROOT/docs/governance/architecture-status.yaml" 2>/dev/null)
    fi
  fi

  export _SCAN_MODULE_METADATA _SCAN_ACTIVE_DOCS _SCAN_MIGRATION_SQL _SCAN_AGENT_JAVA_MAIN _SCAN_SHIPPED_ROWS
}

# Auto-populate when sourced (consumers can also call manually for re-scan).
gate_scan_cache_populate
