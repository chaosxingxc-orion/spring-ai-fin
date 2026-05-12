# Architecture-Code Consistency Feedback

Date: 2026-05-12  
Audience: Architecture design team  
Scope reviewed: root `ARCHITECTURE.md`, `agent-platform/ARCHITECTURE.md`, `agent-runtime/ARCHITECTURE.md`, and the current W0 implementation snippets.

## Executive Summary

The current architecture documents and implementation are not strictly aligned. The code compiles and the current architecture-sync gate passes, but the gate only checks a small set of syntactic corpus rules. It does not catch semantic contract drift between architecture text, Maven dependencies, HTTP filters, runtime ownership boundaries, and tests.

The highest-priority issue is not a missing feature; it is contract ambiguity. Several documents describe future W1/W2 behavior as if it were already implemented, while other documents correctly describe the W0 implementation. This creates conflicting source-of-truth claims for dependency direction, tenant isolation, idempotency, OpenAPI exposure, and runtime checkpoint ownership.

## Review Method

- Read the three active architecture files.
- Cross-checked the POMs, platform filters, runtime orchestration classes, persistence migration, and relevant tests.
- Ran the architecture-sync gate.
- Ran compile and unit tests for `agent-platform` and `agent-runtime`.

Verification commands:

```powershell
powershell -ExecutionPolicy Bypass -File gate\check_architecture_sync.ps1
.\mvnw.cmd -q -pl agent-platform,agent-runtime -DskipTests compile
.\mvnw.cmd -q -pl agent-platform,agent-runtime test
```

All three commands passed.

## Findings

### P1 - Runtime Checkpoint Ownership Contract Is Violated

Observed failure: The root architecture says the `Orchestrator` owns the `catch/checkpoint/dispatch/resume` loop and that executors do not persist. The implementation has both reference executors writing checkpoints directly.

Execution path: `NodeFunction` or `Reasoner` throws `SuspendSignal`; `SequentialGraphExecutor` or `IterativeAgentLoopExecutor` catches it and writes resume data through `ctx.checkpointer().save(...)`; `SyncOrchestrator` then catches the same signal and saves the suspended run.

Root cause statement: Checkpoint resume-position state is persisted inside executors at `SequentialGraphExecutor.java:44` and `IterativeAgentLoopExecutor.java:52`, which contradicts the architecture statement at `ARCHITECTURE.md:160-161` that the orchestrator owns checkpointing and executors do not persist.

Evidence:

- `ARCHITECTURE.md:158-161`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/Orchestrator.java:8-15`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SequentialGraphExecutor.java:44-49`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/IterativeAgentLoopExecutor.java:52-60`

Recommended resolution: Decide one ownership model and update both code and docs. If executors are allowed to persist executor-local resume cursors, the root architecture must say so explicitly and distinguish orchestrator-owned suspension records from executor-owned resume cursors. If the orchestrator must own all persistence, move checkpoint writes out of executors.

### P1 - Module Dependency Direction Is Documented Backwards Relative to Maven

Observed failure: The root architecture states `agent-platform -> SPI-only -> agent-runtime` and says there are no reverse imports. The `agent-runtime` Maven module currently depends on `agent-platform`.

Execution path: Maven builds `agent-runtime` with `agent-platform` on its classpath. `ApiCompatibilityTest` only enforces that platform classes do not depend on runtime classes; it does not enforce the claimed no-reverse-dependency rule at the Maven module level.

Root cause statement: `agent-runtime/pom.xml:18-25` imports the whole `agent-platform` module as a temporary W0 contract-layer substitute, while `ARCHITECTURE.md:91` and `ARCHITECTURE.md:126-127` still claim the opposite module direction.

Evidence:

- `ARCHITECTURE.md:88-92`
- `ARCHITECTURE.md:126-127`
- `agent-runtime/pom.xml:18-25`
- `agent-platform/src/test/java/ascend/springai/platform/api/ApiCompatibilityTest.java:37-44`

Recommended resolution: Either split `agent-platform/contracts` now, or document the W0 exception as an explicit temporary violation with an exit criterion. The architecture should not claim this is already enforced until a module-level dependency rule covers it.

### P1 - Idempotency Contract Overstates Implementation

Observed failure: The root and platform architecture files say `IdempotencyHeaderFilter` deduplicates requests, returns cached responses, handles concurrent duplicates, and prevents double side effects. The current filter only validates the header and never calls `IdempotencyStore`.

Execution path: `IdempotencyHeaderFilter` skips `/actuator` and `/v1/health`; otherwise it reads `Idempotency-Key`, validates UUID shape, and passes the request down the chain. It does not claim, replay, cache, or conflict-check idempotency records.

Root cause statement: The architecture merges future deduplication semantics with the current W0 header-validation filter, causing `ARCHITECTURE.md:139-141` and `agent-platform/ARCHITECTURE.md:38-42` to describe behavior not present in `IdempotencyHeaderFilter.java:31-60`.

Evidence:

- `ARCHITECTURE.md:139-141`
- `ARCHITECTURE.md:284-285`
- `agent-platform/ARCHITECTURE.md:36-42`
- `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilter.java:31-60`
- `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyStore.java:44-52`

Recommended resolution: Rename the W0 contract to header validation only, or wire the store into the filter and implement the documented dedup semantics. Also clarify method scope: the human API contract says idempotency is required on POST/PUT/PATCH routes, but the current filter applies to all non-exempt methods.

### P1 - Tenant Isolation Contract Mixes W0 Header Binding with Future JWT/GUC/RLS Behavior

Observed failure: `agent-platform/ARCHITECTURE.md` says `TenantContextFilter` reads the `tenant_id` JWT claim and propagates it into Postgres through `SET LOCAL app.tenant_id`. The implementation reads the `X-Tenant-Id` header, writes `TenantContextHolder`, and writes MDC. The database migration explicitly says tenant tables and RLS land later.

Execution path: Request enters `TenantContextFilter`; it reads `request.getHeader("X-Tenant-Id")`, validates UUID shape, then sets `TenantContextHolder` and MDC. No JWT claim is read and no transaction-scoped GUC is set.

Root cause statement: The module architecture describes future W1/W2 tenant isolation behavior at `agent-platform/ARCHITECTURE.md:30-34`, while the shipped implementation at `TenantContextFilter.java:42-77` implements W0 header binding only.

Evidence:

- `agent-platform/ARCHITECTURE.md:28-34`
- `ARCHITECTURE.md:133-137`
- `agent-platform/src/main/java/ascend/springai/platform/tenant/TenantContextFilter.java:42-77`
- `agent-platform/src/main/java/ascend/springai/platform/tenant/TenantConstants.java:5-6`
- `agent-platform/src/main/resources/db/migration/V1__init.sql:11`
- `docs/security/rls-policy.sql:1-3`

Recommended resolution: Split the tenant contract by shipped posture and wave. W0 should say header-based binding plus MDC correlation. W1 can introduce JWT claim validation. W2 can introduce GUC and RLS. Avoid wording that makes future isolation controls sound active today.

### P2 - W0 OpenAPI Exposure Contract Is Inconsistent

Observed failure: `agent-platform/ARCHITECTURE.md` says Swagger UI and `/v3/api-docs` are not exposed until W1. The implementation permits `/v3/api-docs`, and `OpenApiContractIT` depends on it returning 200.

Execution path: `WebSecurityConfig` permits `/v3/api-docs` and `/v3/api-docs/**`; `OpenApiContractIT` fetches `/v3/api-docs` and compares it with the pinned OpenAPI snapshot.

Root cause statement: The W0 OpenAPI snapshot gate was added after the module architecture statement, leaving `agent-platform/ARCHITECTURE.md:23-25` stale relative to `WebSecurityConfig.java:31-36` and `OpenApiContractIT.java:62-70`.

Evidence:

- `agent-platform/ARCHITECTURE.md:23-25`
- `agent-platform/src/main/java/ascend/springai/platform/web/WebSecurityConfig.java:31-36`
- `agent-platform/src/test/java/ascend/springai/platform/contracts/OpenApiContractIT.java:62-70`

Recommended resolution: Update the module architecture to say `/v3/api-docs` is exposed in W0 for contract verification, while Swagger UI remains blocked.

### P2 - Module-Level Dependency Version Tables Are Stale

Observed failure: The platform module architecture says Spring Boot `3.5.x`; runtime architecture says Spring AI `1.0.7 GA`, MCP `2.0.0-M2`, and Temporal `1.34.0`. The parent POM and dependency BOM use Spring Boot `4.0.5`, Spring AI `2.0.0-M5`, MCP `1.0.0`, and Temporal `1.35.0`.

Execution path: Maven version management comes from the parent POM. Module architecture files have independent version tables that drifted after dependency upgrades.

Root cause statement: Dependency versions are duplicated across architecture files instead of being sourced from the parent POM or the dependency BOM, causing `agent-platform/ARCHITECTURE.md:48` and `agent-runtime/ARCHITECTURE.md:17-19` to contradict `pom.xml:27-30` and `pom.xml:48-52`.

Evidence:

- `pom.xml:27-30`
- `pom.xml:48-52`
- `spring-ai-ascend-dependencies/pom.xml:105-112`
- `agent-platform/ARCHITECTURE.md:46-52`
- `agent-runtime/ARCHITECTURE.md:15-20`

Recommended resolution: Make the root POM or `spring-ai-ascend-dependencies/pom.xml` the only version source of truth. Module architecture files should either omit patch versions or point to the BOM instead of duplicating values.

## Gate Gap

The architecture-sync gate passed, but it currently checks only:

- status enum validity
- delivery log parity
- shell EOL policy
- CI masking of gate scripts
- required contract files
- Java metric naming prefix

It does not validate:

- POM module dependency direction against architecture diagrams
- architecture dependency version tables against POM properties
- shipped-test claims against actual test class names
- route exposure claims against `WebSecurityConfig`
- idempotency behavior claims against filter/store wiring
- runtime ownership claims against checkpoint write locations

Recommended next gate additions:

1. A module dependency rule that fails if POM dependency direction contradicts root architecture claims.
2. A dependency-version drift check that compares module architecture version tables to parent POM properties or forbids duplicated versions.
3. A shipped-test existence check for test names listed in architecture docs.
4. A W0/W1/W2 status vocabulary check so future behavior cannot be phrased as shipped behavior.
5. A runtime persistence ownership check, or at minimum a textual rule requiring explicit ownership wording when executors write through `Checkpointer`.

## Suggested Repair Order

1. Fix document truth first: mark W0 shipped behavior separately from W1/W2 planned behavior in `agent-platform/ARCHITECTURE.md` and `agent-runtime/ARCHITECTURE.md`.
2. Resolve the runtime checkpoint ownership model before implementing W2 persistence. This is the only finding that can directly compromise the suspension atomicity contract.
3. Resolve the module dependency direction claim by either splitting a contracts module or documenting the W0 exception.
4. Narrow the idempotency architecture wording to validation-only, unless deduplication is implemented now.
5. Update the architecture-sync gate so future drift is caught mechanically.

## Closing Note

The implementation is internally coherent for a W0 slice, and the tests pass. The problem is that the architecture corpus currently mixes shipped W0 facts with future W1/W2 target behavior. The repair should be treated as a source-of-truth cleanup, not as a broad rewrite of the implementation.
