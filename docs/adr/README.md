# Architecture Decision Records

> Owner: architecture | Format: MADR 4.0 | Last refreshed: 2026-05-13

This directory contains Architecture Decision Records (ADRs) for spring-ai-ascend.
Each ADR documents a significant architectural decision with its context,
options considered, decision, and consequences.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-java-21-spring-boot-runtime.md) | Java 21 + Spring Boot 4.0.5 as the runtime baseline | accepted |
| [0002](0002-spring-ai-llm-gateway.md) | Spring AI 2.0.0-M5 as the LLM gateway, not LangChain4j | accepted |
| [0003](0003-temporal-durable-workflows.md) | Temporal Java SDK 1.35.0 for durable workflows, not Airflow / Step Functions | accepted |
| [0004](0004-postgres-primary-data-store.md) | PostgreSQL 16 with RLS + pgvector, not separate vector DB | accepted |
| [0005](0005-tenant-isolation-guc-set-local.md) | Row-level security with SET LOCAL transaction-scoped GUC, not per-connection reset | accepted |
| [0006](0006-posture-model-dev-research-prod.md) | ActionGuard 5-stage chain (cycle-9 truth-cut), not 11-stage | accepted |
| [0007](0007-outbox-postgres-not-kafka.md) | At-least-once outbox in Postgres, not Kafka, for v1 | accepted |
| [0008](0008-resilience4j-circuit-breaker.md) | OPA sidecar for authorization, not in-process Cedar / custom | accepted |
| [0009](0009-micrometer-observability.md) | HashiCorp Vault (OSS) for secrets, not env vars / K8s Secrets only | accepted |
| [0010](0010-spring-security-oauth2.md) | Keycloak (OSS) as default IdP, but customer can BYO | accepted |
| [0011](0011-flyway-schema-migration.md) | Spring Cloud Gateway as ingress, not Kong / Traefik | accepted |
| [0012](0012-valkey-session-cache.md) | Maven multi-module, not Gradle | accepted |
| [0013](0013-vault-secrets-management.md) | UUIDv7 for surrogate IDs, not snowflake / sequence | accepted |
| [0014](0014-contract-spine-versioning-policy.md) | 3-posture model (dev/research/prod), not 5 or 2 | accepted |
| [0015](0015-layered-architecture-capability-model.md) | Defer multi-framework dispatch (Python sidecar, LangChain4j) to W4+ | accepted |
| [0016](0016-a2a-federation-strategic-deferral.md) | A2A federation strategic deferral: AgentCard + AgentRegistry reserved post-W4 | accepted |
| [0017](0017-dev-time-trace-replay.md) | Dev-time trace replay via MCP server (read-only, W4) | accepted |
| [0018](0018-sandbox-executor-spi.md) | SandboxExecutor SPI for ActionGuard Bound stage (W3) | accepted |
| [0019](0019-suspend-signal-and-suspend-reason-taxonomy.md) | SuspendSignal: checked-exception primitive + sealed SuspendReason taxonomy | accepted |
| [0020](0020-runlifecycle-spi-and-runstatus-formal-dfa.md) | RunLifecycle SPI separation + RunStatus formal DFA + transition audit | accepted |
| [0021](0021-layered-spi-taxonomy.md) | Layered SPI taxonomy: cross-tier core vs tier-specific adapters | accepted |
| [0022](0022-payload-codec-spi.md) | PayloadCodec SPI and typed payload contract | accepted |
| [0023](0023-cross-boundary-context-propagation.md) | Cross-boundary context propagation: tenant, trace, MDC, metric tags | accepted |
| [0024](0024-suspension-write-atomicity.md) | Suspension write atomicity: Checkpointer + RunRepository transactional contract | accepted |
| [0025](0025-checkpoint-ownership-boundary.md) | Checkpoint ownership boundary: executor resume cursors vs orchestrator Run row | accepted |
| [0026](0026-module-dependency-direction-contracts-split.md) | Module dependency direction: agent-platform-contracts split (W1) | accepted |
| [0027](0027-idempotency-scope-w0-header-validation.md) | Idempotency scope at W0: header validation only, dedup deferred to W1 | accepted |
| [0028](0028-causal-payload-envelope-and-semantic-ontology.md) | Causal payload envelope and semantic ontology (extension of ADR-0022) | accepted |
| [0029](0029-cognition-action-separation.md) | Cognition-Action separation principle: cognitive reasoning isolated from action execution | accepted |
| [0030](0030-skill-spi-lifecycle-resource-matrix.md) | Skill SPI: lifecycle (init/execute/suspend/teardown), ResourceMatrix, trust tiers | accepted |
| [0031](0031-three-track-channel-isolation.md) | Three-track channel isolation: Control / Data / Heartbeat + RunDispatcher SPI | accepted |
| [0032](0032-scope-based-run-hierarchy-and-planner-contract-minimal.md) | Scope-based run hierarchy (RunScope STEP_LOCAL/SWARM) + planner contract minimal (PlanState/RunPlanRef) | accepted |
| [0033](0033-logical-identity-equivalence-and-deployment-locus-vocabulary.md) | Logical Identity Equivalence: S-Cloud/S-Edge/C-Device deployment-locus vocabulary | accepted |
| [0034](0034-memory-and-knowledge-taxonomy-at-l0.md) | Memory and knowledge taxonomy at L0: 6 categories + common metadata schema | accepted |
| [0035](0035-posture-enforcement-single-construction-path.md) | Posture enforcement single-construction-path: AppPostureGate + posture-model.md as canonical ledger | accepted |
| [0036](0036-contract-surface-truth-generalization.md) | Contract-surface truth generalization: Gate Rules 13/14 for deleted-SPI and method-name drift | accepted |
| [0037](0037-wave-authority-consolidation.md) | Wave authority consolidation: archive stale plan docs, ARCHITECTURE.md is single wave authority | accepted |
| [0038](0038-skill-spi-resource-tier-classification.md) | Skill SPI resource tier classification: 4 enforceability tiers (hard/sandbox/advisory/hints) | accepted |
| [0039](0039-payload-migration-adapter-strategy.md) | Payload migration adapter strategy: Object → Payload → CausalPayloadEnvelope + adapter wrapper | accepted |

## Process

New ADRs are proposed by opening a PR that adds a new file to this directory.
The file must use the MADR 4.0 template (see any existing ADR for reference).
ADR numbers are sequential; never reuse a number.
Superseded ADRs remain in the directory with Status: superseded, linking to the successor.

## References

- `ARCHITECTURE.md` sec-2 (OSS matrix)
- `docs/cross-cutting/contract-evolution-policy.md`
