# Design Decision Register -- cross-cutting policy

> Owner: architecture | Wave: anchored at W0; per-wave additions | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

ADR-style register of major architectural decisions: context,
alternatives considered, the choice, the rationale, the
consequences, and the reversal cost. Closes Phase A item 3 (per
cycle-12).

This is NOT a complete decision history -- only the choices that
shape the system's identity. Smaller decisions live in their owning
L2 doc's Risks or Out-of-scope section. The threshold for inclusion
here: "would changing this require redesigning more than one L2".

## 2. Format

Each entry:

```
### ADR-NN: <short title>

**Status**: accepted | superseded | deferred
**Context**: <one paragraph>
**Options considered**:
  1. <opt 1> -- <one-line summary>
  2. <opt 2> -- <one-line summary>
  3. <opt 3> -- <one-line summary>
**Decision**: <which option, in one sentence>
**Rationale**: <why; <= 5 bullets>
**Consequences**: <implications; positive + negative>
**Reversal cost**: low | medium | high | irreversible
**References**: <docs that depend on this>
```

## 3. Decisions (15 of the major ones)

### ADR-01: Java 21 + Spring Boot 3.5.x as the runtime baseline

**Status**: accepted
**Context**: needed a JVM stack with virtual threads, modern HTTP, and a
mature DI / config story for an agent runtime targeting financial-services
operators.
**Options considered**:
  1. Java 21 + Spring Boot 3.5.x -- mainstream + virtual threads + Spring AI native.
  2. Kotlin + Ktor / Spring Boot -- terser code; fewer libraries pre-built for finserv compliance audits.
  3. Go + chi/gin -- great concurrency model but no Spring AI / no Java-ecosystem tooling.
**Decision**: Java 21 LTS + Spring Boot 3.5.x.
**Rationale**:
  - Spring AI is a Java-first project; using anything else means writing the LLM client from scratch.
  - Customer environments (Tier-1 financial) overwhelmingly run JVM stacks.
  - Virtual threads (Loom) eliminate the reactive vs blocking debate for our IO-heavy workload.
  - Java 21 LTS is supported until 2031 -- aligns with the customer-deployment lifetime.
**Consequences**: locked into JVM ecosystem; library churn risk on Spring Boot major bumps; faster onboarding for Java engineers; slower for Python/Go shops.
**Reversal cost**: high (would force re-implementation of every glue module).
**References**: `ARCHITECTURE.md` sec-2; `docs/cross-cutting/oss-bill-of-materials.md` sec-4.1.

### ADR-02: Spring AI 1.0.7 as the LLM gateway, not LangChain4j

**Status**: accepted
**Context**: needed a Java client abstraction for multiple LLM providers
with prompt caching, tool calling, vector store integration.
**Options considered**:
  1. Spring AI 1.0.x -- first-class Spring integration; mature ChatClient + VectorStore.
  2. LangChain4j -- richer agent abstractions; less Spring-idiomatic.
  3. Custom HTTP wrappers per provider -- maximum control; maximum maintenance.
**Decision**: Spring AI 1.0.7 (latest 1.0.x patch as of design date).
**Rationale**:
  - Spring AI's ChatClient maps directly to the role we need; LangChain4j's chain abstraction would require us to subset it.
  - Spring AI's VectorStore + pgvector binding saves a complete glue module.
  - Spring Boot autoconfiguration cuts wiring boilerplate.
  - LangChain4j integration is left as a per-tenant alternative bean if a customer demands.
**Consequences**: tied to Spring AI's API velocity; M-line / 1.x branches require careful pinning; multi-framework dispatch (LangChain4j) is W4+ optional.
**Reversal cost**: medium (LlmRouter is the only adapter; provider beans isolate vendor surface).
**References**: `agent-runtime/llm/ARCHITECTURE.md`; BoM sec-3.1.

### ADR-03: Temporal Java SDK 1.34.0 for durable workflows, not Airflow / Step Functions

**Status**: accepted
**Context**: long-running runs (>30s) need crash-safe state, replay,
cancellation, and signal-based extension.
**Options considered**:
  1. Temporal -- battle-tested; Java SDK; explicit `getVersion` for workflow evolution.
  2. Apache Airflow / Prefect -- DAG-oriented; weaker at sub-second / signal-driven flows.
  3. AWS Step Functions -- excellent at AWS but locks deployment to AWS.
  4. Custom outbox-driven state machine -- minimum dependencies; maximum bugs.
**Decision**: Temporal Java SDK 1.34.0.
**Rationale**:
  - Customer can self-host (Temporal cluster on K8s) -- aligns with on-prem v1.
  - Workflow versioning (`Workflow.getVersion`) is exactly the pattern we need to evolve agents without breaking running workflows.
  - Java SDK + activity-only-IO discipline is well-documented.
  - Managed Temporal Cloud is an upgrade path for ops simplicity.
**Consequences**: Temporal cluster is operational complexity not present in the rest of the stack; team training required; non-determinism lint becomes a CI gate.
**Reversal cost**: medium (sync-mode RunOrchestrator is still in tree as fallback for short runs).
**References**: `agent-runtime/temporal/ARCHITECTURE.md`; BoM sec-3.2.

### ADR-04: PostgreSQL 16 with RLS + pgvector, not separate vector DB

**Status**: accepted
**Context**: needed multi-tenant relational store, durable outbox, plus
vector search for memory L2.
**Options considered**:
  1. Postgres + pgvector -- one DB; RLS policies cover relational + vector; familiar to ops.
  2. Postgres + Qdrant -- specialized vector DB; better at >10M rows.
  3. Postgres + Elasticsearch -- mature vector + text but heavy.
**Decision**: Postgres 16 + pgvector for v1; Qdrant trigger criteria documented.
**Rationale**:
  - One DB to operate, one backup story, one access-control story.
  - v1 customer profile (~500k rows / tenant; 5 tenants = 2.5M rows) fits comfortably under pgvector's >5M-row trigger threshold.
  - RLS uniformly applies to relational + vector tables.
  - Customer's DBA team already knows Postgres.
**Consequences**: pgvector index grows with data; ANN tuning is on us; Qdrant migration plan is needed but not pre-built.
**Reversal cost**: medium (memory L2 store is one adapter; Qdrant adapter is plug-in).
**References**: `agent-runtime/memory/ARCHITECTURE.md`; `docs/cross-cutting/data-model-conventions.md`; BoM sec-4.2.

### ADR-05: Row-level security with SET LOCAL transaction-scoped GUC, not per-connection reset

**Status**: accepted
**Context**: HikariCP shares connections across tenants; tenant binding
must be transactional.
**Options considered**:
  1. `SET LOCAL app.tenant_id` inside every transaction; auto-discarded by Postgres on commit/rollback.
  2. Per-checkout reset (`HikariConnectionResetPolicy`) -- proven flawed in cycle-2/3/5 review.
  3. Per-tenant connection pool -- simpler isolation; multi-tenant scaling problem.
**Decision**: Option 1 (SET LOCAL) + assertion trigger on every tenant table.
**Rationale**:
  - Postgres semantics make GUCs auto-discarded on transaction end -- no race window.
  - Spring's TransactionSynchronization fits cleanly.
  - Trigger fires fail-closed when GUC is empty -- defense in depth.
**Consequences**: every L2 module that opens a tx must use a Spring-managed tx (no raw JDBC); connection-pool tuning must use HikariCP 5.x with virtual-thread-friendly defaults.
**Reversal cost**: medium (changing isolation strategy means rewriting TenantBinder and every assertion trigger).
**References**: `agent-platform/tenant/ARCHITECTURE.md`; `docs/cross-cutting/security-control-matrix.md` C3-C5.

### ADR-06: ActionGuard 5-stage chain (cycle-9 truth-cut), not 11-stage

**Status**: accepted (supersedes earlier 11-stage design)
**Context**: cycle-1..8 over-specified ActionGuard to 11 stages; 6 of
those were informational rather than enforced.
**Options considered**:
  1. 5-stage: Authenticate / Authorize / Bound / Execute / Witness.
  2. 11-stage as designed in cycles 1..8.
  3. 3-stage (Authenticate / Decide / Witness) -- too coarse for OPA + budget + idempotency split.
**Decision**: 5-stage.
**Rationale**:
  - Each stage maps to an enforced check, not a documentation slot.
  - Pre/Post evidence writers fold into the Witness stage as audit + outbox writes.
  - Smaller surface = fewer places where a stage could be skipped accidentally.
**Consequences**: 11-stage docs (`agent-runtime/action-guard/`, `docs/security-control-matrix.md`) move to transitional_rationale; gate rule binds to 5-stage paths only.
**Reversal cost**: medium (chain class structure; OPA policies; tests).
**References**: `agent-runtime/action/ARCHITECTURE.md`; cycle-9 response sec-C1.

### ADR-07: At-least-once outbox in Postgres, not Kafka, for v1

**Status**: accepted
**Context**: side-effects must be durable across crashes; eventual
delivery must be guaranteed.
**Options considered**:
  1. Postgres outbox table + scheduled publisher (FOR UPDATE SKIP LOCKED).
  2. Kafka direct -- proven scale but requires the cluster as a dependency v1 doesn't need.
  3. NATS JetStream -- lighter than Kafka; still adds operational surface.
**Decision**: Postgres outbox at v1; Kafka adapter pluggable when scale demands.
**Rationale**:
  - v1 customer (~50 RPS sustained) doesn't need Kafka.
  - Outbox sink interface is one method; Kafka is a drop-in replacement.
  - One DB to operate.
**Consequences**: per-tenant ordering requires per-tenant batches (cycle-10 outbox sec-10.1); cross-region outbox replication is W4+ work.
**Reversal cost**: low (sink adapter swap).
**References**: `agent-runtime/outbox/ARCHITECTURE.md`; deployment-topology sec-4.

### ADR-08: OPA sidecar for authorization, not in-process Cedar / custom

**Status**: accepted
**Context**: ActionGuard needs a fast, audit-able authorization decision
per side effect.
**Options considered**:
  1. OPA local sidecar with Rego.
  2. AWS Cedar -- great policy language; not yet a mature Java SDK.
  3. Custom Java authorization -- maximum velocity at v1; minimum durability.
  4. Spring Security Authorization -- great for HTTP; not granular for capability-level.
**Decision**: OPA sidecar; Rego policy bundle in `ops/opa/policies/`.
**Rationale**:
  - Policy-as-code separation: security team owns Rego, app team owns Java.
  - OPA bundle distribution + signing is solved.
  - Local sidecar latency p99 < 5ms is achievable (proven in industry deployments).
  - `opa eval` provides unit-test capability for policies.
**Consequences**: each app pod has an OPA sidecar (~50MB memory); fail-closed on OPA outage in research/prod.
**Reversal cost**: medium (one decision adapter; Cedar Java SDK could replace if it matures).
**References**: `agent-runtime/action/ARCHITECTURE.md`; deployment-topology.

### ADR-09: HashiCorp Vault (OSS) for secrets, not env vars / K8s Secrets only

**Status**: accepted
**Context**: provider keys, JWT secrets, DB passwords need rotation +
audit.
**Options considered**:
  1. Vault OSS + Spring Cloud Vault.
  2. K8s Secrets only -- no rotation; no audit; insufficient for finserv.
  3. AWS Secrets Manager / Azure Key Vault -- cloud-locked.
  4. SOPS + git-secret -- file-based; no audit trail.
**Decision**: Vault OSS + per-tenant subpaths (`secret/tenant/<id>/...`).
**Rationale**:
  - Self-hostable; works on-prem.
  - Watcher API supports hot-reload (Spring Cloud Vault).
  - Per-secret audit trail.
  - Vault community is large; managed offerings exist for upgrade.
**Consequences**: Vault HA cluster (3-node) is operational complexity; Vault outage degrades readiness probe.
**Reversal cost**: medium (Spring Cloud Vault config swap to alternative provider).
**References**: `docs/cross-cutting/secrets-lifecycle.md`; deployment-topology.

### ADR-10: Keycloak (OSS) as default IdP, but customer can BYO

**Status**: accepted
**Context**: needed an OIDC IdP for dev + a default for customers without one.
**Options considered**:
  1. Keycloak as default; OIDC interface for customer's own IdP.
  2. Mandate customer's IdP -- onboarding friction.
  3. Build a tiny IdP -- huge anti-pattern in finserv.
**Decision**: Keycloak default; any OIDC-compliant IdP supported.
**Rationale**:
  - Tier-1 customers usually have an IdP (Azure AD, Auth0, custom OIDC); we accept their JWKS.
  - Keycloak fallback for dev + small-customer cases.
  - OIDC is the contract; Keycloak is one implementation.
**Consequences**: realm-import + initial-user provisioning is a Keycloak-specific job in W1; unsupported when customer brings own IdP.
**Reversal cost**: low (configuration swap).
**References**: `agent-platform/auth/ARCHITECTURE.md`; deployment-topology.

### ADR-11: Spring Cloud Gateway as ingress, not Kong / Traefik

**Status**: accepted
**Context**: edge gateway for routing, rate limit, header manipulation.
**Options considered**:
  1. Spring Cloud Gateway -- Java-native; same Spring Boot stack.
  2. Kong / Traefik -- richer plugin ecosystem; separate operational surface.
  3. K8s Ingress Controller alone -- minimum features.
**Decision**: Spring Cloud Gateway 4.x in front of the app pods (W2).
**Rationale**:
  - Same JVM stack -- no new tooling.
  - RouteLocator is sufficient for v1's small route count.
  - K8s Ingress sits in front for TLS / DDoS.
**Consequences**: latency overhead of an extra hop (acceptable per NFR p99); customer can replace with Kong if their ops team prefers.
**Reversal cost**: low (it's behind K8s Service abstractions).
**References**: `agent-platform/web/ARCHITECTURE.md`; deployment-topology.

### ADR-12: Maven multi-module, not Gradle

**Status**: accepted
**Context**: build system for a 3-module project with strict dependency direction.
**Options considered**:
  1. Maven 3.9 -- mature; explicit; works with Spring's BOM perfectly.
  2. Gradle -- faster builds; more flexible; less standard in finserv shops.
  3. Bazel -- great at scale; massive overhead for 3 modules.
**Decision**: Maven 3.9.
**Rationale**:
  - Spring Boot's BOM is Maven-first.
  - Customer audit teams understand Maven (POM files are deterministic).
  - 3 modules don't need Gradle's flexibility.
**Consequences**: slower incremental builds; less DSL flexibility.
**Reversal cost**: high (every module's build).
**References**: `docs/plans/engineering-plan-W0-W4.md` sec-2.4 (W0).

### ADR-13: UUIDv7 for surrogate IDs, not snowflake / sequence

**Status**: accepted
**Context**: every persistent record needs an ID that's safe under
multi-tenant write load.
**Options considered**:
  1. UUIDv7 (time-ordered) -- no central sequence; B-tree friendly.
  2. UUID v4 (random) -- B-tree fragmentation under load.
  3. Postgres bigserial -- sequence becomes a hotspot with read replicas; cross-region contention.
  4. Twitter-style snowflake -- requires a central time service.
**Decision**: UUIDv7 generated by app via java.util.UUID + helper.
**Rationale**:
  - No central sequence -- safe for cross-replica.
  - Time-ordered -- B-tree pages stay packed for chronological queries.
  - Globally unique -- safe for cross-region replication later.
**Consequences**: app must generate IDs (slight overhead vs DB-default); UUIDv7 helper is glue we own.
**Reversal cost**: high (every table's PK + every Java record).
**References**: `docs/cross-cutting/data-model-conventions.md` sec-3.

### ADR-14: 3-posture model (dev/research/prod), not 5 or 2

**Status**: accepted
**Context**: needed a small enum to drive default behaviors at boot.
**Options considered**:
  1. dev/research/prod -- 3 levels; covers internal, pre-prod, prod.
  2. dev/staging/prod -- 3 levels but staging less expressive than research.
  3. dev/test/staging/uat/prod -- too granular; each adds defaults to maintain.
  4. dev/prod only -- too coarse; no place for "real-deps but not customer-data" mode.
**Decision**: dev (permissive) / research (strict, real deps) / prod (strict + harder).
**Rationale**:
  - Three levels cover the four real environments (dev laptop, internal staging, customer-pre-prod, customer-prod).
  - Each level has clear default semantics.
  - Tests can be tagged per-posture.
**Consequences**: every posture-aware default table has 3 columns; every default has 3 values.
**Reversal cost**: medium (tables in every L2 + bootstrap).
**References**: `docs/cross-cutting/posture-model.md`; `agent-platform/bootstrap/ARCHITECTURE.md`.

### ADR-15: Defer multi-framework dispatch (Python sidecar, LangChain4j) to W4+

**Status**: accepted (deferred)
**Context**: cycle-1..8 designed an adapter for cross-framework dispatch
(Python sidecar via gRPC, LangChain4j as alternative bean).
**Options considered**:
  1. Defer until customer demands.
  2. Build now for a hypothetical future customer.
  3. Drop entirely.
**Decision**: defer until W4+; document under transitional_rationale.
**Rationale**:
  - Spring AI covers the v1 customer's needs; no second-framework demand.
  - Sidecar security profile (UDS / SPIFFE / image digest) was a design tax for a feature nobody asked for.
  - When a customer asks, the adapter pattern is well-understood and small.
**Consequences**: legacy `agent-runtime/adapters/` doc carries DEFERRED banner; sidecar-security-profile is in transitional_rationale.
**Reversal cost**: low (adding the adapter later is a clean increment).
**References**: cycle-10 systematic review sec-2.

## 4. Decisions deferred (not yet captured as ADR)

These choices have not yet been made authoritatively; they will become
ADRs when made:

- **D-LATER-01**: pgvector retention strategy when row count > 5M per tenant (Qdrant migration trigger). Decision deferred to W2.
- **D-LATER-02**: Temporal namespace strategy for prod multi-region. Decision deferred to W4+.
- **D-LATER-03**: Cost-attribution boundary -- which costs are platform vs which are customer-owned. Decision deferred to W2 with a finance owner.
- **D-LATER-04**: BYO-LLM-provider customer onboarding contract. Decision deferred to W3+ first customer.
- **D-LATER-05**: SBOM verification at runtime (vs CI-only). Decision deferred to W4 hardening pass.

## 5. Cadence + revision rule

- A new ADR is added whenever a decision affects > 1 L2 doc.
- An existing ADR is **superseded** (status flip + new ADR added)
  when the decision is reversed; original ADR stays in this register
  for traceability.
- ADRs are reviewed at every wave close: any decision whose
  consequences have proven incorrect gets a **superseded** ADR with
  rationale.
- Reversal cost ratings are sanity-checked at each review; if reality
  differs from estimate, the rating updates.

## 6. References

- `ARCHITECTURE.md` (system overview that these decisions implement)
- Each L2 doc cross-references the ADRs that shaped it
- `docs/cross-cutting/oss-bill-of-materials.md` (version pins from ADR-01..04, 09-12)
- `docs/architecture-design-systematic-review-2026-05-09.md` sec-3 (some carry-forward items become ADRs as they close)
