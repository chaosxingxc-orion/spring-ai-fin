# R3 Contract Surface Audit of L0 v2 Release Note
Date: 2026-05-13
Reviewer: api-contract-reviewer (compound-engineering)
Input: docs/releases/2026-05-13-L0-architecture-release-v2.en.md

## Verdict
PASS-WITH-OBSERVATIONS

## Findings

### Finding 1 — WebSecurityConfig permit-list narrower than reality
- Severity: P3
- Defect category: scope-overclaim (under-claim direction)
- 4-shape label: PERIPHERAL-DRIFT
- Observed: v2 line 53 — "`WebSecurityConfig` | Permits `GET /v1/health`; requires auth on all other routes (deny-by-default returns 403 for missing credentials per `PostureBindingIT`)"
- Reality on disk: `agent-platform/src/main/java/ascend/springai/platform/web/WebSecurityConfig.java:30-37` actually permits four matchers: `/v1/health`, `/actuator/**`, `/v3/api-docs`, `/v3/api-docs/**`. Only the last three are unmentioned. `/v3/api-docs` exposure is required by `OpenApiContractIT` per the same source file's javadoc (lines 13-18).
- Root cause: The row's "Permits `GET /v1/health`" is under-stated; the actual permit-list is the minimum surface needed for ops probe + OpenAPI contract IT. The deny-by-default claim is still correct for all other routes.
- Fix proposal: Replace cell text with: "Permits `GET /v1/health`, `/actuator/**`, `/v3/api-docs`, `/v3/api-docs/**`; denies all other routes by default (returns 403 for missing credentials per `PostureBindingIT`)."

## Verification Matrix (all primary contract claims confirmed)

| v2 claim | Source-of-truth file | Verdict |
|----------|---------------------|---------|
| `RunContext` methods = {`runId`, `tenantId`, `checkpointer`, `suspendForChild(parentNodeKey, childMode, childDef, resumePayload)`} | `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/RunContext.java:18-36` | EXACT MATCH. No `posture()` method present. Gate Rule 26b not violated. |
| Orchestration SPI types = {`Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`, `Checkpointer`, `ExecutorDefinition`, `RunContext`} | `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/` (7 files) | EXACT MATCH. All 7 files exist; none extra. |
| `RunStatus` = 7 values `{PENDING, RUNNING, SUSPENDED, SUCCEEDED, FAILED, CANCELLED, EXPIRED}` | `agent-runtime/src/main/java/ascend/springai/runtime/runs/RunStatus.java:3-5` | EXACT MATCH. Seven values, no more, no less. |
| `AppPostureGate.requireDevForInMemoryComponent` callers = {`SyncOrchestrator`, `InMemoryRunRegistry`, `InMemoryCheckpointer`} | grep over `agent-runtime/src/main/java` returns exactly 3 hits: `InMemoryRunRegistry.java:24`, `InMemoryCheckpointer.java:30`, `SyncOrchestrator.java:40` | EXACT MATCH. Gate Rule 26d not violated. |
| OpenAPI snapshot diff attributed to `OpenApiContractIT` via `OpenApiSnapshotComparator`; `ApiCompatibilityTest` is ArchUnit-only | `agent-platform/src/test/java/ascend/springai/platform/contracts/OpenApiContractIT.java:79-99` calls `OpenApiSnapshotComparator.compare()` + `compareResponseSchemas()`. `agent-platform/src/test/java/ascend/springai/platform/api/ApiCompatibilityTest.java:23-50` is pure ArchUnit (alibaba ban + module dep direction); no OpenAPI reference. | EXACT MATCH. Gate Rule 26c not violated. |
| Reactor modules = 4 (`spring-ai-ascend-dependencies`, `agent-platform`, `agent-runtime`, `spring-ai-ascend-graphmemory-starter`) | `pom.xml:34-39` | EXACT MATCH. |
| HTTP edge surface lists only `GET /v1/health` | grep for `@(Get|Post|Put|Delete|Patch|Request)Mapping` in `agent-platform/src/main/java` returns only `HealthController` (`@RequestMapping("/v1")` + `@GetMapping("/health")`) | EXACT MATCH. No other controller annotations exist. |
| `WebSecurityConfig` deny-by-default returns 403 per `PostureBindingIT` | `WebSecurityConfig.java:37` `.anyRequest().denyAll()`; matches recent commit `a15e05e` "fix(it): PostureBindingIT — expect 403 from deny-by-default security" | MATCH on 403 semantics. (Permit-list narrower-than-stated — see Finding 1.) |
| ArchUnit guards = {`OrchestrationSpiArchTest`, `MemorySpiArchTest`, `ApiCompatibilityTest`, `TenantPropagationPurityTest`} | `agent-runtime/src/test/java/ascend/springai/runtime/orchestration/spi/OrchestrationSpiArchTest.java`, `agent-runtime/src/test/java/ascend/springai/runtime/memory/spi/MemorySpiArchTest.java`, `agent-platform/src/test/java/ascend/springai/platform/api/ApiCompatibilityTest.java`, `agent-runtime/src/test/java/ascend/springai/runtime/architecture/TenantPropagationPurityTest.java` | EXACT MATCH. All four exist on disk. |

## Categorized summary

- **P0 (invented-symbol / signature-drift / test-attribution / route-mismatch)**: 0
- **P1 (scope-overclaim affecting contract correctness)**: 0
- **P2**: 0
- **P3 (peripheral phrasing tightening)**: 1 — Finding 1 (permit-list under-states actual matchers by three entries; deny-by-default semantics correct).

The v2 release note's contract surface section is **accurate** against the source-of-truth Java sources. The four Gate Rule 26 sub-checks named in line 213 of v2 are all satisfied:
- 26a (`RunLifecycle` not claimed as shipped) — v2 line 60 correctly notes "remains design-only for W2".
- 26b (`RunContext.posture()` not invented) — v2 line 61 explicitly disclaims it ("Posture is not threaded through `RunContext` at W0").
- 26c (`ApiCompatibilityTest` not mis-attributed as OpenAPI-snapshot) — v2 line 72 explicitly carves the responsibility to `OpenApiContractIT`.
- 26d (`AppPostureGate` placement+breadth) — v2 lines 63 and 134 name exactly the three real callers.

No ship-blocking finding. The single P3 is a tightening recommendation for v2.1 or a follow-up PR; it does not gate L0 release.
