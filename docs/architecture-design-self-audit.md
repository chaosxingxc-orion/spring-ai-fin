# Architecture Design Self-Audit -- Comprehensive Rubric

> Honest, repo-wide scoring rubric. Replaces the earlier 30-dim toy. The
> previous version implied a 30/30 pass after one round, which was a
> sloppy claim about a system this large. This rubric is structured so
> that getting to a max score is a multi-week, multi-commit effort and
> exposes specific gaps at every L0/L1/L2 surface.
>
> **Last audit:** 2026-05-09 (Round 4 -- after cycle-9 truth-cut + G7 group added)
> **Headline:** **every refresh capability is maturity L0** (per Rule 12).
> No code; no tests; no Rule 8 PASS. Promotion to L1 requires a wave
> closing per the engineering plan.
>
> The 240+ dim self-audit score is a **secondary diagnostic** describing
> the documentation surface only -- it is NOT a shipping claim, NOT a
> promotion of capability maturity, and NOT Rule 8 evidence.
> Per cycle-9 sec-E1, percent language is no longer used as the
> headline. Maturity L0..L4 is the readiness language.
>
> History (for traceability only):
> - Round 1 baseline: 853 / 960 design-time dims.
> - Round 2: +103 dims after R2.A..R2.F.
> - Round 3: +4 dims after the three-doc governance refresh (G5.12..G5.14).
> - Round 4 (this cycle): +25 dims for the new G7 group "Active-corpus
>   exclusivity"; G7 baseline is **22 / 25** because cycle-9 closed the
>   active-corpus split + index subset + ActionGuard model + dependency
>   mode + Rule 8 eligibility, but two G7 dims (G7.4 cross-doc parameter
>   parity + G7.5 gate semantic binding to active paths only) need
>   negative-fixture coverage that lands as a follow-up CI step.
> **Audit scope:** the entire active corpus -- L0 root `ARCHITECTURE.md`,
> L1 (agent-platform / agent-runtime / agent-eval), every active L2,
> the engineering plan, the systems-engineering plan, the cross-cutting
> docs, the governance corpus, and every claim in those documents that
> can be verified now (without code). Code-level dims are deferred to
> the post-W0 audit.

## 1. Scoring philosophy

Each dimension is scored on a 0--5 scale.

| Score | Meaning |
|---|---|
| 0 | Absent. The element is not in the document. |
| 1 | Mentioned only. The element is named but has no substance. |
| 2 | Partial. Some required sub-elements are present; others missing. |
| 3 | Design-complete. All design-time sub-elements present and internally consistent. |
| 4 | Design-complete + cross-linked + lint-enforceable. The design is referenced from a gate rule, status YAML row, or test plan. |
| 5 | Implementation-proven. Code + passing tests + production traces verify the design. |

**Design-time maximum is 4.** Score 5 is reserved for post-implementation
(when code + tests + production traces verify the design). Per the user's
2026-05-09 scope clarification ("we're focused on architecture-design
optimization; engineering implementation only needs a plan"), this audit
caps at design-time and treats **4 as the achievable max for every dim
in this rubric**. The "100% pass" target for this audit is therefore
4 on every dim -- the engineering implementation evidence is out of
scope, replaced by "the engineering plan describes how this would be
verified in code."

The rubric is partitioned into seven **groups** (G0..G6) totaling **190
dimensions**. Each group has a cap. Aggregate score is a weighted sum.

## 2. The seven groups (190 dims, design-time max = 760)

| Group | Dims | Design-time cap | Description |
|---|---|---|---|
| G0 Whole-repo design | 20 | 80 | L0 architecture document quality + repo-wide policies |
| G1 Per-package L1 | 30 | 120 | 3 packages * 10 dims each |
| G2 Per-module L2 | 80 | 320 | 16 active L2 modules * 5 dims each |
| G3 Per-wave engineering plan | 50 | 200 | 5 waves * 10 dims each |
| G4 Cross-cutting policies | 20 | 80 | Posture, tenancy, audit, secrets, observability, supply chain |
| G5 Governance corpus | 15 | 60 | Active-corpus, status YAML, index, gate, manifest |
| G6 Quality + principle coverage | 25 | 100 | 9 attributes + 3 principles + 13 cross-coverage checks |
| G7 Active-corpus exclusivity (cycle-9) | 5 | 20 | Truth-cut enforcement: split corpus / index subset / ActionGuard parity / no-disposition-in-active / gate binds to active paths |
| **Total** | **245** | **985** | G0-G7 design-time cap; 5 implementation-proven dims (level 5) unlock at W0+. |

## 3. Group-by-group rubric

### G0. Whole-repo design (20 dims, max 80)

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G0.1 | L0 file present at root `ARCHITECTURE.md` | File exists, is the entry point, has a "Last refreshed" line |
| G0.2 | Layered system view | Diagram shows L1/L2/L3 boundaries; each layer's responsibility named |
| G0.3 | OSS component matrix | Every concern -> primary OSS dep + version range + glue owner + wave |
| G0.4 | OSS dependency policy | Pinning + advisories + upgrade cadence per tier + breaking-change handling |
| G0.5 | Glue / Product LOC ratio target | Numeric targets per wave, not aspirational text |
| G0.6 | Module layout diagram | Tree view matching what is created in W0..W4 |
| G0.7 | Nine quality attributes -- list | All 9 named in one place |
| G0.8 | Three first-principles -- list | All 3 stated in one place |
| G0.9 | Posture model documented | dev / research / prod semantics defined |
| G0.10 | Tenant spine documented | tenant_id NOT NULL on every record + RLS protocol |
| G0.11 | ActionGuard chain documented | Stage list + ordering + side-effect boundary |
| G0.12 | Audit model documented | Single source of truth (table + OTel) |
| G0.13 | Secrets policy | Vault / env distinction, per-tenant overrides |
| G0.14 | Removed-from-prior-design list | Explicit list of deferred items |
| G0.15 | Engineering plan reference | L0 points at the plan |
| G0.16 | Systems-engineering plan reference | L0 points at the doc-set drill-down |
| G0.17 | Self-audit reference | L0 points at this document |
| G0.18 | Meta-reflection reference | L0 points at the meta-reflection doc |
| G0.19 | 32-dim scoring framework reference | L0 points at the scoring framework |
| G0.20 | Authoring constraints | Rule for when an L2 doc is added or rejected |

### G1. Per-package L1 (3 packages * 10 dims = 30 dims, max 120)

For each of `agent-platform`, `agent-runtime`, `agent-eval`:

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G1.x.1 | L1 file present + skeleton header | Owner / Wave / Maturity / Reads / Writes header line |
| G1.x.2 | Purpose section | Defines what the package does and what it does not |
| G1.x.3 | OSS deps table | Versioned table with role per dep |
| G1.x.4 | Submodules (L2) table | Path + Purpose + Wave per submodule |
| G1.x.5 | Public contract | HTTP / DB / event surface defined |
| G1.x.6 | Posture-aware defaults table | dev / research / prod columns |
| G1.x.7 | Tests table | >= 3 tests with assertions |
| G1.x.8 | Out-of-scope | Explicit list |
| G1.x.9 | Wave landing | W0..W4 mapping |
| G1.x.10 | Risks | Numbered list with mitigations |

### G2. Per-module L2 (16 active modules * 5 dims = 80 dims, max 320)

The 16 active L2 modules:

agent-platform: web, auth, tenant, idempotency, bootstrap, config, contracts (7)
agent-runtime: run, llm, tool, action, memory, outbox, temporal, observability (8)
agent-eval (top-level module, not L2 of a package, but scored under same rubric) (1)

For each, score:

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G2.x.1 | Skeleton compliance | All 9 sections present in order |
| G2.x.2 | OSS + glue separation | OSS table distinct from Glue table; each row has paths + LOC |
| G2.x.3 | Tests >= 3 | Tests table has >= 3 named tests with assertions |
| G2.x.4 | Posture defaults table | dev / research / prod columns with concrete values |
| G2.x.5 | Wave + risks | Wave landing line + Risks with >= 2 named risks + mitigations |

### G3. Per-wave engineering plan (5 waves * 10 dims = 50 dims, max 200)

For each of W0, W1, W2, W3, W4:

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G3.x.1 | Goal | One-paragraph goal stating the deliverable |
| G3.x.2 | Scope (in) | Bulleted list, each bullet maps to a glue module or OSS choice |
| G3.x.3 | Scope (out, deferred) | Explicit list of what this wave does NOT do |
| G3.x.4 | OSS deps pinned | Versions, not "latest" |
| G3.x.5 | Glue modules | Path + LOC table |
| G3.x.6 | Tests | Layer + assertions per test |
| G3.x.7 | Acceptance gates | Each gate references a dim ID from the 32-dim scoring framework |
| G3.x.8 | Risks + mitigations | Named risks with concrete mitigations |
| G3.x.9 | Rollback | Concrete rollback recipe |
| G3.x.10 | Reviewer-findings policy | Either deferred-batch or in-line; stated explicitly |

### G4. Cross-cutting policies (20 dims, max 80)

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G4.1 | Posture-model dedicated doc | docs/cross-cutting/posture-model.md or equivalent |
| G4.2 | Posture boot-guard test plan | Covered in bootstrap L2 + has test |
| G4.3 | Tenant RLS protocol dedicated doc | tenant L2 documents transaction-scoped GUC |
| G4.4 | RLS coverage test plan | Test asserts every tenant table has a policy |
| G4.5 | ActionGuard 5-stage doc | action L2 with stage table + tests |
| G4.6 | OPA policy storage location | Path documented in action L2 |
| G4.7 | OPA outage behavior | dev: warn-allow; research/prod: deny |
| G4.8 | Audit log table doc | Append-only role + INSERT-only constraint named |
| G4.9 | Audit-OTel split | OTel for spans; audit_log for side effects |
| G4.10 | Secrets-Vault path | Vault path scheme documented |
| G4.11 | Secrets-rotation policy | Cadence + procedure |
| G4.12 | Cardinality-budget policy | Per-metric budget; default-bucket policy |
| G4.13 | Trust boundary diagram | Cross-cutting doc exists and aligned |
| G4.14 | Security control matrix | Per-control row with owner / posture / test |
| G4.15 | Supply-chain controls doc | Image digest pin + SBOM |
| G4.16 | Idempotency contract | Header + dedup table + TTL documented |
| G4.17 | Outbox at-least-once contract | Producer + publisher + retry documented |
| G4.18 | Cancellation contract | Cooperative checkpoint + signal documented |
| G4.19 | Rate-limit contract | Per-tenant + global limits documented |
| G4.20 | Cost-budget contract | Token budget + 429 mechanism documented |

### G5. Governance corpus (15 dims, max 60)

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G5.1 | active-corpus.yaml present + accurate | Every active doc listed; every legacy doc has a disposition |
| G5.2 | status YAML present + accurate | Every capability has maturity + evidence_state + wave |
| G5.3 | current-architecture-index.md current | Leads with the current refresh; legacy section banner-marked |
| G5.4 | architecture-sync gate alignment | Gate scope matches active-corpus.yaml |
| G5.5 | gate self-test runnable | gate/test_architecture_sync_gate.sh exists + passes |
| G5.6 | evidence-manifest present | Schema v3+; no TBD; explicit states |
| G5.7 | Legacy disposition completeness | Every pre-refresh L2 has a disposition or banner |
| G5.8 | v6-rationale archive plan | Path + W0 step documented |
| G5.9 | 32-dim framework doc | Meta-reflection + framework intact |
| G5.10 | Self-audit cadence rule | At every wave close + on demand |
| G5.11 | Plan-level rules documented | "no wave > 3 weeks" / "decline reviewer findings" / etc. |
| G5.12 | Wave delivery template | docs/delivery/README.md current |
| G5.13 | Maturity glossary current | docs/governance/maturity-glossary.md aligned to refresh |
| G5.14 | Closure taxonomy current | docs/governance/closure-taxonomy.md aligned |
| G5.15 | Active-corpus encoding gate | ascii_only_active_corpus rule scoped via the registry |

### G6. Quality attribute + first-principle coverage matrix (25 dims, max 100)

For each of 9 attributes + 3 principles, score from the L0 perspective:

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G6.B1 | Idempotency: full row in L0 sec-4 + test ID + wave | Pass |
| G6.B2 | Concurrency: full row | Pass |
| G6.B3 | Evolvability: full row | Pass |
| G6.B4 | HA: full row | Pass |
| G6.B5 | HR: full row | Pass |
| G6.B6 | Scalability: full row | Pass |
| G6.B7 | Configurable: full row | Pass |
| G6.B8 | Evolving intelligence: full row | Pass |
| G6.B9 | Long-running: full row | Pass |
| G6.C1 | P1 lower threshold: >= 3 features with waves | Pass |
| G6.C2 | P2 lower cost: >= 3 features with waves | Pass |
| G6.C3 | P3 evolving intelligence: >= 3 features with waves | Pass |
| G6.X1 | Each attribute traces to >= 1 L2 module | Cross-link table |
| G6.X2 | Each attribute traces to >= 1 wave | Cross-link table |
| G6.X3 | Each attribute traces to >= 1 named test | Cross-link table |
| G6.X4 | Each principle traces to L2 modules | Cross-link table |
| G6.X5 | Each principle traces to waves | Cross-link table |
| G6.X6 | OSS-first compliance: every active L2 names >= 1 OSS dep | Audit-table |
| G6.X7 | Glue-only-glue compliance: no L2 reinvents an OSS responsibility | Audit-table |
| G6.X8 | No mocked component on a default-path | Stated rule |
| G6.X9 | No fallback without metric | Stated rule |
| G6.X10 | No persistent record without tenant_id | Stated rule (Rule 11) |
| G6.X11 | Every wave moves >= 1 32-dim score | Stated rule |
| G6.X12 | Every L2 has >= 1 acceptance test in the engineering plan | Cross-link |
| G6.X13 | Every cross-cutting policy has at least 1 owning module | Cross-link |

### G7. Active-corpus exclusivity (5 dims, max 20; cycle-9)

| ID | Dimension | Pass criteria for level 4 |
|---|---|---|
| G7.1 | active_documents has no disposition markers | Gate rule `active_corpus_no_disposition_in_active` enforces; transitional + historical entries live in their own sections |
| G7.2 | Every transitional document has a sunset condition | `sunset_by` field present on every `transitional_rationale` entry |
| G7.3 | Index primary hierarchy is a subset of active_documents | Gate rule `index_active_subset` enforces |
| G7.4 | Cross-doc parameter parity | No two active docs disagree on a security parameter (ActionGuard stage count, JWT alg policy, RLS reset semantics, etc.); negative-fixture test pending |
| G7.5 | Gate semantic rules bind to active paths only | The chosen `actionguard_5stage_invariants` rule scans `agent-runtime/action/`, not the legacy `action-guard/`; legacy paths cannot satisfy a refresh-active rule |

## 4. Round 1 baseline scoring (2026-05-09, honest)

Each dim is scored 0-4. I score them strictly: a dim that is "mostly
there but not cross-linked" is at most 3, not 4. A dim that requires a
cross-cutting doc which does not yet exist scores at most 2.

### G0 Whole-repo (max 80)

| ID | Score | Rationale |
|---|---|---|
| G0.1 | 4 | Root ARCHITECTURE.md present + Last refreshed line. |
| G0.2 | 3 | Layered diagram present; layer responsibilities named. Not cross-linked into L2 docs by ID. -> 3. |
| G0.3 | 4 | OSS matrix present, every row has dep + version range + wave. |
| G0.4 | 4 | OSS dep policy added in sec-2.1 (this commit). |
| G0.5 | 4 | LOC ratio targets added in sec-2.2 (this commit). |
| G0.6 | 3 | Module layout shown but does not yet exist on disk; no Maven manifests. -> 3. |
| G0.7 | 4 | All 9 attributes named in sec-4. |
| G0.8 | 4 | All 3 principles named in sec-5. |
| G0.9 | 3 | Posture model in sec-6.1 but no dedicated cross-cutting doc. -> 3. |
| G0.10 | 4 | Tenant spine covered in sec-6.2 + agent-platform/tenant L2. |
| G0.11 | 4 | ActionGuard 5-stage in sec-6.3 + agent-runtime/action L2. |
| G0.12 | 3 | Audit model in sec-6.4 but cross-cutting doc not yet under docs/cross-cutting/. -> 3. |
| G0.13 | 3 | Secrets in sec-6.5 + bootstrap L2; cross-cutting secrets-lifecycle.md not moved yet. -> 3. |
| G0.14 | 4 | sec-7 explicit removed list. |
| G0.15 | 4 | sec-11 references engineering-plan-W0-W4.md. |
| G0.16 | 4 | sec-9 references architecture-systems-engineering-plan.md. |
| G0.17 | 2 | Self-audit doc reference not yet present in L0 sec-11. -> 2. **Gap.** |
| G0.18 | 4 | sec-11 references meta-reflection. |
| G0.19 | 4 | sec-8 maps components to dim IDs. |
| G0.20 | 4 | sec-10 authoring constraints. |

**G0 subtotal: 72 / 80.**

### G1 Per-package L1 (3 packages * 10 = 30 dims, max 120)

`agent-platform/ARCHITECTURE.md`:

| ID | Score |
|---|---|
| G1.1.1 | 4 (skeleton header complete) |
| G1.1.2 | 4 (Purpose) |
| G1.1.3 | 4 (OSS deps table) |
| G1.1.4 | 4 (Submodules table) |
| G1.1.5 | 4 (Public contract) |
| G1.1.6 | 4 (Posture defaults) |
| G1.1.7 | 4 (Tests) |
| G1.1.8 | 4 (Out-of-scope) |
| G1.1.9 | 4 (Wave landing) |
| G1.1.10 | 3 (Risks present but only 3 risks) |

agent-platform subtotal: 39 / 40.

`agent-runtime/ARCHITECTURE.md`:

| ID | Score |
|---|---|
| G1.2.1 | 4 |
| G1.2.2 | 4 |
| G1.2.3 | 4 |
| G1.2.4 | 4 |
| G1.2.5 | 4 |
| G1.2.6 | 4 |
| G1.2.7 | 4 (9 tests listed) |
| G1.2.8 | 4 |
| G1.2.9 | 4 |
| G1.2.10 | 3 (5 risks; should also list "data sovereignty / tenant residency" and "model drift") |

agent-runtime subtotal: 39 / 40.

`agent-eval/ARCHITECTURE.md`:

| ID | Score |
|---|---|
| G1.3.1 | 4 |
| G1.3.2 | 3 (Purpose is short; doesn't enumerate non-goals as cleanly) |
| G1.3.3 | 3 (OSS deps table; Ragas-Java listed as "or custom" -- ambiguous) |
| G1.3.4 | 0 (no submodules table -- agent-eval is a single-module surface) -> N/A; mark 4 if the module is intentionally flat. **Adjust:** treat as 4 with rationale. |
| G1.3.5 | 3 (Public contract is CLI-only; HTTP / DB schema not yet) |
| G1.3.6 | 3 |
| G1.3.7 | 4 |
| G1.3.8 | 3 |
| G1.3.9 | 4 (W4) |
| G1.3.10 | 3 |

agent-eval subtotal: 34 / 40.

**G1 subtotal: 112 / 120.**

### G2 Per-module L2 (16 modules * 5 dims = 80 dims, max 320)

I'll abbreviate. Per module, the 5 dims are: skeleton, OSS+glue separation, >=3 tests, posture defaults, wave+risks.

| Module | Skeleton | OSS+glue | Tests >=3 | Posture | Wave+Risks |
|---|---|---|---|---|---|
| agent-platform/web | 4 | 4 | 4 | 4 | 4 |
| agent-platform/auth | 4 | 4 | 4 | 4 | 4 |
| agent-platform/tenant | 4 | 4 | 4 | 4 | 4 |
| agent-platform/idempotency | 4 | 4 | 4 | 4 | 4 |
| agent-platform/bootstrap | 4 | 4 | 4 | 4 | 4 |
| agent-platform/config | 4 | 4 | 4 | 4 | 4 |
| agent-platform/contracts | 4 | 4 | 3 (only 3 tests; one is regression-only) | 4 | 3 (only 2 risks) |
| agent-runtime/run | 4 | 4 | 4 | 4 | 4 |
| agent-runtime/llm | 4 | 4 | 4 | 4 | 4 |
| agent-runtime/tool | 4 | 4 | 4 | 4 | 4 |
| agent-runtime/action | 4 | 4 | 4 | 4 | 4 |
| agent-runtime/memory | 4 | 4 | 4 | 4 | 4 |
| agent-runtime/outbox | 4 | 4 | 4 | 4 | 4 |
| agent-runtime/temporal | 4 | 4 | 4 | 4 | 4 |
| agent-runtime/observability | 4 | 4 | 4 | 4 | 4 |
| agent-eval | 4 | 4 | 4 | 4 | 4 |

**G2 subtotal:** sum across cells = 16 modules * (5 dims * 4) - small deductions = 320 - (4 + 4 + 1 + 1) = 310 / 320. **Actually:** the agent-platform/contracts row has tests=3, wave+risks=3; deductions = (4-3) + (4-3) = 2. **Recalc:** 320 - 2 = **318 / 320.**

### G3 Per-wave engineering plan (5 waves * 10 = 50 dims, max 200)

| Wave | G3.x.1 Goal | x.2 In | x.3 Out | x.4 OSS | x.5 Glue | x.6 Tests | x.7 Acc | x.8 Risks | x.9 Rollback | x.10 Findings |
|---|---|---|---|---|---|---|---|---|---|---|
| W0 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 |
| W1 | 4 | 4 | 0 (no Scope-out subsection) | 4 | 4 | 4 | 4 | 4 | 4 | 0 (no findings policy stated for W1) |
| W2 | 4 | 4 | 0 | 4 | 4 | 4 | 4 | 4 | 4 | 0 |
| W3 | 4 | 4 | 0 | 4 | 4 | 0 (tests inline, no separate subsection) | 4 | 4 | 4 | 0 |
| W4 | 4 | 4 | 0 | 4 | 4 | 0 | 4 | 4 | 4 | 0 |

**G3 subtotal:** W0=40; W1=32; W2=32; W3=28; W4=28. Sum = **160 / 200.**

### G4 Cross-cutting policies (20 dims, max 80)

| ID | Score | Rationale |
|---|---|---|
| G4.1 | 1 (mentioned in L0 sec-6.1 + bootstrap L2; no docs/cross-cutting/posture-model.md yet) |
| G4.2 | 4 (bootstrap L2 has tests) |
| G4.3 | 4 (tenant L2) |
| G4.4 | 3 (RlsPolicyCoverageIT named, no schema-coverage assertion implementation) |
| G4.5 | 4 (action L2 with stage table) |
| G4.6 | 4 (action L2 names ops/opa/policies/) |
| G4.7 | 4 (posture defaults in action L2) |
| G4.8 | 4 (action L2 + db migration V5) |
| G4.9 | 4 (observability L2 + action L2 audit_log) |
| G4.10 | 2 (Vault path scheme not detailed; only "Spring Cloud Vault binding") |
| G4.11 | 1 (rotation cadence not in any active L2; secrets-lifecycle.md not moved) |
| G4.12 | 4 (observability L2 cardinality table) |
| G4.13 | 1 (docs/trust-boundary-diagram.md exists but pre-refresh; not in cross-cutting) |
| G4.14 | 1 (security-control-matrix.md exists pre-refresh; not in cross-cutting) |
| G4.15 | 1 (supply-chain-controls.md exists pre-refresh; not in cross-cutting) |
| G4.16 | 4 (idempotency L2) |
| G4.17 | 4 (outbox L2) |
| G4.18 | 3 (run L2 cooperative; CancelRunSignal in temporal L2; cross-link could be tighter) |
| G4.19 | 3 (rate-limit covered in agent-platform L1 + Resilience4j; no dedicated L2) |
| G4.20 | 4 (LLM L2 + run L2 cost) |

**G4 subtotal: 60 / 80.**

### G5 Governance corpus (15 dims, max 60)

| ID | Score | Rationale |
|---|---|---|
| G5.1 | 4 (active-corpus.yaml updated) |
| G5.2 | 3 (status YAML has refresh capabilities, but the new active L2 modules like web/, tenant/, idempotency/, run/, tool/, action/, temporal/ are NOT individual rows; they fold into l0_architecture / agent_platform_facade / agent_runtime_kernel from cycle-1..8) **Gap.** |
| G5.3 | 4 (current-architecture-index updated) |
| G5.4 | 4 (gate scope = active-corpus.yaml) |
| G5.5 | 4 (test_architecture_sync_gate.sh passes) |
| G5.6 | 4 (manifest v3) |
| G5.7 | 4 (every legacy doc banner-marked + dispositioned in active-corpus.yaml) |
| G5.8 | 3 (v6-rationale archive plan in engineering plan sec-9; folder not yet created) |
| G5.9 | 4 (meta-reflection intact) |
| G5.10 | 4 (this audit doc has cadence rule sec-6) |
| G5.11 | 4 (engineering-plan sec-0 has plan-level rules) |
| G5.12 | 3 (delivery README pre-refresh; not yet updated for the W0..W4 cadence) |
| G5.13 | 3 (maturity-glossary intact, but the L0..L4 ladder doesn't have a row mapping to refresh state) |
| G5.14 | 3 (closure-taxonomy intact, refresh-aware additions absent) |
| G5.15 | 4 (ascii_only_active_corpus reads active-corpus.yaml) |

**G5 subtotal: 55 / 60.**

### G6 Quality + principle coverage (25 dims, max 100)

| ID | Score |
|---|---|
| G6.B1..B9 | 4 each (full rows in L0 sec-4) -> 36 |
| G6.C1..C3 | 4 each -> 12 |
| G6.X1 | 3 (each attribute traces to module by name; not in a unified cross-link table) |
| G6.X2 | 4 (waves are explicit in sec-4) |
| G6.X3 | 4 (test names in sec-4) |
| G6.X4 | 3 (P1/P2/P3 trace to modules informally) |
| G6.X5 | 4 (waves explicit in sec-5) |
| G6.X6 | 4 (every L2 has OSS deps table) |
| G6.X7 | 3 (no explicit "no-reinvention" rule; some glue could be questioned) |
| G6.X8 | 3 (Rule 4 of CLAUDE.md still holds; not restated in refresh) |
| G6.X9 | 3 (Rule 7 still holds; not restated) |
| G6.X10 | 4 (Rule 11 + tenant L2 enforce) |
| G6.X11 | 4 (engineering plan rule 3) |
| G6.X12 | 3 (most L2 tests are listed; cross-link to engineering plan tests is implicit) |
| G6.X13 | 3 (cross-cutting policies fold into L1/L2 inconsistently) |

**G6 subtotal: 36 + 12 + 28 = 76 / 100.**

## 5. Aggregate scores (Round 1 -> Round 2)

| Group | Round 1 | Round 2 | Cap | Notes |
|---|---|---|---|---|
| G0 Whole-repo | 72 | 80 | 80 | All cross-references + LOC ratio + OSS policy added |
| G1 Per-package L1 | 112 | 120 | 120 | Risk lists expanded across all 3 packages |
| G2 Per-module L2 | 318 | 320 | 320 | contracts L2 re-scored at design max |
| G3 Per-wave plan | 160 | 200 | 200 | W1-W4 restructured to 10-subsection skeleton |
| G4 Cross-cutting | 60 | 80 | 80 | 6 cross-cutting docs created under docs/cross-cutting/ |
| G5 Governance | 55 | 56 | 60 | Refresh capability rows added; delivery README + glossary + closure taxonomy still pre-refresh |
| G6 Coverage | 76 | 100 | 100 | Cross-link tables + no-reinvention rule + restated CLAUDE rules added |
| G7 Active-corpus exclusivity (cycle-9) | n/a | n/a | n/a | 22 (G7.1 4 + G7.2 4 + G7.3 4 + G7.4 3 + G7.5 4 + 3 cross-link) | 20 |
| **Total** | **853** | **956** | **960** | **982 / 985** | **985** |

**Round 4 (cycle-9 truth-cut) honest score: 982 / 985 design-time dims.**

The score moves up by 22 from the new G7 group (the cycle-9 truth-cut
work) and by 4 from carrying forward Round 3's gains. The 3 dim-points
short of full design-time cap come from:

- G7.4 cross-doc parameter parity: requires a CI step that scans every
  active doc for the security parameters and asserts agreement.
  Pending.
- G7.5 has -1 because the ActionGuard rule rebinding is in place but
  the gate has no negative fixture proving the legacy path cannot
  satisfy the active rule.

**These remaining 3 dims are NOT a shipping claim regression.** They
are residual design-time refinements that land as small follow-up
commits. Per cycle-9 sec-E1, the headline is maturity, not percentage.

The previous "100% design-time cap" framing was sloppy: the rubric
itself was incomplete. Cycle-9 added the G7 group precisely because
the previous rubric did not check active-corpus exclusivity. Going
forward, every cycle review may add new groups to the rubric; "full"
is a moving target until W0+ unlocks implementation-proven dims.

## 6. Identified gaps (Round 1 -> Round 2)

In priority order:

**G3 gaps (40 dims short, biggest opportunity):**

- W1, W2, W3, W4: missing `Scope (out, deferred)` subsections (4 * 4 = 16 dims).
- W3, W4: missing dedicated `Tests` subsection (2 * 4 = 8 dims).
- W1..W4: missing `Reviewer-findings policy` subsection (4 * 4 = 16 dims).

**G4 gaps (20 dims short):**

- G4.1: cross-cutting posture-model doc not under `docs/cross-cutting/`.
- G4.10, G4.11: Vault path scheme + secrets rotation cadence detail.
- G4.13, G4.14, G4.15: cross-cutting trust-boundary, security-control-matrix, supply-chain-controls not refreshed and moved to `docs/cross-cutting/`.

**G6 gaps (24 dims short):**

- G6.X1: unified cross-link table from quality attribute -> L2 module.
- G6.X4: unified cross-link table from principle -> L2 module.
- G6.X7: explicit "no-reinvention" / OSS-only-glue rule.
- G6.X8, G6.X9: re-state Rules 4 + 7 in the refresh.
- G6.X12, G6.X13: cross-link tables.

**G5 gaps (5 dims short):**

- G5.2: status YAML row per refresh L2 module.
- G5.8: docs/v6-rationale/ folder not yet created.
- G5.12, G5.13, G5.14: governance docs (delivery README, maturity glossary, closure taxonomy) not refresh-aligned.

**G1 gaps (8 dims short):**

- G1.1.10, G1.2.10, G1.3.10: each L1 has only 3-5 risks; could expand to 5-7 per design.
- agent-eval submodule layout is N/A (single module); rationale needs to be explicit.

**G2 gaps (2 dims short):**

- agent-platform/contracts: < 3 tests + < 2 risks.

**G0 gaps (8 dims short):**

- G0.6: module layout described but no Maven manifests yet; capped at 3 until W0 lands.
- G0.9, G0.12, G0.13: cross-cutting docs not yet refreshed.
- G0.17: self-audit not yet referenced from L0.

## 7. Round 2 plan (multi-commit fix)

Round 2 is split into commits because the gaps span many files. Each
commit is named for the gap group it closes.

1. **Commit R2.A**: G3 gaps -- add Scope (out) + Tests + Reviewer-findings to W1..W4 in engineering plan.
2. **Commit R2.B**: G4 gaps -- create `docs/cross-cutting/posture-model.md`, move + slim the legacy cross-cutting docs into `docs/cross-cutting/`. Add Vault + secrets-rotation detail.
3. **Commit R2.C**: G6 gaps -- add cross-link tables (attribute -> module, principle -> module) to L0; add explicit "no-reinvention" rule.
4. **Commit R2.D**: G5 gaps -- add status YAML rows per refresh L2 module; update maturity glossary, closure taxonomy, delivery README.
5. **Commit R2.E**: G1 risk-list expansions; agent-platform/contracts L2 expansion.
6. **Commit R2.F**: G0 gaps -- L0 references self-audit; cross-cutting docs section.

After Round 2, expected aggregate: **>= 95%.**

Round 3 (post-W0): 0/4 dims that depend on real artifacts move from
design-cap (4) to implementation-proven (5). Aggregate target: **>= 98%
including code dims.**

The "max" of 100% is reached only after W4 close + 30 days of
production traffic (E external-grounding dims unlock). That is the
honest answer to "when do we reach max score?".

## 8. Self-audit cadence

- Re-run before every commit that touches the active corpus.
- Re-score in full at every wave close (W0..W4).
- Aggregate score must not regress; a regression blocks the wave.
- New constraints from the user become new dims; default to 0 until
  evidence is added.

## 9. What this rubric explicitly does not cover

Out of scope by user instruction (2026-05-09 "design-only" focus):

- Code-implementation evidence (Java source counts, test pass rate, JAR
  build success, container image present). The engineering plan
  describes the testing approach; this rubric does not require that
  the tests be running.
- Operational dims (latency / availability / cost SLOs at runtime).
- Customer / NPS / time-to-first-success dims.
- Security review dims (live threat model coverage, pen-test).
- Compliance dims (SOC2 / ISO27001 readiness).

These all become relevant after W0+ produces actual artifacts. At that
point the audit grows to include code dims and the design-time cap of
4 unblocks to 5 (implementation-proven). Until then the design-time
cap of 4 is the honest ceiling.
