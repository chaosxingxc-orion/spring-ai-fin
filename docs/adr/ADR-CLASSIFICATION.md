---
level: L0
view: scenarios
status: active
authority: "ADR-0068 (Layered 4+1 + Architecture Graph)"
---

# ADR Classification — Level × View

This table is the canonical per-ADR `level:` + `view:` classification consumed by `gate/migrate_adrs_to_yaml.py` and `gate/build_architecture_graph.sh`. It is hand-maintained because the classification reflects intent (does this ADR govern a cross-module principle, or a per-module contract, or a feature detail?), not surface syntax.

When a new ADR is added, its row MUST be added here in the same PR (Rule 33, Gate Rule 37).

## Levels

- **L0** — cross-module governing principle / meta-rule about how the corpus is itself governed.
- **L1** — domain-or-module-level contract (per agent-platform / agent-runtime / a vertical / a cross-cutting filter chain).
- **L2** — feature-specific technical detail.

## Views

- **logical** — domain model, entity / status semantics, contract surface.
- **development** — package structure, dependency direction, naming, SPI purity.
- **process** — concurrency, async lifecycle, state machine, posture / boot guard, request-filter chain, body-of-request lifetime.
- **physical** — deployment topology, sandbox / OS-level isolation, storage placement.
- **scenarios** — cross-view golden-link; meta-governance about the corpus itself.

## Classification

| ID | Slug | Level | View | One-line decision |
|---|---|---|---|---|
| 0001 | java-21-spring-boot-runtime | L1 | development | Adopt Java 21 + Spring Boot 4 as platform runtime |
| 0002 | spring-ai-llm-gateway | L1 | logical | Spring AI ChatClient is the LLM gateway abstraction |
| 0003 | temporal-durable-workflows | L1 | process | Temporal owns durable orchestration at W3+ |
| 0004 | postgres-primary-data-store | L1 | physical | Postgres is the primary data store |
| 0005 | tenant-isolation-guc-set-local | L1 | physical | Postgres SET LOCAL app.tenant_id + RLS |
| 0006 | posture-model-dev-research-prod | L0 | process | Three-posture model dev/research/prod |
| 0007 | outbox-postgres-not-kafka | L1 | logical | Postgres outbox table, not Kafka, at W1-W3 |
| 0008 | resilience4j-circuit-breaker | L1 | process | Resilience4j for circuit breaking |
| 0009 | micrometer-observability | L1 | development | Micrometer + Prometheus metrics |
| 0010 | spring-security-oauth2 | L1 | process | Spring Security OAuth2 Resource Server |
| 0011 | structured-logging-logback-json | L1 | development | Logback JSON encoder + MDC |
| 0012 | testcontainers-postgres-integration | L1 | development | Testcontainers for Postgres ITs |
| 0013 | mcp-tools-server-stdio-only | L1 | physical | MCP server stdio-only at W3 |
| 0014 | run-id-uuidv7 | L1 | logical | UUIDv7 for run_id |
| 0015 | error-envelope-rfc7807 | L1 | logical | RFC 7807 problem+json error envelope |
| 0016 | dual-mode-runtime | L1 | process | Graph + AgentLoop dual-mode runtime |
| 0017 | mcp-only-telemetry-replay | L1 | logical | MCP-only replay surface; no admin UI |
| 0018 | sandbox-graalvm-polyglot | L1 | physical | GraalVM Polyglot for in-process sandbox at W3 |
| 0019 | competitive-positioning | L0 | scenarios | SAA + AS-Java competitive baseline framing |
| 0020 | run-state-machine-validator | L1 | process | RunStateMachine DFA validator |
| 0021 | tenant-propagation-purity | L1 | development | TenantContextHolder is HTTP-edge-only |
| 0022 | suspend-resume-checkpoint | L1 | process | Checkpointer owns suspend/resume |
| 0023 | cross-boundary-context-propagation | L1 | process | Tenant + trace + MDC + metric-tag carriers |
| 0024 | payload-envelope-codec | L1 | logical | CausalPayloadEnvelope + SemanticOntology |
| 0025 | architecture-text-truth | L0 | scenarios | Capability claims must point to real tests |
| 0026 | module-dependency-direction-contracts-split | L1 | development | agent-runtime does not depend on agent-platform |
| 0027 | tenant-column-required-in-migrations | L1 | logical | Every CREATE TABLE has tenant_id NOT NULL |
| 0028 | causal-payload-envelope-promotion | L1 | logical | Promote CausalPayloadEnvelope to L1 |
| 0029 | semantic-ontology-strictness | L1 | logical | SemanticOntology validation strictness |
| 0030 | suspension-write-atomicity | L1 | process | Suspension write atomicity tiers |
| 0031 | three-track-channel-isolation | L1 | physical | Control / data / rhythm three-track isolation |
| 0032 | scope-hierarchy-run-vs-session | L1 | logical | Run scope vs session scope hierarchy |
| 0033 | posture-aware-defaults | L0 | process | Posture-aware fail-closed defaults |
| 0034 | execution-locus-binding | L1 | process | Execution locus binding for orchestration |
| 0035 | wave-plan-authority | L0 | scenarios | Single canonical wave plan; archives banned |
| 0036 | app-posture-gate | L1 | process | AppPostureGate fail-closed at boot |
| 0037 | resource-isolation-pillars | L1 | physical | Resource-isolation pillar matrix |
| 0038 | active-normative-docs-catalog | L0 | scenarios | ACTIVE_NORMATIVE_DOCS shared enumerator |
| 0039 | release-note-baseline-truth | L0 | scenarios | Release notes carry baseline-truth tables |
| 0040 | jwt-tenant-claim-cross-check | L1 | process | JWT tenant_id claim cross-checked with header |
| 0041 | sealed-status-taxonomies | L1 | logical | Status taxonomies are sealed types |
| 0042 | meta-pattern-peripheral-lag | L0 | scenarios | META: peripheral entry-points lag central truth |
| 0043 | test-evidence-gate | L0 | scenarios | Rule 19 — test evidence must resolve |
| 0044 | peripheral-wave-qualifier | L0 | scenarios | Rule 25 — peripheral wave qualifier |
| 0045 | four-shape-defect-model | L0 | scenarios | REF-DRIFT / HISTORY-PARADOX / PERIPHERAL-DRIFT / GATE-PROMISE-GAP |
| 0046 | release-note-contract-review | L0 | scenarios | GATE-SCOPE-GAP for docs/releases/*.md |
| 0047 | l0-final-entrypoint-truth-review | L0 | scenarios | Active-entrypoint baseline truth gate |
| 0048 | service-layer-microservice-commitment | L1 | physical | Service Layer as long-running microservices |
| 0049 | c-s-dynamic-hydration-protocol | L1 | logical | TaskCursor / BusinessRuleSubset / HydrationRequest |
| 0050 | workflow-intermediary-mailbox-rhythm-track | L1 | process | Workflow intermediary + mailbox + rhythm |
| 0051 | memory-knowledge-ownership-boundary | L1 | logical | C-side ontology vs S-side trajectory |
| 0052 | skill-topology-scheduler-and-capability-bidding | L1 | process | Skill topology scheduler + capability bidding |
| 0053 | cohesive-agent-swarm-execution | L1 | process | Cohesive swarm execution + SpawnEnvelope |
| 0054 | long-connection-containment-runtime-handles | L1 | process | LogicalCallHandle + ConnectionLease |
| 0055 | permit-platform-to-runtime-direction | L1 | development | Generalised platform→runtime dep direction |
| 0056 | jwt-validation-and-tenant-claim-cross-check | L1 | process | Full JWT validation contract |
| 0057 | durable-idempotency-claim-replay | L1 | process | Durable idempotency claim + replay |
| 0058 | posture-boot-guard | L1 | process | PostureBootGuard + @RequiredConfig |
| 0059 | code-as-contract-architectural-enforcement | L0 | scenarios | Rule 28 — Code-as-Contract |
| 0060 | phase-l-reviewer-remediation | L1 | scenarios | Phase L reviewer P0/P1 closure |
| 0061 | telemetry-vertical-layer | L1 | process | Telemetry vertical as first-class layer |
| 0062 | trace-run-session-identity | L1 | logical | RunContext.traceId / spanId / sessionId |
| 0063 | client-sdk-observability-contract | L1 | development | springai-ascend-client observability contract |
| 0064 | layer-0-governing-principles | L0 | scenarios | Layer-0 P-A..P-D governing principles |
| 0065 | competitive-baselines | L0 | scenarios | Four pillars baseline.yaml |
| 0066 | independent-module-evolution | L0 | development | Per-module module-metadata.yaml |
| 0067 | spi-dfx-tck-codesign | L0 | development | SPI + DFX + TCK co-design |
| 0068 | layered-4plus1-and-architecture-graph | L0 | scenarios | Layered 4+1 + Graph as twin sources of truth |

## Cutover procedure

1. Review and refine `level:`/`view:` rows above (especially 0001–0018, which were assigned defaults).
2. Run `python3 gate/migrate_adrs_to_yaml.py --write` from the repo root. This emits sibling `.yaml` files for every `.md` ADR.
3. For each emitted YAML, hand-populate `supersedes:` / `extends:` / `relates_to:` by reading the original prose citations. (The script leaves these empty so no false edges are inserted.)
4. Run `bash gate/build_architecture_graph.sh` and fix any unresolved edges.
5. `git rm docs/adr/*.md` (leaves `docs/adr/*.yaml` and this README).
6. Update `docs/adr/README.md` to regenerate from the YAML corpus.
7. Run `bash gate/check_architecture_sync.sh` — Gate Rules 37, 38, 40 must pass.
