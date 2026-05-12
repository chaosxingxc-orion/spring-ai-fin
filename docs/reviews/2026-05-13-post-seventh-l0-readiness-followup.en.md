# Post-Seventh L0 Architecture Readiness Follow-up

Date: 2026-05-13

Audience: Architecture design team

Scope: post-seventh-review architecture corpus, including the seventh reviewer response, root and module `ARCHITECTURE.md` files, ADR-0032 through ADR-0039, contract documents, cross-cutting documents, status ledger, OpenAPI contract, and current Java code.

## Executive Verdict

Do not publish a clean L0 release note yet.

The seventh-review response fixed the most important previous design gaps. The core Java microservice and agent-runtime direction now looks substantially stronger: minimal planner naming exists, Skill SPI resource enforcement is tiered, payload migration has an adapter strategy, memory/knowledge taxonomy exists at L0, and `run_dispatcher_spi` is now tracked.

The remaining issues are narrower but still L0-relevant. They are mostly second-order drift introduced by the cleanup itself: active documents still reference archived plan files, the HTTP contract disagrees with the tenant identity model, the SPI contract catalog is still not a truthful list of active interfaces, and the sidecar/memory/knowledge story remains inconsistent across active manifests, BoM text, and JavaDoc.

## L0 Standard Applied

For this follow-up, L0 is release-note clean only if:

- active architecture documents do not point implementers to deleted or archived files as current authority;
- HTTP, OpenAPI, and platform architecture describe the same tenant, idempotency, route, status, and run-lifecycle semantics;
- the active SPI contract list matches actual Java interfaces and does not mix probes, starters, and SPIs under one label;
- memory/knowledge sidecar selection is consistent across root architecture, ADRs, BoM, third-party manifest, starter README, and JavaDoc;
- gates fail on the above truth violations instead of passing while active documents still drift.

## Root-cause Block

Observed failure: The seventh-review response claims L0 readiness is complete, but the active architecture corpus still contains false or conflicting contract references.

Execution path: A W1/W2 implementer reading `ARCHITECTURE.md`, `agent-runtime/ARCHITECTURE.md`, `docs/contracts/*`, `docs/cross-cutting/oss-bill-of-materials.md`, ADRs, or `third_party/MANIFEST.md` can still be routed to deleted plan files, obsolete headers, stale route shapes, deleted starter names, or not-selected sidecar implementations.

Root cause: The seventh-review fixes updated the central ADR/root/status layer faster than the remaining active companion docs and manifests; Gate Rules 12-14 are too narrow and allow stale active references outside `contract-catalog.md` and the specific `probe.check()` method-name case.

Evidence: see findings below.

## What Is Now Strong Enough

The following areas no longer look like L0 blockers:

- Dynamic planning: `PlanState` and `RunPlanRef` are named as minimal design contracts, and the false `planningEnabled(true)` activation contract was removed from the active status row.
- Skill design: CPU and memory limits are now classified as sandbox-enforceable, not generally enforceable for in-process VETTED Java skills.
- Payload evolution: ADR-0039 defines `Object -> Payload -> CausalPayloadEnvelope` and requires `PayloadAdapter.wrap(Object)` for migration.
- Streaming: `run_dispatcher_spi` exists in `architecture-status.yaml`, and ADR-0031 now says terminal events use a reserved terminal slot instead of a contradictory drop policy.
- Posture gating: `AppPostureGate.requireDevForInMemoryComponent(...)` exists and is called from `SyncOrchestrator`, `InMemoryRunRegistry`, and `InMemoryCheckpointer`.

These are good L0 design fixes. The remaining blockers are about corpus truth and boundary consistency.

## P1 Findings

### P1.1 - Active documents still reference archived or deleted wave-plan files

ADR-0037 says there is no other wave-authority document and that the originals under `docs/plans/` were deleted:

- `docs/adr/0037-wave-authority-consolidation.md:51-52`
- `docs/adr/0037-wave-authority-consolidation.md:56-69`

But active documents still point to the deleted paths:

- `agent-runtime/ARCHITECTURE.md:64` links to `docs/plans/engineering-plan-W0-W4.md`.
- `docs/plans/architecture-systems-engineering-plan.md:3-10` says it is a companion to the archived engineering plan and was last refreshed on 2026-05-08.
- `docs/cross-cutting/oss-bill-of-materials.md:310` still references `docs/plans/engineering-plan-W0-W4.md`.
- Active ADRs still reference `docs/plans/engineering-plan-W0-W4.md`, including ADR-0018, ADR-0019, ADR-0020, ADR-0024, ADR-0028, ADR-0030, and ADR-0031.

Why this blocks a clean L0 note:

The architecture now claims a single wave authority, but several active docs still send implementers to a deleted authority. This is a direct architecture-text truth problem.

Recommendation:

- Archive or refresh `docs/plans/architecture-systems-engineering-plan.md`.
- Replace active ADR references to `docs/plans/engineering-plan-W0-W4.md` with the archived path when the reference is historical, or with `ARCHITECTURE.md` + `architecture-status.yaml` + `docs/CLAUDE-deferred.md` when the reference is normative.
- Add a gate rule: active docs outside `docs/archive/` and `docs/reviews/` must not reference deleted `docs/plans/roadmap-W0-W4.md` or `docs/plans/engineering-plan-W0-W4.md`.

### P1.2 - W1 HTTP tenant and run contracts disagree across active documents

The platform architecture says W1 replaces `X-Tenant-Id` header extraction with JWT `tenant_id` claim validation:

- `agent-platform/ARCHITECTURE.md:34-35`
- `agent-platform/ARCHITECTURE.md:71-74`
- `ARCHITECTURE.md:149-154`

The HTTP contract and contract catalog still require `X-Tenant-Id` on planned W1 routes:

- `docs/contracts/contract-catalog.md:10`
- `docs/contracts/http-api-contracts.md:14`
- `docs/contracts/http-api-contracts.md:88`
- `docs/contracts/http-api-contracts.md:102`
- `docs/contracts/http-api-contracts.md:116`
- `docs/contracts/openapi-v1.yaml:54`

The same HTTP contract also says a new run starts in `CREATED` stage:

- `docs/contracts/http-api-contracts.md:92`

But the Java enum has no `CREATED`; W0 uses `PENDING` as the initial run status:

- `agent-runtime/src/main/java/ascend/springai/runtime/runs/RunStatus.java:3-5`
- `ARCHITECTURE.md:283-286`

There is also a planned route mismatch:

- `docs/contracts/http-api-contracts.md:110-120` describes `POST /v1/runs/{id}/cancel`.
- `docs/contracts/openapi-v1.yaml:54` says W1 will add `/v1/runs/{runId}` with `GET, DELETE`.

Why this blocks a clean L0 note:

The HTTP/API contract is a high-impact downstream contract. W1 implementers cannot tell whether tenant identity is header-based, JWT-claim-based, or both; nor whether cancel is `POST /cancel` or `DELETE /v1/runs/{id}`; nor whether the initial status is `CREATED` or `PENDING`.

Recommendation:

- Pick one W1 tenant model:
  - JWT `tenant_id` only; or
  - JWT `tenant_id` plus optional `X-Tenant-Id` cross-check; or
  - keep `X-Tenant-Id` through W1 and postpone replacement.
- Update `http-api-contracts.md`, `contract-catalog.md`, and `openapi-v1.yaml` to match the chosen model.
- Replace `CREATED` with `PENDING` unless a new enum value is intentionally added.
- Choose one cancel route shape and document it consistently.

### P1.3 - Contract catalog still does not truthfully describe active SPI interfaces

`docs/contracts/contract-catalog.md:16-28` says "5 active interfaces" and "Active SPI interfaces", but the table includes `OssApiProbe`, which is a classpath probe, not an SPI interface. The same table omits active orchestration SPI interfaces that exist in source:

- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/Orchestrator.java`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/GraphExecutor.java`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/AgentLoopExecutor.java`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/RunContext.java`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/ExecutorDefinition.java`

It also assigns `GraphMemoryRepository` to the `spring-ai-ascend-graphmemory-starter` module, but the interface lives in `agent-runtime`:

- `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java:14`
- `docs/contracts/contract-catalog.md:26`

Why this blocks a clean L0 note:

The contract catalog is explicitly labelled as the single source of truth for public contracts. It still mixes SPI interfaces, probes, implementations, starters, and modules.

Recommendation:

- Split the catalog into:
  - active SPI interfaces;
  - active contract records/classes;
  - probes/tests;
  - starters/adapters.
- Either list all active SPI interfaces or define a narrower term such as "public extension SPIs".
- Move `OssApiProbe` out of the SPI table.
- Put `GraphMemoryRepository` under `agent-runtime`; describe the graphmemory starter as the adapter shell.

### P1.4 - Memory/knowledge sidecar selection is still inconsistent

ADR-0034 and root architecture say Graphiti is the W1 reference sidecar, while mem0 and Cognee are not selected:

- `ARCHITECTURE.md:381-392`
- `docs/adr/0034-memory-and-knowledge-taxonomy-at-l0.md:76-81`
- `docs/cross-cutting/oss-bill-of-materials.md:248-251`

But active or referenced artifacts still carry older claims:

- `third_party/MANIFEST.md:30` says mem0 implements `LongTermMemoryRepository` via `spring-ai-ascend-mem0-starter`.
- `third_party/MANIFEST.md:33` says Docling implements `LayoutParser` via `spring-ai-ascend-docling-starter`.
- `third_party/MANIFEST.md:53` says Cognee and Graphiti are both evaluated and cycle 15 picks one.
- `docs/cross-cutting/oss-bill-of-materials.md:153` still says Docling is optional via `docling-starter SPI`.
- `docs/cross-cutting/oss-bill-of-materials.md:155-163` still describes a future `spring-ai-ascend-langchain4j-profile` starter, although LangChain4j dispatch is out of scope in `ARCHITECTURE.md:12`.
- `docs/cross-cutting/oss-bill-of-materials.md:303` still names Python sidecar version drift for mem0, Graphiti, and Docling.
- `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java:9-10` says Cognee is an evaluation alternative and cycle 15 selects one.
- `ARCHITECTURE.md:83` says the graphmemory starter is W2, while `docs/governance/architecture-status.yaml:94` says W1 wires the real Graphiti REST client.

Why this blocks a clean L0 note:

Memory and knowledge are agent-core architecture areas. The current corpus still looks like it may ship mem0, Graphiti, Cognee, Docling, and LangChain4j profile paths, while the refreshed L0 design says only Graphiti is selected as the W1 graph-memory reference sidecar and the deleted SPI/starters are not active.

Recommendation:

- Refresh `third_party/MANIFEST.md` or mark stale rows historical.
- Update `GraphMemoryRepository` JavaDoc to match ADR-0034.
- Remove `docling-starter`, `LongTermMemoryRepository`, `LayoutParser`, and `langchain4j-profile` language from active BoM text unless they are explicitly future research and gated by new ADRs.
- Normalize the graphmemory starter wave to W1 or W2 in root architecture, status ledger, and starter README.

## P2 Findings

### P2.1 - Root and module architecture comments still contain W0 truth drift

Examples:

- `ARCHITECTURE.md:41` labels `IdempotencyHeaderFilter` as "Idempotency-Key dedup", but W0 validation has no dedup and no store interaction (`ARCHITECTURE.md:158-160`, `agent-platform/ARCHITECTURE.md:41-45`).
- `ARCHITECTURE.md:42` labels `IdempotencyStore` as a "dev-posture in-memory store", but the implementation is an unregistered W0 stub, not a durable or in-memory store (`agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyStore.java:12-17`).
- `ARCHITECTURE.md:442` says `GET /v1/health` returns `{"status":"UP"}`, while OpenAPI and implementation require `status`, `sha`, `db_ping_ns`, and `ts` (`docs/contracts/openapi-v1.yaml:31-50`, `HealthEndpointIT` assertions).
- `agent-platform/ARCHITECTURE.md:86-94` says W0 shipped tests have no Testcontainers dependency, but `HealthEndpointIT` and `OpenApiContractIT` both use Testcontainers.

Recommendation:

- Treat comments in module-layout sections as contract text; keep them as strict as prose.
- Add gate coverage for known high-risk phrases such as "dedup" on the W0 idempotency filter.

### P2.2 - Gate Rule 13 and Rule 14 are useful but too narrow

The architecture sync gate currently passes all 14 rules, but it does not catch:

- active docs referencing deleted wave plans;
- HTTP contract disagreement between headers, route shape, and run status;
- `third_party/MANIFEST.md` references to deleted starters/SPIs;
- `contract-catalog.md` mixing `OssApiProbe` into "active SPI interfaces";
- root module-layout comments claiming dedup or wrong sidecar wave.

Recommendation:

- Add `no_active_refs_deleted_wave_plan_paths`.
- Add `http_contract_w1_tenant_and_cancel_consistency`.
- Add `contract_catalog_spi_table_matches_source`.
- Extend deleted SPI/starter-name checks to `third_party/MANIFEST.md`, active README files, and active cross-cutting docs, not only `contract-catalog.md`.

## Overdesign Assessment

The core post-seventh design is not overdesigned in the planning, skill, payload, or streaming areas. The new ADRs reduce ambiguity without forcing implementation early.

The remaining overdesign risk is in optional ecosystem scope. Keeping active text for LangChain4j profile, mem0, Cognee, Docling, Python sidecar drift, and deleted starter names makes the architecture look broader than the current L0 boundary. Either remove those from active docs or mark them explicitly as archived research inputs that require fresh ADRs before activation.

## Release Note Status

A clean L0 release note should wait until the P1 findings are resolved or explicitly deferred with non-normative wording.

After the fixes, a release note can safely say:

> L0 architecture baseline is accepted for spring-ai-ascend. The Java/Spring AI default runtime, HTTP surface, tenant/idempotency rules, run lifecycle DFA, orchestration SPI, posture model, planner/minimal memory taxonomy, Skill SPI resource tiers, payload migration path, and streaming dispatcher design are aligned across active architecture docs, ADRs, status ledger, OpenAPI contract, and current Java code. Deleted starters and archived plans are no longer referenced as active contracts.

