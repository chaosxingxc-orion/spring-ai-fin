# spring-ai-fin Systematic Architecture Remediation Plan - Cycle 2

**Date**: 2026-05-08  
**Scope**: `D:/chao_workspace/spring-ai-fin` after remediation cycle 1 and the latest architecture review  
**Audience**: Architecture committee, platform engineers, security reviewers, release captains  
**Current classification**: Architecture corpus with partial document-sync gate. Not implementation-verified. Not operator-gated.  
**Relation to prior plan**: This document extends `docs/systematic-architecture-remediation-plan-2026-05-08.en.md`. The prior plan addressed the first eight review findings. This cycle addresses six new findings found after the architecture team added the sync gate and updated several L2 documents.

---

## 1. Executive Judgment

The second remediation pass improved several important L2 designs:

- ActionGuard L2 now defines 11 stages, including pre-action and post-action evidence.
- Server L2 now defines a tenant RLS connection protocol.
- Skill and capability L2 now distinguish load-time registry hygiene from runtime ActionGuard authorization.
- LLM L2 now defines prompt sections, taint propagation, prompt-cache classification, and ActionGuard handoff.
- Adapter L2 now binds Python sidecar dispatch to UDS, SPIFFE, image digest, tenant-metadata validation, and payload guards.
- Observability L2 now adds emitter failure counters and a tenant-label cardinality policy.
- `gate/check_architecture_sync.{ps1,sh}` now exists and produces a structured JSON log.

Those are real improvements, but the latest review found a more subtle failure mode: **the gate can pass while the architecture corpus still contains material contradictions**.

The core problem is no longer simply "there is no governance." The problem is now:

> Governance exists, but the executable checks are too narrow to protect the architecture from L0/L1/L2 drift, dirty-tree evidence, and operator-shape gaps.

The repository still has no Maven/Gradle build, no Java source tree, no tests, no `run_operator_shape_smoke.*`, and no `docs/delivery/<date>-<sha>.md` for a real Rule 8 run. Therefore no P0 security finding may be closed, no core capability may be promoted beyond design evidence, and the current sync-gate PASS must be treated as a narrow document-lint result rather than delivery evidence.

---

## 2. Root-Cause Block

**Observed failure**: `gate/check_architecture_sync.ps1` passes and writes `gate/log/<sha>.json`, while `ARCHITECTURE.md` still says ActionGuard is a 10-stage pipeline, `agent-platform/ARCHITECTURE.md` still carries the old HMAC/posture-contract model, and `agent-runtime/server/ARCHITECTURE.md` relies on the wrong HikariCP lifecycle hook for tenant reset.

**Execution path**: A reviewer reads the L0 `ARCHITECTURE.md`, then the L1 documents under `agent-platform/` and `agent-runtime/`, then L2 subsystem documents, then `docs/governance/architecture-status.yaml`, then `gate/check_architecture_sync.*`. The gate only checks a subset of that path. It scans root L0 and `docs/*.md` for some closure shortcuts, checks a few hard-coded strings, and emits a log under the git HEAD SHA. It does not fully validate L1/L2 semantics, dirty working-tree state, ActionGuard stage parity, auth/posture policy parity, or operator-shape readiness.

**Root cause statement**: The first sync gate codified the last review's visible symptoms instead of the architecture's invariants, so it can pass while unverified or contradictory design claims remain outside its scan surface.

**Evidence**:

- `ARCHITECTURE.md:981-989` still says ActionGuard is a 10-stage pipeline.
- `agent-runtime/action-guard/ARCHITECTURE.md:21-32` defines 11 stages.
- `agent-platform/ARCHITECTURE.md:317-334` says contracts read posture from `Environment` and auth uses HMAC via `APP_JWT_SECRET`.
- `agent-platform/contracts/ARCHITECTURE.md` says contracts are environment-free and posture-conditional validation lives outside records.
- `agent-runtime/auth/ARCHITECTURE.md` says research SaaS and prod require RS256/ES256 with JWKS.
- `agent-runtime/server/ARCHITECTURE.md:171-173` says HikariCP `connectionInitSql` resets tenant state on checkout.
- HikariCP documents `connectionInitSql` as running after new connection creation before adding the connection to the pool, not on every checkout. Source: <https://github.com/brettwooldridge/HikariCP>.
- `gate/check_architecture_sync.ps1:32-57` scans root `ARCHITECTURE.md` and `docs/*.md`, but not all L1/L2 architecture files.
- `gate/check_architecture_sync.ps1:139-152` records `git rev-parse --short HEAD` without recording or rejecting dirty working-tree state.
- `gate/README.md:7-21` still says the operator-shape smoke scripts are W0 deliverables and the directory remains a placeholder until W0 lands.

---

## 3. Finding-to-Remediation Matrix

| Finding | Severity | Category | Primary files | Required remediation | Target wave |
|---|---:|---|---|---|---|
| L0 still says ActionGuard is 10-stage | P0 | L0/L2 security-control drift | `ARCHITECTURE.md`, `agent-runtime/action-guard/ARCHITECTURE.md`, `gate/check_architecture_sync.*` | Make 11 stages canonical everywhere; add a gate rule that fails on 10-stage ActionGuard wording | W0 document sync; W2 implementation |
| Platform L1 still uses old auth and posture-contract model | P0 | Platform boundary and identity policy drift | `agent-platform/ARCHITECTURE.md`, `agent-platform/contracts/ARCHITECTURE.md`, `agent-runtime/auth/ARCHITECTURE.md`, `agent-runtime/posture/ARCHITECTURE.md` | Remove contract environment reads; replace HMAC research/prod standard path with issuer registry + JWKS; align metric label policy | W0 document sync; W1/W2 implementation |
| RLS reset protocol relies on the wrong Hikari hook | P0 | Tenant isolation and connection-pool lifecycle | `agent-runtime/server/ARCHITECTURE.md`, `docs/security-control-matrix.md` | Remove checkout-reset claim from `connectionInitSql`; define transaction-scoped binding and explicit return/reset validation | W0 document sync; W2 tests |
| Architecture sync gate does not scan L1/L2 closure language | P1 | Governance-gate coverage | `gate/check_architecture_sync.ps1`, `gate/check_architecture_sync.sh` | Scan `agent-platform/**/ARCHITECTURE.md` and `agent-runtime/**/ARCHITECTURE.md`; enforce taxonomy across L0/L1/L2 | W0 |
| Gate log records HEAD SHA without dirty-tree protection | P1 | Evidence reproducibility | `gate/check_architecture_sync.ps1`, `gate/check_architecture_sync.sh`, `docs/delivery/README.md` | Record `git status --porcelain`; fail by default on dirty tree; allow explicit local-only mode that cannot be delivery evidence | W0 |
| Operator-shape gate is still not implemented | P1 | Rule 8 delivery gate | `gate/README.md`, `docs/plans/W0-evidence-skeleton.md`, `docs/delivery/README.md` | Add `run_operator_shape_smoke.{ps1,sh}` with long-lived process, real dependencies, sequential runs, cancellation, lifecycle, and fallback-zero checks | W0 |

---

## 4. Workstream A: Canonicalize ActionGuard Stage Semantics

### Problem

L0 still says ActionGuard is a 10-stage pipeline, while ActionGuard L2 and the decision matrix now require 11 stages. This is not a cosmetic mismatch. ActionGuard is the central security boundary between model/tool/framework output and side effects. If the architecture cannot name the pipeline consistently, implementation cannot prove coverage.

### Required correction

Make the following the canonical ActionGuard shape everywhere:

```text
1. SchemaValidator
2. TenantBindingChecker
3. ActorAuthorizer
4. MaturityChecker
5. EffectClassifier
6. DataAccessClassifier
7. OpaPolicyDecider
8. HitlGate
9. PreActionEvidenceWriter
10. Executor
11. PostActionEvidenceWriter
```

Replace all "10-stage" references in L0, L1, L2, docs, and gate comments.

### Gate rule

`gate/check_architecture_sync.*` must fail when:

- `ARCHITECTURE.md` contains `10-stage pipeline` near `ActionGuard`;
- any ActionGuard-related doc does not mention both `PreActionEvidenceWriter` and `PostActionEvidenceWriter`;
- the decision matrix says "11 stage classes" while L0 says any other number.

### Exit criteria

- L0 and L2 both say 11 stages.
- The sync gate catches a deliberately introduced 10-stage reference.
- The status ledger keeps ActionGuard at `design_accepted` until code and tests exist.

---

## 5. Workstream B: Align Platform L1 With Current Contract, Auth, and Posture Decisions

### Problem

`agent-platform/ARCHITECTURE.md` still describes an old model:

- contracts read posture through `Environment.getProperty`;
- auth uses HMAC via `APP_JWT_SECRET`;
- research/prod fail closed but not through the current issuer registry + JWKS model;
- idempotency metrics use raw `tenantId` labels despite the new cardinality policy.

This conflicts with the newer architecture:

- contract records are environment-free;
- posture is read once at boot and injected into facade validators;
- research SaaS and prod require RS256/ES256 with JWKS;
- raw tenant metric labels require explicit cardinality budget.

### Required correction

Update `agent-platform/ARCHITECTURE.md` so it states:

- `contracts/` records enforce shape only;
- posture-conditional behavior lives in `agent-platform/facade/PostureAwareValidator`;
- contracts never call `System.getenv`, `Environment.getProperty`, or `AppPosture.fromEnv`;
- auth is mediated by runtime auth primitives through a narrow seam;
- `dev` loopback can use anonymous or HS256;
- `research` SaaS and `prod` require issuer registry + JWKS;
- BYOC HS256 is an explicit allowlist carve-out, not the standard path;
- platform metrics use `tenant_bucket` or trace attributes unless `docs/observability/cardinality-policy.md` allows raw `tenant_id`.

### Gate rule

`gate/check_architecture_sync.*` must fail when:

- `agent-platform/ARCHITECTURE.md` says contracts read posture from `Environment`;
- `agent-platform/ARCHITECTURE.md` presents `APP_JWT_SECRET` as the standard research/prod path;
- platform metrics use raw `tenantId` labels without a cardinality policy reference.

### Exit criteria

- Platform L1 matches contracts L2 and auth/posture L2.
- The sync gate catches reintroduction of direct contract environment reads.
- The sync gate catches research/prod HMAC-as-standard wording.

---

## 6. Workstream C: Fix the RLS Connection-Pool Lifecycle Claim

### Problem

The RLS design correctly requires transaction-scoped tenant binding with `SET LOCAL app.tenant_id`, but it also claims HikariCP `connectionInitSql` resets `app.tenant_id` on every checkout. That claim is not correct. HikariCP documents `connectionInitSql` as executing after a new connection is created before it is added to the pool. It is not a per-checkout reset hook.

This matters because tenant isolation depends on proving that pooled connection reuse cannot carry tenant state from tenant A to tenant B.

### Required correction

Remove the claim that `connectionInitSql` proves per-checkout reset. Replace it with a design that does not depend on that hook:

1. `TenantBinder` starts every tenant-scoped transaction.
2. It obtains a connection and explicitly begins a transaction.
3. It executes `SET LOCAL app.tenant_id = :tenantId` before any tenant-scoped query.
4. Store methods cannot access tenant-scoped tables outside `TenantBinder`.
5. Transaction completion always commits or rolls back.
6. On strict postures, any missing tenant binding raises `TenantContextMissingException`.
7. Tests prove connection reuse does not leak state.

Optional defense-in-depth:

- set safe defaults on newly created connections;
- validate connection state at the start of each `TenantBinder` transaction;
- record `springaifin_rls_binding_missing_total{posture, store}`;
- use a proxy `DataSource` or transaction interceptor if the framework needs enforcement below store code.

### Gate rule

`gate/check_architecture_sync.*` must fail when:

- docs say `connectionInitSql` runs on every checkout;
- docs say `connectionInitSql` is the proof that tenant state is reset between leases;
- RLS docs mention pooled reuse without `PooledConnectionLeakageIT`.

### Exit criteria

- Server L2 no longer relies on `connectionInitSql` as checkout reset.
- `docs/security-control-matrix.md` uses the same wording as server L2.
- W2 test plan includes `PooledConnectionLeakageIT` against a real Postgres connection pool.

---

## 7. Workstream D: Expand Architecture Sync Gate Coverage

### Problem

The sync gate exists, but it currently checks too little. It scans root L0 and docs, but misses several L1/L2 files where forbidden closure language and stale architectural claims remain.

### Required correction

Expand scan surface to include:

```text
ARCHITECTURE.md
agent-platform/**/ARCHITECTURE.md
agent-runtime/**/ARCHITECTURE.md
docs/**/*.md
docs/governance/architecture-status.yaml
docs/governance/decision-sync-matrix.md
gate/README.md
docs/delivery/README.md
```

Add semantic checks for:

- ActionGuard stage count parity;
- contract posture purity;
- auth algorithm policy;
- raw tenant metric labels;
- RLS connection-pool lifecycle wording;
- forbidden closure shortcuts across all L0/L1/L2 docs;
- `architecture-status.yaml` status enum and evidence-level consistency;
- gate path and log-extension consistency.

### Required script behavior

The gate must print actionable failures:

```json
{
  "category": "actionguard_stage_drift",
  "message": "ARCHITECTURE.md says 10-stage while action-guard L2 says 11 stages",
  "path": "ARCHITECTURE.md",
  "line": 983
}
```

### Exit criteria

- The gate fails when any of the six findings in this document are reintroduced.
- The gate runs on Windows PowerShell and POSIX shell.
- The gate emits equivalent results across `.ps1` and `.sh`.
- The gate is documented as an architecture-sync gate, not a Rule 8 operator-shape gate.

---

## 8. Workstream E: Make Gate Evidence Reproducible

### Problem

The sync gate writes a log named by `git rev-parse --short HEAD`, but the current repository can have modified and untracked files. A log named after HEAD is not reproducible evidence when the working tree differs from HEAD.

### Required correction

The gate must record:

- `head_sha`;
- `working_tree_clean: true/false`;
- `git_status_porcelain`;
- script name and version;
- generated timestamp;
- scan root;
- failure list;
- local-only override flag, if any.

Default behavior:

- delivery mode fails when the working tree is dirty;
- local mode may pass with dirty tree, but must write `evidence_valid_for_delivery: false`;
- `docs/delivery/<date>-<sha>.md` may only reference clean-tree gate logs.

### Gate rule

For `check_architecture_sync.*`:

```text
if git status --porcelain is not empty:
  fail unless --local-only is set
  if --local-only is set:
    write evidence_valid_for_delivery=false
```

For future `run_operator_shape_smoke.*`:

```text
dirty tree is never valid release evidence
```

### Exit criteria

- A dirty working tree causes sync gate failure by default.
- Local-only mode is clearly marked as non-delivery evidence.
- `docs/delivery/README.md` states that delivery files cannot attach dirty-tree logs.

---

## 9. Workstream F: Implement the Real Operator-Shape Gate

### Problem

`check_architecture_sync.*` is useful, but it is not Rule 8. It does not start the application, run a long-lived process, use real dependencies, execute sequential runs, prove resource reuse, assert lifecycle observability, test cancellation, or assert fallback counts are zero.

### Required W0 deliverables

Create:

```text
pom.xml
agent-platform/pom.xml
agent-runtime/pom.xml
agent-platform/src/main/java/...
agent-runtime/src/main/java/...
agent-platform/src/test/java/...
agent-runtime/src/test/java/...
gate/run_operator_shape_smoke.ps1
gate/run_operator_shape_smoke.sh
docs/delivery/<date>-<sha>.md
```

### Minimum Rule 8 smoke gate

The W0 operator-shape smoke must:

1. build the runnable artifact;
2. start a long-lived managed process;
3. use real local Postgres;
4. hit `/health` and `/ready`;
5. perform three sequential public-entry invocations;
6. prove the same process survives all invocations;
7. prove lifecycle fields are populated;
8. cancel a live run and drive it terminal;
9. return 404 for cancel on unknown run id;
10. assert fallback count is zero;
11. write `gate/log/<sha>.json`;
12. write `docs/delivery/<date>-<sha>.md`.

### Exit criteria

- `run_operator_shape_smoke.*` exists and fails when no runnable artifact exists.
- It cannot pass by running only documentation checks.
- It records real process, dependency, lifecycle, cancellation, and fallback evidence.
- No capability can claim `operator_gated` without a delivery file for the exact SHA.

---

## 10. Status Promotion Impact

The new findings should be added to `docs/governance/architecture-status.yaml#findings` as remediation findings.

Recommended identifiers:

| Finding id | Capability | Status | Target wave |
|---|---|---|---|
| `REM-2026-05-08-C2-1` | `action_guard` | `design_accepted` | W0/W2 |
| `REM-2026-05-08-C2-2` | `agent_platform_facade` | `design_accepted` | W0/W2 |
| `REM-2026-05-08-C2-3` | `server_rls_protocol` | `design_accepted` | W0/W2 |
| `REM-2026-05-08-C2-4` | `operator_shape_gate` | `implemented_unverified` only after expanded sync gate exists | W0 |
| `REM-2026-05-08-C2-5` | `operator_shape_gate` | `design_accepted` until dirty-tree protection exists | W0 |
| `REM-2026-05-08-C2-6` | `operator_shape_gate` | `design_accepted` until smoke gate exists | W0 |

Important: the existing sync gate may remain `implemented_unverified` only for the narrow architecture-sync capability. The Rule 8 operator-shape gate remains `design_accepted` until `run_operator_shape_smoke.*` exists and passes.

---

## 11. Immediate Next Pull Request

The next PR should be small and evidence-oriented.

Recommended scope:

1. Fix `ARCHITECTURE.md` ActionGuard wording from 10 stages to 11 stages.
2. Fix `agent-platform/ARCHITECTURE.md` posture, contract, auth, and tenant-label sections.
3. Fix `agent-runtime/server/ARCHITECTURE.md` and `docs/security-control-matrix.md` so RLS does not rely on HikariCP `connectionInitSql` as a checkout reset hook.
4. Expand `gate/check_architecture_sync.ps1` and `.sh` to scan L1/L2 architecture files.
5. Add explicit checks for ActionGuard stage count, contract posture purity, auth algorithm policy, RLS pool wording, and dirty-tree evidence.
6. Update `docs/governance/architecture-status.yaml` with the six cycle-2 findings.
7. Update `docs/delivery/README.md` to forbid dirty-tree logs as delivery evidence.

Expected result after that PR:

```text
The architecture corpus is internally consistent at L0/L1/L2.
The sync gate catches the six cycle-2 drift classes.
The sync gate's PASS log is reproducible evidence only when the working tree is clean.
The operator-shape gate is still pending W0 and is not misrepresented as complete.
```

---

## 12. Definition of Done for Cycle 2

Cycle 2 is complete only when:

1. All six findings are recorded in `architecture-status.yaml`.
2. L0 ActionGuard says 11 stages.
3. Platform L1 no longer contradicts contracts/auth/posture L2.
4. Server RLS no longer claims HikariCP `connectionInitSql` is a checkout reset hook.
5. Sync gate scans L0, L1, L2, docs, governance, and gate metadata.
6. Sync gate fails on dirty tree by default.
7. Sync gate catches deliberate reintroduction of each cycle-2 defect.
8. `run_operator_shape_smoke.*` remains explicitly pending until implemented.
9. No P0 is called closed before at least `test_verified`.
10. No release or delivery evidence references a dirty-tree gate log.

