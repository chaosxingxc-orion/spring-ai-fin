# spring-ai-fin Systematic Architecture Remediation Plan

**Date**: 2026-05-08  
**Scope**: `D:/chao_workspace/spring-ai-fin` architecture corpus after the architecture-team response  
**Audience**: Architecture committee, platform engineers, security reviewers, release captains  
**Current classification**: Documented design direction with governance scaffolding. Not yet implementation-verified. Not yet operator-gated.  
**Supersedes for this review cycle**: any local "closed", "fixed", or "production-ready" wording that is not backed by `docs/governance/architecture-status.yaml`, green tests, and a recorded operator-shape gate.

---

## 1. Executive Judgment

The architecture team made meaningful progress after the prior review. The repository now contains a governance ledger, an allowlist format, closure taxonomy, maturity glossary, W0-W4 roadmap, delivery template, and placeholder gate directory. Several subsystem documents also moved in the right direction: `ContractError` is separated from thrown exceptions, posture validation moved out of wire records, JWT posture policy is stricter, audit classes were split from best-effort observability, and financial write classes now distinguish saga behavior from ACID behavior.

However, the current repository still cannot be treated as an architecture that has been fixed. It is an architecture corpus with an improved governance frame, but the evidence layer is still missing:

- no Maven or Gradle build file exists;
- no Java source tree exists;
- no test tree exists;
- no executable operator-shape gate exists;
- no delivery evidence exists for the current SHA;
- several L0 decisions still conflict with L2 subsystem documents;
- several security-response claims say affected documents were extended, but the corresponding L2 docs still carry older semantics.

The strongest valid reading is:

> `spring-ai-fin` has accepted the right security and governance direction, but the accepted findings remain open until W0 creates executable evidence and W2 verifies the security controls under real operator shape.

No P0 finding should be called closed at the current state. The correct status is `design_accepted` unless and until implementation, tests, and gate evidence say otherwise.

---

## 2. Root-Cause Block

**Observed failure**: L0 says some P0 findings are closed, while the governance ledger still marks them as `design_accepted` with `implementation: null`, empty or absent tests, and `operator_gate: null`.

**Execution path**: Reviewers read `ARCHITECTURE.md`, then follow `docs/governance/decision-sync-matrix.md`, L2 subsystem documents, `docs/governance/architecture-status.yaml`, and the `gate/` plus `docs/delivery/` evidence chain. That path diverges: L0 and response docs sometimes claim closure; the ledger and gate directories still say the work is only accepted design.

**Root cause statement**: Architecture claims were promoted by document edits before an executable evidence layer existed, which allows "accepted", "designed", "implemented", "tested", and "operator-gated" to collapse into narrative language.

**Evidence**:

- `ARCHITECTURE.md:20-21` says ActionGuard and audit close P0 findings.
- `docs/governance/architecture-status.yaml:53-112` still records key capabilities with `implementation: null` and `operator_gate: null`.
- `docs/governance/architecture-status.yaml:173-223` keeps P0 findings at `design_accepted`.
- `gate/README.md:7-21` states the gate scripts are W0 deliverables and placeholders.
- Repository inventory contains Markdown and YAML only; there is no build, source, test, or executable gate.

---

## 3. Remediation Principles

1. **Evidence outranks prose**  
   When L0, L2, response docs, and the governance ledger disagree, the lowest-evidence status wins.

2. **No closure without three proofs**  
   A P0 can move out of open status only after code exists, tests pass, and the operator-shape gate records the current SHA.

3. **L0 decisions must be synchronized into every affected L2**  
   A hard decision is not accepted until the claimed L2 documents contain the same semantics.

4. **Security controls must sit at runtime side-effect boundaries**  
   Load-time validation helps, but it does not replace runtime authorization of model/tool/framework-proposed actions.

5. **Operator shape is the release shape**  
   A foreground smoke run, a mocked dependency path, or a documentation-only checklist cannot satisfy Rule 8.

6. **Fallbacks are not success paths**  
   Every fallback remains countable, attributable, inspectable, and gate-asserted to zero unless explicitly exempted with compensating visibility.

---

## 4. Finding-to-Remediation Matrix

| Finding | Severity | Category | Primary files | Required remediation | Target wave |
|---|---:|---|---|---|---|
| Closure claims conflict with evidence ledger | P0 | Governance and evidence | `ARCHITECTURE.md`, `architecture-status.yaml`, `closure-taxonomy.md` | Remove or downgrade closure language; make ledger the source of truth; add sync check for illegal status claims | W0 |
| ActionGuard L0/L2 pipeline drift | P0 | Runtime security boundary | `ARCHITECTURE.md`, `agent-runtime/action-guard/ARCHITECTURE.md`, `decision-sync-matrix.md` | Normalize ActionGuard to 11 stages everywhere; require pre-action and post-action evidence writers | W0 document sync, W2 implementation |
| Tenant RLS claimed but not specified in server L2 | P0 | Tenant isolation | `agent-runtime/server/ARCHITECTURE.md`, `security-control-matrix.md` | Define RLS connection protocol, `SET LOCAL`, pool reset, fail-closed boundaries, and isolation tests | W2 |
| Skill authorization remains load-time only | P0 | Tool and skill runtime authorization | `agent-runtime/skill/ARCHITECTURE.md`, `agent-runtime/capability/ARCHITECTURE.md` | Keep load-time validation, but add mandatory runtime ActionGuard invocation for every side effect | W2 |
| Prompt-security model missing from LLM L2 | P1 | Prompt and LLM security | `agent-runtime/llm/ARCHITECTURE.md`, `observability/`, `security-control-matrix.md` | Add `PromptSection`, taint propagation, prompt-cache classification, and raw-prompt leakage tests | W2 |
| Python sidecar security profile incomplete | P1 | Cross-process adapter security | `agent-runtime/adapters/ARCHITECTURE.md`, `docs/sidecar-security-profile.md` | Define transport profile, identity, token boundary, metadata trust, payload limits, and cancellation behavior | W2/W4 |
| Operator gate remains a placeholder | P1 | Delivery evidence | `gate/README.md`, `docs/delivery/README.md`, `docs/plans/W0-evidence-skeleton.md` | Implement gate scripts and align log path format; record delivery evidence for the current SHA | W0 |
| Observability failure is log-only | P2 | Observability and readiness | `agent-runtime/observability/ARCHITECTURE.md` | Add emitter-failure counter, health/gate assertion, and cardinality policy for tenant labels | W2 |

---

## 5. Workstream A: Governance and Evidence Lock

### Problem

The repository now has the right governance artifacts, but they are not yet enforceable. L0 still contains closure language, old wave references, and stale startup instructions that conflict with the newer status ledger and posture/auth documents.

### Required changes

1. Make `docs/governance/architecture-status.yaml` the authoritative status ledger.
2. Replace unsupported words such as `closes`, `closed`, `fixed`, `production-ready`, and `released` unless the ledger and evidence chain support them.
3. Add `gate/check_architecture_sync.{sh,ps1}` in W0.
4. Align naming between:
   - `docs/governance/decision-sync-matrix.md`, which currently names `scripts/check_architecture_sync.*`;
   - `gate/README.md`, which names `gate/check_architecture_sync.*`;
   - `docs/plans/W0-evidence-skeleton.md`, which also names `gate/check_architecture_sync.*`.
5. Align gate log extension:
   - `gate/README.md` says `gate/log/<sha>.json`;
   - `docs/delivery/README.md` says `gate/log/<sha>.txt`.

### Exit criteria

- `ARCHITECTURE.md` contains no unsupported closure claims.
- `architecture-status.yaml` is the only place where capability status is summarized.
- The sync script fails if L0 says a finding is closed while the ledger says `design_accepted`.
- The sync script fails if a decision matrix row references a missing L2 section.

---

## 6. Workstream B: L0/L2 Decision Synchronization

### Problem

Several decisions were fixed in one layer but not the others. This is more dangerous than an obvious missing document because different implementation teams can follow different documents and still believe they are compliant.

### Required changes

1. Normalize ActionGuard everywhere:
   - 11 stages;
   - `PreActionEvidenceWriter` before side effects;
   - `PostActionEvidenceWriter` after success or failure;
   - `ActionGuardCoverageTest` as a release gate.
2. Replace the old `SYNC_SAGA` wording in L0:
   - `SYNC_SAGA` is not cross-entity ACID;
   - it is a saga with compensation, idempotency, reconciliation, and explicit "not all-or-nothing" semantics.
3. Update L0 "Open at v1" section:
   - W0 is the first wave;
   - W1 begins only after W0 delivery evidence is committed;
   - no capability moves above L1 during W0.
4. Replace standard startup guidance:
   - research/prod must use issuer registry plus JWKS for SaaS multi-tenant;
   - `APP_JWT_SECRET` must not be the standard research/prod path;
   - BYOC HS256 requires explicit allowlist entry and audit alarm.
5. Clean stale or misleading line-level language:
   - `Last refreshed` must match the current review date or say "not yet refreshed";
   - future or stale "commit pushed" claims must be removed unless supported by git evidence.

### Exit criteria

- Every hard L0 decision has matching L2 text.
- Every decision-sync row has an implementation path, test path, and target wave.
- `check_architecture_sync` can be run locally and in CI.

---

## 7. Workstream C: Runtime Security Boundaries

### 7.1 ActionGuard and side-effect authorization

Load-time validation is necessary but not enough. The dangerous moment is runtime conversion of model/framework/tool output into a side effect.

Required architecture:

```text
Model or framework proposal
  -> ActionEnvelope construction
  -> Schema validation
  -> Tenant binding
  -> Actor and entitlement check
  -> Capability maturity and posture check
  -> Effect and data-access classification
  -> Policy decision
  -> Human gate when required
  -> Pre-action evidence write
  -> Execution
  -> Post-action evidence write
```

Every side-effectful path must be unreachable without `ActionGuard.authorize(...)`.

Required tests:

- bypass attempt fails CI;
- cross-tenant proposal denied;
- argument hash tampering denied;
- PII or financial action writes pre-action evidence before execution;
- execution failure still writes post-action evidence;
- fallback count remains zero on happy path.

### 7.2 Skill and capability runtime authorization

The skill document currently defines dangerous-capability gating at load time. Keep that gate, but classify it as a registry hygiene check, not the runtime security boundary.

Required architecture:

- skill load validates schema and declared dangerous capabilities;
- capability descriptor declares effect class, data class, maturity level, posture availability, and human-gate requirement;
- tenant entitlement is checked at runtime;
- every invocation constructs an `ActionEnvelope`;
- every side-effect invocation goes through ActionGuard.

### 7.3 Tenant RLS connection protocol

The server L2 must define the actual connection-pool protocol, not only say "RLS-enforced".

Required architecture:

- tenant is bound before any store access;
- each transaction runs `SET LOCAL app.tenant_id = :tenantId`;
- no tenant-scoped query can run outside an active tenant-bound transaction;
- pooled connections are reset or validated before reuse;
- missing tenant in research/prod fails closed;
- cross-tenant reads return 404 or typed denial, never empty success that masks leakage;
- migrations define RLS policies for every tenant-scoped table.

Required tests:

- `TenantBindingIT`;
- `RlsConnectionIsolationIT`;
- `CrossTenantEventReadReturns404IT`;
- pooled connection reuse does not leak previous tenant;
- missing tenant fails under research/prod.

### 7.4 LLM prompt-security control plane

The LLM L2 must explicitly model prompt sections and taint propagation.

Required architecture:

- `PromptSection` taxonomy: system, developer, tenant policy, user input, retrieved context, tool output, private scratch, model output;
- taint levels for PII, financial data, secret material, retrieved documents, and untrusted tool output;
- prompt cache keys include tenant, model, version, and security classification;
- raw prompts never appear in logs, metric labels, traces, cache keys, or audit metadata;
- tool calls generated from tainted model output still go through ActionGuard.

Required tests:

- `NoRawPromptInLogsTest`;
- `NoPiiInMetricLabelsTest`;
- `PromptCacheClassificationTest`;
- `ToolOutputTaintToActionGuardIT`;
- `RetrievedContextRedactionIT`.

### 7.5 Python sidecar profile

The adapter L2 must pull `docs/sidecar-security-profile.md` into the actual dispatch architecture.

Required architecture:

- define whether the default sidecar transport is UDS, loopback TCP, or mTLS;
- define when SPIFFE or equivalent workload identity is required;
- treat tenant metadata from the sidecar as untrusted unless bound by the JVM-side run context;
- enforce payload size, timeout, cancellation, and stream-close behavior;
- record sidecar image digest and supply-chain evidence;
- sidecar fallback is not a success path and must be gate-asserted to zero on the happy path.

---

## 8. Workstream D: Operator-Shape Gate and Delivery Evidence

### Problem

The gate directory describes the right target but contains no executable scripts yet. Without an executable gate, Rule 8 remains aspirational.

### W0 deliverables

Create:

```text
pom.xml
agent-platform/pom.xml
agent-runtime/pom.xml
agent-platform/src/main/java/...
agent-platform/src/test/java/...
agent-runtime/src/main/java/...
agent-runtime/src/test/java/...
gate/run_operator_shape_smoke.ps1
gate/run_operator_shape_smoke.sh
gate/check_architecture_sync.ps1
gate/check_architecture_sync.sh
docs/delivery/<date>-<sha>.md
```

### Minimum W0 gate behavior

The first gate does not need the full product, but it must prove the delivery shape:

- build a runnable artifact;
- start it as a long-lived managed process;
- hit `/health` and `/ready`;
- execute three sequential public-entry invocations;
- prove run lifecycle fields are non-null;
- prove cancellation round-trip behavior;
- prove fallback count is zero;
- write a structured gate log;
- record the current SHA in `docs/delivery/`.

### Exit criteria

- `mvn -q -pl agent-platform,agent-runtime test` exits 0.
- `gate/run_operator_shape_smoke.{sh,ps1}` exits 0 in the documented environment.
- `gate/check_architecture_sync.{sh,ps1}` exits 0.
- No capability is reported above L1.
- A delivery document exists for the W0 SHA.

---

## 9. Workstream E: Observability, Privacy, and Readiness

### Problem

The observability design correctly separates best-effort telemetry from mandatory audit evidence, but `SpineEmitter` currently uses catch-and-log-only failure handling. That is acceptable for request-path availability, but insufficient for readiness and operator diagnosis.

### Required changes

1. Keep spine emitters non-throwing on the request path.
2. Add a countable failure metric:

```text
springaifin_spine_emit_failures_total{layer, reason}
```

3. Add a readiness rule:

```text
if spine emitter failure rate exceeds threshold during gate window:
  readiness = degraded
  operator gate = fail
```

4. Revisit raw `tenant_id` metric labels:
   - default metric labels should remain low-cardinality;
   - tenant can be carried in traces, logs, exemplars, or controlled hash labels;
   - raw tenant labels should require an explicit cardinality budget and retention policy.
5. Add `docs/observability/cardinality-policy.md` before allowing raw tenant labels at scale.

### Exit criteria

- emitter failure metric exists;
- gate asserts emitter failures are zero during the happy path;
- privacy policy tests cover logs, metrics, traces, prompt cache, and tool arguments;
- cardinality policy is explicit before production readiness claims.

---

## 10. Workstream F: Financial Write Semantics

### Problem

The outbox L2 now correctly separates commit mechanism from financial commitment class, but L0 still contains old wording that can imply saga-based strong consistency. This is dangerous in a financial context.

### Required changes

1. Update L0 to say:
   - `DIRECT_DB` can support atomic writes inside one database transaction;
   - `SYNC_SAGA` is not ACID across entities;
   - `OUTBOX_ASYNC` is never a customer-facing financial mutation path by itself.
2. Keep `FinancialWriteClass` as the higher-level claim boundary:
   - `LEDGER_ATOMIC`;
   - `SAGA_COMPENSATED`;
   - `EXTERNAL_SETTLEMENT`;
   - `ADVISORY_ONLY`.
3. Avoid business-domain examples that make the platform appear to own ledger business logic unless the module really owns that domain.
4. Require `WriteSiteAuditTest` and `FinancialWriteCompatibilityTest` before any financial mutation path can move beyond L1.

### Exit criteria

- L0 and L2 use the same write semantics.
- unannotated writes fail CI.
- saga paths expose reconciliation states.
- no user-facing copy can claim "all-or-nothing" for saga-compensated writes.

---

## 11. Recommended Sequencing

### Phase 0: Stop status drift immediately

Do this before writing more design:

- remove unsupported closure claims;
- align gate script paths and log extensions;
- align ActionGuard stage count;
- update stale W1-first language to W0-first;
- update standard startup variables to the current JWT posture policy.

### Phase 1: Build W0 evidence skeleton

Create the smallest runnable system that can compile, start, answer health checks, exercise stub run routes, and emit gate evidence. This phase should deliberately keep capabilities at L0-L1.

### Phase 2: Implement W2 security controls

Implement ActionGuard, runtime skill/capability authorization, RLS protocol, JWT posture enforcement, prompt-security taxonomy, audit-class storage, and sidecar conformance.

### Phase 3: Harden financial writes and outbox

Add enforceable `@WriteSite` annotations, outbox schema, saga state, compensation records, reconciliation queue, and financial compatibility tests.

### Phase 4: Enable multi-framework dispatch

Keep Python sidecar and non-default adapters gated until security, supply chain, cancellation, payload limits, and fallback-zero evidence are present.

---

## 12. Status Promotion Rules

Use these rules for every capability row in `architecture-status.yaml`.

| Status | Minimum evidence |
|---|---|
| `proposed` | idea exists, not yet accepted |
| `design_accepted` | architecture committee accepts direction; no implementation claim |
| `implemented_unverified` | code exists, but tests or gate are incomplete |
| `test_verified` | required unit/integration/E2E tests pass |
| `operator_gated` | Rule 8 gate passes for the current SHA |
| `released` | delivery document exists and release owner approves |

Forbidden status shortcuts:

- "closed by design";
- "fixed in docs";
- "production-ready pending implementation";
- "accepted, therefore closed";
- "operator-gated by intention";
- "verified by review only".

---

## 13. Definition of Done for This Remediation Cycle

This remediation cycle is complete only when all conditions below hold:

1. The eight review findings in this document are represented in `architecture-status.yaml`.
2. L0, decision matrix, L2 docs, and status ledger agree.
3. `gate/check_architecture_sync.*` exists and passes.
4. `gate/run_operator_shape_smoke.*` exists and passes for the current SHA.
5. A delivery document exists in `docs/delivery/`.
6. No P0 remains at `design_accepted` after the W2 security gate.
7. No document claims closure without test and operator evidence.
8. Every fallback touched by the remediation is countable, attributable, inspectable, and gate-asserted.
9. Every persistent record introduced by implementation carries the required contract spine fields.
10. The architecture committee can answer, from evidence alone, which capabilities are L0, L1, L2, L3, or L4.

---

## 14. Immediate Next Pull Request

The next pull request should be intentionally small and should not attempt to implement the full platform.

Recommended scope:

1. Edit `ARCHITECTURE.md` to remove unsupported closure claims and align ActionGuard, W0, JWT, and write-semantics language.
2. Edit `agent-runtime/server/ARCHITECTURE.md` to add the RLS connection protocol.
3. Edit `agent-runtime/skill/ARCHITECTURE.md` and `agent-runtime/capability/ARCHITECTURE.md` to distinguish load-time validation from runtime ActionGuard authorization.
4. Edit `agent-runtime/llm/ARCHITECTURE.md` to add prompt-section and taint taxonomy.
5. Edit `agent-runtime/adapters/ARCHITECTURE.md` to bind sidecar dispatch to the sidecar security profile.
6. Align gate script path and log extension across `gate/README.md`, `docs/delivery/README.md`, and `docs/governance/decision-sync-matrix.md`.
7. Add a minimal `gate/check_architecture_sync.ps1` that catches the exact drift classes found in this review.

Expected status after that PR:

```text
No P0 is closed.
All P0s remain design_accepted unless code and tests are added.
The architecture corpus is internally consistent.
W0 implementation can start without giving teams conflicting instructions.
```

