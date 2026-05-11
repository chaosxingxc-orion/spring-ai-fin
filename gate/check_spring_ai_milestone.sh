#!/usr/bin/env bash
# spring-ai-ascend Spring AI milestone gate.
#
# Fails CI past 2026-08-01 if spring-ai.version still contains "-M"
# (milestone), forcing re-evaluation when Spring AI 2.0 GA ships.
#
# Exit 0: version is GA or date is before deadline.
# Exit 1: version is still milestone AND today >= 2026-08-01.

set -euo pipefail

DEADLINE="2026-08-01"
POM="pom.xml"

version=$(grep '<spring-ai\.version>' "$POM" 2>/dev/null | sed 's/.*<spring-ai\.version>\([^<]*\).*/\1/' | head -1 || true)

if [[ -z "$version" ]]; then
  echo "ERROR: could not find <spring-ai.version> in $POM" >&2
  exit 1
fi

echo "spring-ai.version=${version}"

if [[ "$version" != *"-M"* ]]; then
  echo "PASS: Spring AI version is GA (no -M suffix)."
  exit 0
fi

today=$(date +%Y-%m-%d 2>/dev/null || echo "0000-00-00")

if [[ "$today" < "$DEADLINE" ]]; then
  echo "INFO: Spring AI ${version} is a milestone; deadline ${DEADLINE} not yet reached (today=${today}). Allowed."
  exit 0
fi

echo "FAIL: Spring AI ${version} is a milestone and today (${today}) >= deadline ${DEADLINE}." >&2
echo "      Spring AI 2.0 GA is expected. Upgrade spring-ai.version to a GA release." >&2
exit 1
