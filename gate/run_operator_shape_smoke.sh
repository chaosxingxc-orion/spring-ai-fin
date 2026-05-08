#!/usr/bin/env bash
# spring-ai-fin Rule 8 operator-shape smoke gate -- POSIX entry point.
#
# Per CLAUDE.md / AGENTS.md Rule 8 and
# docs/systematic-architecture-remediation-plan-2026-05-08-cycle-4.en.md sec-D1.
#
# Currently fails closed because the runnable artifact does not exist
# (W0 has not landed yet). When W0 produces the Maven multi-module + minimal
# Spring Boot, this script will be replaced with the real smoke flow:
#
#   1. build the runnable artifact (mvn -q package)
#   2. start a long-lived managed process
#   3. use real local Postgres
#   4. hit /health and /ready
#   5. perform N>=3 sequential POST /v1/runs
#   6. prove resource reuse + lifecycle observability
#   7. cancel a live run and drive it terminal (200)
#   8. cancel an unknown run -> 404
#   9. assert *_fallback_total == 0 on the happy path
#  10. write gate/log/operator-shape/<sha>.json with evidence_valid_for_delivery=true
#  11. write docs/delivery/<date>-<sha>.md
#
# Until then, the script writes a fail-closed artifact-missing log under
# gate/log/local/ (gitignored) and exits 1.
#
# There is NO --local-only mode for the operator-shape gate. Dirty trees are
# never valid Rule 8 evidence.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

sha_candidate="$(git rev-parse --short HEAD 2>/dev/null || echo no-git)"
[[ -z "$sha_candidate" ]] && sha_candidate=no-git

# Pre-W0: artifact missing. Probe once for clarity.
declare -a artifact_probes=(
  "pom.xml|no Maven build manifest at repo root"
  "agent-platform/pom.xml|no Maven build manifest under agent-platform/"
  "agent-runtime/pom.xml|no Maven build manifest under agent-runtime/"
  "agent-platform/src/main/java|no source tree under agent-platform/"
  "agent-runtime/src/main/java|no source tree under agent-runtime/"
)
missing_json=""
missing_count=0
for entry in "${artifact_probes[@]}"; do
  path="${entry%%|*}"
  reason="${entry##*|}"
  if [[ ! -e "$path" ]]; then
    if [[ -n "$missing_json" ]]; then missing_json+=","; fi
    missing_json+="{\"path\":\"$path\",\"reason\":\"$reason\"}"
    missing_count=$((missing_count + 1))
  fi
done

artifact_present=true
[[ $missing_count -gt 0 ]] && artifact_present=false

log_dir="gate/log/local"
mkdir -p "$log_dir"
log_path="$log_dir/operator-shape-${sha_candidate}-posix.json"

{
  printf '{'
  printf '"script":"run_operator_shape_smoke.sh",'
  printf '"version":"cycle-4-fail-closed",'
  printf '"kind":"operator_shape_smoke",'
  printf '"sha":"%s",' "$sha_candidate"
  printf '"generated":"%s",' "$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '"artifact_present":%s,' "$artifact_present"
  printf '"missing_artifacts":[%s],' "$missing_json"
  printf '"outcome":"FAIL_ARTIFACT_MISSING",'
  printf '"evidence_valid_for_delivery":false,'
  printf '"rule_8_evidence":false,'
  printf '"message":"Rule 8 operator-shape smoke gate fails closed: no runnable artifact exists yet. W0 deliverable per docs/plans/W0-evidence-skeleton.md. Architecture-sync evidence (gate/check_architecture_sync.*) does NOT substitute for Rule 8 evidence."'
  printf '}\n'
} > "$log_path"

echo "FAIL: operator-shape smoke gate has no runnable artifact (W0 deliverable). Log: $log_path" >&2
cat "$log_path"
exit 1
