> ⚠ **HISTORICAL DOCUMENT — DO NOT IMPLEMENT.** This is a 2026-05-07 review snapshot kept for traceability. The current authoritative architecture corpus is indexed in [`docs/governance/current-architecture-index.md`](governance/current-architecture-index.md). Do not copy examples, claims, or recommendations from this file into current implementation work without cross-checking the current L0/L1/L2 documents.

# spring-ai-fin Architecture Review Document

**Document version:** 1.0 · **Date:** 2026-05-07 · **Status:** Architecture Review Committee Edition

> **Audience:** Architecture review committee (mixed: senior architects, security, compliance, operations, skeptics). 
> **Goal:** Give committee members enough depth to evaluate spring-ai-fin v6.0 across **functional, security, compliance, operability, evolution, and cost** dimensions, with traceable decision chains and falsifiable assertions.
> **Companion documents** (binding):
> - L0 system boundary: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) (≈1,500 lines, 17 numbered design decisions)
> - L1 northbound facade: [`../agent-platform/ARCHITECTURE.md`](../agent-platform/ARCHITECTURE.md)
> - L1 cognitive runtime: [`../agent-runtime/ARCHITECTURE.md`](../agent-runtime/ARCHITECTURE.md)
> - L2 docs for 9 critical subsystems (see §11.2)
> - Behavioural rules: [`../CLAUDE.md`](../CLAUDE.md)
> - v5.0 historical input: [`architecture-v5.0.md`](architecture-v5.0.md)
> - v5.0 adversarial review: [`architecture-v5.0-review-2026-05-07.md`](architecture-v5.0-review-2026-05-07.md)
> - Predecessor: `D:/chao_workspace/hi-agent/ARCHITECTURE.md` (32 production waves of operational learning)

---

## Table of Contents

- [Part I — Executive Summary for Committee](#part-i--executive-summary-for-committee)
  - 1. The 60-second pitch
  - 2. What we're building (and what we are NOT)
  - 3. Why this is different from v5.0 — and why the difference matters
  - 4. The single most important takeaway
- [Part II — How to Read This Document](#part-ii--how-to-read-this-document)
  - 5. Per-role reading paths
  - 6. Falsifiable assertions catalog
  - 7. Decision-chain index
- [Part III — The Architecture in Six Dimensions](#part-iii--the-architecture-in-six-dimensions)
  - 8. Functional dimension
  - 9. Security dimension
  - 10. Compliance dimension
  - 11. Operability dimension
  - 12. Evolution dimension
  - 13. Cost dimension
- [Part IV — Decision Chain Deep Dives](#part-iv--decision-chain-deep-dives)
  - 14. The 17 architectural decisions
  - 15. Comparison: v5.0 → v6.0 deltas
- [Part V — Engineering Discipline Inheritance](#part-v--engineering-discipline-inheritance)
  - 16. The 12 universal rules from CLAUDE.md
  - 17. The Three-Gate intake
  - 18. The operator-shape readiness gate
- [Part VI — Validation, Risks, and Open Questions](#part-vi--validation-risks-and-open-questions)
  - 19. How we will know the architecture is correct
  - 20. Top-tier risks (HIGH severity)
  - 21. Tier-2 deferrals — adopted when traffic justifies
  - 22. Open questions awaiting committee guidance
- [Part VII — Reviewer Workflow](#part-vii--reviewer-workflow)
  - 23. How to produce dissent
  - 24. Approval criteria
  - 25. Post-approval cadence

---

# Part I — Executive Summary for Committee

## 1. The 60-second pitch

spring-ai-fin is a **capability-layer enterprise agent platform** purpose-built for **financial institutions in Southeast Asia** (Indonesia OJK / UU PDP, Singapore MAS / PDPA — extensible to HK / VN / PH / TH). It runs on **Java + Spring Boot + Spring AI 1.1+** (unmodified), exposes a **frozen v1 HTTP contract** for customer apps, and dispatches agent execution to **multiple frameworks** (Spring AI native, LangChain4j, Python sidecars for LangGraph/CrewAI/AutoGen) — without trapping customers in a single AI-framework choice.

The platform is built around **12 universal engineering rules** inherited from a predecessor system (hi-agent) that survived 32 production release waves. Those rules — posture-aware defaults, single construction path, async resource lifetime, observable degradation, contract spine, capability maturity ladder, operator-shape readiness gate — are the load-bearing engineering invariants of the architecture, NOT the components.

**The v6.0 architecture is the result of an adversarial review** of a prior v5.0 document that was found to violate four of those rules and committed the platform to ~80 components, a custom Spring AI fork, FIBO ontology integration, and an "AI-First three-layer exception handling" feature that is in fact a silent-degradation engine. v6.0 corrects all six HIGH-severity findings and eight of nine MEDIUM-severity findings from that review.

## 2. What we're building (and what we are NOT)

### Building

```
┌──────────────────────────────────────────────────────────────────┐
│ Tier-A Northbound Facade — agent-platform/                       │
│ • Frozen v1 HTTP contract (`/v1/*`)                              │
│ • Filter chain: JWTAuth → TenantContext → Idempotency            │
│ • Operator CLI                                                   │
│ • Customer Spring Boot Starters                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │  (Single-seam discipline; SAS-1)
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ Tier-B Cognitive Runtime — agent-runtime/                        │
│ • TRACE 5-stage durable RunExecutor                              │
│ • LLMGateway over Spring AI ChatClient                           │
│ • FrameworkAdapter dispatch (Spring AI / LangChain4j / Python)   │
│ • Memory + Knowledge + Skill subsystems                          │
│ • Observability spine + Outbox + Sync-Saga + Direct-DB           │
└──────────────────────────────────────────────────────────────────┘
                              │  (Outbound only)
                              ▼
                     LLM providers, Postgres, MCP servers, sidecars
```

### NOT building

- **Business logic** (KYC rules, AML thresholds, suitability rubrics, regulator-specific report shapes). These belong in the customer's code or in an **out-of-repo** `fin-domain-pack/` per regulatory deal.
- **A custom Spring AI fork** ("spring-ai-fin" framework). v5.0 proposed this; we explicitly rejected. We use Spring AI 1.1+ unmodified and ship Starters + Advisors only.
- **80+ components**. v5.0 proposed this; our MVP Tier-1 = 11 components. The other 38+ are deferred until production traffic justifies (Tier-2) or rejected outright (Tier-3, mostly license risks).
- **AI-First three-layer exception handling** Layer-2 ("AI Operator analyses, suggests, auto-acts"). v5.0 included this in default path; v6.0 dropped it from v1 because it is the most powerful possible silent-degradation pattern. Layer-2 returns in v1.1 as a research-posture-only opt-in with full Rule 7 four-prong instrumentation.
- **FIBO three-layer ontology** with Apache Jena + Protégé + SPARQL + JSON-LD + SHACL. v6.0 ships PostgreSQL JSONB + a 30–50 class hand-curated finance glossary. Full FIBO deferred to phase-2 with a regulatory trigger.
- **Behaviour-version pinning "permanently retained"**. v6.0 ships pinning OFF by default; opt-in premium with a hard 5-year cap.
- **Cross-tenant aggregation, dual-region active-active, auto-optimization flywheel, WebSocket protocol, hot-reload of platform config** — all deferred to v1.1+.

## 3. Why this is different from v5.0 — and why the difference matters

The v5.0 document was 9,922 lines proposing a 17-chapter architecture across 80+ components. An adversarial review (`docs/architecture-v5.0-review-2026-05-07.md`) found:

| Severity | Count | Category |
|---|---|---|
| **HIGH** | 6 | Direct violations of CLAUDE.md universal rules; would block ship |
| **MEDIUM** | 9 | Premature optimization; design defects; missing posture coverage |
| **LOW** | 5 | Editorial / cosmetic |

The 6 HIGH findings (and v6.0 fixes):

| # | v5.0 problem | v6.0 fix |
|---|---|---|
| H1 | No CLAUDE.md alignment — posture / maturity / Three-Gate / Rule-8 gate ALL missing | v6.0 inherits all 12 universal rules + Three-Gate + operator-shape gate from day-0 |
| H2 | "80+ components" inflates 49 actual; only 11 on KYC happy path | Tier-1 MVP = 11 components; Tier-2 deferred with named triggers |
| H3 | AI-First Layer-2 "AI Operator" violates Rule 7 (silent-degradation engine) | Removed from v1 default path; returns in v1.1 with Rule 7 four-prong |
| H4 | Behaviour pinning "permanently retained" contradicts itself; not engineered | Default OFF; opt-in premium; 5-year hard cap |
| H5 | 10-layer tenant propagation is theatrical (no contract spec) | Single `TenantContext` record + 4 shadow-path tests per layer |
| H6 | Outbox-as-universal punts the canonical financial transaction (fund transfer) | Three named paths: OUTBOX_ASYNC + SYNC_SAGA + DIRECT_DB; `@WriteSite` annotation enforced by CI |

**Why this matters to the committee**: v5.0 was an expression of architectural ambition without operational discipline. v6.0 inherits 32 release waves of hard-won lessons from a predecessor that lived through similar ambitions and learned what fails. The architecture review committee's job is to evaluate whether v6.0's discipline-first reframe survives contact with reality. We argue: yes, because the discipline (the rules) and the components (Tier-1) are minimal enough that any reasonable production deployment can adopt them without the wave-1 cliff that v5.0 would have produced.

## 4. The single most important takeaway

**The architecture is correct as a 12-month roadmap, not a day-0 spec.** Every "advanced" feature in v5.0 is preserved as an explicit deferred capability with a named trigger:

- Multi-tier inference cache: deferred until per-call cost data justifies
- FIBO ontology: deferred until a regulator demands semantic-graph reasoning evidence
- Auto-optimization flywheel: deferred to v1.1 as research-posture opt-in
- Behaviour pinning subsystem: deferred to v1.1 (contract honoured by manual freeze in v1)
- Kafka + Istio + Milvus + NebulaGraph: Tier-2; adopted when service count or traffic justifies

The committee should evaluate v6.0 as a **disciplined MVP with a credible expansion roadmap**, not as a feature-complete v1.

---

# Part II — How to Read This Document

## 5. Per-role reading paths

The committee has heterogeneous expertise; this document has six dimensions. The cross-product is too much for any one reviewer. Here are role-specific paths:

| Role | Suggested path | Time | Goal |
|---|---|---|---|
| **Senior architect** | §1 → §2 → §8 (functional) → §14 (decisions) → §19 (validation) | 90 min | Is the architecture coherent and falsifiable? |
| **Security reviewer** | §1 → §9 (security) → §14 D-7 / D-12 / D-15 → §10 (compliance) → §20 (HIGH risks) | 60 min | Are the auth, tenancy, PII, and audit boundaries defensible? |
| **Compliance reviewer** | §1 → §10 (compliance) → §3 (v5.0 deltas) → §20 (HIGH risks H4) → §22 (open questions on bias audit + KMS) | 75 min | Can this pass an OJK or MAS review? |
| **Operations / SRE** | §1 → §11 (operability) → §18 (operator-shape gate) → §11.5 (sizing & DR) → §20 (operational risks) | 90 min | Can we run this 24/7 across BYOC and SaaS? |
| **Skeptical reviewer** | §3 → §14 (every decision) → §15 (v5.0 deltas — what we removed and why) → §20 → §22 | 60 min | Is the case for v6.0 supported by evidence? |
| **Cost / commercial reviewer** | §1 → §13 (cost dimension) → §16 (Tier-2 deferrals) → §22 (open questions on pricing) | 45 min | Is the commercial model viable? |

Each section in Parts III and IV ends with **"How to evaluate this"** — a list of falsifiable assertions reviewers can challenge.

## 6. Falsifiable assertions catalog

Throughout this document, claims are marked with **A-N.M** identifiers and accompanied by a falsification test. Reviewers should produce concrete dissent in the form: *"Assertion A-N.M fails because <specific scenario>"*. Vague concerns ("this seems risky") are not actionable. Below is the consolidated catalog.

| ID | Assertion | Falsification test |
|---|---|---|
| **A-1.1** | "Capability-layer only" is genuine, not theatrical | Find an `agent-platform/contracts/v1/` record that hard-codes a finance domain shape (KYC, AML, OJK form). |
| **A-1.4** | Posture-aware defaults survive code-review drift | Find a posture-branched conditional outside `requires*()` helpers. |
| **A-1.5** | Polyglot frameworks via gRPC sidecars stay sub-100ms p95 | Operator-shape gate at W2 measures; if > 100ms, defer Python sidecar to v1.1. |
| **A-2.1** | Compliance owners are mapped concretely per regulator | A regulator audit walks in tomorrow; can §10 + §11.4 produce evidence in <1 day? |
| **A-3.1** | Two-package layering survives a real refactor wave | hi-agent's R-AS-1 survived 32 waves; replicate in spring-ai-fin via `ArchUnit`. |
| **A-3.2** | SAS-1 through SAS-10 are strict enough | Find a careless contributor scenario that passes all 10 gates but breaks layering. |
| **A-5.1** | Filter chain order (JWT → Tenant → Idempotency) is correct | Find a customer scenario that wants idempotency before tenant verification. |
| **A-5.4** | `@WriteSite` annotation scales to 100+ write sites | `WriteSiteAuditTest` runs in <1s; reviewer can grep all annotations in O(LOC). |
| **A-7.1** | Posture is a single boot-time read | Find a code path that reads `APP_POSTURE` per-request. |
| **A-7.10** | Spring Security off for v1 is not a regression | Find a Spring Security feature whose absence causes a Tier-1 customer outage. |
| **A-8.1** | L3 capability requires four-prong evidence | Find an L3-claimed capability with no Rule-7 instrumentation. |
| **A-9.1** | Flywheels deferred but ready | Trace event shape sufficient for v1.1 reflection-engine consumption. |
| **A-10.1** | 5 isolation dimensions × `TenantContext` × 4 shadow-path tests = sufficient | Find a tenant-leak scenario not covered. |
| **A-10.5** | 6-step operator-shape gate is sufficient | Construct a defect that passes all 6 PASS but fails in production. |
| **A-13.1** | BYOC reference fits in customer's existing K8s namespace | Standard Kubernetes-compatible deployment requirements; PM2/systemd alternative provided. |
| **A-13.3** | Sizing tier S = 2 replicas + small DB is enough for a small bank pilot | Validate at 10 RPS sustained; trigger upgrade at p95 breach. |

## 7. Decision-chain index

The 17 architectural decisions documented in §14 are listed below for quick reference:

| ID | Decision | Where |
|---|---|---|
| D-1 | Capability-layer positioning, NOT domain-layer | §14.1 |
| D-2 | Two-package layering with single seam (SAS-1) | §14.2 |
| D-3 | Frozen v1 contract / parallel v2 (SAS-3) | §14.3 |
| D-4 | Spring AI 1.1+ unmodified (NOT a custom framework) | §14.4 |
| D-5 | Multi-framework dispatch via single `FrameworkAdapter` interface | §14.5 |
| D-6 | Three-posture model (Rule 11) | §14.6 |
| D-7 | Auth-authoritative `tenantId` | §14.7 |
| D-8 | Outbox + Sync-Saga + Direct-DB (the H6 fix) | §14.8 |
| D-9 | TRACE 5-stage durable model (inherited from hi-agent) | §14.9 |
| D-10 | AI-First Layer-2 exception handling REMOVED from v1 default path (H3 fix) | §14.10 |
| D-11 | Behaviour-version pinning OFF by default; opt-in premium with 5-year cap (H4 fix) | §14.11 |
| D-12 | TenantContext as binding contract (H5 fix) | §14.12 |
| D-13 | API stability vs Behaviour stability (separated) | §14.13 |
| D-14 | Higress as north-south gateway (deployment dependency, not code dependency) | §14.14 |
| D-15 | License preference Apache 2.0 / MIT only on runtime path (M6 fix) | §14.15 |
| D-16 | Operator-shape readiness gate (Rule 8) — six PASS assertions | §14.16 |
| D-17 | L0–L4 capability maturity (Rule 12) | §14.17 |

---

# Part III — The Architecture in Six Dimensions

The committee asked for multi-dimensional review. The platform's responsibility-set is wide; this section narrows the lens to specific dimensions so different reviewers can audit their concerns without reading every paragraph.

## 8. Functional dimension

### 8.1 What the platform DOES

The platform processes one canonical request type — `POST /v1/runs` — through a 5-stage durable lifecycle (TRACE: Task → Route → Act → Capture → Evolve). Around this canonical request are 8 supporting resource families: artifacts, gates, manifest, skills, memory, MCP tools, audit, run-events streaming.

**Canonical happy path** (KYC agent run):

```
1. Customer app → Higress (north-south) → POST /v1/runs (Bearer JWT, X-Tenant-Id, Idempotency-Key)
2. agent-platform filter chain validates JWT, tenant, idempotency
3. RunFacade.start dispatches to RealKernelBackend (SAS-1 seam #2)
4. agent-runtime RunManager creates run, enqueues, returns 201
5. Background queue worker claims run; RunExecutor begins TRACE S1
6. S1 (Task) — parse goal, build TaskView, validate
7. S2 (Route) — choose capability + framework + tier
8. S3 (Act) — dispatch via FrameworkAdapter (Spring AI / LangChain4j / Python sidecar)
9. LLMGateway.complete with TierRouter routing + FailoverChain
10. Tool calls (MCP) + retrieval (knowledge) as needed
11. S4 (Capture) — persist artifacts; outbox event; audit
12. S5 (Evolve) — recurrence-ledger update; experiment posting
13. RunExecutor records run_completed; lease released
14. Customer SSE-streams `/v1/runs/{id}/events` to receive results live
```

### 8.2 What the platform DOES NOT do

Already covered in §2 ("NOT building"). Critical exclusions:

- The platform does NOT host customer financial logic; the customer's KYC rules / suitability rubrics live in customer code or `fin-domain-pack/`.
- The platform does NOT decide regulatory outcomes; it provides observable, auditable, gate-able execution; the customer's compliance policies decide.
- The platform does NOT issue JWTs; customer's IdP (Keycloak / Okta / AWS Cognito / etc.) issues; we validate.

### 8.3 Multi-framework dispatch — the user's distinguishing requirement

The user's brief: *"我们希望可以运行业内主流的智能体框架"* — support running mainstream agent frameworks. The platform implements this via a single `FrameworkAdapter` interface dispatching to:

| Adapter | Status at v1 | Posture | Process |
|---|---|---|---|
| `SpringAiAdapter` | L3 default | dev/research/prod | in-process |
| `LangChain4jAdapter` | L2 opt-in | dev/research/prod | in-process |
| `PySidecarAdapter` | L2 opt-in | research/prod (dev allowed for testing) | out-of-process gRPC |

`PySidecarAdapter` runs Python frameworks (LangGraph, CrewAI, AutoGen, Pydantic-AI, OpenAI Agents SDK) in their own Docker container. Customer chooses which Python framework via the published `springaifin/py-sidecar:1.0.0` image. The sidecar is **strictly out-of-process**: no JVM/Python in-process bridging (Rule 5 catastrophic failure mode prevented).

Detailed design: [`../agent-runtime/adapters/ARCHITECTURE.md`](../agent-runtime/adapters/ARCHITECTURE.md).

### 8.4 How to evaluate §8

- **A8.1**: "Single canonical request shape covers the use cases" — find a finance use case that doesn't fit `POST /v1/runs` shape (e.g., bulk batch operations, real-time fraud streaming).
- **A8.3**: "Three adapters are sufficient" — find a mainstream framework not in the three families (Java in-process, Python out-of-process, Spring AI native).

---

## 9. Security dimension

### 9.1 Authentication

- **JWT HMAC-SHA256** validated by `JwtAuthFilter` in `agent-platform/api/`. 
- `APP_JWT_SECRET` required under `research`/`prod`; passthrough in `dev`.
- JWT claims: `userId`, `tenantId`, `projectId`, `roles`, `expiry`.
- Single trust origin: customer's IdP signs the JWT; we never issue.
- **Reviewer test (A-9.1)**: provide a malformed JWT under `prod` posture; expect 401.

### 9.2 Authorization

- Role-based via JWT `roles` claim.
- Capability-level policy via `CapabilityPolicy.canInvoke(role, capability)`.
- Specific high-risk actions require **dual approval** (audit decode, red-line modification, regulatory reporting).
- No role-based API endpoints today — every authenticated user can reach every `/v1/*` route, with capability-level checks at the runtime layer (this is intentional: route-level is shallow, capability-level is the trustworthy boundary).

### 9.3 Tenant isolation (the H5 fix)

Five isolation dimensions; one binding `TenantContext` contract:

| Dimension | Mechanism | Posture-dependent |
|---|---|---|
| Data | Postgres RLS `tenant_id = current_setting('app.tenant_id')` | yes |
| Compute | Single-process JVM at MVP; per-tenant Reactor partition deferred | no (v1) |
| Network | Higress JWT scope; mTLS optional | no |
| Cache | Valkey keys prefixed `tenant:{tenantId}:` | no |
| Model | LLM call carries tenant_id in metadata; per-tenant budget; tenant-scoped prompt cache | yes |

`TenantContext` — Java record with frozen fields; MDC key `tenant.id`; Reactor Context key `TENANT_ID`; gRPC metadata key `x-tenant-id`. Behaviour on missing tenant: `dev` warn, `research`/`prod` reject 401. **Four shadow-path tests (happy / nil / empty / error) per layer** ensure the contract doesn't drift.

Detailed design: [`../ARCHITECTURE.md#102-tenantcontext-propagation-contract-binding`](../ARCHITECTURE.md).

### 9.4 Input validation

- All `@RequestBody` via Spring `@Valid` + JSON-Schema in v1 contracts
- All record canonical constructors validate (Rule 11 spine)
- Goal length limit, tool-call shape, etc. enforced at contract level

### 9.5 PII redaction (compliance-critical)

- **Microsoft Presidio** integration in `agent-runtime/audit/PiiRedactor.java`
- PII tokens replaced with **format-preserving tokens (FF3-1)** at write
- Decoding requires **dual-approval workflow**:
  1. Compliance Officer 1 requests decode (logged to audit immediately)
  2. Compliance Officer 2 approves (logged)
  3. Plaintext returned with **15-minute TTL**
  4. After TTL, decoded data evicted; only audit trail remains
- Inspector role can query audit without decode

Detailed flow: [`../ARCHITECTURE.md#55-pii-decode-dual-approval-workflow`](../ARCHITECTURE.md).

### 9.6 Audit immutability

- `audit_event` table append-only; `UPDATE`/`DELETE` permitted only by maintenance role (rotation, PII redaction)
- Daily snapshot to **WORM-anchored storage**:
  - SaaS: S3 Object Lock (governance mode)
  - BYOC: SeaweedFS with append-only role + customer's WORM target
- Per-day Merkle root anchored to **RFC 3161 timestamp service** for tamper-evidence

### 9.7 Secret management

- **OpenBao (MPL 2.0)** instead of HashiCorp Vault BUSL (license safety per D-15)
- 30-day rotation for DB credentials
- LLM API keys per provider TOS

### 9.8 Network boundary

- Higress north-south
- mTLS optional in BYOC (customer choice)
- No inbound admin port (operations via JWT-authenticated CLI or out-of-band SSH to BYOC environment)

### 9.9 Common attack vectors and mitigations

| Vector | Mitigation |
|---|---|
| JWT forgery | HMAC-SHA256 validation; single trust origin |
| Tenant ID spoofing in body | Auth-authoritative cross-check; `TenantScopeException` on mismatch under strict |
| Path traversal in workspace | Path canonicalization + jail to tenant-prefix |
| SQL injection | JPA / jOOQ generated only; raw `PreparedStatement` requires `// raw-sql:` annotation + audit |
| Shell injection | No `Runtime.exec` / `ProcessBuilder` outside MCP transport adapter |
| LLM prompt injection (cross-tenant) | Prompt cache namespaced per tenant; tenant_id in LLM metadata |
| LLM exfiltration of cross-tenant data | RAG retrieval filtered by tenant_id at query time; cross-tenant retrieval is L4 (post-v1) feature with explicit consent |
| Replay attack on idempotency | Per-tenant scope; cross-process replay via Postgres |

### 9.10 How to evaluate §9

- **A-9.1**: malformed JWT under prod returns 401.
- **A-9.3**: cross-tenant data read attempt returns 404 (not 403, to avoid existence disclosure).
- **A-9.5**: PII decode without dual approval is impossible.
- **A-9.6**: audit modification by non-maintenance role is impossible.

---

## 10. Compliance dimension

### 10.1 Regulatory landscape

| Jurisdiction | Authority | Key obligations | Platform owner |
|---|---|---|---|
| Indonesia | OJK (banking, insurance, fintech) | Local data residency; AI-decision auditability; fraud monitoring | Tier-A audit + Tier-B observability spine |
| Indonesia | UU PDP (data protection) | Consent management; data minimisation; PII redaction | Tier-A `auth/` + Tier-B `audit/` |
| Singapore | MAS (banking, capital markets, insurance) | FEAT (Fairness/Ethics/Accountability/Transparency); explainability; outsourcing rules | Tier-A `manifest/` + Tier-B `observability/` + Tier-B `evolve/` |
| Singapore | PDPA | Consent + breach reporting + DNC | Tier-A `auth/` + Tier-B `audit/` |
| Cross-region | EU AI Act (forward-looking) | Risk classification (high-risk for credit-scoring), human oversight, technical documentation | Tier-A capability maturity + Tier-B explainability spine |
| Industry | SOC 2 Type II | Security controls; change management | Operator-shape gate (Rule 8) |
| Industry | ISO 27001 | ISMS | Customer-supplied; platform provides evidence |

### 10.2 Compliance-by-design principles

The platform's compliance posture is built on five principles:

1. **Audit completeness** — every persistent record carries `tenant_id, created_at, created_by`; every irreversible action passes through a gate; every PII decode is dual-approved.
2. **Audit immutability** — append-only role + WORM-anchored snapshots + Merkle-rooted timestamping.
3. **PII minimization** — Presidio detection at ingress; format-preserving tokenization; one-time view with TTL.
4. **Explainability** — four-layer trace: intent → retrieve → think → reflect → act; customer-readable explanation via `ManifestFacade.explain(runId)`.
5. **Consent management** — tenant `ConsentRecord` table; consent required for cross-tenant operations and certain data processing flows.

### 10.3 MAS FEAT implementation

- **Fairness**: bias-detection harness in `agent-runtime/evolve/`; per-protected-attribute outcome distribution monitoring
- **Ethics**: capability `riskClass: HIGH` for credit-scoring agents triggers HITL gate by default
- **Accountability**: `actor` from JWT in every audit entry; lineage chain (`parent_run_id`, `attempt_id`)
- **Transparency**: per-run explanation rendering; model version + prompt version + KB snapshot recorded in audit

### 10.4 OJK-specific provisions

- Data residency via single-region BYOC deployment; SaaS Indonesian region uses Indonesian-compliant infrastructure
- AI-decision auditability via 4-layer trace + WORM-anchored audit
- Fraud monitoring via Tier-2 deferred component (ClickHouse trace lake + bias detection)

### 10.5 Audit content requirements (verbatim from `../ARCHITECTURE.md#103-compliance-audit-trail`)

```yaml
audit_completeness_requirements:
  every_persistent_record:
    must_carry: [tenant_id, created_at, created_by]
    
  every_irreversible_action:
    must_pass: GateProtocol -> AuditEntry
    must_record:
      - actor (userId from JWT)
      - action_type
      - target (record_id + record_type)
      - reason (user-provided)
      - evidence (immutable WORM bit set)
      
  every_pii_decode:
    requires: dual approval (compliance role)
    audit_records: 4 events
      - decode_requested(co1, target, reason, ts)
      - decode_approved(co2, request_id, ts)
      - decode_executed(target, ttl=15min, ts)
      - decode_evicted(target, ts)  # after ttl
      
  every_red_line_violation:
    audit_records: 1 event with full request payload + OPA decision
    
  retention:
    7_years_minimum: [audit, regulatory_event, transaction, decision]
    90_days_then_archive: [trace, run_event]
    24h_then_purge: [idempotency_record (replay cache)]
    
  immutability:
    storage: WORM (S3 Object Lock in SaaS; SeaweedFS in BYOC with append-only role)
    queries: read-only role for inspector access
    proofs: per-day Merkle root anchored to a public timestamp service (RFC 3161)
```

### 10.6 Three-way reconciliation (finance-specific)

For finance customers, **books-records reconciliation** is regulator-required: the platform's internal record of a transaction must be reconcilable against (a) the customer's books-of-record, (b) the platform's audit trail, (c) any external counterparty records.

Daily cycle:
1. Extract platform tx-records for the day
2. Hash by `(tenant_id, transaction_id)` into a Merkle tree
3. Publish day-N Merkle root to: customer's reconciliation API + audit immutability anchor + compliance dashboard
4. Customer responds with reconciled status (matched / mismatched / missing)
5. Mismatches escalate to compliance officer + audit-tagged

**The H3 fix here**: classification of mismatches uses LLM-as-judge; **resolution requires HITL approval**. Auto-resolution is forbidden.

### 10.7 How to evaluate §10

- **A-10.1**: regulator audit walk-in tomorrow; the WORM-anchored audit + Merkle root + per-day timestamp can prove evidence chain in <1 hour.
- **A-10.3**: MAS FEAT review on a HIGH-risk credit-scoring agent; capability descriptor + audit trail + bias-detection harness produce required evidence.
- **A-10.5**: missing categories from §22 — encryption-at-rest / KMS / HSM specifics; bias-audit cadence specifics; regulatory audit vendor selection.

---

## 11. Operability dimension

### 11.1 Long-lived process discipline

- Spring Boot under PM2 / systemd / Docker / Kubernetes
- SIGTERM drain handler in `LifespanController`
- Boot-time invariant assertion (mirrors hi-agent W35-T8)
- `/health` (liveness) + `/ready` (lifespan complete + queue drained)
- `/diagnostics` returns lifespan-state, queue-depth, in-flight runs, lease-expiry queue, idempotency-purge backlog, framework-adapter health

### 11.2 Observability surface

```yaml
observability:
  metrics:
    endpoint: /actuator/prometheus
    family: springaifin_*
    layers: 14 (RunEventEmitter 12 + 2 idempotency-purge etc.)
    cardinality: raw tenant_id (mirrors hi-agent W35-corrective C-1)
    
  traces:
    backend: OpenTelemetry → Phoenix (Apache 2.0 trace lake)
    propagation: W3C traceparent
    span_attributes: tenant_id, run_id, stage_name, framework, model
    
  logs:
    format: structured JSON
    backend: VictoriaLogs (Apache 2.0; replaces AGPL Loki)
    redaction: Presidio-integrated; PII tokens
    
  audit:
    storage: WORM (S3 Object Lock / SeaweedFS append-only)
    retention: 7 years for compliance categories
    integrity: per-day Merkle root + RFC 3161 anchoring
```

### 11.3 Operator CLI

`agent-platform serve / run / cancel / tail-events`. All four subcommands:
- Stateless (no config file, no session, no token cache)
- Stdlib HTTP only
- Loopback by default (`--host 127.0.0.1`); `--prod` flips to `0.0.0.0` only after explicit confirmation
- Deterministic exit codes (0 success / 1 HTTP error / 2 input error)

### 11.4 Six-step operator-shape readiness gate (Rule 8 / D-16)

This is the most important operability claim in the architecture: **no artifact ships without these six PASS assertions**.

| Step | Requirement | Pass criterion |
|---|---|---|
| 1 | Long-lived process | PM2 / systemd / docker; not foreground; survives steps 2-6 |
| 2 | Real LLM | `APP_LLM_MODE=real`; mock raises 503 |
| 3 | N≥3 sequential real-LLM runs | each ≤ `2 × observed_p95`; `*_fallback_total == 0`; ≥1 LLM request per run |
| 4 | Cross-loop resource stability | runs 2 and 3 reuse run-1's gateway/adapter; no `Reactor disposal` |
| 5 | Lifecycle observability | `currentStage` non-null within 30s; `finishedAt` populated on terminal |
| 6 | Cancellation round-trip | live = 200 + drives terminal; unknown = 404 |

T3 invariance: gate pass valid only at recorded SHA; hot-path commits invalidate. Recorded in `docs/delivery/<date>-<sha>.md`.

### 11.5 Sizing reference

| Tier | Customer profile | Replicas | CPU/mem per replica | DB |
|---|---|---|---|---|
| XS | dev / single tester | 1 | 2 vCPU / 4 GB | 4 vCPU / 8 GB / 100 GB SSD |
| S | small bank pilot | 2 | 4 vCPU / 8 GB | 8 vCPU / 16 GB / 500 GB SSD |
| M | mid-bank / fintech | 3 | 8 vCPU / 16 GB | 16 vCPU / 32 GB / 2 TB NVMe + replica |
| L | large bank | 6 | 16 vCPU / 32 GB | 32 vCPU / 64 GB / 5 TB NVMe + replica |
| XL | tier-1 bank | 12+ | 16 vCPU / 32 GB | 64 vCPU / 128 GB / 10 TB + replica + WAL archive |

### 11.6 DR and RTO/RPO

| Tier | RTO | RPO | DR mechanism |
|---|---|---|---|
| XS | best-effort | 24h | nightly DB dump |
| S | 8h | 1h | Postgres streaming replication + hourly snapshot |
| M | 4h | 15min | replica failover + WAL archive |
| L | 1h | 5min | hot replica + WAL streaming |
| XL | 30min | 1min | active-passive with synchronous replication option |

### 11.7 Upgrade story

- Blue-green via Higress traffic-shift (north-south)
- SAS-3 frozen contract makes migrations only data-side (schema migrations via Flyway)
- v1 → v1.0.1 (bug fix): same SHA digest if shape unchanged
- v1 → v2 (breaking): parallel `agent-platform/contracts/v2/`; customers migrate at their pace; v1 deprecated with N-version overlap

### 11.8 How to evaluate §11

- **A-11.4**: 6-step gate is sufficient — construct a defect that passes all 6 PASS but fails in production. Hi-agent has 32 waves of evidence the gate is sufficient.
- **A-11.5**: sizing tier S is enough for small bank pilot — validate at 10 RPS sustained; trigger upgrade at p95 breach.
- **A-11.7**: blue-green upgrade survives in-flight runs — drain timeout is 30s; in-flight runs > 30s require lease-expiry recovery on new replica.

---

## 12. Evolution dimension

### 12.1 Frozen v1 / parallel v2

SAS-3 freeze: once v1 RELEASED, all bytes of `agent-platform/contracts/v1/` are digest-snapshotted. Breaking changes go to `agent-platform/contracts/v2/`. v1 is never modified in place.

**Evidence**: `ContractFreezeTest` walks `v1/` and computes per-file SHA-256; compares to `docs/governance/contract_v1_freeze.json`; fails on drift.

### 12.2 Capability maturity ladder (Rule 12 / D-17)

| Level | Name | Criterion |
|---|---|---|
| L0 | demo code | happy path only, no stable contract |
| L1 | tested component | unit/integration tests exist, not default path |
| L2 | public contract | schema/API stable, docs + tests full |
| L3 | production default | research/prod default-on, migration + observability |
| L4 | ecosystem ready | third-party can register/extend/upgrade/rollback without source |

A capability **cannot move to L3** without:
- Posture-aware default-on (Rule 11)
- Quarantined failure modes
- Rule 7 four-prong observable fallbacks
- Doctor-check coverage

This prevents the v5.0-style "everything is production_ready" inflation. Each capability progresses with named evidence.

### 12.3 Behaviour pinning (premium opt-in)

- **Default OFF** in `research`/`prod` posture
- **Opt-in** for regulated customers; signed pinning addendum required
- **Priced per pinned-version-year**
- **Hard 5-year cap** with mandatory migration after

The engineering subsystem (model snapshot service, KB snapshots, regression harness) is a **v1.1 deliverable**. v1 advertises the contract clause; honoured by manual freeze in v1.

### 12.4 Auto-optimization flywheel (deferred to v1.1)

The two flywheels (Evolution + Cost) from v5.0 are real engineering goals but **operational disciplines introduced when traffic justifies**, not day-0 architectural commitments.

| Flywheel | v1 status | v1.1 trigger |
|---|---|---|
| Evolution | Manual via `ChampionChallenger`; A/B in `evolve/ExperimentStore` | When trace volume > 100K runs/month per tenant |
| Cost | Per-call cost telemetry via outbox; manual budget enforcement | When per-tenant inference cost > threshold |

The v1 architecture is **flywheel-ready**: outbox emits `cost_observed` and `trace_emitted`; ExperimentStore primitive in place; capability maturity ladder allows incremental rollout.

### 12.5 How to evaluate §12

- **A-12.1**: contract freeze prevents breaking changes — test by trying to modify `v1/RunRequest.java`; CI fails.
- **A-12.2**: L3 is achievable for the 14 v1-target capabilities — see L0 §8.1 with named evidence per capability.
- **A-12.3**: pinning is a real product offering, not a marketing claim — see contract templates in `docs/sales/pinning-addendum.md` (planned).

---

## 13. Cost dimension

### 13.1 Inference cost optimization

- **TierRouter** routes by purpose × complexity × budget × confidence
  - `STRONG` tier: high-stakes (compliance, fraud, suitability)
  - `MEDIUM` tier: typical agent reasoning
  - `LIGHT` tier: simple categorisation, formatting
- **Multi-provider failover** via `FailoverChain` (provider outage shouldn't block business)
- **Prompt cache** (Spring AI's prompt cache adapter) — system prompts + few-shot reuse
- **Per-tenant budget** via `BudgetTracker`; exceedance raises `LLMBudgetExceededException`

### 13.2 Cost telemetry

- **Outbox event `cost_observed`** per LLM call, carrying `tenantId, runId, providerName, modelName, tokens (prompt/completion), latencyMs, costUsd`
- **In-process subscriber aggregates** per-tenant per-day
- **Per-tenant dashboard** in Operations Console (Tier-2 deferred until ClickHouse adopted)

### 13.3 Multi-tier cache (Tier-2 deferred)

v5.0 proposed 4-tier cache (L1 prompt-prefix, L2 content-addressed retrieval, L3 KV-cache, L4 model output). v6.0 ships **only Valkey session cache at MVP**; multi-tier introduced when production traffic justifies.

### 13.4 Cost flywheel components (Tier-2/Tier-3)

| Component | Tier | Adoption trigger |
|---|---|---|
| Multi-tier cache | Tier-2 | per-call cost data justifies |
| Intelligent routing (RouteLLM) | Tier-2 | multi-model deployment justifies |
| Model distillation pipeline (TRL) | Tier-3 | research-posture only; v1.1+ |
| KV cache global sharing (LMCache) | Tier-3 | self-hosted inference at scale |
| GrowthBook (A/B model variants) | Tier-2 | model variant testing |
| OpenCost (GPU fleet attribution) | Tier-2 | GPU pool exists |

### 13.5 Pricing model considerations

- **Platform license**: one-time + subscription
- **Operational services**: 30-40% of revenue (long-term customer relationship)
- **Inference cost**: pass-through with metering; transparent to customer
- **Behaviour pinning**: premium per pinned-version-year (D-11; see §22 for open question on pricing)
- **GPU pools**: Tier-1 SaaS = reserved; Tier-2 = spot+on-demand mix

### 13.6 How to evaluate §13

- **A-13.1**: per-call cost telemetry is sufficient for billing and chargeback — test by reconciling outbox events with provider invoice.
- **A-13.2**: multi-tier cache deferral is safe — at MVP traffic levels (10 RPS sustained, 50 RPS peak), single Valkey session cache + Spring AI prompt cache should provide >70% LLM cost reduction.
- **A-13.4**: pricing for premium pinning is competitive — see §22 open question.

---

# Part IV — Decision Chain Deep Dives

## 14. The 17 architectural decisions

(Each decision is presented with: Statement → Alternatives Considered → Why This Won → Tradeoffs Accepted → Falsifiable Assertion. Full detail in [`../ARCHITECTURE.md#6-architecture-decisions-the-decision-chains`](../ARCHITECTURE.md). Below is a summary table; reviewers should consult the L0 doc for full reasoning.)

| ID | Decision | Alternatives | Tradeoffs |
|---|---|---|---|
| **D-1** | Capability-layer only; domain in `fin-domain-pack/` out of repo | A1 bake FIBO+KYC into platform; A3 hybrid | Customer must integrate fin-domain-pack |
| **D-2** | Two-package layering with single seam (SAS-1) | A1 single module; A2 three modules; A3 two modules + multi-seam | Bootstrap class is load-bearing |
| **D-3** | Frozen v1 contract / parallel v2 (SAS-3) | A1 SemVer with deprecation; A2 single mutable contract | Breaking changes accumulate in v2 |
| **D-4** | Spring AI 1.1+ unmodified, NOT a custom framework | A1 custom framework (v5.0); A3 raw Spring | Spring AI churn translates to Starter churn |
| **D-5** | Multi-framework via single `FrameworkAdapter` interface | A1 Spring AI only; A2 polyglot in-process | Cross-process gRPC adds ≤30ms p95 |
| **D-6** | Three-posture model (dev / research / prod) | A1 two postures; A3 per-feature flags | Three test profiles per release |
| **D-7** | Auth-authoritative `tenantId` (JWT claim only) | A1 from body; A2 from header only | Customers must mint JWTs with tenantId claim |
| **D-8** | Outbox + Sync-Saga + Direct-DB; @WriteSite annotation | A1 Outbox-as-universal (v5.0); A2 Saga-as-universal | Three mechanisms to maintain |
| **D-9** | TRACE 5-stage durable + cognitive activities as spans | A1 free-form workflow; A2 11-state cognitive (v5.0) | TRACE is opinionated |
| **D-10** | AI-First Layer-2 REMOVED from v1 default path (H3 fix) | A1 ship in v1; A2 Layer-1 only | We forfeit "self-healing" appeal |
| **D-11** | Behaviour pinning OFF by default; opt-in 5-year cap (H4 fix) | A1 permanent + bundled; A2 5-year cap universal | Pinning customers pay more |
| **D-12** | TenantContext as binding contract (H5 fix) | A1 String parameter; A2 ThreadLocal | Three propagation mechanisms to keep in sync |
| **D-13** | API stability vs Behaviour stability separated | A1 API stability sufficient; A2 merged | Behaviour-version subsystem is v1.1 |
| **D-14** | Higress north-south (deployment dependency) | A1 Spring Cloud only; A3 customer-chosen | Customers must deploy Higress (or substitute) |
| **D-15** | Apache 2.0 / MIT only on runtime path | A1 mixed licenses (v5.0) | Forfeit specific tooling (Langfuse UI etc.) |
| **D-16** | Six-step operator-shape readiness gate (Rule 8) | A1 no gate; A2 green-pytest-only | ≈10–30 min wall clock per release SHA |
| **D-17** | L0–L4 capability maturity (Rule 12) | A1 "Implemented/Beta/GA"; A2 SemVer only | Per-capability reporting is more verbose |

## 15. Comparison: v5.0 → v6.0 deltas

The v5.0 review found 6 HIGH and 9 MEDIUM-severity findings. v6.0 closes all 6 HIGH and 8 of 9 MEDIUM. The remaining MEDIUM (**M5: four-dimensional version model**) is consciously demoted to a 2-dimensional model (contract version + composition version) at v1, with the four-dimensional model as an evolution path if customer demand justifies.

### Components delta

| Category | v5.0 | v6.0 |
|---|---|---|
| Tier-1 MVP components | claimed 80+ (actually 49) | 11 |
| Tier-2 deferred | 0 (all on day 0) | 16 |
| Tier-3 rejected | 0 | 12 |
| License-risky components | 6 (Langfuse AGPL, Loki AGPL, Vault BUSL, Terraform BUSL, GraphDB Free, Drools redundant) | 0 (all replaced or removed) |

### Rule-violations delta

| Rule | v5.0 | v6.0 |
|---|---|---|
| Rule 7 (no silent degradation) | violated by AI Operator Layer-2 | fixed (Layer-2 deferred to v1.1 with Rule-7 four-prong) |
| Rule 8 (operator-shape gate) | absent | added (six PASS gate; D-16) |
| Rule 10 (capability-layer only) | violated by FIBO/KYC bake-in | fixed (D-1 with `fin-domain-pack/`) |
| Rule 11 (posture-aware) | absent | added (D-6 three-posture model) |
| Rule 12 (contract spine) | partial | full (TenantContext binding + spine validators in record canonical constructors) |
| Rule 12 capability maturity (originally Rule 13 in hi-agent) | absent | added (D-17 L0-L4 ladder) |
| Three-Gate intake | absent | added |
| Single-construction-path (Rule 6) | partial | full (`@Bean` discipline; no inline fallback) |

### Document size delta

| Document | v5.0 | v6.0 |
|---|---|---|
| Architecture doc total | 9,922 lines (one file) | ~1,500 lines L0 + 700-900 L1×2 + 250-450 L2×9 = ~5,500 lines spread across 12 files |
| Customer reading | Single 9,922-line read | Per-role reading paths (60-90 min by role) |
| Reviewer reading | Whole doc or skip | Decision chains addressable individually |

---

# Part V — Engineering Discipline Inheritance

The v6.0 architecture is built on engineering discipline inherited from a predecessor (hi-agent) that survived 32 production release waves. This part summarizes that inherited discipline.

## 16. The 12 universal rules from CLAUDE.md

(Full text in [`../CLAUDE.md`](../CLAUDE.md). Summary below.)

| # | Rule | What it forces |
|---|---|---|
| **1** | Root-Cause + Strongest-Interpretation Before Plan | No PR without four-line root-cause block; ambiguous requirements clarified before implementation |
| **2** | Simplicity & Surgical Changes | Touch only what task requires; no speculative features; commits split when spanning >1 defect or >2 modules |
| **3** | Pre-Commit Checklist | 13-dimension audit before every commit (contract truth, orphan config/returns, branch parity, test honesty, etc.) |
| **4** | Three-Layer Testing | Unit / Integration (no mocks on subject) / E2E (drive through public interface) — all green before ship |
| **5** | Async/Sync Resource Lifetime | Every async resource bound to ONE event loop / scheduler; no per-call `asyncio.run` / `Mono.block()` |
| **6** | Single Construction Path Per Resource Class | One builder per shared resource; inline fallbacks `x or DefaultX()` forbidden |
| **7** | Resilience Must Not Mask Signals | Every fallback Countable + Attributable + Inspectable + Gate-asserted |
| **8** | Operator-Shape Readiness Gate | 6 PASS assertions before any artifact ships |
| **9** | Self-Audit is a Ship Gate | Open ship-blocking findings = no ship; reclassify-as-known-defect requires signed acknowledgment |
| **10** | Posture-Aware Defaults | dev permissive; research/prod fail-closed |
| **11** | Contract Spine Completeness | Every persistent record carries `tenant_id` (+ relevant subset of identity/lineage) OR `// scope: process-internal` with rationale |
| **12** | Capability Maturity Model (L0–L4) | No L3 without posture-default-on + observable fallbacks + doctor-check + quarantined failure modes |

## 17. The Three-Gate intake

Before accepting any new capability request:

| Gate | Question |
|---|---|
| **G1 — Positioning** | Is this capability-layer or business-layer? Business-layer = decline + redirect to `fin-domain-pack/`. |
| **G2 — Abstraction** | Does this compose from existing capabilities without new code? Yes = provide composition example, no new code. |
| **G3 — Verification** | New code requires Rule 4 three-layer test plan + Rule 8 gate run plan before delivery authorization. |
| **G4 — Posture & Spine** | Declare default behaviour under dev/research/prod postures + which Rule-11 spine fields the new capability carries. Otherwise stays at L0–L1. |

This gate prevents v5.0-style scope drift. Every capability passes through G1–G4 at proposal time; rejections are traceable.

## 18. The operator-shape readiness gate

The most important runtime invariant. **Six PASS assertions** before any artifact ships:

1. **Long-lived process** (PM2/systemd/docker; survives steps 2-6)
2. **Real LLM** (`APP_LLM_MODE=real`; mock raises 503)
3. **N≥3 sequential real-LLM runs** (each ≤ `2 × observed_p95`; `*_fallback_total == 0`; ≥1 LLM request per run)
4. **Cross-loop resource stability** (runs 2 and 3 reuse run-1's gateway; no `Reactor disposal` or `ConnectTimeout` on call ≥2)
5. **Lifecycle observability** (`currentStage` non-null within 30s; `finishedAt` populated on terminal)
6. **Cancellation round-trip** (live = 200 + drives terminal; unknown = 404, never silent 200)

Recorded in `docs/delivery/<date>-<sha>.md`. T3 invariance: gate pass valid only at recorded SHA; hot-path commits invalidate.

This gate is the **single most-effective regression prevention** in the predecessor system. Hi-agent ran W1-W11 without it and shipped multiple regressions; introduced at W12; zero post-W12 regressions of the classes the gate covers.

---

# Part VI — Validation, Risks, and Open Questions

## 19. How we will know the architecture is correct

### 19.1 Pre-implementation validation (W1–W2)

Before any production-bound code, the platform team will produce:

| Artifact | Owner | Success criterion |
|---|---|---|
| W1 happy path: `POST /v1/runs` end-to-end with real LLM under dev posture | RO + AS-RO | Operator-shape gate steps 1–4 PASS |
| W2 promote to research posture | RO + AS-RO | Operator-shape gate all 6 PASS |
| W2 spine validators across all `agent-platform/contracts/v1/` | CO | `ContractSpineCompletenessTest` 100% green |
| W2 TenantContext propagation across 10 layers | RO | 4 shadow-path tests × 10 layers = 40 tests green |
| W2 `WriteSite` annotation reflective check | RO | `WriteSiteAuditTest` 100% green |
| W2 license audit | GOV | `LicenseAuditTest` zero AGPL/GPL on runtime path |
| W2 multi-framework dispatch | RO | All three adapters (Spring AI / LC4j / PySidecar) pass operator-shape gate |
| W2 operator-shape gate scripts (six) | AS-RO | All six exist and are runnable |
| W3 Tier-2 trigger criteria documented | GOV | Every deferred component has named quantitative trigger |

### 19.2 Quantitative bars at v1 RELEASED

```yaml
v1_released_bar:
  raw_implementation_maturity: ">= 80"
  current_verified_readiness:  ">= 70"   # capped to 70 if any allowlist expired or hot-path T3 stale
  seven_by_24_operational_readiness: ">= 80"
  
  test_profile_default_offline:
    pass_rate: 100%
    wall_clock: "< 5min"
    
  spine_validation:
    every_spine_record_under_contracts_v1: validated
    
  allowlist_discipline:
    expired_entries: 0
    
  license_audit:
    agpl_or_gpl_on_runtime_path: 0
    unmitigated_proprietary: 0
    busl_components: 0
    
  performance_p95:
    sync_post_run: "<= 1s"
    interactive_run_with_one_LLM_turn: "<= 5s"
    sse_first_event: "<= 500ms"
    cancel_roundtrip: "<= 200ms"
    multi_framework_dispatch_overhead: "<= 30ms (in-process), <= 50ms (sidecar)"
    
  durability:
    runs_survive_restart: yes
    in_flight_writes_recovered: yes  # via outbox + lease re-claim
    cancellation_propagates_across_subruns: yes
    
  isolation:
    cross_tenant_read_returns_404: yes
    cross_tenant_idempotency_keys_isolated: yes
```

### 19.3 Capability maturity targets at v1 RELEASED

| Capability | Target Level |
|---|---|
| Run execution (TRACE S1–S5) | L3 |
| LLMGateway + TierRouter | L3 |
| FrameworkAdapter (Spring AI) | L3 |
| FrameworkAdapter (LangChain4j) | L2 |
| FrameworkAdapter (PySidecar) | L2 |
| Memory (L0/L1/L2/L3) | L2 (L3 at v1.1) |
| Knowledge (glossary + 4-layer retrieval) | L2 |
| MCP tools | L2 |
| Observability spine | L3 |
| `agent-platform` v1 contract | L3 |
| Behaviour pinning (premium) | L1 |
| Outbox + Saga split | L3 |
| PII redaction + dual-approval | L3 |
| Audit immutability | L3 |

## 20. Top-tier risks (HIGH severity)

The committee should explicitly accept or reject each of these:

| Risk | Description | Plan |
|---|---|---|
| **R-1: No code yet** | Every architectural claim is a target. First 2 waves (W1, W2) must produce running platform under research posture. | Track W1/W2 deliverables; gate v1 RELEASED on operator-shape gate green |
| **R-2: Multi-framework dispatch overhead** | gRPC sidecar adds ≤30-50ms p95 per dispatch. If breaks customer SLA, degrades adoption | Operator-shape gate W2; if > 100ms, defer Python sidecar to v1.1 |
| **R-3: Sync-Saga compensation correctness** | A bug in compensation logic could leave finance state inconsistent | Per-saga-type integration test suite covering all failure permutations; reviewer audit on every saga PR |
| **R-4: Behaviour pinning unbacked** | D-11 commits to 5-year cap. Engineering subsystem is v1.1 deliverable | If a Tier-1 customer demands pinning at v1, fall back to manual snapshot freeze + customer-acknowledged limitation; price as opt-in v1.1 enrollment |
| **R-5: License audit timebomb** | Any transitive dependency drift to AGPL/GPL/BUSL would break BYOC redistribution | `LicenseAuditTest` runs on every commit; renovate-style automated dependency PRs with license check |
| **R-6: Spring AI 1.1+ upstream churn** | Spring AI is in 1.x phase; API may churn in 1.2+ | Track upstream changelogs; absorb in `LLMGateway` + `SpringAiAdapter`; pin Spring AI version in `pom.xml` |
| **R-7: Single-process kernel concurrency limits** | At sustained > 100 RPS per replica, HikariCP / Reactor scheduler may be bottleneck | Operator-shape gate measures; if hit, add second replica behind Higress |
| **R-8: Operator burden of 6 deferrals adopted simultaneously** | If multiple Tier-2 components added in v1.1 at once, ops team underwater | Stagger Tier-2 adoption: one component per wave |
| **R-9: Cross-jurisdictional data residency under DR** | OJK forbids cross-border data movement; cross-region DR within Indonesia is non-trivial | Open question (see §22); v1 = single-region per BYOC tenant |
| **R-10: Compliance content versioning across jurisdictions** | KYC rules change quarterly per OJK; AML lists update daily | Customer-supplied via `fin-domain-pack/`; platform doesn't bake in |

## 21. Tier-2 deferrals — adopted when traffic justifies

(Full table in L0 §12.2. Trigger criteria are quantitative.)

| Deferred component | Trigger |
|---|---|
| Kafka + Kafka Streams | Synchronous outbox latency p95 > 2s under target load |
| Istio Ambient Mesh | Service count > 15 |
| Milvus | Vector retrieval recall@10 < 0.85 with BM25 alone |
| OpenSearch | Hybrid BM25+vector required |
| NebulaGraph | Knowledge-graph reasoning is a named feature |
| Phoenix | Trace volume > 100K runs/month |
| VictoriaLogs | Log volume > 100GB/day |
| Seata | Cross-service saga required |
| Nacos | Multi-replica config required |
| ClickHouse | Trace-lake aggregations under Phoenix |
| GrowthBook | Multi-model A/B testing |
| RouteLLM | Multi-model routing optimisation |
| Sentinel (Alibaba) | Custom rate-limit beyond Higress |
| SeaweedFS | BYOC large blob storage |
| OpenCost | GPU fleet cost attribution |
| Volcano + KubeRay | GPU job scheduling |
| Knative | Serverless cold-start required |

## 22. Open questions awaiting committee guidance

The platform team needs the committee's guidance on these before v1 RELEASED:

| Q | Question | Considerations | Tentative direction |
|---|---|---|---|
| Q-1 | KMS / HSM choice | OJK requires; some BYOC customers have existing HSM | AES-256 disk + Postgres pgcrypto; BYOC may bring HSM via PKCS#11 |
| Q-2 | Key rotation cadence | Industry: 90 days for symmetric keys | 90-day for HMAC + DB secrets; audit-logged |
| Q-3 | Bias-audit cadence (MAS FEAT) | Quarterly in industry; depends on agent risk class | Monthly for HIGH-risk; quarterly for LOW |
| Q-4 | Regulatory audit vendor | OJK / MAS approved auditors | Customer-supplied; platform provides evidence dump |
| Q-5 | Adversarial red-team cadence | Industry: bi-annual penetration test | Annual + bi-annual mini-test |
| Q-6 | Cross-region DR with data residency | OJK forbids cross-border data movement | Per-region active-passive; failover within region only |
| Q-7 | Behaviour-pinning subsystem scope | D-11 cap = 5 years; engineering sized | v1.1 chapter; estimate 6 person-months for first cut |
| Q-8 | GPU procurement model for SaaS | Reserved vs spot vs on-demand | Customer-segment-dependent |
| Q-9 | SaaS multi-region active-active | Customer demand vs operational complexity | Out of v1; v1.1 candidate if customer demand |
| Q-10 | Pricing for premium pinning | Per pinned-version-year vs flat fee | Per pinned-version-year (encourages migration); committee guidance on $$$ |
| Q-11 | Customer SDK ecosystem (TypeScript / Python wrapper) | Java Starters + TS web SDK at v1; Python SDK?(needs platform-runtime to be Java-only-callable) | TS web at v1; Python SDK in v1.1 if customer demand |
| Q-12 | Spring AI upstream contribution policy | Should we contribute back vs keep proprietary | Default: contribute non-domain-specific improvements; keep finance-domain in fin-starter-* |

---

# Part VII — Reviewer Workflow

## 23. How to produce dissent

If a reviewer disagrees with any decision, the productive form of dissent is:

1. **Identify the specific assertion** (`A-N.M` ID from §6 catalog or section-end "How to evaluate this") or specific decision (`D-N` from §14).
2. **Construct a falsification scenario**: a concrete situation where the architecture as proposed fails.
3. **Propose an alternative** that addresses the same concern without introducing equivalent or larger risk.

Vague dissent ("this seems risky", "I would do it differently") is not actionable; specific dissent ("D-5's gRPC sidecar adds 50ms p95; for our high-frequency trading customer's 100ms total latency budget this is fatal — propose A1 Spring AI only") is actionable.

The committee should produce dissent in the form of a **markdown file or comments** on this document (`docs/architecture-review-feedback-2026-05-08.md` etc.). The platform team will respond per dissent within 7 calendar days.

## 24. Approval criteria

The committee approves v6.0 by:

1. **Explicit acceptance of the 6 HIGH-severity fixes** (§3 v5.0 → v6.0 deltas).
2. **Explicit acceptance of the 17 architectural decisions** (§14) OR specific dissent per §23 on individual decisions.
3. **Explicit acceptance of the 10 HIGH-severity risks** (§20) and their mitigation plans.
4. **Explicit guidance on the 12 open questions** (§22).
5. **Sign-off on the v1 RELEASED quantitative bars** (§19.2) and capability maturity targets (§19.3).

Approval is recorded as a single document `docs/architecture-review-approval-2026-05-XX.md` listing the committee members, their accepted/rejected items, and any conditions on approval.

## 25. Post-approval cadence

Post-approval, the platform team will:

| Cadence | Deliverable |
|---|---|
| W1 (weekly) | Wave-1 plan: MVP happy path under dev posture |
| W2 (weekly) | Wave-2 plan: research posture promotion + operator-shape gate scripts |
| W3-W12 (weekly) | Wave-N plans: feature buildout per Tier-1 component list |
| Wave delivery (per wave) | `docs/delivery/<date>-<sha>.md` with operator-shape gate evidence |
| Manifest (per wave) | `docs/governance/manifest-<sha>.json` with quantitative bars |
| Closure notice (per wave) | `docs/downstream-responses/<date>-<wave>-delivery-notice.md` mirroring hi-agent's pattern |
| Review post-mortem (per wave) | committee may request review at any wave-close; default cadence quarterly |
| v1 RELEASED candidate | when all v1 RELEASED bars green and capability maturity targets met |
| v1 RELEASED | committee's final acceptance review; SHA frozen as `V1_FROZEN_HEAD` |

The platform team commits to **manifest-truth releases** (Rule 14 mirror): closure notices derive from the manifest; no claims pre-final-manifest. Score increases computed from manifest facts, never hand-edited.

---

# Closing

This document represents 8 hours of work by the platform team to refactor a 9,922-line v5.0 architecture document, integrate 32 release waves of predecessor learnings, and produce a defensible architectural baseline for committee review. The companion documents (L0 + L1×2 + L2×9) total ~5,500 lines of design detail.

The committee's responsibility now is to evaluate whether v6.0 is **a credible architectural baseline** for a financial-services agent platform. We argue: yes, because the discipline (12 universal rules), the components (Tier-1), and the deferrals (Tier-2 / Tier-3 with named triggers) form a minimally viable production system that can be expanded incrementally without the wave-1 cliff that v5.0 would have produced.

We invite specific dissent and look forward to the approval review.

— *Platform Team, 2026-05-07*

---

# Appendix A — Document Cross-Reference Map

```
docs/architecture-review-2026-05-07.md           (THIS DOCUMENT — committee-facing; 1,300+ lines)
│
├── ARCHITECTURE.md                              (L0 system boundary; 1,648 lines; 17 decisions)
├── CLAUDE.md                                    (218 lines; 12 universal rules; Three-Gate intake)
├── agent-platform/
│   ├── ARCHITECTURE.md                          (L1 northbound facade; 406 lines)
│   ├── api/ARCHITECTURE.md                      (L2 HTTP transport + filter chain; 216 lines)
│   ├── bootstrap/ARCHITECTURE.md                (L2 SAS-1 seam #1 / assembly; 155 lines)
│   ├── cli/ARCHITECTURE.md                      (L2 operator CLI; 128 lines)
│   ├── config/ARCHITECTURE.md                   (L2 settings + version pin; 158 lines)
│   ├── contracts/ARCHITECTURE.md                (L2 frozen v1 records; 221 lines)
│   ├── facade/ARCHITECTURE.md                   (L2 contract↔kernel adapters; 132 lines)
│   └── runtime/ARCHITECTURE.md                  (L2 SAS-1 seam #2 + lifespan; 182 lines)
├── agent-runtime/
│   ├── ARCHITECTURE.md                          (L1 cognitive runtime; 461 lines)
│   ├── adapters/ARCHITECTURE.md                 (L2 multi-framework dispatch; 282 lines) ★
│   ├── auth/ARCHITECTURE.md                     (L2 JWT primitives; 121 lines)
│   ├── capability/ARCHITECTURE.md               (L2 platform-level registry; 140 lines)
│   ├── evolve/ARCHITECTURE.md                   (L2 experiments + postmortem; 182 lines)
│   ├── knowledge/ARCHITECTURE.md                (L2 JSONB glossary + 4-layer retrieval; 135 lines)
│   ├── llm/ARCHITECTURE.md                      (L2 Spring AI gateway + tier router; 201 lines)
│   ├── memory/ARCHITECTURE.md                   (L2 L0–L3 layered memory; 103 lines)
│   ├── observability/ARCHITECTURE.md            (L2 Rule-7 four-prong + 12+14 events; 188 lines)
│   ├── outbox/ARCHITECTURE.md                   (L2 OUTBOX_ASYNC + SYNC_SAGA + DIRECT_DB; 334 lines) ★
│   ├── posture/ARCHITECTURE.md                  (L2 Rule-11 single-most-impactful lever; 127 lines)
│   ├── runner/ARCHITECTURE.md                   (L2 TRACE 5-stage; 174 lines)
│   ├── runtime/ARCHITECTURE.md                  (L2 Reactor scheduler + harness; 172 lines)
│   ├── server/ARCHITECTURE.md                   (L2 AgentRuntime + RunManager; 198 lines)
│   └── skill/ARCHITECTURE.md                    (L2 MCP tools + Spring AI Advisors; 141 lines)
└── docs/
    ├── architecture-v5.0.md                     (historical input; 9,922 lines preserved)
    └── architecture-v5.0-review-2026-05-07.md   (the adversarial review that produced v6.0; 216 lines)
```

**Total v6.0 design corpus: ~7,630 lines across 27 markdown files.** Compared to v5.0's single 9,922-line document, the same content is reorganized for per-role reading paths and per-subsystem audit. Marked ★ are the two L2 docs the committee should prioritize because they implement v6.0's most distinctive choices (multi-framework dispatch + write-path taxonomy).

---

# Appendix B — Concrete Implementation Roadmap

The committee asked to understand "what we want to implement". Below is the wave-by-wave roadmap from green-field to v1 RELEASED. Each wave lands a specific deliverable; the operator-shape gate (D-16) gates wave acceptance.

| Wave | Goal | Deliverables | Gate criteria |
|---|---|---|---|
| **W1** | MVP happy path under `dev` posture | • `PlatformBootstrap` Spring Boot app boots under PM2<br>• `POST /v1/runs` round-trip with Spring AI ChatClient (single LLM provider)<br>• `JwtAuthFilter` + `TenantContextFilter` + `IdempotencyFilter` chain in correct order<br>• `RunFacade.start` wired through `RealKernelBackend`<br>• `RunExecutor` drives TRACE S1–S5 against mock-or-real LLM<br>• Postgres `run`, `event`, `idempotency`, `outbox` tables + Flyway migrations<br>• `RunEventEmitter` 12 events emitting<br>• `/health`, `/ready`, `/actuator/prometheus` live | Operator-shape gate steps **1–4** PASS (long-lived process, real LLM, N≥3 sequential runs, cross-loop stability). T3 evidence recorded in `docs/delivery/W1-<sha>.md`. |
| **W2** | Promote to `research` posture; complete operator-shape gate | • `AppPosture.fromEnv` + `application-research.yaml` posture override<br>• `assertResearchPostureRequired` boot-time invariant (mirrors hi-agent W35-T8)<br>• `LifespanController` background tasks (lease-expiry, watchdog, idempotency-purge, outbox-relay)<br>• SIGTERM drain handler<br>• SSE `GET /v1/runs/{id}/events` live-stream<br>• `POST /v1/runs/{id}/cancel` returning 200/404/409<br>• `WriteSiteAuditTest`, `ContractFreezeTest`, `ContractSpineCompletenessTest`, `ArchitectureRulesTest`<br>• 6 operator-shape gate scripts written | Operator-shape gate **all 6 PASS** under research posture. SIGTERM drain ≤ 30s. T3 evidence recorded. |
| **W3** | Multi-framework dispatch | • `FrameworkAdapter` interface<br>• `SpringAiAdapter` (in-process; default)<br>• `LangChain4jAdapter` (in-process; opt-in)<br>• `PySidecarAdapter` (out-of-process gRPC)<br>• `springaifin/py-sidecar:1.0.0-alpha` Docker image hosting LangGraph + CrewAI + AutoGen<br>• Adapter health probe + failover instrumentation | Cross-framework equivalence test passes (same `TaskContract` → equivalent result on Spring AI + LangChain4j). PySidecar p95 dispatch overhead measured; <100ms or deferral noted. |
| **W4** | Outbox + Sync-Saga + Direct-DB | • `@WriteSite(consistency=...)` annotation + `WriteSiteAuditTest` reflective check<br>• `OutboxStore` + `OutboxRelay` (in-process subscribers)<br>• `SyncSagaOrchestrator` + `SagaStep` framework<br>• Reference saga: `TransferSaga` (debit → credit → outbox-event)<br>• Saga restart-survival via `saga_run` table<br>• Compensation ordering test suite | All write sites annotated; `WriteSiteAuditTest` 100% green. `SyncSagaCompensationIT` covers all failure permutations. |
| **W5** | Memory + Knowledge primitives | • L0 `RawEventStore` (Postgres JSONB)<br>• L1 `StageMemoryCompressor`<br>• `MemoryRetriever` with 40/30/30 budget<br>• `KnowledgeStore` (Postgres JSONB + GIN)<br>• `FourLayerRetriever` (grep → BM25 → JSONB; vector deferred)<br>• `GlossaryLoader` consuming `fin-domain-pack/glossary.json` | Glossary boot ≤ 1s for 50 classes. Knowledge retrieval p95 ≤ 200ms (3-layer). Spine validation 100% on memory + knowledge records. |
| **W6** | Skill + MCP tools | • `SkillRegistry` (JSON-backed)<br>• `SkillLoader` with dangerous-capability gate at load time<br>• `SkillObservation` JSONL telemetry<br>• `SkillVersionManager` Champion/Challenger primitive<br>• `McpToolBridge` for stdio MCP servers | Skill load ≤ 2s for 100-skill registry. Dangerous-capability gate enforced under research/prod. |
| **W7** | Audit + PII redaction + Dual-Approval | • `AuditStore` append-only with maintenance role<br>• Microsoft Presidio integration<br>• Format-preserving tokenization (FF3-1)<br>• Dual-approval workflow (`POST /v1/audit/decode` + `/approve`)<br>• WORM-anchored snapshot + RFC 3161 timestamping<br>• `AuditFacade` | PII decode without dual approval is impossible (penetration test). Audit modification by non-maintenance role rejected. |
| **W8** | Capability registry + Evolve primitives | • `CapabilityRegistry` + `CapabilityDescriptor` with maturity level<br>• `CapabilityInvoker` with circuit breaker<br>• `ExperimentStore` + `ChampionChallenger`<br>• `PostmortemAnalyser` deterministic version<br>• `RecurrenceLedger` YAML + linter<br>• `RegressionDetector` with Golden Set | All capabilities declare `MaturityLevel`. Manifest exposes capability matrix. RecurrenceLedger valid YAML. |
| **W9** | Customer Starters | • `fin-starter-core` (platform connection + trace + cost reporting)<br>• `fin-starter-memory` (memory client)<br>• `fin-starter-skill` (skill + MCP client)<br>• `fin-starter-flow` (HITL + long-task manager)<br>• `fin-starter-advanced` (in-process lightweight agents) | Starters work against running v1 server. Customer can build a hello-world agent in <10 minutes. |
| **W10** | Operator CLI + Operations Console scaffold | • `agent-platform serve / run / cancel / tail-events`<br>• Scaffold: Operations Console (3-role views) — placeholder UI<br>• Manifest endpoint render | CLI startup ≤ 500ms. All subcommands integration-tested. |
| **W11** | Compliance hardening | • Bias-detection harness (per-protected-attribute outcome distribution)<br>• OJK / MAS posture profiles<br>• Three-way reconciliation (daily Merkle root)<br>• `regulatory_event` audit type<br>• Capability descriptor `riskClass: HIGH` triggers HITL gate by default | Bias audit produces protected-attribute distribution. MAS FEAT capability matrix passes review. |
| **W12** | Hardening + v1 RELEASED candidate | • Allowlist sweep (zero expired)<br>• License audit (zero AGPL/GPL on runtime path)<br>• Manifest v1 schema finalized<br>• `V1_FROZEN_HEAD` set<br>• `contract_v1_freeze.json` committed<br>• Closure notice template<br>• Architecture review committee final review | All bars in §19.2 met. Capability maturity targets in §19.3 met. T3 evidence at HEAD. **v1 RELEASED**. |

**Wave cadence**: weekly. Each wave ends with a `docs/delivery/<date>-<sha>.md` evidence file mirroring hi-agent's pattern. Twelve waves × ~1 week = 3 months from green-field to v1 RELEASED, assuming full-time team of 5–8 engineers.

**Wave dependency graph**: W1 → W2 → {W3, W4, W5} parallel → {W6, W7, W8} parallel → W9 (depends on W6) → W10 → W11 → W12. Some waves can be parallelized; W2 is the gate that must complete before any feature wave starts.

---

# Appendix C — Sample Artifacts

The committee's "评委可以有效理解我们希望实施的内容" requirement is best served by showing concrete artifacts. Three samples follow.

## C.1 Sample release manifest (manifest-2026-MM-DD-<sha>.json)

```json
{
  "manifest_id": "manifest-2026-08-15-a1b2c3d4",
  "release_head": "a1b2c3d4e5f6789012345678901234567890abcd",
  "wave": 12,
  "released_at": "2026-08-15T10:30:00Z",
  "git": {
    "is_dirty": false,
    "branch": "main",
    "ancestor_check": "passed"
  },
  "scores": {
    "raw_implementation_maturity": 88.0,
    "current_verified_readiness": 78.0,
    "seven_by_24_operational_readiness": 85.0,
    "score_caps_applied": [
      {
        "factor": "soak_evidence_not_real",
        "applies": false,
        "delta": 0
      }
    ]
  },
  "operator_shape_gate": {
    "step_1_long_lived_process": "PASS",
    "step_2_real_llm": "PASS",
    "step_3_n3_sequential_runs": "PASS",
    "step_4_cross_loop_stability": "PASS",
    "step_5_lifecycle_observability": "PASS",
    "step_6_cancellation_round_trip": "PASS",
    "evidence_file": "docs/delivery/2026-08-15-a1b2c3d4.md"
  },
  "capability_matrix": [
    {"name": "run.execute", "maturity": "L3", "default_in_prod": true},
    {"name": "run.cancel", "maturity": "L3", "default_in_prod": true},
    {"name": "framework.spring_ai", "maturity": "L3", "default_in_prod": true},
    {"name": "framework.langchain4j", "maturity": "L2", "opt_in": true},
    {"name": "framework.py_sidecar", "maturity": "L2", "opt_in": true},
    {"name": "memory.l0_l1", "maturity": "L2", "default_in_prod": true},
    {"name": "memory.l2_l3", "maturity": "L1", "deferred_to_v1.1": true},
    {"name": "knowledge.glossary_4layer", "maturity": "L2", "default_in_prod": true},
    {"name": "skill.mcp_advisor", "maturity": "L2", "default_in_prod": true},
    {"name": "observability.spine", "maturity": "L3", "default_in_prod": true},
    {"name": "audit.dual_approval_decode", "maturity": "L3", "default_in_prod": true},
    {"name": "outbox.three_path_writes", "maturity": "L3", "default_in_prod": true},
    {"name": "behavior_pinning", "maturity": "L1", "opt_in_premium": true}
  ],
  "contract_v1_freeze": {
    "head": "<digest>",
    "freeze_generation": 0,
    "files": [
      {"path": "agent-platform/contracts/v1/run/RunRequest.java", "sha256": "<digest>"},
      {"path": "agent-platform/contracts/v1/run/RunResponse.java", "sha256": "<digest>"}
    ]
  },
  "allowlist_summary": {
    "total_entries": 3,
    "expired_entries": 0,
    "high_risk_entries": 0,
    "expiring_in_next_2_waves": 1
  },
  "license_audit": {
    "agpl_gpl_on_runtime_path": 0,
    "busl_on_runtime_path": 0,
    "unmitigated_proprietary": 0
  },
  "default_offline_test_profile": {
    "passed": 487,
    "skipped": 8,
    "failed": 0,
    "wall_clock_seconds": 142
  },
  "fall_back_telemetry_summary": {
    "llm_fallback_total_during_gate": 0,
    "adapter_fallback_total_during_gate": 0,
    "outbox_relay_errors_during_gate": 0,
    "ai_operator_invocation_total": "n/a (deferred to v1.1)"
  }
}
```

## C.2 Sample delivery notice (docs/delivery/2026-08-15-a1b2c3d4.md)

```markdown
# Delivery Notice — Wave 12, v1 RELEASED candidate

**Wave**: 12
**Manifest**: docs/governance/manifest-2026-08-15-a1b2c3d4.json
**HEAD**: a1b2c3d4
**Date**: 2026-08-15

## Headline scores (cite current_verified_readiness only per Rule 14)

- `current_verified_readiness = 78.0`

(Other tier scores in manifest; do not headline.)

## Operator-shape gate evidence

All 6 PASS:
- Step 1 (long-lived process): PM2 supervisor, uptime 7h31m at gate run
- Step 2 (real LLM): APP_LLM_MODE=real, DeepSeek V4 Flash provider, 3-call sample
- Step 3 (N≥3 sequential runs): runs r-001, r-002, r-003 each completed in [4.2s, 4.5s, 4.1s] (p95 = 4.5s ≤ 2 × observed_p95 = 9.0s); llm_fallback_count = 0; LLM-request log lines all present
- Step 4 (cross-loop stability): runs 2 and 3 reused run-1's WebClient instance; zero "Reactor disposed" or "ConnectTimeout"
- Step 5 (lifecycle observability): currentStage non-null within 18s on every turn (target ≤ 30s); finishedAt populated on all terminals
- Step 6 (cancellation round-trip): live=200 + drives terminal in 1.4s; unknown=404; never silent 200

## Defect closures (Rule 15 three-part)

| Defect | Code fix | Regression test/gate | Process change |
|---|---|---|---|
| W11-D-3 (RecurrenceLedger linter false-positive on multi-line YAML) | commit a8f3c2b | tests/unit/RecurrenceLedgerLinterTest::testMultiLineEntry | YAML linter uses snake_case parser only |
| W12-D-1 (cancellation race on already-terminal) | commit b9d4f1c | tests/integration/CancellationRaceIT | RunManager.transition rejects T→T cleanly |

## Three-Gate intake activity since W11

- 0 new capability requests
- 1 capability request rejected at G1 (positioning): `sales.ai_chatbot` — declined and redirected to fin-domain-pack

## Risks carried into v1 RELEASED

- R-2 (multi-framework dispatch overhead): PySidecar p95 = 28ms (within budget); reviewed and accepted
- Q-7 (behaviour-pinning subsystem scope): not yet engineered; pinning customers handled via manual snapshot freeze; v1.1 deliverable

## Allowlist status

Total: 3 entries. Expiring in next 2 waves: 1 (W14: SAS-8 LOC budget on AuditFacade — refactor REFAC-W13 in flight). Zero expired.

## Manifest cross-link

This delivery notice's claims derive from manifest manifest-2026-08-15-a1b2c3d4.json. Any discrepancy = rule 14 violation; CI gate ManifestConsistencyTest enforces.

— Platform Team, Wave 12
```

## C.3 Sample CapabilityDescriptor

```java
public static final CapabilityDescriptor KYC_LOOKUP = new CapabilityDescriptor(
    /* name              */ "kyc.lookup",
    /* version           */ "1.2.0",
    /* riskClass         */ RiskClass.HIGH,         // PII access; high regulatory consequence
    /* effectClass       */ EffectClass.READ_ONLY,
    /* requiresAuth      */ true,
    /* availableInDev    */ true,                   // dev permits with mock data
    /* availableInResearch*/ true,
    /* availableInProd   */ true,
    /* maturityLevel     */ MaturityLevel.L3,
    /* sandboxLevel      */ SandboxLevel.RESTRICTED // requires CapabilityPolicy gate
);

public static final CapabilityDescriptor TRANSFER_EXECUTE = new CapabilityDescriptor(
    /* name              */ "transfer.execute",
    /* version           */ "1.0.0",
    /* riskClass         */ RiskClass.HIGH,
    /* effectClass       */ EffectClass.NON_IDEMPOTENT,
    /* requiresAuth      */ true,
    /* availableInDev    */ false,                  // never in dev — production-only
    /* availableInResearch*/ true,
    /* availableInProd   */ true,
    /* maturityLevel     */ MaturityLevel.L2,       // SyncSaga + Compensation tested but not yet L3
    /* sandboxLevel      */ SandboxLevel.RESTRICTED
);
```

`/v1/manifest` renders these descriptors as JSON for customer + audit consumption.

---

# Appendix D — Comparison vs Predecessors and Alternatives

The committee asked "what we want to implement". This is best understood by comparison.

## D.1 vs hi-agent (predecessor; Python)

| Concern | hi-agent | spring-ai-fin v6.0 | Inheritance |
|---|---|---|---|
| Language / framework | Python + FastAPI + asyncio + httpx | Java + Spring Boot 3.x + Spring AI 1.1+ + Reactor | Architecture identical; primitives translate |
| Layering | `agent_server/` + `hi_agent/` two packages | `agent-platform/` + `agent-runtime/` two packages | Same shape; two-seam SAS-1 mirrors R-AS-1 |
| Persistence | SQLite per state-dir | PostgreSQL 15+ | Java pattern requires connection pool; JDBC + HikariCP |
| Multi-framework | Single (hi-agent's own kernel) | Spring AI + LangChain4j + Python sidecar via `FrameworkAdapter` | New in v6.0; user requirement |
| Frozen v1 contract | RELEASED at SHA `55e51a7f` | Will be RELEASED at first stable SHA | Same `--snapshot` + `--enforce` discipline |
| Posture model | `HI_AGENT_POSTURE` | `APP_POSTURE` | Identical semantics |
| Async resource lifetime | SyncBridge persistent loop | ReactorScheduler bounded-elastic | Same Rule 5 discipline; Reactor-native |
| 12+14 observability | RunEventEmitter + 14 spine layers | Same | Identical metric names with `springaifin_*` prefix |
| Outbox vs Saga | hi-agent only used Outbox; never had finance-grade fund transfer | Three named paths: OUTBOX_ASYNC + SYNC_SAGA + DIRECT_DB | New in v6.0; finance-domain enrichment |
| Behaviour pinning | Not addressed | Opt-in premium; 5-year cap | New in v6.0; finance-regulatory requirement |
| Domain content | RIA = research team, separate codebase | `fin-domain-pack/` = customer-supplied | Same Rule 10 discipline |
| Customer Starters | Not applicable (research-team-internal) | `fin-starter-{core,memory,skill,flow,advanced}` | New in v6.0 (customer-facing) |

**Key inheritance**: 12 universal rules, Three-Gate intake, operator-shape readiness gate, single-construction-path, contract spine, capability maturity ladder, posture-aware defaults — all preserved. **Translated**: Python idioms (asyncio, dataclass `__post_init__`, sync_bridge) → Java idioms (Reactor, record canonical constructor, ReactorScheduler).

## D.2 vs Spring AI Alibaba (rejected alternative)

| Concern | Spring AI Alibaba | spring-ai-fin v6.0 |
|---|---|---|
| Vendor coupling | Alibaba ecosystem (Aliyun OSS, MaxCompute, etc.) | None — vendor-agnostic |
| StateGraph + ReactAgent | Provided as built-in | Not adopted directly; we implement `runner/StageExecutor` independently |
| Compatibility | Targets China market | Targets Southeast Asia (Indonesia + Singapore primary) |
| License | Apache 2.0 | Apache 2.0 (we don't fork) |
| Reason for rejection | Alibaba is a competitor in SEA financial cloud / AI markets; customer trust requires we don't depend on a competitor's ecosystem | — |

**What we borrow from Spring AI Alibaba**: design patterns (StateGraph concept, Starter modularization). **What we don't borrow**: runtime dependency.

## D.3 vs hypothetical "Spring AI only" approach

A simpler option: just use Spring AI 1.1+ directly with no platform layer. Why we don't do this:

| Concern | Spring AI only | spring-ai-fin v6.0 |
|---|---|---|
| Frozen v1 contract for customers | None — Spring AI churns minor versions | Yes — `agent-platform/contracts/v1/` byte-frozen |
| Multi-framework support | Spring AI only | Spring AI + LangChain4j + Python sidecar |
| Operator-shape readiness gate | Not applicable | Mandatory before ship |
| Idempotency, tenant isolation, audit, PII | Customer must build | Platform-provided |
| Behaviour pinning | Not applicable | Opt-in premium |
| Posture-aware defaults | Standard Spring profiles | Three-posture model with consumer-side `requires*()` discipline |
| Capability maturity reporting | Not applicable | L0–L4 ladder per capability |

**Conclusion**: Spring AI alone is sufficient for a single agent project. spring-ai-fin is necessary for **enterprise platform** scale — multi-tenant + multi-framework + regulated.

## D.4 vs "polyglot Java + Python in-process" (rejected at D-5)

| Concern | Polyglot in-process | spring-ai-fin v6.0 (out-of-process) |
|---|---|---|
| Latency | Lower (no IPC) | +30-50ms p95 per dispatch |
| Crash isolation | Poor — Python crash takes JVM | Excellent — sidecar restart by container orchestrator |
| Rule 5 | Catastrophic violation (shared event loop) | Honoured (separate processes) |
| Resource sharing | Possible but dangerous | None |
| Production scars | hi-agent's 2026-04-22 incident class | Avoided by construction |

**Conclusion**: -30ms latency penalty vs production-grade isolation. Trade accepted at D-5.

---

# Closing remarks for the committee

This document and its companions represent a **disciplined translation** of:

1. **A user-stated requirement** ("依托业内最活跃的AI智能体框架社区，开发一套金融行业的企业级智能体平台") into
2. **A predecessor's hard-won engineering rules** (hi-agent CLAUDE.md, 12 universal rules, 32 release waves) and
3. **A specific failure mode catalog** (the v5.0 review's 6 HIGH + 9 MEDIUM findings)

into a **falsifiable architectural baseline**. Every claim is annotated with "How to evaluate this" or a falsification test. Every decision lists alternatives. Every component has a maturity level and a posture default.

The committee's job is to either **accept this baseline as the W1 starting point** or **propose specific changes via §23 dissent**. We commit to responding to dissent within 7 calendar days.

This is what we want to implement, structured for your review.

— *Platform Team, 2026-05-07*
