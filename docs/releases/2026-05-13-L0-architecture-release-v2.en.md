# spring-ai-ascend L0 Architecture Release — 2026-05-13 (v2)

> **This note supersedes** `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md`. The v1 was published earlier on 2026-05-13 at SHA `82a1397` with a baseline of 45 §4 constraints / 47 ADRs / 27 gate rules / 30 self-tests. Subsequent same-day work (Service-Layer Microservice Commitment — ADR-0048, §4 #46; Whitepaper-Alignment Remediation — ADRs 0049/0050/0051/0052, §4 #47-#50, Gate Rules 28-29, +5 self-tests) materially shifted the architecture surface, so the L0 release note has been re-cut with the full current baseline and re-audited by six parallel reviewer agents. The v1 file is retained under `docs/archive/` for historical traceability per ADR-0043.

> Status: **L0 architecturally ready** (after multi-agent self-audit cycle — see Verification section for per-reviewer verdicts)
> Released: 2026-05-13
> Review cycles: 13 passes (2nd reviewer → post-seventh third-pass → L0 release-note contract review → L0 final entrypoint truth review → Service-Layer Microservice Commitment → Whitepaper-Alignment Remediation)
> Supersedes: v1 (archived)

---

## Executive Summary

The spring-ai-ascend W0 runtime kernel is architecturally ready for L0 release.

The architecture went through thirteen structured review cycles between 2026-05-12 and 2026-05-13, each cycle (a) categorising defects into named patterns, (b) doing systematic self-audits beyond the reviewer's named symptoms, and (c) landing gate-enforced structural prevention for each pattern class. The 4-shape defect model — **REF-DRIFT**, **HISTORY-PARADOX**, **PERIPHERAL-DRIFT**, **GATE-PROMISE-GAP** — plus the **GATE-SCOPE-GAP** shape codified in the tenth cycle is the canonical lens any future review must use. Each shape has a dedicated gate rule (Rules 16/22/24/25/26/27/28/29) that prevents recurrence.

Two major architectural commitments landed in the twelfth and thirteenth cycles:

- **Service-Layer Microservice Commitment (§4 #46, ADR-0048).** The Service Layer is deployed as long-running JVM microservices coordinating via an Agent Bus with locked data-P2P / control-event-bus / Rhythm-track traffic split. The W0 SPI primitives remain serverless-friendly so W4+ migration stays open; the commitment is at the deployment-topology level, not the SPI level. The whitepaper §1.3 microservice-dictatorship trap is mitigated by scoping microservice to the Service Layer (not per-agent) and routing inter-agent calls through the bus by intent.

- **Whitepaper-Alignment Remediation (§4 #47-#50, ADRs 0049/0050/0051/0052).** Four central whitepaper concepts are now named at L0 contract level: C/S Dynamic Hydration Protocol (ADR-0049 — `TaskCursor`, `BusinessRuleSubset`, `SkillPoolLimit`, `HydrationRequest`, `SyncStateResponse`, `SubStreamFrame`, `YieldResponse`, `ResumeEnvelope`); Workflow Intermediary + three-track cross-service bus with Rhythm restored (ADR-0050); Memory and Knowledge Ownership Boundary (ADR-0051 — C-Side business ontology vs S-Side trajectory with first-class `PlaceholderPreservationPolicy`); Skill Topology Scheduler and Capability Bidding (ADR-0052 — two-axis tenant×global arbitration).

The W0 kernel is intentionally small. W1–W4 capabilities are staged as design contracts (ADRs + `architecture-status.yaml` deferred rows), not premature implementation. Nothing that is not shipped at W0 is described as shipped.

---

## Architecture Baseline at Release

| Metric | Value |
|--------|-------|
| §4 constraints | 50 (#1–#50) |
| Active ADRs | 52 (ADR-0001–ADR-0052) |
| Active gate rules | 29 (PowerShell + bash parity) |
| Active engineering rules | 11 (Rules 1–6, 9–10, 20–21, 25) |
| Deferred engineering rules | 14 (with documented re-introduction triggers) |
| Gate self-test cases | 35 (covering Rules 1–6, 16, 19, 22, 24, 25, 26, 27, 28, 29) |
| Maven tests | 101+ (all GREEN) |

The four baseline counts above MUST match `docs/governance/architecture-status.yaml.architecture_sync_gate.allowed_claim` exactly. Gate Rule 28 (`release_note_baseline_truth`) cross-checks this at commit time.

---

## Capabilities Shipped at W0

### HTTP Edge (`agent-platform`)

| Capability | Description |
|-----------|-------------|
| `GET /v1/health` | Health probe — no auth required, exempt from tenant/idempotency filters |
| `TenantContextFilter` | Binds `X-Tenant-Id` header to `TenantContextHolder` + MDC `tenant_id`; reads header only at W0 (W1 adds JWT `tenant_id` claim cross-check against the header per ADR-0040) |
| `IdempotencyHeaderFilter` | Validates UUID shape of `Idempotency-Key` on POST/PUT/PATCH; returns 400 in research/prod on missing key; validation only at W0 (no dedup; W1 promotion per ADR-0027) |
| `WebSecurityConfig` | Permits `GET /v1/health` + `/actuator/**` + `/v3/api-docs` + `/v3/api-docs/**` (the OpenAPI snapshot IT needs the spec endpoint); requires auth on all other routes via `anyRequest().denyAll()` — deny-by-default returns 403 for unauthenticated requests per `PostureBindingIT`. Swagger UI is NOT permitted in W0 (W1 adds posture-aware UI exposure) |

### Runtime Kernel (`agent-runtime`)

| Capability | Description |
|-----------|-------------|
| `Run` entity + DFA | 7 statuses (PENDING, RUNNING, SUSPENDED, SUCCEEDED, FAILED, CANCELLED, EXPIRED); `RunStateMachine` validates every transition (Rule 20, ADR-0020) |
| Orchestration SPI | `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`, `Checkpointer`, `ExecutorDefinition`, `RunContext` — pure-Java SPIs (verified by `OrchestrationSpiArchTest`); no framework imports. `RunLifecycle` (cancel/resume/retry) remains design-only for W2 — see ADR-0020 |
| `RunContext` | Interface with canonical methods `runId()`, `tenantId()`, `checkpointer()`, `suspendForChild(parentNodeKey, childMode, childDef, resumePayload)`. Tenant identity is sourced from the runtime context, not from the HTTP ThreadLocal (Rule 21). Posture is not threaded through `RunContext` at W0 — posture is enforced via construction-time `AppPostureGate` calls in the in-memory components only |
| Dev-posture executors | `SyncOrchestrator`, `SequentialGraphExecutor`, `IterativeAgentLoopExecutor`, `InMemoryRunRegistry`, `InMemoryCheckpointer` — reference impls that fail-closed in research/prod via `AppPostureGate` |
| `AppPostureGate` (located in `agent-runtime`, package `ascend.springai.runtime.posture`) | Construction-time posture guard (ADR-0035, Rule 6 single-construction-path). Called by exactly three in-memory components — `SyncOrchestrator`, `InMemoryRunRegistry`, `InMemoryCheckpointer` — during construction to fail-closed in research/prod. Other runtime types do not receive posture as a parameter. The gate is not part of the HTTP edge module. |
| `ResilienceContract` + `YamlResilienceContract` | Per-operation resilience routing (operationId → (cbName, retryName, tlName)); Spring `@ConfigurationProperties` wiring is deferred to W2 LLM gateway |
| `GraphMemoryRepository` SPI scaffold | Interface only at W0; no adapter registers a bean. Graphiti REST reference adapter lands at W1 per ADR-0034 |
| `IdempotencyRecord` entity | Contract-spine entity with mandatory `tenantId` (Rule 11 target) |

### Contract and Guard Layer

| Capability | Description |
|-----------|-------------|
| OpenAPI v1 snapshot | `docs/contracts/openapi-v1.yaml` pinned. **Snapshot-diff enforcement lives in `OpenApiContractIT`** (via `OpenApiSnapshotComparator.compareResponseSchemas()`); the IT fails if the pinned snapshot diverges from the live spec at `/v3/api-docs`. `ApiCompatibilityTest` is ArchUnit-only — it enforces SPI purity and module-dep direction, not the OpenAPI diff |
| ArchUnit guards | `OrchestrationSpiArchTest` + `MemorySpiArchTest` (SPI purity: imports `java.*` only); `ApiCompatibilityTest` (no `com.alibaba.cloud.ai.*` imports + `agent-platform` → `agent-runtime` dep ban); `TenantPropagationPurityTest` (no HTTP ThreadLocal in runtime main sources) |
| Architecture-sync gate | 29 active rules on PowerShell + bash with byte-level parity; covers path existence (Rule 7/24), version pinning (Rule 8), route exposure (Rule 9), module dep direction (Rule 10), SPI contract truth, wave qualifiers, 4-shape defect patterns, release-note shipped-surface truth (Rule 26), active-entrypoint baseline truth (Rule 27), release-note baseline truth (Rule 28), whitepaper-alignment matrix presence (Rule 29) |

---

## Architectural Commitments (L0 contract level)

### Service-Layer Microservice Commitment (§4 #46, ADR-0048)

- `agent-platform` and `agent-runtime` are deployed as long-running JVM microservices.
- Multiple Agent Service instances coordinate via the **Agent Bus** (cross-docker, cross-service).
- **Bus traffic split (locked):** Data flow is **P2P** (gRPC streaming over mTLS or equivalent between instances — heavy LLM context, tool results, scraped documents never traverse a central broker). Control flow is on a **centralized event bus** (PAUSE/KILL/RESUME/UPDATE_CONFIG commands, scheduling, capability bidding — Kafka / NATS JetStream / Redpanda choice deferred to expanded ADR-0031). Heartbeats moved to Rhythm track per ADR-0050.
- The serverless future direction is archived at `docs/archive/2026-05-13-serverless-architecture-future-direction.md`; SPI primitives stay serverless-friendly so W4+ migration remains open.
- **Microservice-trap mitigation (whitepaper §1.3):** microservice for the Service Layer, NOT per-agent. Agents within an Agent Service instance are in-process; cross-instance coordination uses the bus by intent.

### C/S Dynamic Hydration Protocol (§4 #47, ADR-0049)

- C-Side holds lightweight `TaskCursor` + `BusinessRuleSubset` + `SkillPoolLimit`.
- S-Side hydrates a `HydrationRequest` into a `HydratedRunContext` and returns one of three handoff modes: `SyncStateResponse` (cursor advancement), `SubStreamFrame` (pass-through UI stream), `YieldResponse` (permission suspension; composes with sealed `SuspendReason`).
- C-Side resume occurs via `ResumeEnvelope`.
- `RunContext` is the internal S-Side execution context — NOT the C/S wire protocol.
- **Degradation authority red line:** S-Side MAY `ComputeCompensation` (substitute tools/models/routes) while preserving the C-Side task goal; S-Side MUST issue `BusinessDegradationRequest` (yield with reason + options) when same-quality completion is impossible. `GoalMutationProhibition` forbids S-Side reinterpretation/narrowing/broadening/replacing the C-Side task goal.
- Java types and wire bindings deferred to W2+; protocol named at L0 contract level.

### Workflow Intermediary + Three-Track Cross-Service Bus (§4 #48, ADR-0050)

- Every Agent Service instance hosts a local `WorkflowIntermediary` owning mailbox polling, local admission control, lease checks, and dispatch into in-process workers.
- **The bus MUST NOT force-start computation inside an Agent Service instance.** Admission decisions (`Accepted | Delayed | Rejected | Yielded`) are local; backpressure propagates via `BackpressureSignal`.
- Three physical tracks: **Track 1 Control** (event bus), **Track 2 Data/Compute** (P2P, pointer-based, never on broker), **Track 3 Rhythm** (independently protected — heartbeats, `SleepDeclaration`, `WakeupPulse`, `TickEngine` ticks, lease renewal, `ChronosHydration` triggers).
- The Rhythm track restores the whitepaper §5.2 design; ADR-0048's prior heartbeat placement on the control bus is amended.
- `ChronosHydration` end-to-end flow (whitepaper §5.4, runtime implementation deferred to W4): sleep declaration → snapshot durable → compute self-destruct → `TickEngine` evaluates condition → `WakeupPulse` on Rhythm track → local intermediary rehydrates. At L0 this is named at contract level only; Java types and the `TickEngine` scheduler implementation are W4 deliverables.

### Memory and Knowledge Ownership Boundary (§4 #49, ADR-0051)

- **C-Side owned (default):** business ontology, business entity state, user preferences, domain facts discovered during agent execution, business knowledge graph / DB.
- **S-Side owned:** run trajectory, token usage, model version + gateway telemetry, tool-call trace, retry/failure diagnostics, execution snapshots for resume, platform scheduling/quota/billing.
- **Shared/delegated memory** requires explicit `DelegationGrant` declaring `(tenantScope, retention, redactionState, visibilityScope, exportDeleteSemantics, placeholderPolicy)`.
- S-Side emits `BusinessFactEvent` / `OntologyUpdateCandidate` (with `proposalSemantics ∈ {HYPOTHESIS, OBSERVATION, INFERENCE}`) on Data track for C-Side consumption; S-Side MUST NOT directly write to C-Side knowledge graph.
- **`PlaceholderPreservationPolicy` (W3 ship-blocking; enforcement deferred to W3 per ADR-0051):** when C-Side passes placeholders (e.g. `[USER_ID_102]`), S-Side MUST preserve them verbatim through every LLM prompt, tool call, intermediate result, and final return. Results return via `SymbolicReturnEnvelope` with placeholders unchanged. At L0 the policy is contract-level only; runtime preservation against LLM paraphrasing is an open enforcement problem (placeholder detection, prompt-template insertion, post-LLM verification) and is W3 work — see ADR-0051 for the enforcement strategy.
- ADR-0034's M1–M6 memory taxonomy is split per row: M3/M4/M5 split into platform-derived operational memory (S-Side) vs business-owned ontology (C-Side default). `GraphMemoryRepository` is the platform SPI for M4; it is NOT the default owner of customer business ontology.

### Skill Topology Scheduler and Capability Bidding (§4 #50, ADR-0052)

- Two-axis arbitration: horizontal = **Tenant Quota** (per-tenant caps), vertical = **Global Skill Capacity** (cluster-wide caps per Skill).
- A Run hitting the vertical-axis cap yields only the dependent agent step via `SuspendSignal` with `SuspendReason.RateLimited` (`SkillSaturationYield`), releasing the LLM inference thread.
- `CapabilityRegistry` (extended — contract-level only at L0; Java implementation deferred to W2 per ADR-0052) — capability tags bound to domain permission identifiers; tenant-scoped pre-authorization; rejects with `Rejected(INSUFFICIENT_PERMISSION)` if the requesting tenant lacks the required identifier.
- **Capability bidding:** only pre-authorized delegates see `BidRequest`; non-authorized bidders silently dropped at the Registry. Bidders respond with `BidResponse(capacityAvailable, expectedStartTime, requiredSubstitutions[], confidence, costEstimate)`.
- `PermissionEnvelope` — short-lived, signed, subsumption-bounded; S-Side issues per-task action/tool permissions to the winning delegate; revokes on yield.

---

## Posture Defaults

`APP_POSTURE` environment variable, read once at boot via `AppPostureGate`:

| Posture | Behavior |
|---------|---------|
| `dev` (default) | Permissive — in-memory backends allowed; missing config emits WARN, not exception |
| `research` | Fail-closed — required config present or ISE; durable persistence expected |
| `prod` | Fail-closed — same as research; stricter enforcement planned for W2 |

`AppPostureGate.requireDevForInMemoryComponent(name)` is the **single construction-time read** of `APP_POSTURE` (Rule 6 single-construction-path; ADR-0035). It is called by three in-memory runtime components — `SyncOrchestrator`, `InMemoryRunRegistry`, `InMemoryCheckpointer` — during construction. Posture is **not** threaded through `RunContext` or passed as an argument to every runtime component.

---

## The 5-Shape Defect Model (canonical review lens)

The thirteen review cycles produced and refined a five-shape model. Every future architecture review MUST audit using these five shapes before declaring a cycle clean.

| Shape | Definition | Gate-enforced prevention |
|-------|-----------|--------------------------|
| **REF-DRIFT** | Shipped row points to a deleted/non-existent contract/file/test | Gate Rule 24 (`shipped_row_evidence_paths_exist`) + Gate Rule 7 + Gate Rule 19 |
| **HISTORY-PARADOX** | Document simultaneously active and historical; body stale; archived plans cited as active | Archive policy + ADR-0043 + Gate Rule 15 |
| **PERIPHERAL-DRIFT** | Central canonical file correct; module POM / README / Javadoc / BoM / contract-catalog still carries old claim | Gate Rule 25 (`peripheral_wave_qualifier`) + Rule 16a verb-class -cmatch |
| **GATE-PROMISE-GAP** | Gate regex matches 3 literal phrasings but misses the semantic *class* | PS `-cmatch` + bash `[[:space:]]`; per-verb self-tests for Rules 16a/19/22/24/25 |
| **GATE-SCOPE-GAP** | Truth-rule's pattern catalog correct but token catalog doesn't cover a sibling artefact class | Dedicated rules per artefact class — Rule 26 (release notes), Rule 27 (README), Rule 28 (release-note baselines), Rule 29 (whitepaper-alignment matrix) |

---

## Deferred Capabilities (by wave)

### W1 (next milestone)

| Capability | ADR / §4 |
|-----------|---------|
| `IdempotencyStore` dedup (moves from validation to deduplication) | ADR-0027 / §4 #4 |
| JWT `tenant_id` claim cross-check against `X-Tenant-Id` header (`TenantContextFilter`) | ADR-0040 / §4 #3 |
| Graphiti REST sidecar adapter (`spring-ai-ascend-graphmemory-starter`) | ADR-0034 / §4 #31 |
| Posture boot guard (startup fail on missing required config) | ADR-0006 / §4 #2 |
| Micrometer `tenant_id` tag propagation | ADR-0023 / §4 #22 |

### W2 (major capability expansion)

| Capability | ADR / §4 |
|-----------|---------|
| `PostgresCheckpointer` (durable run storage) | ADR-0021 / §4 #9 |
| `Skill` SPI + `ResourceMatrix` (4 enforceability tiers) | ADR-0030 + ADR-0038 / §4 #27, #35 |
| `RunDispatcher` + Control/Data/Heartbeat channel isolation (in-process) | ADR-0031 / §4 #28 |
| `PayloadCodec` SPI + `CausalPayloadEnvelope` write path | ADR-0022 + ADR-0028 / §4 #21, #25 |
| OTel `traceparent` cross-boundary propagation | ADR-0023 / §4 #22 |
| `SET LOCAL app.tenant_id` GUC + RLS policies | ADR-0005 / §4 #3 |
| C/S protocol Java types + wire format | ADR-0049 / §4 #47 |
| Workflow Intermediary + cross-service three-track bus | ADR-0050 / §4 #48 |
| Memory ownership types + `DelegationGrant` | ADR-0051 / §4 #49 |
| Skill Topology Scheduler runtime + bidding | ADR-0052 / §4 #50 |

### W3 (research-grade features)

| Capability | ADR / §4 |
|-----------|---------|
| `SandboxExecutor` SPI for `ActionGuard` Bound stage | ADR-0018 / §4 #27 |
| Graph DSL conformance (reducers, typed edges, JSON/Mermaid export) | §4 #17 |
| `PlaceholderPreservationPolicy` enforcement | ADR-0051 / §4 #49 |

### W4 (long-horizon)

| Capability | ADR / §4 |
|-----------|---------|
| Temporal Java SDK durable workflows | ADR-0003 / §4 #9 |
| Dev-time trace replay via MCP server | ADR-0017 |
| `RunPlanSheet` toolset + eval harness | ADR-0032 + §4 #18 |
| `ChronosHydration` runtime (sleep→self-destruct→wakeup→rehydrate) | ADR-0050 |

---

## Verification at Release

```
Maven:           101+ tests, 0 failures, 0 errors — BUILD SUCCESS
Gate (PS):       29/29 rules PASS — GATE: PASS (decision-level parity with bash)
Gate (bash):     29/29 rules PASS — GATE: PASS
Self-tests:      35/35 PASS
Reviewer audit:  six parallel agents — R1 Correctness, R2 Coherence, R3 Contract,
                  R4 Scope, R5 Adversarial, R6 Feasibility — iterated to convergence
                  on the verification commit (see docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r{1..6}.en.md
                  for per-reviewer verdicts and resolved findings).
```

All `shipped: true` capability rows in `docs/governance/architecture-status.yaml` have:
- resolvable `implementation:` paths (Gate Rule 7),
- resolvable `tests:` entries (Gate Rule 19),
- resolvable `l2_documents:` + `latest_delivery_file:` paths (Gate Rule 24).

This release note's text is validated for shipped-surface truth by Gate Rule 26 — `RunLifecycle`/`RunContext.posture()`/`ApiCompatibilityTest`-as-OpenAPI-snapshot/`AppPostureGate` placement+breadth overclaims are mechanically rejected before commit. The baseline counts above are validated against `architecture_sync_gate.allowed_claim` by Gate Rule 28.

---

## CI Hardening (JDK 21 + Spring Boot 4)

The following CI/build hardening landed alongside the architectural work and is verified by the IT suite (see `agent-platform/src/test/java/.../**IT.java`):

| Issue | Fix |
|-------|-----|
| RestAssured 5.5.0 NPE on JDK 21 system-proxy probe | Bumped to 5.5.2; later rewrote 5 ITs to JDK 21 `HttpClient` and dropped RestAssured |
| Groovy 5.0.4 transitive incompatibility | Pinned 5.0.6 in parent POM |
| Spring Cloud Vault autoconfig pulled in under Boot 4 | Disabled in `agent-platform/application.yml` (W0 doesn't use Vault) |
| Resilience4j SpringBoot3Verifier autoconfig under Boot 4 | Excluded in `agent-platform/application.yml` |
| Jackson `WRITE_DATES_AS_TIMESTAMPS` YAML enum casing | Use canonical SCREAMING_SNAKE_CASE enum constant name |
| Flyway autoconfig missing under Boot 4 | Added `spring-boot-starter-flyway` |
| Failsafe system-proxy probe hanging IT runs | Disabled |
| `PostureBindingIT` expectations after deny-by-default security | Updated to expect 403 |
| Dangling `agent-eval` references in `Dockerfile` | Removed (C31 module deleted; W4 timeline) |

None of the CI hardening changed runtime behaviour or contract surface. Architecture remained green throughout.

---

## Historical Cycle Summary (2026-05-12 → 2026-05-13)

| Phase | Focus | Mechanism landed |
|-------|-------|-----------------|
| 2nd reviewer + competitive analysis | Vocabulary, OSS stack, competitive positioning | Ascend-native vocab; 9 YAML rows; deferred Rules 18-19 |
| 3rd reviewer | Runtime correctness — lifecycle DFA, SPI tiers, context atomicity | `RunStateMachine` + EXPIRED; `TenantPropagationPurityTest`; Rules 20-21 |
| 4th reviewer | Contract drift in code — filter scope, speculative deps, API truth | `IdempotencyHeaderFilter` narrowed; Rule 25; first 10 gate rules |
| 5th reviewer | Payload and cognitive boundary | `CausalPayloadEnvelope`; Skill SPI; Rules 26-27 deferred |
| 6th + 7th reviewer | Posture enforcement and corpus authority | `AppPostureGate`; plans archived; single wave authority; Gate Rules 12-14 |
| Post-7th follow-up | HTTP contract consistency | W1 cross-check (not replace); PENDING start; POST /cancel; Gate Rules 15-18 |
| Post-7th 2nd pass | META pattern — active corpus drift | ACTIVE_NORMATIVE_DOCS catalog; test-evidence gate; Gate Rules 19-23 |
| Post-7th 3rd pass | 4-shape defect model canonised | Gate Rules 24-25; Rule 19/22 strengthened; bash cut-field fix |
| L0 v1 release | Final residual fix — Rule 16a widened | Rule 16a catches "switches-to-JWT" class; agent-platform README corrected |
| 10th — L0 release-note contract review | Release-note shipped-surface drift caught | ADR-0046 + Gate Rule 26 (`release_note_shipped_surface_truth`) with 4 sub-checks; §4 #44 |
| 11th — L0 final entrypoint truth review | Active-entrypoint drift caught: README baseline drift + system-boundary tense overreach | ADR-0047 + Gate Rule 27 (`active_entrypoint_baseline_truth`); §1 split target-vs-W0; §4 #45 |
| 12th — Service-Layer Microservice Commitment | Deployment-topology decision: microservice for Service Layer (not per-agent); data-P2P / control-event-bus split | ADR-0048; §4 #46; serverless analysis archived |
| 13th — Whitepaper-Alignment Remediation | Whitepaper concepts named at L0 contract level: C/S Dynamic Hydration; Workflow Intermediary + Rhythm; Memory Ownership Boundary; Skill Topology + Bidding | ADRs 0049/0050/0051/0052; §4 #47-#50; Gate Rules 28-29; +5 self-tests; whitepaper-alignment matrix at `docs/governance/whitepaper-alignment-matrix.md` |
| v2 release note + multi-agent self-audit | v1 superseded; six parallel reviewer agents (R1-R6) audit v2 to convergence | This document; reviewer reports under `docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r{1-6}.en.md` |

---

## Known Limitations

The following are known, intentional, and documented:

- **No production-tier durable storage**: `PostgresCheckpointer` and RLS policies are W2 (ADR-0021). The W0 dev-posture executors use in-memory state that does not survive restart.
- **`IdempotencyStore` is a `@Component` stub**: validates `Idempotency-Key` header format only; no deduplication at W0 (ADR-0027 — W1 promotion).
- **No runtime `GraphMemoryRepository` adapter**: `spring-ai-ascend-graphmemory-starter` registers no bean at W0; the Graphiti REST reference adapter lands at W1 (ADR-0034).
- **C/S protocol types, Workflow Intermediary, Memory Ownership types, Skill Topology Scheduler all design-only**: named at L0 contract level via ADRs 0049–0052 and §4 #47–#50; Java types and wire formats deferred to W2+ (W2/W3 per ADR).
- **Ops runbooks and Helm chart are skeletons**: not deployment-tested in this release; targeted for W1 hardening.
- **JMH performance baseline document exists**: no captured latency/throughput numbers at W0; W4 cadence.

---

## Migration from v1

v1 baseline → v2 baseline diff:

| Dimension | v1 (frozen 82a1397) | v2 (current) | Delta |
|-----------|---------------------|--------------|-------|
| §4 constraints | 45 | 50 | +5 (#46–#50 from ADRs 0048–0052) |
| Active ADRs | 47 | 52 | +5 (0048 Service Layer; 0049 C/S Hydration; 0050 Workflow Intermediary + Rhythm; 0051 Memory Ownership; 0052 Skill Topology) |
| Gate rules | 27 | 29 | +2 (Rule 28 `release_note_baseline_truth`; Rule 29 `whitepaper_alignment_matrix_present`) |
| Self-tests | 30 | 35 | +5 (Rule 28 pos/neg/no-freeze + Rule 29 coverage) |
| Active engineering rules | 11 | 11 | No change |
| Maven tests | 101 | 101+ | CI hardening preserved test count; deny-by-default IT updated |

**No regression vector.** Every v1 capability that was shipped is still shipped; every v1 deferral is still deferred (now with stronger ADR backing). The Service-Layer Microservice Commitment is a deployment-topology decision that does not alter the SPI surface; the whitepaper-alignment work is contract-level naming with implementation deferred.

---

## References

- `ARCHITECTURE.md` — full §4 constraint list (#1–#50)
- `docs/adr/README.md` — ADR index (0001–0052)
- `docs/governance/architecture-status.yaml` — capability status ledger with shipped evidence
- `docs/governance/whitepaper-alignment-matrix.md` — whitepaper concept traceability matrix (Rule 29)
- `docs/cross-cutting/posture-model.md` — posture matrix
- `gate/check_architecture_sync.ps1` + `gate/check_architecture_sync.sh` — 29 gate rules
- `gate/test_architecture_sync_gate.sh` — 35 self-tests
- `CLAUDE.md` — 11 active engineering rules + 14 deferred with re-introduction triggers
- `docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md` — thirteenth-cycle reviewer input
- `docs/reviews/2026-05-13-whitepaper-alignment-self-audit.en.md` — self-audit PASS report
- `docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r1.en.md` — R1 Correctness audit
- `docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r2.en.md` — R2 Coherence audit
- `docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r3.en.md` — R3 Contract audit
- `docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r4.en.md` — R4 Scope audit
- `docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r5.en.md` — R5 Adversarial audit
- `docs/reviews/2026-05-13-l0-v2-multi-agent-self-audit-r6.en.md` — R6 Feasibility audit
- `docs/adr/0046-release-note-shipped-surface-truth.md` — Gate Rule 26 + GATE-SCOPE-GAP closure
- `docs/adr/0047-active-entrypoint-truth-and-system-boundary-prose-convention.md` — Gate Rule 27 + CANONICAL-DRIFT closure
- `docs/adr/0048-service-layer-microservice-architecture-commitment.md` — §4 #46
- `docs/adr/0049-c-s-dynamic-hydration-protocol.md` — §4 #47 + Gate Rule 28
- `docs/adr/0050-workflow-intermediary-mailbox-rhythm-track.md` — §4 #48
- `docs/adr/0051-memory-knowledge-ownership-boundary.md` — §4 #49
- `docs/adr/0052-skill-topology-scheduler-and-capability-bidding.md` — §4 #50 + Gate Rule 29
- `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md` — v1, retained for traceability
- `docs/archive/2026-05-13-serverless-architecture-future-direction.md` — five-tier topology analysis (future direction)
