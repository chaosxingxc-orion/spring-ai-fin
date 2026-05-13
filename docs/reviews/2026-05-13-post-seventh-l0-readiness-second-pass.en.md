# Post-Seventh Response L0 Readiness Second-Pass Review

**Reviewer:** Java microservices and agent-architecture reviewer
**Date:** 2026-05-13
**Review input:** `docs/reviews/2026-05-13-post-seventh-l0-readiness-followup-response.en.md`
**Review standard:** L0 architecture-text truth, strict contract/code consistency, no clean release note while active contracts disagree.

---

## 1. Executive Verdict

Do **not** publish the clean L0 release note yet.

The post-seventh response correctly addresses the six named clusters from the prior follow-up, but a stricter second pass still finds active documentation, build metadata, gate text, and Java contracts that do not agree with each other. Most remaining issues are not new architectural concepts; they are truth-maintenance gaps caused by partial repair scope.

The main architectural conclusion is:

- The L0 direction is sound and not materially over-designed if design-only agent capabilities remain explicitly deferred.
- The remaining blockers are contract drift: active documents still overclaim implementation, mention deleted extension points, or state invariants that the code does not implement.
- The agent-driven design areas are acceptable for L0 only if planning, skill lifecycle, memory, and knowledge contracts are clearly marked as design-only where no code ships.

---

## 2. P1 Blocking Findings

### P1.1 Rule 25 still has an unguarded shipped-row violation

**Observed failure:** `docs/governance/architecture-status.yaml` says `shipped: true = implementation exists + at least 1 test GREEN`, and AGENTS Rule 25 requires every `shipped: true` row to have a non-empty `tests:` list. The `architecture_sync_gate` row is still `shipped: true` with `tests: []`.

**Execution path:** The architecture status ledger is the source of truth for shipped capability claims. Gate Rule 7 checks only shipped implementation paths and explicitly skips rows with null or empty implementation. It does not enforce the required non-empty tests list.

**Root cause statement:** The status ledger can ship a capability without test evidence because `gate/check_architecture_sync.ps1` Rule 7 validates implementation paths only, not `tests:` path presence.

**Evidence:**

- `docs/governance/architecture-status.yaml:57-68` - `architecture_sync_gate` has `shipped: true` and `tests: []`.
- `gate/check_architecture_sync.ps1:199-238` - Rule 7 is named `shipped_impl_paths_exist` and checks implementation paths only.
- `AGENTS.md` Rule 25 - shipped rows require non-empty tests pointing to real test classes.

**Required fix:**

1. Either mark `architecture_sync_gate` as `shipped: false` or add real test evidence, for example `gate/test_architecture_sync_gate.sh` if that is the intended verifier.
2. Add a gate rule that fails every `shipped: true` row with an empty `tests:` list or a test path that does not exist.
3. Update Rule 25 prose, gate comments, and the status ledger so they all describe the same constraint.

---

### P1.2 Deleted SPI names remain in active contracts and module README text

**Observed failure:** Active documents still reference deleted or non-contract extension names that the response says were removed from active documentation.

**Execution path:** Developers read `docs/contracts/http-api-contracts.md` and `agent-platform/README.md` as active contract/module guidance. Those files still mention `PolicyEvaluator` and `IdempotencyRepository`, which the Occam pass deleted or replaced with direct platform mechanisms.

**Root cause statement:** The deleted-name cleanup was scoped to `contract-catalog.md`, the root `README.md`, `third_party/MANIFEST.md`, and the BoM, leaving other active contract files unscanned.

**Evidence:**

- `docs/contracts/http-api-contracts.md:34` - HTTP 403 semantics still say `PolicyEvaluator returned DENY`.
- `agent-platform/README.md:11` - says the platform calls `RunRepository`, `IdempotencyRepository`, `PolicyEvaluator`, and other SPI interfaces.
- `docs/cross-cutting/oss-bill-of-materials.md:216` - says these names must not be referenced in active documentation.
- `gate/check_architecture_sync.ps1:555-560` - Rule 18 scans only selected files, not all active contract/module docs.

**Required fix:**

1. Replace `PolicyEvaluator` in HTTP semantics with the chosen W1/W2 authorization mechanism, such as Spring Security `AuthorizationManager` plus tenant/JWT cross-check, if that is the intended contract.
2. Replace `IdempotencyRepository` in `agent-platform/README.md` with the actual W0/W1 name and status. Current code has header validation at W0 and `IdempotencyStore` promotion later.
3. Widen the deleted-name gate to all active normative docs and module READMEs, with explicitly documented historical exclusions.

---

### P1.3 Graph memory starter metadata overclaims the implementation

**Observed failure:** The graphmemory starter POM and README still describe a Graphiti implementation path that does not exist in code, and the README still presents Cognee as an implementation option despite ADR-0034 selecting Graphiti as the W1 reference and marking Cognee not selected.

**Execution path:** The reactor publishes the starter artifact metadata and README. Consumers will infer that enabling the starter wires a Graphiti REST implementation, but `GraphMemoryAutoConfiguration` registers no `GraphMemoryRepository` bean and the only test asserts no bean exists.

**Root cause statement:** The graphmemory starter text was partially updated to say "adapter shell", but POM/README examples still describe a concrete Graphiti/Cognee adapter that is not present in the shipped code.

**Evidence:**

- `spring-ai-ascend-graphmemory-starter/pom.xml:17-22` - says the starter implements `GraphMemoryRepository` via Graphiti REST and wires Graphiti by default.
- `spring-ai-ascend-graphmemory-starter/README.md:5-17` - says users provide their own bean, but the example still references `GraphitiRestGraphMemoryRepository` and "Or Cognee".
- `spring-ai-ascend-graphmemory-starter/src/main/java/ascend/springai/runtime/graphmemory/GraphMemoryAutoConfiguration.java:8-13` - empty auto-configuration, no bean.
- `spring-ai-ascend-graphmemory-starter/src/test/java/ascend/springai/runtime/graphmemory/GraphMemoryAutoConfigurationTest.java:16-20` - asserts no `GraphMemoryRepository` bean.
- `docs/governance/architecture-status.yaml:86-94` - correctly says scaffold now; W1 wires real Graphiti REST client.

**Required fix:**

1. Change the POM description to "optional adapter scaffold; no repository bean is contributed at W0; Graphiti REST client is W1".
2. Remove `GraphitiRestGraphMemoryRepository` and Cognee examples from the W0 README unless those classes are actually added.
3. Keep Cognee only as a not-selected evaluation alternative per ADR-0034.

---

### P1.4 The BoM claims non-existent owned glue classes

**Observed failure:** The OSS bill of materials lists multiple "Glue we own" classes that do not exist in the repository.

**Execution path:** The BoM is an active L2 architecture document used to establish OSS integration readiness. "Glue we own" reads as an implementation claim, not a design placeholder. Missing classes therefore violate architecture-text truth.

**Root cause statement:** The BoM still mixes dependency shape probes with planned integration glue, so U2 dependency verification is being confused with shipped adapter code.

**Evidence:**

- `docs/cross-cutting/oss-bill-of-materials.md:41` - lists `agent-runtime/llm/ChatClientFactory`, `agent-runtime/llm/LlmRouter`, `agent-runtime/memory/PgVectorAdapter`; none exist.
- `docs/cross-cutting/oss-bill-of-materials.md:56` - lists `agent-runtime/temporal/RunWorkflow`, `RunWorkflowImpl`, `LlmCallActivity`, `ToolCallActivity`; none exist.
- `docs/cross-cutting/oss-bill-of-materials.md:71` - lists `agent-runtime/tool/McpToolRegistry`; it does not exist.
- `agent-runtime/src/main/java/ascend/springai/runtime/probe/OssApiProbe.java` is the actual W0 verification surface for these dependencies.

**Required fix:**

1. Split each BoM row into "APIs cited/probed at W0" and "planned glue class at W2+".
2. Do not list a class under "Glue we own" unless the path exists.
3. Add a gate that checks BoM implementation-path cells or requires an explicit `planned:` marker.

---

### P1.5 Telemetry naming contract is inconsistent

**Observed failure:** The canonical metric namespace is lowercase in root architecture, module architecture, gate code, Java code, and tests, but the contract catalog and HTTP contract use uppercase `SPRINGAI_ASCEND_`.

**Execution path:** Contract readers will implement uppercase metric names from `contract-catalog.md`, while the platform emits lowercase names and the gate enforces lowercase.

**Root cause statement:** Telemetry contracts were copied from older environment-variable style naming and not reconciled with the implemented Micrometer namespace.

**Evidence:**

- `ARCHITECTURE.md:129` and `ARCHITECTURE.md:166` - canonical metric prefix is `springai_ascend_*`.
- `agent-platform/ARCHITECTURE.md:67` - canonical metric prefix is `springai_ascend_*`.
- `gate/check_architecture_sync.ps1:164-180` - Java metric strings must start with `springai_ascend`.
- `agent-platform/src/main/java/ascend/springai/platform/tenant/TenantContextFilter.java:27-29` - emits lowercase metrics.
- `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilter.java:25-27` - emits lowercase metrics.
- `docs/contracts/contract-catalog.md:71` - says `SPRINGAI_ASCEND_<domain>_<subject>_total`.
- `docs/contracts/http-api-contracts.md:39` - says `SPRINGAI_ASCEND_filter_errors_total`.

**Required fix:** Normalize active telemetry contracts to lowercase `springai_ascend_...`, and add a docs-side gate for uppercase metric contract drift.

---

### P1.6 SPI contract invariants overgeneralize tenant scope and misclassify `RunContext`

**Observed failure:** The contract catalog says all SPI implementations are tenant-scoped and that `RunContext` is a per-run context record. The source code has `RunContext` as an interface, and `ResilienceContract` is operation-scoped at W0.

**Execution path:** The SPI table is supposed to be the public extension contract. Overgeneralized invariants lead implementers to add tenant semantics where the W0 interface does not carry tenant identity.

**Root cause statement:** The SPI catalog was repaired for interface count but not reconciled against each interface signature and ADR-0030's W2 tenant-scope extension.

**Evidence:**

- `docs/contracts/contract-catalog.md:20` - "All SPI impls: ... tenant-scoped."
- `docs/contracts/contract-catalog.md:38` - `RunContext` described as a "record".
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/RunContext.java:15-29` - `RunContext` is an interface.
- `agent-runtime/src/main/java/ascend/springai/runtime/resilience/ResilienceContract.java:17` - `resolve(String operationId)` has no tenant parameter.
- `docs/adr/0030-skill-spi-lifecycle-resource-matrix.md:223` - says `ResilienceContract.resolve(operationId)` extends to `(tenantId, operationId)` at W2.

**Required fix:**

1. Change the invariant to "SPIs that process tenant-owned runtime data must carry tenant scope."
2. Explicitly classify `ResilienceContract` as W0 operation-scoped, W2 tenant-aware.
3. Correct `RunContext` from "record" to "interface" or move it into a separate "context interfaces" table.

---

### P1.7 Memory metadata contract still drifts across root architecture, ADR, and shipped graph SPI

**Observed failure:** The root architecture names `embeddingModel?`; ADR-0034 and `architecture-status.yaml` name `embeddingModelVersion`; the shipped `GraphMemoryRepository.GraphMetadata` record contains only `tenantId`, `sessionId`, `runId`, and `createdAt`.

**Execution path:** Memory and knowledge are central to the agent-driven architecture. L0 may defer implementation, but the shipped graph-memory SPI should not expose metadata that appears inconsistent with the canonical design contract.

**Root cause statement:** ADR-0034 introduced the common `MemoryMetadata` shape after `GraphMemoryRepository.GraphMetadata` was already present, but the shipped interface was not marked as pre-W2 minimal or aligned with the new schema.

**Evidence:**

- `ARCHITECTURE.md:387-390` - common metadata includes `embeddingModel?`.
- `docs/adr/0034-memory-and-knowledge-taxonomy-at-l0.md:58-67` - common metadata includes `embeddingModelVersion`.
- `docs/governance/architecture-status.yaml:389-391` - allowed claim names `embeddingModel`.
- `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java:27` - `GraphMetadata` lacks the common metadata fields.

**Required fix:**

Choose one of these paths:

1. If W0 `GraphMetadata` is intentionally minimal, document it as a pre-W2 graph-edge metadata subset and state that full `MemoryMetadata` lands with the W2 memory implementation.
2. If the common metadata contract is already binding, update `GraphMemoryRepository.GraphMetadata` to align with it and add tests.
3. Normalize the field name to either `embeddingModel` or `embeddingModelVersion` across root architecture, ADR-0034, and the status ledger.

---

## 3. P2 Consistency Findings

### P2.1 Active docs still contain broken internal references

**Evidence:**

- `docs/contracts/contract-catalog.md:98` links to missing `docs/cross-cutting/observability-policy.md`; the actual file is `docs/observability/policy.md`.
- `docs/contracts/contract-catalog.md:98` links to missing `docs/cross-cutting/data-model-conventions.md`; a historical replacement exists at `docs/v6-rationale/v6-data-model-conventions.md`, but it is not an obvious active contract path.
- `docs/contracts/http-api-contracts.md:141` links to missing `agent-platform/api/ARCHITECTURE.md`.
- `agent-platform/README.md:58` links to missing `agent-platform/api/ARCHITECTURE.md`.
- `agent-platform/README.md:60` links to missing `docs/contracts/spi-contracts.md`.

**Required fix:** Repair the links, remove them, or add the referenced active documents. Add a link-existence gate for active architecture and contract docs.

---

### P2.2 Gate Rule 15 scope text and implementation disagree

**Evidence:**

- `docs/adr/0041-active-corpus-truth-sweep.md:82-87` says Rule 15 scans active `.md` files excluding only `docs/archive/`, `docs/reviews/`, `third_party/`, `target/`, and `.git/`.
- `gate/check_architecture_sync.ps1:438-446` additionally excludes `docs/adr/`, `docs/delivery/`, and `docs/v6-rationale/`.
- Stale deleted-plan references remain in `docs/delivery/` and `docs/v6-rationale/`, but the gate passes them because of the broader implementation exclusion.

**Required fix:** Either update ADR-0041 to declare these directories as historical exclusions, or remove the extra exclusions and repair the files. The gate and ADR must describe the same corpus.

---

### P2.3 BoM "Active SPI surface" still lists a probe under the SPI heading

**Evidence:**

- `docs/cross-cutting/oss-bill-of-materials.md:208-214` is headed "Active SPI surface (W0 shipped)" and includes `ascend.springai.runtime.probe.OssApiProbe`.
- `docs/contracts/contract-catalog.md:44-47` correctly classifies `OssApiProbe` as a probe, not an SPI.

**Required fix:** Split the BoM subsection into "Active SPI surface" and "Probes", matching `contract-catalog.md`.

---

## 4. Agent-Driven Architecture Assessment

### Dynamic planning

The `PlanState` / `RunPlanRef` minimal planner contract is acceptable for L0 because it is clearly design-only and avoids prematurely shipping `planningEnabled` or a fake planner. The current risk is not overdesign; the risk is that future docs may treat these records as shipped API before W4.

### Skills and capability registry

The Skill SPI lifecycle, `SkillResourceMatrix`, trust tier, and sandbox posture rules are heavier than a minimal tool adapter, but they address real W2/W3 risks: resource cleanup on suspend, cost accounting, and untrusted execution. This is acceptable as deferred design. Do not implement a broad skill framework at L0.

### Memory and knowledge

The six-category taxonomy is directionally sound, and selecting Graphiti as the W1 reference while leaving mem0/Cognee unselected is a good simplification. The remaining issue is contract precision: the shipped `GraphMemoryRepository` metadata and the canonical `MemoryMetadata` schema must either align or be explicitly staged.

### OSS-first microservice posture

The strongest L0 principle is still "probe dependency shape now, implement integration glue only when the wave needs it." The BoM and graphmemory starter currently weaken that principle by describing planned glue as owned implementation.

---

## 5. Recommended Repair Order

1. Fix P1.1 first: make Rule 25 enforce shipped test evidence, then repair `architecture_sync_gate`.
2. Clean active deleted-name drift across all normative docs and module READMEs.
3. Correct graphmemory starter POM/README to match the actual W0 scaffold.
4. Rewrite BoM "Glue we own" rows to separate W0 probes from W2 planned glue.
5. Normalize telemetry casing to lowercase `springai_ascend_`.
6. Reconcile SPI invariants and memory metadata naming.
7. Repair broken internal links and align Gate Rule 15 scope text.

---

## 6. Acceptance Criteria for Clean L0 Release Note

Before publishing a clean L0 release note:

1. `gate/check_architecture_sync.ps1` fails on any `shipped: true` row with empty or missing tests.
2. Deleted SPI names do not appear in active contract/module docs except in explicitly historical ADR/review/archive contexts.
3. No active document says the graphmemory starter wires Graphiti by default unless the bean and tests exist.
4. BoM "Glue we own" entries either resolve to real files or are explicitly marked planned.
5. All active metric contract text uses lowercase `springai_ascend_`.
6. `RunContext`, `ResilienceContract`, and memory metadata are classified exactly as implemented or explicitly staged.
7. Active architecture/contract docs have no broken internal links.
8. The architecture sync gate and relevant unit/integration tests pass after the documentation repair.

Until those criteria are met, the correct release note is a "near-ready with residual contract-truth fixes" note, not a clean L0 completion note.
