# spring-ai-fin Systematic Architecture Improvement Plan

**Date**: 2026-05-07  
**Scope**: Architecture corpus under `D:/chao_workspace/spring-ai-fin`  
**Audience**: Architecture committee, platform engineers, security reviewers, release captains  
**Current classification**: Security-first proof-of-concept design baseline. Not production architecture. Not implementation-ready without the W0 gates below.

---

## 1. Executive Judgment

The current `spring-ai-fin` repository contains a serious and useful architecture design corpus, but it does not yet contain an engineering architecture that can be verified by build, test, runtime, or delivery evidence.

The design has moved in the right direction compared with v5.0:

- v5.0 component sprawl was reduced.
- The platform/business boundary is now explicit.
- The three-posture model is the right organizing principle.
- The ActionGuard idea correctly centralizes model/tool side-effect authorization.
- Tenant context and contract spine are treated as first-class concerns.
- Outbox, saga, and direct database writes are no longer described as one universal consistency mechanism.

However, the current corpus still has a hard governance problem: many documents describe target classes, tests, scripts, and closure states that do not exist yet. Some post-security-review updates exist at L0 but are not consistently propagated into L2 subsystem documents. As a result, a reviewer cannot reliably tell whether a statement is proposed, accepted, implemented, tested, or operator-gated.

The strongest valid reading is:

> `spring-ai-fin` is approved only as an architecture direction and PoC baseline. It must pass a W0 evidence wave before implementation can proceed as a governed platform program.

---

## 2. Root-Cause Block

**Observed failure**: The repository claims Spring Boot + Spring AI, two Maven modules, CI gates, route tests, operator-shape gates, and security closures, but the filesystem currently contains only Markdown documents and `.gitignore`.

**Execution path**: `README.md` and `ARCHITECTURE.md` describe a pre-implementation corpus. L0 and L2 documents then reference Java classes, Maven modules, tests, scripts, delivery artifacts, and CI gates. A repository inventory shows no `pom.xml`, no source files, no test tree, no gate scripts, no `docs/delivery`, and no `docs/plans`.

**Root cause statement**: Architecture claims were promoted through document edits before a status model and evidence gate existed, which allows "accepted", "designed", "closed", "implemented", and "verified" to collapse into the same narrative state.

**Evidence**:

- `README.md` says the repository is pre-implementation and pending committee review.
- `ARCHITECTURE.md` says current state is planning with no implementation yet.
- `ARCHITECTURE.md` lists "No code yet", "Operator-shape gate scripts not written", "Spine-validation framework not coded", and other W1 deliverables.
- The repository inventory contains Markdown files only.

---

## 3. Improvement Principles

Every correction below follows five principles.

1. **Evidence before claims**  
   A capability cannot be reported above its evidence level. A design document can accept a finding, but it cannot close it without implementation, tests, and gate evidence.

2. **One truth source per concern**  
   Posture, maturity, identity policy, financial write classification, route inventory, and security-control status each need one machine-readable source of truth.

3. **L0 and L2 must not drift**  
   If L0 changes a hard platform decision, every affected L2 document must be updated in the same wave.

4. **Security controls must be runtime controls**  
   Load-time approval is not enough for tools, skills, sidecars, LLM output, and financial actions. The dangerous boundary is model output becoming a side effect.

5. **Operator shape is the delivery shape**  
   Unit and integration tests are necessary but insufficient. The first runnable artifact must prove process lifetime, real dependencies, cancellation, observability, and fallback-zero behavior.

---

## 4. Finding Categories and Corrections

### 4.1 Evidence and Status Governance

**Problem**

The corpus uses strong closure language before implementation exists. The security response says all P0 and P1 findings are accepted and that documents were amended, but several subsystem documents still carry older semantics. There are also future-dated `2026-05-08` artifacts inside a repository whose current review date is `2026-05-07`.

**Architectural risk**

This breaks auditability. In a regulated financial platform, a future reviewer must be able to distinguish:

- A concern that was found.
- A concern that was accepted.
- A concern that was designed.
- A concern that was implemented.
- A concern that passed test and operator gates.

**Required correction**

Create `docs/governance/architecture-status.yaml` as the single status ledger:

```yaml
capabilities:
  action_guard:
    status: design_accepted
    maturity: L0
    l0_decision: ARCHITECTURE.md#d-18
    l2_document: agent-runtime/action-guard/ARCHITECTURE.md
    implementation: null
    tests: []
    operator_gate: null
    open_findings:
      - P0-1
```

Allowed statuses:

- `proposed`
- `design_accepted`
- `implemented`
- `test_verified`
- `operator_gated`
- `released`

Policy:

- `closed` is not an allowed status.
- A finding is not closed until it reaches at least `test_verified`.
- A production claim requires `operator_gated`.
- Future-dated documents must be renamed, re-dated, or marked as proposed drafts.

---

### 4.2 L0/L1/L2 Consistency

**Problem**

L0 now states that research/prod should use RS256 or ES256 with JWKS, while `agent-runtime/auth/ARCHITECTURE.md` still states that v1 uses HS256 only and defers RS256 to v1.1.

Similar drift exists around prompt security, skill runtime authorization, sidecar hardening, audit classes, financial write classes, and observability privacy.

**Architectural risk**

The implementation team will not know which document to follow. Worse, two teams could implement incompatible security models while both believing they are compliant.

**Required correction**

Add a document consistency gate:

```text
docs/governance/decision-sync-matrix.md
```

For every hard L0 decision, include:

- Decision id.
- Affected L1 documents.
- Affected L2 documents.
- Required implementation file paths.
- Required tests.
- Required gate evidence.
- Current status.

Then add a simple script later:

```text
scripts/check_architecture_sync.*
```

The first version can be a deterministic text check. It should fail when a decision claims a detail section that does not exist.

---

### 4.3 Contract and API Implementability

**Problem**

The public contract document defines `ContractError` as a Java record implementing `Throwable`. That is not a valid Java type shape. A record can implement interfaces, but `Throwable` is a class.

There is also a posture leak inside contract constructors: `RunRequest` calls `System.getenv("APP_POSTURE")` directly. This conflicts with the platform rule that posture is read once at boot and injected.

**Architectural risk**

The frozen v1 contract could be non-compilable or environment-dependent. That would break the core promise of a stable northbound contract.

**Required correction**

Use two separate concepts:

```java
public record ContractError(
    String code,
    String message,
    Object detail,
    String traceId,
    Instant occurredAt
) {}

public final class ContractException extends RuntimeException {
    private final ContractError error;
}
```

Contract records should enforce shape invariants only:

- Required fields are present.
- Strings are not blank where forbidden.
- Size limits are enforced.
- Type-level constraints hold.

Posture-specific enforcement belongs in validators or facades that receive injected `AppPosture`.

---

### 4.4 Identity, Posture, and Tenant Isolation

**Problem**

The posture model is directionally correct, but `DEV` defaults remain unsafe if accidentally used outside localhost or with real dependencies. The auth design also has inconsistent HS256 versus RS256/JWKS rules across documents.

**Architectural risk**

The largest practical failure mode is not a cryptographic bug. It is a pilot deployment accidentally running permissive dev posture with real data, real sidecars, or real LLM credentials.

**Required correction**

Define `PostureBootGuard` as a hard boot gate:

```text
If APP_POSTURE is unset:
  allow only loopback bind, no real DB, no real LLM, no sidecar, no external MCP.

If APP_POSTURE=dev:
  require ALLOW_DEV_WITH_REAL_DB=true for real database.
  require ALLOW_DEV_WITH_REAL_LLM=true for real LLM credentials.
  require ALLOW_DEV_NON_LOOPBACK=true for non-loopback bind.

If APP_POSTURE=research:
  require durable DB.
  require JWT.
  require strict tenant spine.
  require real LLM only if the route exercises LLM behavior.

If APP_POSTURE=prod:
  require RS256/ES256 JWKS.
  require gateway conformance.
  require WORM audit readiness.
  require fallback-zero gate.
```

Make identity policy explicit:

- Local dev: anonymous or HS256 allowed only on loopback.
- Research BYOC single tenant: HS256 allowed only with explicit risk acknowledgement.
- Research SaaS multi-tenant: RS256/ES256 JWKS required.
- Prod all shapes: RS256/ES256 JWKS required.

---

### 4.5 ActionGuard and Runtime Authorization

**Problem**

ActionGuard is the right architectural move, but the current stage ordering is internally inconsistent. The pipeline lists `Executor` before `EvidenceWriter`, while the audit decision says PII and financial actions require evidence before action.

**Architectural risk**

An irreversible action could occur before mandatory evidence is persisted. That violates the audit model and can create unprovable PII access or financial mutation.

**Required correction**

Split evidence into pre-action and post-action phases:

```text
ActionEnvelope
  -> SchemaValidator
  -> TenantBindingChecker
  -> ActorAuthorizer
  -> MaturityChecker
  -> EffectClassifier
  -> DataAccessClassifier
  -> OpaPolicyDecider
  -> HitlGate
  -> PreActionEvidenceWriter
  -> Executor
  -> PostActionEvidenceWriter
```

Rules:

- `PII_ACCESS`: pre-action evidence must persist before plaintext reveal.
- `FINANCIAL_ACTION`: evidence must be in the same transaction or saga journal as the action.
- `SECURITY_EVENT`: evidence failure blocks in research/prod.
- `TELEMETRY`: best effort, never blocks.

---

### 4.6 Financial Write Semantics

**Problem**

The outbox design correctly rejects "outbox as universal transaction", but its L2 document still overstates saga behavior with phrases like "strong within saga" and "all-or-nothing across step failure points".

**Architectural risk**

Saga is not ACID. In financial systems, compensation is not the same as the intermediate state never existing. It must create reversal entries, reconciliation evidence, and sometimes human escalation.

**Required correction**

Add `FinancialWriteClass` to the L2 outbox document and implementation plan:

```java
public enum FinancialWriteClass {
    LEDGER_ATOMIC,
    SAGA_COMPENSATED,
    EXTERNAL_SETTLEMENT,
    ADVISORY_ONLY
}
```

Compatibility rules:

- `LEDGER_ATOMIC` requires `DIRECT_DB` and double-entry invariant in one database transaction.
- `SAGA_COMPENSATED` requires `SYNC_SAGA`, per-step idempotency, and reversal journal.
- `EXTERNAL_SETTLEMENT` requires `SYNC_SAGA` plus outbox event and counterparty evidence.
- `ADVISORY_ONLY` may use `OUTBOX_ASYNC` and must not mutate financial state.

Replace "strong within saga" with:

> Saga provides restartable, idempotent, journaled progress with explicit compensations and reconciliation. It is not ACID across entities.

---

### 4.7 Observability, Audit, and Privacy Boundary

**Problem**

The design separates audit from observability in newer documents, but older observability text still implies audit logging and WORM anchoring live inside observability. Privacy controls for logs, metrics, traces, prompts, retrieved chunks, and sidecar metadata are not consistently reflected in all L2 documents.

**Architectural risk**

Optional telemetry and mandatory regulatory evidence can be confused. Sensitive data can leak through logs, traces, prompt cache keys, or metrics labels.

**Required correction**

Use a strict boundary:

- `observability/`: metrics, traces, lifecycle events, fallback records, redaction primitives.
- `audit/`: mandatory evidence, audit classes, WORM anchoring, PII reveal protocol, financial action evidence.

Metrics and traces must never include:

- Raw prompt text.
- Raw retrieved document text.
- PII.
- Tool arguments in full.
- Tokens, credentials, or headers.
- Customer financial values unless bucketed or explicitly approved.

Add `ObservabilityPrivacyPolicy` with tests:

- No raw prompt in logs.
- No PII in metric labels.
- No raw tool arguments in traces.
- Prompt cache stores section-classified content only.

---

### 4.8 Delivery Gate and Operator Shape

**Problem**

The operator-shape gate is well described but not implemented. There are no gate scripts, delivery artifacts, runnable process, or real-dependency evidence.

**Architectural risk**

The architecture could pass committee review while still failing the first real deployment due to process lifetime, dependency wiring, connection reuse, cancellation, or observability gaps.

**Required correction**

Create a W0 delivery gate before feature implementation:

```text
W0 objective:
  Build a minimal runnable skeleton that proves the architecture can be operated.

W0 required outputs:
  root pom.xml
  agent-platform/pom.xml
  agent-runtime/pom.xml
  minimal /health
  minimal /ready
  minimal POST /v1/runs
  minimal GET /v1/runs/{id}
  AppPosture boot read
  ContractError DTO
  RunRecord with tenantId
  real or explicitly fake-free local Postgres path
  gate scripts under gate/
  docs/delivery/<date>-<sha>.md
```

W0 must pass:

- Build exits 0.
- Smoke tests exit 0.
- No mock provider allowed in research/prod gate.
- Non-loopback unset posture fails boot.
- Three sequential runs reuse the same runtime resources.
- Cancellation known run returns 200.
- Cancellation unknown run returns 404.
- Fallback count is zero for the happy path.

---

## 5. Proposed Roadmap

### W0: Evidence Skeleton

Goal: Convert the corpus from "document-only" into a runnable, gateable skeleton.

Deliverables:

- Maven multi-module skeleton.
- Minimal Spring Boot app.
- Posture boot guard.
- Contract DTOs that compile.
- Minimal durable run store.
- First operator-shape gate scripts.
- `docs/delivery` evidence file for the W0 SHA.

Exit criteria:

- `mvn test` passes.
- `gate/run_operator_shape_smoke.*` passes.
- No capability is reported above L1.

### W1: v1 Contract and Run Happy Path

Goal: Make `POST /v1/runs` real under dev and research posture.

Deliverables:

- Route inventory tests.
- TenantContext filter.
- Idempotency reserve/replay.
- Run state machine.
- SSE event stream minimal path.
- Contract freeze digest scaffold.

Exit criteria:

- Dev path accepts loopback-only anonymous mode.
- Research path requires JWT and tenant.
- Cross-tenant event read returns 404.

### W2: Security Gate

Goal: Close the accepted P0 security findings with implementation evidence.

Deliverables:

- ActionGuard mandatory boundary.
- RS256/JWKS validator for research/prod.
- RLS connection-pool protocol.
- Audit class model.
- Prompt section and taint model.
- Sidecar conformance checks if sidecar is enabled.
- Gateway conformance readiness check.

Exit criteria:

- P0 tests pass.
- Security control matrix rows reference real tests.
- No P0 row remains `design_accepted`.

### W3: Financial Write and Outbox Hardening

Goal: Make write consistency explicit and enforceable.

Deliverables:

- `@WriteSite(consistency, financialClass, reason)`.
- `WriteSiteAuditTest`.
- Outbox table and relay.
- Saga journal model.
- Reversal and reconciliation records.

Exit criteria:

- Unannotated write fails CI.
- Direct database writes cannot claim cross-account mutation.
- Saga compensation failure opens an operational gate.

### W4: Multi-Framework Dispatch

Goal: Support Spring AI as default, then LangChain4j and Python sidecar only after the security gate is live.

Deliverables:

- `FrameworkAdapter` interface.
- Spring AI default adapter.
- LangChain4j opt-in adapter.
- Sidecar profile verification.
- Adapter fallback metrics and fallback-zero gate.

Exit criteria:

- Python sidecar is not generally available until identity, payload validation, message limits, cancellation, and supply-chain checks pass.

---

## 6. Required Governance Artifacts

Create these before W1 starts:

```text
docs/governance/architecture-status.yaml
docs/governance/decision-sync-matrix.md
docs/governance/maturity-glossary.md
docs/governance/closure-taxonomy.md
docs/governance/allowlists.yaml
docs/plans/W0-evidence-skeleton.md
docs/delivery/.gitkeep
gate/.gitkeep
```

Minimum policy:

- No `L3` claim without operator-gate evidence.
- No `closed` claim without implementation and regression test.
- No future-dated response documents unless explicitly marked draft.
- No P0 security acceptance without a named implementation wave.
- No L0 decision without L2 synchronization.

---

## 7. Capability Reclassification

Until W0 passes, classify the current system as follows:

| Capability | Current evidence level | Allowed claim |
|---|---:|---|
| L0 architecture boundary | L1 | Documented design |
| `agent-platform` HTTP facade | L0 | Proposed contract |
| `agent-runtime` execution kernel | L0 | Proposed runtime |
| ActionGuard | L0 | Accepted security design |
| Audit class model | L0 | Accepted security design |
| Posture model | L0 | Accepted design with unresolved boot-guard risk |
| TenantContext and spine | L0 | Accepted design, no implementation evidence |
| LLMGateway | L0 | Proposed design |
| Outbox/Saga/Direct-DB | L0 | Proposed design, financial semantics need L2 correction |
| Multi-framework dispatch | L0 | Proposed design |
| Python sidecar profile | L0 | Deployment profile, no runtime evidence |
| Operator-shape gate | L0 | Required gate, not implemented |

Do not report any capability as L2 or L3 until the corresponding implementation, tests, and gate records exist.

---

## 8. Acceptance Criteria for the Improved Architecture

The improved architecture is acceptable only when all of the following are true:

1. Repository status is machine-readable and matches prose claims.
2. L0 decisions have synchronized L2 sections.
3. The public contract compiles.
4. Posture is read once at boot and enforced by boot guard.
5. Research/prod identity policy is unambiguous.
6. TenantContext is enforced through filters, records, database transactions, sidecar payloads, and event streams.
7. ActionGuard gates every side-effectful action.
8. Audit-before-action is enforced for PII and financial actions.
9. Saga semantics are described as compensating and journaled, not ACID.
10. Observability cannot leak prompts, PII, secrets, or raw tool arguments.
11. Operator-shape gate scripts exist and pass against a long-lived process.
12. Delivery evidence is written under `docs/delivery` for the exact SHA under review.

---

## 9. Final Recommendation

Do not expand features yet.

The next useful move is W0: build the evidence skeleton and make the architecture corpus accountable to real files, real tests, and real gate outputs. Once W0 exists, the design can evolve with discipline. Without W0, every additional architecture document increases the surface area of unverified claims.

The architecture direction is promising. The correction is not to add more ambition. The correction is to bind every claim to a status, every status to evidence, and every release to the operator shape downstream will actually run.
