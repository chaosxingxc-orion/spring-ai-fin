---
affects_level: L0
affects_view: process
proposal_status: response
authors: ["spring-ai-ascend architecture group"]
related_review: docs/reviews/2026-05-16-l0-w2x-post-release-architecture-review.en.md
related_adrs: [ADR-0071, ADR-0072, ADR-0073, ADR-0074, ADR-0076, ADR-0077]
related_rules: [Rule-25, Rule-28, Rule-44, Rule-45, Rule-46, Rule-48]
affects_artefact:
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java
  - agent-runtime/src/test/java/ascend/springai/runtime/s2c/S2cCallbackRoundTripIT.java
  - agent-runtime/src/test/java/ascend/springai/runtime/s2c/S2cFailureTransitionsRunToFailedIT.java
  - agent-platform/pom.xml
  - agent-platform/src/test/java/ascend/springai/platform/engine/EngineRegistryClasspathBootIT.java
  - agent-platform/src/test/java/ascend/springai/platform/engine/EngineRegistryBootValidationIT.java
  - CLAUDE.md
  - docs/CLAUDE-deferred.md
  - docs/governance/enforcers.yaml
  - docs/releases/2026-05-16-W2x-engine-contract-wave.en.md
  - docs/contracts/plan-projection.v1.yaml
  - docs/contracts/{engine-envelope,engine-hooks,s2c-callback}.v1.yaml
  - docs/governance/evolution-scope.v1.yaml
  - gate/check_architecture_sync.sh
  - gate/test_architecture_sync_gate.sh
  - README.md
  - docs/governance/architecture-status.yaml
---

# L0 / W2.x Post-Release Architecture Review — Response

> **Date:** 2026-05-17 (evening of 2026-05-16 working session)
> **Status:** Response to the 2026-05-16 review
> **Outcome:** All 6 review findings accepted; 2 explicit REJECTs documented with reasoning; 4 agent-driven recommendations addressed (3 light-touch, 1 deferred-strengthened); v2.0.0-w2x-final tag retracted; v2.0.0-rc1 cut.

## 1. Acknowledgement

The post-release architecture review (`docs/reviews/2026-05-16-l0-w2x-post-release-architecture-review.en.md`) caught four ship-blocking defects (P0-1..P0-4) plus two release-truth findings (P1-1, P1-2) that the W2.x Phase 7 self-audit missed. The Phase 7 audit verified with `./mvnw test` (Surefire only), which silently skipped the `*IT.java` integration tests cited as enforcement evidence — exactly the kind of phase mismatch that the review flagged.

We accept the review verdict that **v2.0.0-w2x-final should not stand as L0-final**. The tag has been retracted from the remote and replaced with **v2.0.0-rc1** carrying the fixes documented below. All six numbered findings are closed; two explicit REJECTs are recorded with reasoning (post-review §P0-2 mechanism description, §P1-1 gate-amendment recommendation).

## 2. Accept / Reject judgment table

| Finding | Verdict | Closure |
|---|---|---|
| **P0-1** S2cCallbackRoundTripIT broken fixture | ACCEPT | Reasoner trigger uses `capturedEnvelope` ref as the "already fired" sentinel; the prior `payload == null` clause never matched because `IterativeAgentLoopExecutor` injects `AgentLoopDefinition.initialContext` (`Map.of()`) as the initial payload. 4/4 IT cases now GREEN under `mvn verify`. See `S2cCallbackRoundTripIT.java` lines 60-71 (post-review fix). |
| **P0-2** S2C handler doesn't transition Run to FAILED | ACCEPT (substance) + REJECT (mechanism description — see §3) | `SyncOrchestrator.executeLoop()` now wraps the `handleClientCallback` call with a typed `catch (RuntimeException)` that transitions the Run to `FAILED` with `finishedAt`, fires `HookPoint.ON_ERROR` with `reason` (one of `s2c_response_invalid` / `s2c_client_error` / `s2c_transport_unavailable` / `s2c_transport_failure` / `s2c_timeout` / `s2c_unknown_failure`) + `callbackId` + exception details, then re-throws. New `S2cFailureTransitionsRunToFailedIT` (enforcer **E90**) covers all four documented failure modes plus the rethrow contract. |
| **P0-3** SyncOrchestrator ignores HookOutcome | ACCEPT (defer path) + REJECT (implement-now path — see §3) | `CLAUDE.md` Rule 45 now carries an explicit W2.x scope clarification paragraph aligning prose with ADR-0073's already-declared "Outcomes are LOGGED, NOT acted upon at Phase 2". `CLAUDE-deferred.md` 45.b adds the deferred clause with trigger "first consumer hook lands in W2 Telemetry Vertical". The fail-fast property remains correctly described as dispatcher-chain only, not Run-state. |
| **P0-4** Engine-envelope YAML not packaged in jar | ACCEPT | `agent-platform/pom.xml` `<build>` now declares a `<resources>` rule copying `docs/contracts/{engine-envelope,engine-hooks,s2c-callback}.v1.yaml` from `${project.basedir}/../docs/contracts` into `target/classes/docs/contracts/` at package time. New `EngineRegistryClasspathBootIT` (enforcer **E91**) boots Spring with a filesystem-absent schema path and proves the classpath fallback resolves. `EngineAutoConfiguration` Javadoc lines 34-48 updated to describe both launch modes accurately. |
| **P1-1** Conflicting baseline counts | ACCEPT (substance) + REJECT (gate-amendment — see §3) | Single canonical post-rc1 baseline now lives in three synchronized places: release-note top table, `README.md` line 15, and `architecture-status.yaml` `architecture_sync_gate.allowed_claim`. The release-note "Updated counts" addendum table is replaced with a one-paragraph historical pointer to this response document (where the pre-audit → post-audit → post-rc1 evolution lives in §4). No gate change. |
| **P1-2** Test class Javadoc enforcer mis-citations | ACCEPT | `S2cCallbackRoundTripIT.java` line 39 corrected `#E83` → `#E82` (E83 is the no-`Thread.sleep` ArchUnit; E82 is this IT). `EngineRegistryBootValidationIT.java` Javadoc corrected `#E81` → `#E84` (E81 is the S2C gate-script; E84 is this IT). NEW gate sub-rule **28k** (`javadoc_enforcer_citation_semantic_check`) scans `*Test.java`/`*IT.java` for `enforcers.yaml#E\d+` citations and asserts each cited E-row's `artifact:` path matches the source file; 2 self-tests (positive + negative) pass. |
| **§4 PlanProjection contract** | ACCEPT (design-only) | NEW `docs/contracts/plan-projection.v1.yaml` declared with `status: design_only` and `runtime_enforced: false`. Bridges ADR-0032 (PlanState) ↔ ADR-0052 (SkillResourceMatrix) without claiming runtime enforcement. The schema names required + optional fields, scheduler-contract questions, and a deferred-runtime-binding block keyed to W2 scheduler wave. |
| **§4 GraphMemoryRepository comment cleanup** | ACCEPT | `GraphMemoryRepository.java` Javadoc rewritten — "tenant's knowledge graph" replaced with "platform or explicitly delegated graph memory" (ADR-0051 ownership boundary); ownership-discriminator W2 plan referenced inline. |
| **§4 Skill-capacity orchestration binding** | ACCEPT (already-deferred strengthened) | `CLAUDE-deferred.md` 46.b extended to make the W2 contract explicit: over-capacity skill use suspends ONLY the dependent step, not the whole Run nor unrelated LLM threads (2D defence per Rule 41 at sub-Run granularity). |
| **§5 overdesign labels** | ACCEPT (scope-tighten to W2.x contracts) | Five W2.x contracts gained explicit `status:` header fields: `engine-envelope.v1.yaml` → `runtime_enforced`; `engine-hooks.v1.yaml` → `runtime_enforced` (delivery) with `outcome_consumption_status: design_only` (per 45.b); `s2c-callback.v1.yaml` → `runtime_enforced`; `evolution-scope.v1.yaml` → `schema_shipped`; `plan-projection.v1.yaml` → `design_only`. Retroactive corpus-wide sweep deferred to a separate W2.x.1 wave. |
| **Tag retraction** | ACCEPT | `v2.0.0-w2x-final` deleted from origin (user-authorized destructive action). `v2.0.0-rc1` annotated tag pushed in its place after all rc1 fixes land and verify GREEN. |

## 3. Explicit REJECTs (with reasoning)

### REJECT 1 — P0-2 mechanism description (substance accepted, mechanism re-described)

The review wrote:

> "those exceptions are thrown inside the catch (S2cCallbackSignal) block at line 110 and are not caught by the later catch (RuntimeException) branch, which means the documented SUSPENDED → FAILED transition is not guaranteed."

The substance is correct (the Run was stuck in SUSPENDED), but the Java semantics in the explanation are off. Sibling `catch` clauses in the **same** `try` statement cannot catch exceptions thrown from each other's bodies — once a `catch` block starts executing, the active handler scope is that one catch, and any exception it throws escapes the entire `try` to the caller. A reader who took the review's mechanism literally might expect a fix to involve "catching the RuntimeException in the later branch", which would not be valid Java. The actual fix is to wrap `handleClientCallback` in its own inner `try`, exactly as plan C / `SyncOrchestrator.java` now does. The response is structurally identical, but we want the mechanism record to be accurate for future readers.

### REJECT 2 — P1-1 gate-amendment recommendation (substance accepted, fix shape differs)

The review recommended:

> "Extend Gate Rule 28 to detect 'Updated counts' / addendum tables, or forbid later contradictory count tables unless marked historical."

We reject the gate-amendment shape. Teaching the gate to parse multiple count tables and decide which is canonical is over-engineering when the simpler fix is **single canonical baseline**: kill the addendum table; require release-note, README, and `architecture-status.yaml#allowed_claim` to agree. The existing `release_note_baseline_truth` gate already enforces a single-source comparison; we only needed to delete the contradictory addendum. The narrative content the addendum carried lives in this response document and the W2.x release note's historical narrative paragraph.

## 4. Updated baseline counts (single canonical, post-rc1)

| metric | pre-audit (W2.x Phase 6) | post-audit (W2.x Phase 7) | post-rc1 (this response) |
|---|---|---|---|
| §4 constraints | 65 | 65 | **65** |
| Active ADRs | 77 | 77 | **77** |
| Active gate rules | 60 | 60 | **60** |
| Gate self-test cases | 82 | 84 | **86** (+2 for Rule 28k) |
| Active engineering rules | 34 | 34 | **34** |
| Deferred sub-clauses | 11 | 16 | **17** (+45.b) |
| Layer-0 governing principles | 13 | 13 | **13** |
| Enforcer rows | 87 | 89 | **91** (+E90 S2C FAILED IT, +E91 classpath IT) |
| Maven tests GREEN (`mvn verify`) | 200 (under `test` only — S2C IT was red under `verify`) | 208 (still verified under `test`) | **213** under `mvn verify` |
| Architecture-graph nodes / edges | 219 / 272 | 242 / 318 | **246 / 323** |

The post-rc1 column is the canonical baseline. The pre-audit and post-audit columns are historical record.

## 5. Verification commands reviewers can run

```text
# Clean reactor build + Surefire + Failsafe
./mvnw clean verify

# Gate (60 rules + 28a..28k sub-checks):
bash gate/check_architecture_sync.sh
# Expected: PASS

# Gate self-tests (86 cases):
bash gate/test_architecture_sync_gate.sh
# Expected: Tests passed: 86/86

# Architecture graph idempotency:
python gate/build_architecture_graph.py
# Expected: Wrote docs/governance/architecture-graph.yaml: 246 nodes, 323 edges; Graph validation: OK

# Single-canonical baseline check:
grep -E '91 enforcer rows|86 self-tests|213 Maven' \
  docs/releases/2026-05-16-W2x-engine-contract-wave.en.md \
  README.md \
  docs/governance/architecture-status.yaml
# Expected: each phrase appears in all three files exactly once

# E90 + E91 enforcer rows resolve:
ls -la \
  agent-runtime/src/test/java/ascend/springai/runtime/s2c/S2cFailureTransitionsRunToFailedIT.java \
  agent-platform/src/test/java/ascend/springai/platform/engine/EngineRegistryClasspathBootIT.java
# Expected: both files present
```

## 6. Open items (deferred with explicit triggers)

| Deferred clause | Trigger | Origin |
|---|---|---|
| **45.b** HookOutcome Run-state consumption | First consumer hook (TokenCounterHook / PiiRedactionHook etc.) lands in W2 Telemetry Vertical | This response, §P0-3 |
| **46.b** ResilienceContract s2c.client.callback wiring (strengthened: per-step suspension granularity) | First production S2C deployment with > 1 concurrent client | This response, §4 |
| **44.b** Run.engineType persistence | First W2+ Postgres-backed orchestrator | Phase 7 audit |
| **44.c** Parent-Run propagation on child failure | First W2 async orchestrator | Phase 7 audit |
| **48.b** W3 prose-enum schema-first retrofit | 2026-09-30 default sunset; advanced earlier via ADR | Phase 7 audit |
| **48.c** EngineEnvelope strict-construction validation | First EngineEnvelope construction outside Spring-boot test harness | Phase 7 audit |
| Planner ↔ scheduler bridge runtime binding | First non-in-memory scheduler implementation | This response, §4 (plan-projection.v1.yaml `deferred_runtime_binding`) |
| Retroactive `status:` labelling across pre-W2.x contracts | Separate W2.x.1 wave | This response, §5 reject scoping |

## 7. Process learning captured to memory

The single most important process learning from this review cycle: **release verification MUST run `mvn verify` (Failsafe phase) not just `mvn test` (Surefire) whenever any cited enforcer is an `*IT.java` class.** The Phase 7 audit's `mvn test` run reported 208/208 GREEN, but `S2cCallbackRoundTripIT` was failing 4/4 under `verify`. The mismatch existed for hours before the post-release review caught it. A memory entry (`feedback_release_verify_runs_failsafe.md`) records this so future release-verification commands default to `verify` whenever the touched diff contains `*IT.java` files or the enforcer index cites `*IT.java` artifacts.

## 8. Acknowledgement of reviewer rigor

The post-release review identified four ship-blocking defects in artefacts that had just passed a multi-dimensional self-audit. The pattern of "audit verifies the wrong Maven phase" is exactly the kind of meta-error that internal review cycles tend to miss — the reviewer's outside perspective and the willingness to run `./mvnw verify` (not just `./mvnw test`) was the decisive value-add. The accept-rate of 6/6 P0/P1 + 4/4 §4 items reflects that the review was substantively correct on every count; the two REJECTs are about fix shape, not findings.

We will run `./mvnw clean verify` in all future release verification.
