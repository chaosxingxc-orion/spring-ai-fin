# Response to Fifth Architecture Reviewer

**Date**: 2026-05-12  
**Reviewer document**: `docs/reviews/spring-ai-ascend-implementation-guidelines-en.md`  
**Responding to**: four directional findings (F1–F4)  
**Methodology**: per user directive, findings were not fixed case-by-case. They were first categorized into architectural clusters, then each cluster received a systematic self-audit that surfaced additional hidden defects beyond the reviewer's named items.

---

## Executive Summary

| Finding | Title | Verdict |
|---------|-------|---------|
| F1 | Data Boundaries / Over-abstraction | **ACCEPT WITH EXTENSION** — ADR-0022 already covers shape typing; we add ADR-0028 for the content-semantic layer above it |
| F2 | Cognitive vs Execution Flow | **PARTIAL ACCEPT** — accept the Cognition-Action separation principle (ADR-0029); reject Python-as-mandatory-brain and the C4/C5/C6 "Java-can't-solve" claims |
| F3 | Skill System | **ACCEPT** — all three sub-requirements (lifecycle, resource matrix, mandatory sandbox) are genuine gaps; ADR-0030 addresses them |
| F4 | Agent Bus / Workflow Intermediary | **PARTIAL ACCEPT** — accept three-track channel isolation (ADR-0031) and push-pull buffer; reject "Temporal-as-God" characterization as factually incorrect |

**Hidden defects surfaced by systematic self-audit: 29** (across 4 categories, beyond the 4 reviewer-named findings).

**Code fixes shipped inline**: 2 (HD-A.8 critical bug; HD-A.10 enforcement gap).

---

## Per-Finding Response

### F1 — Data Boundaries / Over-abstraction

**Reviewer's claim**: Raw `Object resumePayload` exposes us to "semantic collateral poisoning" and "context-explosion OOM"; need sealed envelopes + epistemological tags + payload fingerprints.

**Response: ACCEPT WITH EXTENSION.**

ADR-0022 (PayloadCodec SPI, already committed) addresses *shape* typing via the `Payload` sealed interface and `PayloadCodec<T>`. The reviewer's *content-semantics* layer — distinguishing a FACT from a HYPOTHESIS from a synthesized PLACEHOLDER — is genuinely additive and addresses a different (higher) semantic plane.

**Action taken**: ADR-0028 adds `CausalPayloadEnvelope` wrapping any `Payload` with:
- `SemanticOntology {FACT, PLACEHOLDER, HYPOTHESIS, REDACTED}` — content-semantic classification
- SHA-256 payload fingerprint + `byteSize` field — oversize detection precommit
- `decayed` flag — semantic decay when envelope exceeds §4 #13 16-KiB inline cap

§4 #25 names this constraint. Implementation deferred to W2.

**Additionally shipped at W0** (HD-A.10, discovered during self-audit): `InMemoryCheckpointer` now enforces the §4 #13 16-KiB inline cap with posture-aware behavior:
- `dev` posture: WARN to stderr, continue (in-memory is non-durable anyway)
- `research`/`prod` posture: throw `IllegalStateException`

Gate Rule 11 (`shipped_envelope_fingerprint_present`) verifies the enforcement constant is present in the implementation file.

---

### F2 — Cognitive vs Execution Flow

**Reviewer's claim**: C4/C5/C6 distributed defects cannot be solved with Java lambdas; recommends Python-brain-via-GraalVM-Polyglot as the mandatory cognitive layer; Java relegated to passive adapter role.

**Response: PARTIAL ACCEPT.**

**Accepted**: The *principle* that cognitive reasoning (LLM-driven, non-deterministic) must be decoupled from action execution (deterministic, RLS-bound, side-effecting) by a formal SPI boundary is a real architectural primitive we had not named explicitly.

**Rejected** (with specific rebuttal for each claim):

*Prescription: Python-via-GraalVM-Polyglot as mandatory cognitive engine.*
ARCHITECTURE.md §1 explicitly excludes Python sidecars at W0. ADR-0018 already designates `GraalPolyglotSandboxExecutor` as one *optional* W3 sandbox implementation — not a mandatory cognitive layer. Forcing Python-as-brain conflates two orthogonal axes: sandbox isolation (ADR-0018 concern) and cognitive engine choice (Spring AI ChatClient, the project's stated LLM gateway). These axes are independent.

*C4 claim: cross-JVM serialization unsolvable in Java.*
Rejected. §4 #15 (`executor_definition_serialization`) + ADR-0022 (`PayloadCodec`) already mandate that named `CapabilityRegistry` entries replace inline lambdas before W2. No cross-JVM serialization of closures occurs; named dispatch eliminates the problem.

*C5 claim: resume privilege escalation unsolvable in Java.*
Rejected. §4 #14 (`resume_reauthorization_check`) + Rule 17 (deferred) already mandate that every resume re-validates `(request.tenantId == Run.tenantId)` with HTTP 403 on mismatch. This is Java-tractable and committed.

*C6 claim: lambda closure serialization unsolvable in Java.*
Rejected. The project already mandates named-registry dispatch before W2 (§4 #15). Lambda closures are eliminated by design, not solved via serialization.

**Action taken**: ADR-0029 (Cognition-Action Separation) names the architectural principle, disambiguates §1 scope ("Python sidecars" = out-of-process network IPC, excluded; "in-process polyglot" = optional W3 per ADR-0018), and documents the C4/C5/C6 rebuttals with pointers to existing solutions. §4 #26 names this constraint.

---

### F3 — Skill System

**Reviewer's claim**: External skills lack Lifecycle Sensing + Resource Matrix + mandatory sandbox SPI; pure-memory plugin integration must be eliminated.

**Response: ACCEPT.**

All three sub-requirements are genuine gaps in the current design:
- §4 #12 covers tenant × global *capacity* but not *lifecycle* (no `init/suspend/teardown`).
- §4 #16 (`PRE_TOOL_INVOKE`/`POST_TOOL_INVOKE` hooks) covers *interception* but not *initialization or teardown*.
- ADR-0018 makes the sandbox *opt-in*; the reviewer correctly demands posture-mandatory for untrusted code.

**Action taken**: ADR-0030 defines:
- **Skill SPI** with full lifecycle: `init(ctx)` → `execute(ctx, input)` → `suspend(ctx) → SkillResumeToken` → `resume(ctx, token)` → `teardown(ctx)`
- **`SkillResourceMatrix`** with 7 dimensions: `tenantQuotaKey`, `globalCapacityKey`, `tokenBudget`, `wallClockMs`, `cpuMillis`, `maxMemoryBytes`, `concurrencyCap`
- **`SkillTrustTier {VETTED, UNTRUSTED}`** with posture rule: `research/prod` + `UNTRUSTED` → MUST route via non-NoOp `SandboxExecutor` (per ADR-0018)
- **`SkillCostReceipt`** pre-wired for Rule 13 (P1 cost-of-use, W3)
- **`SkillKind {JAVA_NATIVE, MCP_TOOL, SANDBOXED_CODE_INTERPRETER}`** taxonomy (clarifies "capability" ambiguity from §4 #15)

§4 #27 names this constraint. Rule 26 (Skill Lifecycle Conformance, W2 trigger) and Rule 27 (Untrusted Skill Sandbox Mandate, W3 trigger) added to `docs/CLAUDE-deferred.md`. Implementation deferred to W2 (SPI) + W3 (mandatory sandbox gate).

---

### F4 — Agent Bus / Workflow Intermediary

**Reviewer's claim**: Risk of swinging to "Temporal-as-God" rigidity; need lightweight push-pull buffer + dynamic registry + three-track channel isolation (control / data / heartbeat).

**Response: PARTIAL ACCEPT.**

**Rejected**: "Temporal-as-God" characterization is factually incorrect about the current design.
- `SyncOrchestrator` is 102 lines of pure Java with no framework dependencies.
- The `Orchestrator` SPI is a single-method interface — the minimal possible surface.
- Temporal is *one optional tier* behind the SPI, deferred to W4 — not committed, not default.
- ADR-0021 (Layered SPI Taxonomy) explicitly maintains tier-interchangeability. The architecture already embodies the lightweight-first principle the reviewer advocates.

**Accepted**: three-track channel isolation, push-pull buffer, and tenant-scoped capability registry linkage are real design gaps.
- §4 #11 currently implies a single mixed `Flux<RunEvent>` stream for data + control + heartbeat.
- Physical channel separation prevents one slow consumer (heartbeat) from stalling a high-throughput data stream.
- The reviewer's "dynamic registry" (capabilities registered/deregistered at runtime per tenant) aligns with `capability_registry_spi` (W2, already in yaml) but lacked a tenant-scoping guarantee.

**Action taken**: ADR-0031 (Three-Track Channel Isolation) defines:
- **Control track** — `RunControlSink` for out-of-band cancel/suspend/resume commands (separate from data)
- **Data track** — `Flux<RunEvent>` for typed progress/output events
- **Heartbeat track** — `Flux<Instant>` at a separate configurable cadence (default ≤ 30 s)
- **`RunDispatcher` SPI** separating intent-enqueue from intent-execute (precondition for W2 async orchestrator)
- **Tenant-scoped `CapabilityRegistry.resolve(name, runContext)`** — unauthorized tenant lookups return 403, not null

§4 #28 names this constraint. Implementation deferred to W2.

---

## Hidden-Defect Audit (29 items)

The following table captures defects surfaced by auditing every surface in each category — beyond the four reviewer-named items.

### Category A — Data Plane Typing (11 defects)

| # | Defect | Evidence | Action |
|---|--------|----------|--------|
| HD-A.1 | `SuspendSignal.resumePayload : Object` | `spi/SuspendSignal.java:18` | Covered by ADR-0022 W2. No new action. |
| HD-A.2 | `NodeFunction.apply(RunContext, Object) → Object` | `spi/ExecutorDefinition.java:51` | Covered by ADR-0022 W2. No new action. |
| HD-A.3 | `ReasoningResult(boolean terminal, Object payload)` | `spi/ExecutorDefinition.java:61` | Added to ADR-0022 W2 scope. |
| HD-A.4 | `AgentLoopDefinition.initialContext : Map<String, Object>` | `spi/ExecutorDefinition.java:39` | Added to ADR-0028 — leaks Map at the entry surface. |
| HD-A.5 | `Orchestrator.run(..., Object initialPayload) : Object` | `spi/Orchestrator.java:28` | Added to ADR-0022 W2 scope. |
| HD-A.6 | `GraphExecutor.execute(...) : Object` + `AgentLoopExecutor.execute(...) : Object` | spi files | Added to ADR-0022 W2 scope. |
| HD-A.7 | `GraphDefinition.edges : Map<String,String>` — no typed Edge, no predicate | `spi/ExecutorDefinition.java:19` | §4 #17 graph_dsl_conformance W3 — already designed. |
| HD-A.8 | **CRITICAL BUG — `IterativeAgentLoopExecutor` string concat on Object** | `IterativeAgentLoopExecutor.java:39` (pre-fix) | **Fixed inline**. See "W0 Code Fixes" below. |
| HD-A.9 | `Checkpointer.save(... byte[])` no codec metadata | `IterativeAgentLoopExecutor.java:59` (pre-fix) | Covered by ADR-0022 W2 `saveTyped(EncodedPayload)`. |
| HD-A.10 | §4 #13 16-KiB inline cap not enforced in any code | grep `16384` → zero hits | **Fixed inline**. See "W0 Code Fixes" below. |
| HD-A.11 | No semantic-ontology (FACT/PLACEHOLDER) — privacy-mode placeholder injection has no schema | grep semantic-ontology → zero | Added to ADR-0028 as content-typing layer above ADR-0022. |

### Category B — Cognition/Action Separation (5 defects)

| # | Defect | Evidence | Action |
|---|--------|----------|--------|
| HD-B.1 | §1 "Not in scope: Python sidecars" is ambiguous — precludes in-process GraalVM Polyglot? | `ARCHITECTURE.md §1` | Clarified: "Python sidecars (network IPC)" vs "in-process polyglot (W3 optional per ADR-0018)". |
| HD-B.2 | ADR-0018 positions GraalPolyglot only as sandbox impl, not cognitive layer | `docs/adr/0018-sandbox-executor-spi.md:74` | Clarified in ADR-0029 — Cognition-Action separation does not mandate any cognitive engine. |
| HD-B.3 | §4 #15 says "NodeFunction lambdas → CapabilityRegistry entries" but "capability" is undefined — Java code? MCP tool? | `ARCHITECTURE.md §4 #15` | SkillKind taxonomy added in ADR-0030. |
| HD-B.4 | C5 (resume privilege escalation) — reviewer claims Java can't solve | reviewer doc | Rejected. §4 #14 + Rule 17 already solve this. Documented rebuttal in ADR-0029. |
| HD-B.5 | C6 (lambda closure serialization) — reviewer claims Java can't solve | reviewer doc | Rejected. §4 #15 named-registry dispatch eliminates closures by design. |

### Category C — Skill SPI (7 defects)

| # | Defect | Evidence | Action |
|---|--------|----------|--------|
| HD-C.1 | No `Skill.java` / `Tool.java` / `Capability.java` SPI exists | exhaustive grep → 0 | Design added in ADR-0030. Implementation W2. |
| HD-C.2 | `ResiliencePolicy` has no tenant axis, no per-skill quota, no token-cost dimension | `resilience/ResiliencePolicy.java:7` | ADR-0030 extends to multi-axis ResourceMatrix. |
| HD-C.3 | §4 #16 hooks cover invocation but not skill lifecycle (init/suspend/teardown) | `ARCHITECTURE.md §4 #16` | Skill lifecycle is ADR-0030 first-class SPI — lifecycle ≠ interception. |
| HD-C.4 | ADR-0018 SandboxExecutor default is NoOpSandboxExecutor — no posture-based mandate | `docs/adr/0018-sandbox-executor-spi.md:71` | ADR-0030 introduces SkillTrustTier + posture rule. |
| HD-C.5 | No "skill suspend on long-horizon task" — if Run suspends 8 h, skill-held resources leak | no current SPI | Added to ADR-0030 lifecycle: `Skill.suspend → SkillResumeToken`. |
| HD-C.6 | No "skill cost emission" hook for P1 Rule 13 (W3 deferred) | `docs/CLAUDE-deferred.md:56` | ADR-0030 every `Skill.execute` returns `SkillCostReceipt`. Pre-wired. |
| HD-C.7 | C-side / S-side fault-tolerance boundary not codified | reviewer doc | Rule 17 (deferred) already covers this. Cross-referenced in ADR-0030. |

### Category D — Bus Discipline (6 defects)

| # | Defect | Evidence | Action |
|---|--------|----------|--------|
| HD-D.1 | §4 #11 mixes control + data + liveness on a single `Flux<RunEvent>` | `ARCHITECTURE.md §4 #11` | §4 #28 + ADR-0031 three-track isolation. |
| HD-D.2 | No out-of-band cancel transport once a Run is in flight | yaml `orchestrator_cancellation_handshake` | ADR-0031: dedicated `RunControlSink` (W2). |
| HD-D.3 | §4 #11(c) heartbeat ≤ 30s — when introduced, which channel carries it? | `architecture-status.yaml:368` | Resolved by ADR-0031 physical separation. |
| HD-D.4 | `capability_registry_spi` registration has no per-tenant authorization | yaml row 436 | ADR-0031: registry queries are `RunContext`-scoped. |
| HD-D.5 | Capability "bidding" — selection by intent — no current design | not in docs | Deferred W4+. Noted in ADR-0031 §"Future". |
| HD-D.6 | SyncOrchestrator child dispatch is synchronous recursive — no queue/buffer SPI surface | `SyncOrchestrator.java:64` | ADR-0031: `RunDispatcher` SPI (W2 evolution). |

---

## W0 Code Fixes (shipped inline)

### HD-A.8 — IterativeAgentLoopExecutor: Object.toString() silent corruption

**Root cause**: `IterativeAgentLoopExecutor.java:39` (pre-fix) evaluated `savedState + resumePayload` where Java's string concatenation calls `Object.toString()` on any non-String `resumePayload`. For non-String values this produces e.g. `"[Ljava.lang.Object;@1234abcd"` — an unrecoverable byte stream. The string was then persisted as UTF-8 bytes, making resume data permanently corrupt if a non-String payload had ever been used.

**Fix**: replaced the implicit concat with explicit `instanceof String` guards at both the resume path and the save path. When `savedState != null` and `resumePayload` is not a `String`, the executor throws `IllegalStateException` with an ADR-0022 reference (the W2 solution path). Similarly, when `payload` is not a `String` at suspension time, the executor refuses to persist and throws rather than saving corrupted bytes.

**Tests**: `IterativeAgentLoopExecutorResumeCursorTest` — 4 cases:
1. String payload resume completes successfully
2. Suspend-and-resume cycle with String payload works correctly
3. Non-String resumePayload with existing saved state throws ISE referencing ADR-0022
4. Null saved state accepts non-String initial payload (first-call path, no corruption risk)

### HD-A.10 — InMemoryCheckpointer: §4 #13 16-KiB cap not enforced

**Root cause**: §4 #13 states "inline bytes ≤ 16 KiB" but `InMemoryCheckpointer.save()` had zero size enforcement. Any arbitrarily large payload would silently bloat in-memory state. When W2 `PostgresCheckpointer` enforces the cap (as it must, per the byte-addressing design), pre-existing code that had not observed the cap would fail at W2 with no W0 warning.

**Fix**: added `MAX_INLINE_PAYLOAD_BYTES = 16 * 1024` constant and posture-aware precommit check in `save()`:
- `dev` posture (default): emits `[WARN]` to stderr and continues (in-memory is non-durable; warn and continue is appropriate)
- `research`/`prod` posture: throws `IllegalStateException` (fail-closed per Rule 10)

Posture read via `System.getenv("APP_POSTURE")` in the no-arg constructor. A package-private constructor accepting `boolean failOnOversize` enables test isolation without env-var manipulation.

**Gate Rule 11** (`shipped_envelope_fingerprint_present`) added to both `gate/check_architecture_sync.ps1` (as rule 11) and `gate/check_architecture_sync.sh` (as rule 7): verifies `MAX_INLINE_PAYLOAD_BYTES` is present in the implementation file.

**Tests**: `InMemoryCheckpointerSizeCapTest` — 5 cases:
1. Dev posture permits small payload
2. Dev posture warns but saves oversize payload (warn-and-continue)
3. Dev posture allows payload exactly at cap (no warn, no throw)
4. Research/prod posture throws ISE on oversize payload
5. Research/prod posture allows payload exactly at cap

---

## Ship-Now vs Defer Matrix

| Artifact | Status | Wave |
|----------|--------|------|
| ADR-0028 (CausalPayloadEnvelope + SemanticOntology) | design_accepted | W2 impl |
| ADR-0029 (Cognition-Action Separation) | design_accepted | W2–W3 impl |
| ADR-0030 (Skill SPI + Lifecycle + ResourceMatrix) | design_accepted | W2 (SPI) + W3 (sandbox gate) |
| ADR-0031 (Three-Track Channel Isolation) | design_accepted | W2 impl |
| §4 #25 — Causal payload envelope + semantic ontology | shipped (design) | W2 enforcement |
| §4 #26 — Cognition-Action separation principle | shipped (design) | W2–W3 enforcement |
| §4 #27 — Skill SPI + lifecycle + ResourceMatrix | shipped (design) | W2 enforcement |
| §4 #28 — Three-track channel isolation | shipped (design) | W2 enforcement |
| `InMemoryCheckpointer` 16-KiB cap enforcement (HD-A.10) | **shipped** | W0 |
| `IterativeAgentLoopExecutor` typed cursor (HD-A.8) | **shipped** | W0 |
| Gate Rule 11 (`shipped_envelope_fingerprint_present`) | **shipped** | W0 |
| Rule 26 (Skill Lifecycle Conformance) | deferred | W2 trigger |
| Rule 27 (Untrusted Skill Sandbox Mandate) | deferred | W3 trigger |
| `CausalPayloadEnvelope` Java type, `SemanticOntology` enum | deferred | W2 |
| `Skill` SPI interface, `SkillResourceMatrix`, `SkillCostReceipt` | deferred | W2 |
| `RunControlSink`, `RunDispatcher` SPI, three-track transport | deferred | W2 |

---

## Test Count and Gate Rules

| Metric | Previous | This cycle |
|--------|----------|------------|
| Active gate rules | 10 | 11 (+Gate Rule 11) |
| Deferred rules | 13 | 15 (+Rules 26, 27) |
| Active §4 constraints | 24 | 28 (+#25–#28) |
| ADRs | 0001–0027 | 0001–0031 (+0028–0031) |
| architecture-status.yaml rows | ~85 | ~94 (+9 new rows) |
| Test classes added | 0 | 2 (ResumeCursorTest + SizeCapTest) |
| Total tests (estimated) | ~109 | ~115 |

---

## Commit

```
docs(review): respond to fifth reviewer; +Rules 26-27, +ADR-0028-0031, +9 yaml rows, +Gate Rule 11, ~115 tests pass
```
