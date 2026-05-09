# Architecture Design Systematic Review -- 2026-05-09

> Self-driven (cycle-10), max-effort review. Reviewer prompt:
> "categorize problems, systematically reflect on the current
> architecture design according to problem categories, systematically
> analyze every L0-L2 design, propose a remediation plan, and
> systematically fix."
>
> This is NOT a reactive cycle responding to an external reviewer. It
> is a self-audit done after cycle-9 closed the truth-cut, asking
> "what's structurally missing in the design now that the corpus is
> internally consistent?". The honest answer below identifies real
> gaps that the 240+ dim self-audit (which verifies internal
> consistency, not architectural completeness) cannot detect.

## 0. Honest framing

The 240+ dim self-audit at Round 4 (982 / 985) confirms the
**documentation surface is internally consistent**. What the rubric
does not measure is whether the design covers the **right concerns**
in the first place. This document fills that gap by walking every
L0/L1/L2 doc, naming concerns the design has not addressed, and
prioritizing the closure work.

The review is structured in four parts:

1. Problem categories (the analytical frame).
2. Per-document analysis (one walk of every active doc).
3. Issue inventory consolidated by category.
4. Remediation plan (this cycle's commits + carry-forward to W0+).

## 1. Problem categories

Six categories. Each has a recognition signature and a "this is real"
test.

### P-A: Architectural coverage gaps

Concerns the design has not addressed at all. Recognition: a competent
reviewer asks "what's the X for Y?" and no document answers.

Examples (this cycle): non-functional requirements (latency / throughput
/ cost SLOs); threat model; deployment topology; data-model
conventions; API conventions (error codes, pagination, versioning).
None of these are mentioned anywhere in the active corpus today.

### P-B: Under-specified existing modules

Modules the design names but specifies only at the surface. Recognition:
a module's L2 doc says "we do X" without explaining how X handles
specific failure / scale / lifecycle cases that the module's role
implies.

Examples: tenant module names "tenant binding" but does not specify
tenant lifecycle (create / suspend / delete / export); memory module
names "L0/L1/L2 tiers" but does not specify eviction or per-tenant
quota; tool module names "MCP registry" but does not specify tool
versioning or per-tenant quota; run module does not specify parallel
run handling.

### P-C: Cross-cutting under-coupling

Concerns that span multiple modules without a single owning document.
Recognition: a concern shows up in two L2 docs with slight
contradictions or with a "details TBD" note.

Examples: cross-module Java type ownership (where does `Tenant` live,
who imports whom); error-propagation conventions between platform and
runtime; timeout policies between modules; inter-module retry budgets.

### P-D: First-principle measurability

The three first-principles (lower threshold, lower cost, evolving
intelligence) are stated but not operationalized. Recognition: a
reviewer asks "what does P1 actually measure?" and the answer is
prose, not a metric.

Examples: "lower threshold" is described via features (one-command
compose, OpenAPI, admin UI) but lacks a measurable proxy (e.g.,
"time-to-first-successful-run for a new customer < 30 minutes" or
"docker compose up to /health 200 < 60s"). Without a proxy, the
principle cannot be regressed.

### P-E: OSS-choice validation

The OSS matrix names primary deps but does not always validate that
the dep is appropriate for the role. Recognition: a reviewer reading
the matrix asks "is X actually available at version Y?" or "is X the
right tool for that role at the v1 scale?".

Examples: Spring AI 1.0.x -- GA status to confirm; MCP Java SDK pinned
as "latest 0.x"; Temporal vs simpler durable-execution alternative
for a single-customer v1; pgvector vs Qdrant trigger criteria.

### P-F: Process drift

Reactive review-cycle pattern continuing or new closure-pressure
mechanisms emerging. Recognition: governance documents grow faster
than product documents, or audit-rule additions outpace artifact
deliverables.

Examples: 10 review cycles in 2 days; 240+ dim self-audit treated as
authoritative even though it's design-only; cross-cutting docs
proliferating without index updates. (Cycle-9 already addressed the
worst form of this; this category is a tripwire for next cycles.)

## 2. Per-document analysis

A walk of every active doc. For each I list the top 1-3 honest issues
and the category. "(in-flight)" marks items being closed in this
cycle.

### L0 -- ARCHITECTURE.md

- Issue L0-1 (P-A): No NFR / SLO section. Latency, throughput, cost,
  availability targets per posture are not stated. Tests reference
  `p99` but no target value lives in design.
  **(in-flight: this cycle adds sec-13 NFRs.)**
- Issue L0-2 (P-D): The 3 first-principles in sec-5 are described as
  feature lists with waves; no measurable proxy per principle.
  **(in-flight: this cycle adds sec-5.4 measurable proxies.)**
- Issue L0-3 (P-C): No module dependency graph. The module layout in
  sec-3 is a tree, but cross-module call directions and the "no
  cycles" rule are implicit.
  **(in-flight: this cycle adds sec-3.1 dependency graph.)**
- Issue L0-4 (P-E): Spring AI 1.0.x and MCP Java SDK "latest 0.x"
  versions not pinned to specific releases.
  Carry-forward (next cycle).

### L1 -- agent-platform/ARCHITECTURE.md

- Issue PL-1 (P-C): Cross-module contract to agent-runtime is not
  named. How does agent-platform call agent-runtime? Spring bean
  injection? Java interface? The doc treats it as implicit.
  **(in-flight: cross-module-deps section added.)**
- Issue PL-2 (P-A): No tenant-lifecycle ownership statement. The L2
  tenant doc handles in-flight requests; nobody owns
  create/suspend/delete/export.
  **(in-flight: tenant L2 expanded.)**
- Issue PL-3 (P-C): Error propagation between platform and runtime is
  not specified. What happens when runtime returns 500?

### L1 -- agent-runtime/ARCHITECTURE.md

- Issue RT-1 (P-C): Same as PL-1 from the other side.
  **(in-flight.)**
- Issue RT-2 (P-A): No latency budget per submodule.
- Issue RT-3 (P-A): No clear ownership of `Tenant`, `Run`, etc Java
  types -- platform or runtime?
  **(carry-forward; addressed partially by data-model-conventions.)**

### L2 -- agent-platform/web

- Issue WEB-1 (P-A): No streaming response handling described.
- Issue WEB-2 (P-C): Rate-limit module mentioned in L1 but not as L2;
  responsibilities split implicitly between web and idempotency.
- Issue WEB-3 (P-A): No request/response logging policy.

### L2 -- agent-platform/auth

- Issue AUTH-1 (P-B): No token revocation handling (revocation list,
  introspection endpoint).
- Issue AUTH-2 (P-B): No stepped-up auth for high-risk operations.
- Issue AUTH-3 (P-A): No token-binding (DPoP / mTLS) discussion.

### L2 -- agent-platform/tenant

- Issue TEN-1 (P-B): No tenant lifecycle (create / suspend / delete /
  export).
  **(in-flight: this cycle expands the L2.)**
- Issue TEN-2 (P-B): No tenant impersonation procedure for support.
- Issue TEN-3 (P-A): No tenant data export contract (GDPR, customer
  offboarding).

### L2 -- agent-platform/idempotency

- Issue IDEM-1 (P-B): Response body storage for replay not specified
  (size cap, partial responses, streaming).
- Issue IDEM-2 (P-B): Cleanup job specification (cadence, target TTL,
  metrics) is mentioned but not concrete.

### L2 -- agent-platform/bootstrap

- Issue BOOT-1 (P-B): Boot timeout / health-startup window not
  specified.
- Mostly well-specified. No major gaps.

### L2 -- agent-platform/config

- Issue CFG-1 (P-B): Config change propagation semantics (hot-reload
  vs restart) not specified per key.
- Issue CFG-2 (P-A): Config audit trail (who changed what when) not
  specified.

### L2 -- agent-platform/contracts

- Issue CON-1 (P-A): Error code taxonomy not defined.
  **(in-flight: api-conventions cross-cutting doc.)**
- Issue CON-2 (P-A): Pagination conventions not defined.
  **(in-flight: api-conventions.)**
- Issue CON-3 (P-A): Versioning policy implicit (URL prefix), but no
  policy doc.
  **(in-flight: api-conventions.)**

### L2 -- agent-runtime/run

- Issue RUN-1 (P-B): Parallel run handling per tenant not specified.
  **(in-flight: this cycle expands.)**
- Issue RUN-2 (P-B): Timeout escalation (per-stage vs total) not
  specified.
  **(in-flight.)**
- Issue RUN-3 (P-B): Run cancellation semantics across Temporal vs
  sync orchestrator boundary partially specified.

### L2 -- agent-runtime/llm

- Issue LLM-1 (P-B): Token streaming protocol not specified.
- Issue LLM-2 (P-B): Tool-calling protocol detail (which provider's
  function-calling format, how it maps to MCP) not specified.
- Issue LLM-3 (P-B): Prompt template management (storage, versioning,
  inheritance) not specified.

### L2 -- agent-runtime/tool

- Issue TOOL-1 (P-B): Tool versioning strategy not specified.
  **(in-flight: this cycle expands.)**
- Issue TOOL-2 (P-B): Per-tenant tool quota not specified.
  **(in-flight.)**
- Issue TOOL-3 (P-A): Tool sandboxing levels (in-process bean vs MCP
  out-of-process vs Wasm vs container) not specified.

### L2 -- agent-runtime/action

- Issue ACT-1 (P-B): Action retry semantics not specified (which
  stages are retryable, which are terminal).
- Issue ACT-2 (P-A): Audit chain validation procedure (Merkle root
  verification) not specified.
- Mostly well-specified for a 5-stage chain.

### L2 -- agent-runtime/memory

- Issue MEM-1 (P-B): Memory eviction policy (LRU? size cap? per-tenant
  cap?) not specified.
  **(in-flight: this cycle expands.)**
- Issue MEM-2 (P-B): Per-tenant memory quota not specified.
  **(in-flight.)**
- Issue MEM-3 (P-A): Memory privacy policy (encryption at rest, PII
  tagging on writes) partially specified; no concrete schema.

### L2 -- agent-runtime/outbox

- Issue OUT-1 (P-B): Per-tenant ordering guarantees not specified.
  **(in-flight: this cycle expands.)**
- Issue OUT-2 (P-B): DLQ procedure (what happens when max-retries
  exceeded; manual replay) not specified.
  **(in-flight.)**
- Issue OUT-3 (P-A): Cross-region outbox replication not addressed
  (related to deployment topology).

### L2 -- agent-runtime/temporal

- Issue TMP-1 (P-B): Workflow versioning strategy not specified.
  **(in-flight: this cycle expands.)**
- Issue TMP-2 (P-B): Signal contract / signal-handler discipline not
  specified beyond "CancelRunSignal exists".
- Issue TMP-3 (P-A): Temporal namespace strategy per tenant /
  environment not specified.

### L2 -- agent-runtime/observability

- Issue OBS-1 (P-A): Alerting rules (Prometheus alerts, Alertmanager
  routes) not specified.
- Issue OBS-2 (P-A): Cross-region trace propagation not addressed.
- Mostly well-specified.

### Module -- agent-eval

- Issue EVAL-1 (P-B): Human-eval integration / RLHF feedback loop not
  specified.
- Issue EVAL-2 (P-A): Eval cost budget not specified.

### Cross-cutting docs (existing 6)

- posture-model: complete.
- security-control-matrix: complete (20 controls).
- trust-boundary-diagram: complete (4 boundaries).
- secrets-lifecycle: complete (9 secrets enumerated).
- supply-chain-controls: complete (Maven, container, SBOM).
- observability-policy: complete (cardinality, sample rates).

### Missing cross-cutting docs (P-A)

- non-functional-requirements.md -- latency / throughput / cost / availability SLOs per posture.
  **(in-flight: this cycle adds.)**
- threat-model.md -- STRIDE per trust boundary.
  **(in-flight.)**
- api-conventions.md -- error codes, pagination, versioning, naming.
  **(in-flight.)**
- data-model-conventions.md -- table naming, ID strategy, timestamps,
  audit columns, multi-tenant patterns.
  **(in-flight.)**
- deployment-topology.md -- single-region / multi-region, replicas,
  HA / DR.
  **(in-flight.)**
- failure-modes-catalog.md -- per-module failure modes.
  **(in-flight.)**

## 3. Consolidated issue inventory by category

| Category | Issues identified | This cycle | Carry-forward |
|---|---|---|---|
| P-A coverage gaps | 17 | 11 (NFR / threat / API / data / deployment / failure-modes / L0 sec-13 / lifecycle / module-deps / first-principles measurability / 1 misc) | 6 (token-binding, alerting, cross-region, sandboxing, audit chain validate, eval cost budget) |
| P-B under-specified | 16 | 6 (tenant lifecycle, memory eviction, tool versioning, run parallel, temporal versioning, outbox per-tenant ordering) | 10 (token revocation, stepped-up auth, idempotency body storage, config hot-reload, run timeout escalation, LLM streaming, tool-calling protocol, prompt templates, action retry, signal contract, eval human-loop) |
| P-C cross-cutting | 5 | 2 (module-deps + data-model = type ownership) | 3 (error propagation policy, timeout policy, retry budgets) |
| P-D measurability | 3 | 1 (first-principles measurable proxies) | 2 (per-wave score lift, per-feature business KPI) |
| P-E OSS validation | 4 | 0 | 4 (Spring AI 1.0.x GA, MCP version pin, Temporal vs simpler, pgvector vs Qdrant) |
| P-F process drift | 0 | 0 (tripwire only) | continue monitoring |

**Total identified: 45 issues.** This cycle closes **20** (the
top-priority P-A gaps + 6 most-impactful P-B items). **25 carry-forward**
to subsequent cycles or to W0+.

## 4. Remediation plan

### 4.1 This cycle's commits (cycle-10 self-driven)

Six new active documents under `docs/cross-cutting/`:

1. `non-functional-requirements.md`
2. `threat-model.md`
3. `api-conventions.md`
4. `data-model-conventions.md`
5. `deployment-topology.md`
6. `failure-modes-catalog.md`

L0 enhancements:

7. New section: Non-functional requirements summary (full detail in NFR doc).
8. New section: Measurable proxies for the three first-principles.
9. New section: Module dependency graph + acyclic rule.

L2 expansions (6 modules):

10. agent-platform/tenant: full tenant lifecycle + impersonation procedure + data export contract.
11. agent-runtime/memory: eviction + per-tenant quota.
12. agent-runtime/tool: tool versioning + per-tenant quota + sandboxing levels.
13. agent-runtime/run: parallel runs + timeout escalation.
14. agent-runtime/temporal: workflow versioning + signal-handler discipline + namespace strategy.
15. agent-runtime/outbox: per-tenant ordering + DLQ procedure.

Governance:

16. active-corpus.yaml: 6 new active docs added.
17. current-architecture-index.md: 6 new entries.
18. architecture-status.yaml: 20 closure rows + 25 carry-forward rows.

### 4.2 Carry-forward (next cycle / W0+)

| Item | Category | Priority | Target |
|---|---|---|---|
| Token revocation handling (auth) | P-B | P1 | next cycle |
| Stepped-up auth | P-B | P2 | W2 |
| Idempotency response body storage | P-B | P1 | W1 |
| Config hot-reload semantics | P-B | P1 | W2 |
| Run timeout escalation | P-B | P1 | W2 |
| LLM streaming + tool-calling protocol | P-B | P1 | W3 |
| Prompt template management | P-B | P2 | W3 |
| Action retry semantics | P-B | P1 | W3 |
| Temporal signal-handler discipline | P-B | P1 | W4 |
| Eval human-loop | P-B | P2 | W4+ |
| Token-binding (DPoP / mTLS) | P-A | P2 | W4+ |
| Alerting rules | P-A | P1 | W2 |
| Cross-region trace propagation | P-A | P2 | W4+ |
| Tool sandboxing levels | P-A | P2 | W3 |
| Audit chain validation procedure | P-A | P1 | W3 |
| Eval cost budget | P-A | P2 | W4 |
| Error propagation policy (cross-module) | P-C | P1 | next cycle |
| Inter-module timeout policy | P-C | P1 | next cycle |
| Retry-budget cross-module policy | P-C | P1 | next cycle |
| Per-wave score-lift target | P-D | P2 | next cycle |
| Per-feature business-KPI proxy | P-D | P2 | next cycle |
| Spring AI 1.0.x GA confirmation | P-E | P1 | next cycle |
| MCP Java SDK version pin | P-E | P1 | next cycle |
| Temporal vs simpler v1 alternative | P-E | P2 | next cycle |
| pgvector vs Qdrant trigger criteria | P-E | P2 | W2 |

### 4.3 Cadence

This document is re-run before every cycle as part of self-audit. It
is NOT scored against the 240+ dim rubric (which measures internal
consistency); it is a separate "are we addressing the right concerns?"
check. Going forward:

- Every cycle: re-run problem-category scan; net-new gaps or new
  carry-forward items get a row.
- Every 3 cycles: prune carry-forward items that have been resolved
  or downgraded.
- At W0 close: rebalance the rubric -- some carry-forward items become
  L0-runtime-relevant once code lands.

## 5. Operating principle going forward

The 240+ dim self-audit answers "is the design surface internally
consistent?" -- a yes/no check on documentation. This systematic review
answers "is the design surface architecturally adequate?" -- a
multi-dimensional check on coverage. **Both are needed.** A passing
self-audit + a passing systematic review together approximate "the
design is ready for W0+ to start coding."

Cycle-10 (this self-driven cycle) demonstrates the pattern: take the
self-audit-clean baseline; do a category-driven walk; close the
top-priority gaps; promote the rest to a tracked carry-forward list.
The next external review cycle should add new categories (or new
issues within categories), not re-find old ones.

## 6. Closing note

The remediation work in this commit chain does NOT introduce code. It
introduces design coverage that should have been there before W0
starts -- specifically the NFRs, the threat model, the data and API
conventions, the deployment topology, the failure-modes catalog, and
the lifecycle / quota / versioning details that W0+ implementations
will reference. The intent is that **W0 starts with a complete design
to implement against**, not with documents to write while
implementing. That is the point of doing this self-driven cycle now.
