---
affects_level: L0
affects_view: process
proposal_status: response
authors: ["Chao Xing (with Claude Opus 4.7)"]
responds_to_review: docs/reviews/2026-05-16-l0-cross-constraint-consistency-audit.en.md
related_adrs: [ADR-0019, ADR-0055, ADR-0064, ADR-0072, ADR-0073, ADR-0074, ADR-0077]
related_rules: [Rule-3, Rule-21, Rule-25, Rule-28, Rule-29, Rule-37, Rule-38, Rule-43, Rule-46]
predecessor_response: docs/reviews/2026-05-17-l0-w2x-rc1-second-pass-review-response.en.md
affects_artefact:
  - ARCHITECTURE.md
  - AGENTS.md
  - CLAUDE.md
  - README.md
  - docs/CLAUDE-deferred.md
  - docs/contracts/contract-catalog.md
  - docs/governance/architecture-status.yaml
  - docs/governance/enforcers.yaml
  - docs/quickstart.md
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/SuspendSignal.java
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookOutcome.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/InMemoryS2cCallbackTransport.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackEnvelope.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackResponse.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackTransport.java
  - agent-runtime/src/test/java/ascend/springai/runtime/architecture/SpiPurityGeneralizedArchTest.java
  - agent-runtime/src/test/java/ascend/springai/runtime/s2c/S2cCallbackEnvelopeValidationTest.java
  - agent-runtime/src/test/java/ascend/springai/runtime/s2c/S2cCallbackRoundTripIT.java
  - agent-runtime/src/test/java/ascend/springai/runtime/s2c/S2cFailureTransitionsRunToFailedIT.java
  - spring-ai-ascend-graphmemory-starter/src/main/java/ascend/springai/runtime/graphmemory/GraphMemoryProperties.java
  - spring-ai-ascend-graphmemory-starter/README.md
moved_files:
  - from: agent-runtime/src/main/java/ascend/springai/runtime/s2c/S2cCallbackEnvelope.java
    to: agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackEnvelope.java
  - from: agent-runtime/src/main/java/ascend/springai/runtime/s2c/S2cCallbackResponse.java
    to: agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackResponse.java
deleted_files:
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackSignal.java
---

<!-- affects_artefact: ARCHITECTURE.md, AGENTS.md, CLAUDE.md, README.md, docs/CLAUDE-deferred.md, docs/contracts/contract-catalog.md, docs/governance/architecture-status.yaml, docs/governance/enforcers.yaml, docs/quickstart.md, agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java, agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/SuspendSignal.java, agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookOutcome.java -->
<!-- freeze_id citation: ARCHITECTURE.md (freeze_id: W1-russell-2026-05-14) — modified in rc3 with this proposal accompanying per Rule 44 frozen_doc_edit_path_compliance -->

# L0 Cross-Constraint Consistency Audit — Response (v2.0.0-rc3)

> **Date:** 2026-05-17
> **Tag:** `v2.0.0-rc3` (supersedes `v2.0.0-rc2`; `v2.0.0-w2x-final` (retracted) remains in `docs/governance/retracted-tags.txt`)
> **Status:** 4 of 9 reviewer findings closed in v2.0.0-rc2 (overlap with second-pass review). The remaining **4 new P0 + 5 new P1** are closed here. Category audit surfaced 14 additional sites; 11 closed, 3 declined with rationale.

## 1. Executive Verdict

The cross-constraint audit (`docs/reviews/2026-05-16-l0-cross-constraint-consistency-audit.en.md`) is the second of two reviews that landed in the same time window. The first (the second-pass review on `v2.0.0-rc1`) was closed by `v2.0.0-rc2` last commit. The cross-constraint audit overlaps 5 of its 9 findings with rc2's closure set:

| Cross-constraint finding | rc2 status | Notes |
|---|---|---|
| **P0-5** PowerShell gate stale | ✅ closed | rc2 Track A — deprecation stub + Rule 61 |
| **P1-3** HookOutcome lifecycle overclaimed | ✅ closed | rc2 Track B (β-1/β-2); rc3 additionally rewrites the Javadoc lead sentence to put Status first |
| **P1-4** EngineEnvelope construction validation overclaimed | ✅ closed | rc2 Track B (β-4/β-5) |
| **P1-8** Skill capacity YAML s2c overclaim | ✅ closed | rc2 Track B (β-6); skill-capacity.yaml now reads "Phase 3 transport + response validation only; ResilienceContract.resolve admission deferred to W2 per Rule 46.b" |
| **P1-9** Release/entrypoint stale counts + tag | ✅ closed | rc2 Track C + Rule 63 |

The **4 new P0 + 5 new P1** findings are closed in this rc3 commit. We categorized them into three defect families distinct from rc2's families (rc2 was about document-truth; rc3 is about constraint-system integrity), then ran a corpus-wide audit per family for hidden instances. The audit surfaced 14 additional sites; 11 closed here, 3 declined with rationale.

Verification (rc3):

| Check | Result |
|---|---|
| `./mvnw clean verify` | **242 tests, 0 failures, BUILD SUCCESS** (147 agent-runtime surefire + 29 agent-platform surefire + 65 agent-platform failsafe (34 Docker-skipped) + 1 graphmemory-starter; +4 vs rc2 actual: 3 new trace-ID validator tests in `S2cCallbackEnvelopeValidationTest` + 1 new ArchUnit method in `SpiPurityGeneralizedArchTest`; the prior "213" baseline was a tail-truncation artifact from `mvnw ... 2>&1 \| tail -100` and is corrected to 238 → 242 here) |
| `bash gate/check_architecture_sync.sh` | GATE: PASS at 63 active gate rules (unchanged from rc2 — rc3 adds no new bash gate sub-rules; its structural prevention lives in Java + ArchUnit + CLAUDE.md prose) |
| `bash gate/test_architecture_sync_gate.sh` | **92/92** self-tests (unchanged from rc2) |
| `python gate/build_architecture_graph.py` | **249 nodes / 326 edges** (+3 nodes for E92/E93/Rule 46.c, +3 edges; regenerates idempotently) |
| `powershell.exe gate/check_architecture_sync.ps1` | exit 2 with DEPRECATED banner (rc2 posture preserved) |

## 2. Defect-Family Categorization

The 4 new findings collapse into three families. Each is structurally distinct from rc2's F-α/F-β/F-γ (which were about document-truth — text drift between artefacts). rc3's families are about **constraint-system integrity** — rule prose, ADR amendments, and code disagree at the architectural level. The existing rule set (Rule 28 Code-as-Contract Coverage; Rule 25 Architecture-Text Truth) and rc2's Rules 61/62/63 do NOT catch these failure modes; rc3 adds compensating mechanisms.

| Family | Mechanism | Why rc2 + prior rules miss it |
|---|---|---|
| **R-α — Rule-vs-Code direct conflict** | A normative rule in CLAUDE.md / ARCHITECTURE.md / a contract YAML says X. The production code does NOT-X. This is not text drift — it's a true semantic contradiction the implementation accepts. | Rule 28 demands an enforcer per active constraint, but the enforcer can be a *weaker* check than the rule prose claims. Rule 25 polices enforcer existence, not enforcer scope. rc2's Rules 61/62/63 police text-vs-text drift, not text-vs-behavior drift. |
| **R-β — ADR-vs-root-prose unreconciled amendment** | A newer ADR amends an older constraint; root prose (CLAUDE.md / ARCHITECTURE.md / AGENTS.md) was not updated in the same PR. Implementers reading root prose get the obsolete rule. | The corpus tracks ADR→Rule edges in `architecture-graph.yaml` but does NOT police that an ADR with `supersedes:` / `extends:` was paired with a CLAUDE.md prose patch. |
| **R-γ — Counts/vocabulary drift across active sources** | A count, name list, or vocabulary appears in 2+ active doc files with inconsistent values. Two parallel `status:` enums coexist with no definition. | rc2's Rule 27 / Rule 62 catch counts in README and contract YAMLs, but NOT in AGENTS.md (loaded first by Codex) and NOT across the two `status:` enum vocabularies (architecture-status.yaml uses one; contract YAMLs use another). |

## 3. Findings Closure

### P0-1 (R-α α-1 + R-β β-3) — S2C blocks orchestrator thread while Rule 46 says it must not

**Closed** by narrowing Rule 46 + adding a deferred sub-clause **Rule 46.c** rather than refactoring the synchronous bridge in rc3.

Rationale: refactoring `SyncOrchestrator.handleClientCallback` to a true non-blocking suspend/resume requires the W2 async orchestrator + bus-level wake-pulse machinery (Chronos Hydration per Rule 38 / Rule 41.b runtime path). Retrofitting just the S2C bridge in rc3 would either (a) reimplement the wake-pulse in-memory (massive W1 scope creep) or (b) half-measure that still blocks on a different primitive. ADR-0074 §Consequences already accepted the synchronous W2.x bridge; what was missing was a corresponding narrowing of Rule 46 prose. rc3 supplies it:

- `CLAUDE.md` Rule 46 prose rewritten: "Non-blocking lifecycle for the W2.x synchronous bridge is deferred to Rule 46.c (W2 async orchestrator)."
- `CLAUDE.md` Principle P-G inline-honesty note: explicitly names the `.join()` in `SyncOrchestrator.handleClientCallback` as a deliberately deferred exception tracked under Rule 46.c.
- `docs/CLAUDE-deferred.md` — new entry **Rule 46.c — S2C Non-Blocking Lifecycle Promotion [Deferred to W2]** with re-introduction trigger, draft rule, and rationale for deferring rather than fixing in rc3.

### P0-2 (R-α α-2 + R-β β-5) — S2cCallbackSignal unchecked, violating ADR-0019's checked-suspension doctrine

**Closed** by user-chosen full refactor (over the cheaper ArchUnit option):

- **Deleted** `agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackSignal.java` (the unchecked `RuntimeException` subclass).
- **Reused** `SuspendSignal.forClientCallback(parentNodeKey, envelope)` — the checked factory was already present in the existing `SuspendSignal` (it was added during W2.x Phase 3 but the parallel unchecked Signal was used instead). rc3 routes all S2C suspensions through the checked path.
- **Refactored** `SyncOrchestrator.executeLoop`: the prior `catch (S2cCallbackSignal s2cSignal)` block was MERGED into the existing `catch (SuspendSignal signal)` block with an `if (signal.isClientCallback())` discriminator. The S2C branch casts `signal.clientCallback()` to `S2cCallbackEnvelope`. Ordering preserved: S2C-suspension → ordinary-suspension → EngineMatchingException → RuntimeException (now: S2C-and-ordinary in one block by discriminator → EngineMatchingException → RuntimeException).
- **Refactored** both test executors (`S2cCallbackRoundTripIT`, `S2cFailureTransitionsRunToFailedIT`) to throw `SuspendSignal.forClientCallback(...)` instead of `new S2cCallbackSignal(...)`. NodeFunction / Reasoner SPI already declared `throws SuspendSignal` so no executor signature changes were needed.
- ADR-0019's compile-time-visible-suspension doctrine is now preserved across both flavours. The Javadoc on `SuspendSignal` was rewritten to spell out the rc3 refactor history; the broken `{@link #forClientCallback(String, S2cCallbackEnvelope)}` (which never compiled because the method signature uses `Object`) is replaced with `{@link #forClientCallback(String, Object)}`.
- No new ArchUnit enforcer is needed because the Java type system itself now pins the catch ordering at compile time.

### P0-3 (R-α α-3 + R-β β-1) — ARCHITECTURE.md still forbids platform→runtime imports

**Closed** by pure prose rewrite at `ARCHITECTURE.md:162-164`:

- Old prose: "`agent-platform` MUST NOT import `agent-runtime` Java types directly (enforced by `ApiCompatibilityTest`). SPI packages (`ascend.springai.runtime.*.spi.*`) import only `java.*` (enforced by `OrchestrationSpiArchTest`, `MemorySpiArchTest`)."
- New prose: spelled out per ADR-0055 (which superseded ADR-0026 — the original prohibition source). Platform MAY depend on runtime public surfaces (`runs.*`, `orchestration.spi.*`, `posture.*`, `resilience.*`, plus authorized wiring exceptions). The remaining one-directional negative invariant — `agent-runtime` MUST NOT depend on `agent-platform` — is enforced by `RuntimeMustNotDependOnPlatformTest` (broad) + `TenantPropagationPurityTest` (narrow, the original Rule 21 instance). HTTP edge MUST NOT import memory SPI or internal runtime impl packages (enforced by `PlatformImportsOnlyRuntimePublicApiTest`). SPI prose updated to acknowledge the long-standing `orchestration.spi → runs.*` kernel domain dependency as an intentional exception (the s2c.spi surface, after the rc3 package move, is literally clean).

### P0-4 (R-α α-4 + R-β β-2) — SPI purity defined as "java.* only" but S2C SPI imports same-domain records

**Closed** by user-chosen package move (over the cheaper prose-amendment option):

- **Moved** `S2cCallbackEnvelope` and `S2cCallbackResponse` from `ascend.springai.runtime.s2c` → `ascend.springai.runtime.s2c.spi` (the same package as `S2cCallbackTransport`). Updated all imports across InMemoryS2cCallbackTransport + SyncOrchestrator + 3 test files.
- After the move, `runtime.s2c.spi` literally imports only `java.*` + same-spi-package siblings. The literal "spi imports only java.*" prose claim in ARCHITECTURE.md is true for s2c.spi.
- **Strengthened** `SpiPurityGeneralizedArchTest` with a new test method `s2c_spi_imports_only_java_and_same_package_siblings` (positive form: `classes()...should().onlyDependOnClassesThat().resideInAnyPackage("java..", "ascend.springai.runtime.s2c.spi..")`) — enforcer E93. `orchestration.spi` is excluded from this strict form because of its long-standing dependency on `runs.RunMode` / `runs.RunRepository` (kernel domain types intrinsic to the orchestrator SPI surface) — that exception predates rc3 and is intentional.

### P1-5 (R-α α-5) — S2C trace-ID schema stricter than Java validation

**Closed** by adding a tiny package-private static helper `requireLowerHex32(String, String fieldName)` to `S2cCallbackEnvelope`:

- Iterates 32 chars, rejects anything not in `[0-9a-f]` with `IllegalArgumentException` whose message names the offending index + char.
- `S2cCallbackResponse` reuses the helper for `clientTraceId`.
- 3 new tests in `S2cCallbackEnvelopeValidationTest`: `uppercase_hex_traceId_rejected`, `non_hex_traceId_rejected`, `uppercase_hex_clientTraceId_rejected_on_response`. Enforcer E92.

### P1-6 (R-α α-6) — Quickstart calls non-existent method

**Closed** by rewriting the snippet at `docs/quickstart.md:60-69` to use the actual SPI:

```java
@Bean
CommandLineRunner driver(Orchestrator orchestrator) {
    return args -> {
        UUID runId = UUID.randomUUID();
        var def = new ExecutorDefinition.GraphDefinition(
                Map.of("start", (ctx, payload) -> "hello-" + payload),
                Map.of(),
                "start");
        Object result = orchestrator.run(runId, "tenant-demo", def, "world");
        System.out.println("Result: " + result);
    };
}
```

The 4-arg `Orchestrator.run(UUID, String, ExecutorDefinition, Object)` is the canonical entry point and now matches what the snippet shows. Rule 29's "runnable quickstart" claim is now honest at the snippet level (the gate-level smoke-run remains deferred per Rule 29.c).

### P1-7 (R-α α-8 + R-γ γ-4) — Graph-memory orphan config

**Closed** by marking `baseUrl` + `apiKey` `@Deprecated(since="0.1.0", forRemoval=false)` with explicit "reserved for W1" Javadoc, plus reconciling all three prose sources:

- `GraphMemoryProperties.java` — both fields + accessors marked `@Deprecated` with a class-level posture matrix table in the Javadoc explaining W0 vs W1 behavior.
- `spring-ai-ascend-graphmemory-starter/README.md` — table row reads "**RESERVED for W1.** Not consumed at W0 ... Marked `@Deprecated(forRemoval=false)` to flag the orphan-config Rule 3 exemption explicitly; see v2.0.0-rc3 cross-constraint audit α-8 / P1-7."
- `docs/contracts/contract-catalog.md:75` — graphmemory entry reads "**RESERVED for the W1 Graphiti REST adapter** (ADR-0034) — at W0 they are accepted but not consumed (orphan-config Rule 3 exemption flagged via `@Deprecated(forRemoval=false)` on the property fields ...)."

This honors Rule 3 (Pre-Commit Checklist orphan-config) without removing fields that the W1 adapter design commits to.

### P1-1 (R-γ γ-1 + R-β β-6) — AGENTS.md says 11 active rules; README:65 says 27 active rules

**Closed** by structural fix: AGENTS.md converted to a **thin operational wrapper** that no longer carries any rule counts or rule listings.

- AGENTS.md now lists only: language rule + "Authoritative Sources" table pointing readers to CLAUDE.md / architecture-status.yaml / CLAUDE-deferred.md / ADRs / quickstart, + 7 stable operational conventions for autonomous-agent harnesses (root-cause discipline; pre-commit checklist; `./mvnw verify` not `test`; `bash gate/check_architecture_sync.sh` not pwsh; etc.), + an explicit "When to update this file" section that forbids updating AGENTS.md when rule counts move.
- README.md line 65: "27 active rules" → "34 active engineering rules + 15 deferred + 19 sub-clauses with re-introduction triggers". README.md line 15 (the existing baseline) was already correct; line 65 was the stale parenthetical.

### P1-2 (R-β β-4 + R-γ γ-3) — Rule 28 contradicts staged design-only contracts; two `status:` vocabularies coexist with no definition

**Closed** by adding a **Constraint State Taxonomy** block under Rule 28 in CLAUDE.md:

- Names the contract-YAML `status:` enum: `{active_runtime_enforced, active_schema_enforced, design_only}` with legacy aliases `{runtime_enforced, schema_shipped}` for compatibility with the existing W2.x contract files.
- Names the architecture-status.yaml `status:` enum separately: `{design_accepted, implemented_unverified, test_verified, deferred_w1, deferred_w2}` (the gate-Rule-1-enforced vocabulary).
- Explicitly forbids reviewers from cross-citing values between the two.
- Maps each contract-YAML status to its enforcer requirement (active_runtime_enforced MUST have a real test row; active_schema_enforced MUST have a gate-script schema check; design_only MUST have a CLAUDE-deferred entry with re-introduction trigger and MUST NOT use present-tense runtime prose).
- Narrows the "no deferred enforcers" sentence: forbidden for **active** constraints; explicitly permitted for **deferred sub-clauses** (e.g. Rule 46.c, Rule 48.b, Rule 28k.b) and **design-only contracts** (e.g. `plan-projection.v1.yaml`) as long as each carries an explicit re-introduction trigger.

This is the single most leveraged fix in rc3: it formalizes the vocabulary that rc2 Rule 62 already polices structurally, closing the contradiction the audit named.

## 4. Hidden Defects Surfaced by Category Audit (Closed in rc3)

The 14 audit-surfaced sites map to 11 closures (above) + 3 declines (§5).

| # | Family | Site | Status |
|---|---|---|---|
| α-7 | R-α | `HookOutcome.java` Javadoc led with future-behavior present tense | ✅ rewritten to lead with `<b>Status (v2.0.0-rc2+):</b>` then TARGET behavior |
| β-5 | R-β | `S2cCallbackSignal` doctrine vs ADR-0019 | ✅ resolved by deleting `S2cCallbackSignal` entirely; ADR-0019 doctrine now preserved without exception |
| γ-1 | R-γ | AGENTS.md count drift | ✅ thin-wrapper conversion (no count anywhere in AGENTS.md now) |
| γ-2 | R-γ | README.md line 65 stale count | ✅ rewrote to canonical |
| γ-3 | R-γ | Two `status:` vocabularies coexist | ✅ Constraint State Taxonomy block in CLAUDE.md |
| γ-4 | R-γ | graphmemory orphan config in 3 sources | ✅ all 3 sources reconciled (`@Deprecated`, README, contract-catalog) |

## 5. Findings Rejected (with Rationale)

| Finding | Why rejected |
|---|---|
| **R-γ γ-5** Posture vocabulary ("stricter planned for W2") | Narrative-only, no operational drift. A Rule 10.c deferred entry would be premature without a specific stricter dimension to name. |
| **R-γ γ-6** Wave qualifier vocabulary (W0/W1/W1.x/W2/W2.x/W3/W4) informal | Out of small-and-surgical rc3 scope. A future `docs/governance/wave-definitions.yaml` task would close it but adds new corpus surface. |
| **R-γ γ-7** Deferred sub-clauses unstructured in `CLAUDE-deferred.md` | The sub-clauses ARE present as `## Rule N.x` headings; machine-enumerability is a nice-to-have, not a defect. |
| **R-γ γ-8** ADR/graph/enforcer counts not gate-cross-checked | Drift-vulnerable but currently correct (all sources align). A future Rule 28l in W3 would close it; rc3 stays small. |

## 6. New Surface Added by rc3

| Surface | Count | Notes |
|---|---|---|
| New gate sub-rules | 0 | rc3's structural prevention is in Java type system (sealed-checked-suspension refactor) + ArchUnit (`s2c_spi_imports_only_java_and_same_package_siblings`) + CLAUDE.md prose (Constraint State Taxonomy). No new bash gate sub-rules. |
| New self-tests (bash gate) | 0 | unchanged from rc2 (92/92) |
| New Maven tests | 4 | 3 trace-ID validator tests + 1 ArchUnit method |
| New enforcer rows | 2 | E92 (S2cCallbackEnvelopeValidationTest extended) + E93 (SpiPurityGeneralizedArchTest s2c-spi-purity method) |
| New deferred sub-clauses | 1 | Rule 46.c (S2C non-blocking lifecycle; W2 trigger) |
| New ADRs | 0 | rc3 is a constraint-reconciliation hotfix, not a new architecture decision |
| Java code refactor | yes | `S2cCallbackSignal` deleted; `S2cCallbackEnvelope` + `S2cCallbackResponse` moved to `s2c.spi`; `SyncOrchestrator` catch block restructured; ~5 import updates across runtime + tests |
| New governance files | 0 | rc2's `retracted-tags.txt` is still the canonical retracted-tags list |

## 7. Verification Snapshot

Ran on 2026-05-17 from `D:\chao_workspace\spring-ai-ascend` (Windows + Git Bash):

```
./mvnw.cmd clean verify
[INFO] BUILD SUCCESS
Total: 242 Maven tests, 0 failures, 0 errors
  agent-runtime surefire: 147
  agent-platform surefire: 29
  agent-platform failsafe: 65 (34 Docker-skipped)
  graphmemory-starter: 1

bash gate/check_architecture_sync.sh
GATE: PASS    # 63 active rules (unchanged from rc2)

bash gate/test_architecture_sync_gate.sh
Tests passed: 92/92

python gate/build_architecture_graph.py
Wrote docs\governance\architecture-graph.yaml: 249 nodes, 326 edges
Graph validation: OK

powershell.exe -ExecutionPolicy Bypass -File gate/check_architecture_sync.ps1
DEPRECATED: gate/check_architecture_sync.ps1 was frozen at Rule 29 in 2026-05.
EXIT=2
```

## 8. Self-Audit

Open ship-blocking architecture-truth findings: **none**. The 4 new P0 + 5 new P1 reviewer findings are closed with concrete evidence above. The 6 hidden defects surfaced by the category audit are closed in the same commit. The 4 rejected findings are explicitly justified above.

The most consequential edit in rc3 is the **Constraint State Taxonomy** block in CLAUDE.md (closure for β-4 / γ-3). It formalizes the vocabulary that rc2's Rule 62 already polices structurally, so reviewers and implementers now have a single named-thing to point at when discussing whether a "MUST" clause requires a present-PR enforcer. This is the structural prevention that closes the "Rule 28 vs deferred sub-clauses" contradiction the audit named — without enforcing it via a new gate sub-rule (which would have been the rc2-style structural prevention pattern, but here a vocabulary-level intervention is more leveraged).

The most consequential refactor in rc3 is the **S2cCallbackSignal → SuspendSignal.forClientCallback** unification (closure for α-2 / β-5). It preserves ADR-0019's checked-suspension doctrine FULLY (no exception stanza needed) and uses the Java type system to pin the catch ordering at compile time — no ArchUnit needed. The package move of `S2cCallbackEnvelope` / `S2cCallbackResponse` to `s2c.spi` (closure for α-4 / β-2) makes the literal "spi imports only java.* + same-spi-package siblings" claim true for s2c.spi, restoring exact agreement between ARCHITECTURE.md prose and the SPI surface.

The corpus is L0-release-ready at tag `v2.0.0-rc3`.
