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
| [0040](0040-w1-http-contract-reconciliation.md) | W1 HTTP contract reconciliation: X-Tenant-Id + JWT cross-check, PENDING initial status, POST /cancel | accepted |
| [0041](0041-active-corpus-truth-sweep.md) | Active-corpus truth sweep: archive stale plans, Gate Rule 15 deleted-plan-path freeze | accepted |
| [0042](0042-test-evidence-enforcement-for-rule-25.md) | Test-evidence enforcement for Rule 25: Gate Rule 19 shipped_row_tests_evidence | accepted |
| [0043](0043-active-normative-doc-catalog-and-peripheral-drift-prevention.md) | Active normative doc catalog and peripheral drift prevention: ACTIVE_NORMATIVE_DOCS + Gate Rules 20-23 | accepted |
| [0044](0044-spi-contract-precision-and-memory-metadata-reconciliation.md) | SPI contract precision and memory metadata reconciliation: RunContext interface, per-SPI scope, embeddingModelVersion | accepted |
| [0045](0045-shipped-row-evidence-path-existence-and-peripheral-wave-qualifier.md) | Shipped-row evidence path existence (Gate Rule 24) and peripheral wave-qualifier (Gate Rule 25): closes REF-DRIFT and PERIPHERAL-DRIFT patterns | accepted |
| [0046](0046-release-note-shipped-surface-truth.md) | Release-note shipped-surface truth (Gate Rule 26): closes GATE-SCOPE-GAP for `docs/releases/*.md` with four sub-checks (RunLifecycle name guard, RunContext method-list guard, OpenAPI test attribution, AppPostureGate scope guard) | accepted |
| [0047](0047-active-entrypoint-truth-and-system-boundary-prose-convention.md) | Active-entrypoint truth (Gate Rule 27, README baseline cross-check) + system-boundary prose convention (target-vs-W0 split in §1) + header-metadata convention (content-change-tracked, not re-review-tracked) | accepted |
| [0048](0048-service-layer-microservice-architecture-commitment.md) | Service-Layer Microservice-Architecture Commitment (§4 #46): Service Layer deployed as long-running microservices; Agent Bus traffic split locked at data-P2P / control-event-bus; SPI primitives remain serverless-friendly so W4+ migration stays open; serverless five-tier topology analysis archived as future direction; **amended** by ADR-0050 (heartbeats moved to Rhythm track) and narrowed by ADR-0049/0050/0051 | accepted |
| [0049](0049-c-s-dynamic-hydration-protocol.md) | C/S Dynamic Hydration Protocol and Cursor Handoff (§4 #47): TaskCursor + BusinessRuleSubset + SkillPoolLimit request; HydrationRequest envelope; SyncStateResponse / SubStreamFrame / YieldResponse handoff modes; ResumeEnvelope; degradation-authority red line (ComputeCompensation vs BusinessDegradationRequest; GoalMutationProhibition); closes whitepaper-alignment P0-2 + P1-2 | accepted |
| [0050](0050-workflow-intermediary-mailbox-rhythm-track.md) | Workflow Intermediary Bus, Mailbox Backpressure, and Rhythm Track (§4 #48): WorkflowIntermediary local supervisor; bus MUST NOT force-start computation; three-track cross-service bus with Rhythm RESTORED as independently protected channel; SleepDeclaration / WakeupPulse / TickEngine / ChronosHydration; amends ADR-0048 heartbeat placement; closes whitepaper-alignment P0-3 + P0-4 | accepted |
| [0051](0051-memory-knowledge-ownership-boundary.md) | Memory and Knowledge Ownership Boundary (§4 #49): C-side owned (business ontology) vs S-side owned (run trajectory) vs delegated; BusinessFactEvent + OntologyUpdateCandidate emission path; PlaceholderPreservationPolicy + SymbolicReturnEnvelope as first-class ship-blocking rule; ADR-0034 M3/M4/M5 split into platform-derived vs business-owned; closes whitepaper-alignment P0-5 | accepted |
| [0052](0052-skill-topology-scheduler-and-capability-bidding.md) | Skill Topology Scheduler and Capability Bidding (§4 #50): two-axis tenant×global arbitration; SkillResourceMatrix extended; CapabilityRegistry with tenant-scoped pre-authorization; BidRequest/BidResponse; PermissionEnvelope (subsumption-bounded, short-lived, signed); SkillSaturationYield releases LLM thread; closes whitepaper-alignment P1-1 | accepted |
| [0053](0053-cohesive-agent-swarm-execution.md) | Cohesive Agent Swarm Execution — Workflow Authority Invariant + SpawnEnvelope (§4 #51): SwarmRun / ParentRunRef / SwarmJoinPolicy aliases for existing types; SpawnEnvelope as consolidated 15-dimension parent→child propagation contract (1 W0 shipped, 5 partial, 7 W2 design gaps, 1 W1 deferred, 1 deferred); CrossWorkflowHandoff as explicit escape hatch; 5-boundary authority-transfer taxonomy; Envelope pattern codified; closes capability-labels reviewer P0 + class-based hidden defects | accepted |
| [0054](0054-long-connection-containment-runtime-handles.md) | Long-Connection Containment — Logical Runtime Handle Invariant (§4 #52): LogicalCallHandle ≡ Run+SuspendSignal; ConnectionLease alias for three-track + bus traffic split; AdmissionDecision and BackpressureSignal confirmed as canonical (reviewer-named LongCallAdmissionPolicy / ConnectionPressureSignal documented as aliases); SuspendInsteadOfHold as named principle; 3 W1+ deferred resource-explosion vectors (socket-per-tenant cap, file-descriptor bound, in-flight Runs pool cap); Netty/epoll explicitly NOT L0 contract | accepted |

## Process

New ADRs are proposed by opening a PR that adds a new file to this directory.
The file must use the MADR 4.0 template (see any existing ADR for reference).
ADR numbers are sequential; never reuse a number.
Superseded ADRs remain in the directory with Status: superseded, linking to the successor.

## References

- `ARCHITECTURE.md` sec-2 (OSS matrix)
- `docs/cross-cutting/contract-evolution-policy.md`
