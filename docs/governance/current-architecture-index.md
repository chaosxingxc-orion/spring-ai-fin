# Current Architecture Index

> Per `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-4.en.md` sec-E1
> and `docs/systematic-architecture-remediation-plan-2026-05-09-cycle-9.en.md`
> sec-B2.
>
> This file lists the **single authoritative active architecture
> hierarchy** at the current HEAD. It is mechanically a subset of
> `docs/governance/active-corpus.yaml#active_documents`. Documents
> listed under "Historical Rationale" below are NOT authoritative; they
> are retained for migration context until the W0 deprecation step
> archives them under `docs/v6-rationale/`.

## Authoritative core (read these first)

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) -- L0 platform architecture (continuous v6 line; 2026-05-08 refresh; cycle-9 truth-cut). OSS-first; nine quality attributes; three first-principles.
- [`docs/plans/engineering-plan-W0-W4.md`](../plans/engineering-plan-W0-W4.md) -- the only document that schedules work and defines acceptance.
- [`docs/plans/architecture-systems-engineering-plan.md`](../plans/architecture-systems-engineering-plan.md) -- doc-set drill-down; surviving / deferred mapping.
- [`docs/architecture-design-self-audit.md`](../architecture-design-self-audit.md) -- 240+ dim audit rubric + scoring cadence.
- [`docs/architecture-meta-reflection-2026-05-08.en.md`](../architecture-meta-reflection-2026-05-08.en.md) -- root-cause analysis + 32-dim scoring framework.

## Active hierarchy (refresh authoritative)

### L0 -- System boundary

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md)

### L1 -- Per-package

- [`agent-platform/ARCHITECTURE.md`](../../agent-platform/ARCHITECTURE.md) -- northbound HTTP module (Maturity: L1; HealthEndpointIT + ApiCompatibilityTest GREEN).
- [`agent-runtime/ARCHITECTURE.md`](../../agent-runtime/ARCHITECTURE.md) -- cognitive runtime kernel (Maturity: L0; OssApiProbe shell).

### Capability starters (W0 scaffold; SPI frozen)

- `spring-ai-fin-dependencies/` -- BoM (L1; pins 9 starter coordinates + 13 OSS deps)
- `spring-ai-fin-memory-starter/` -- SPI: LongTermMemoryRepository, GraphMemoryRepository (L0 sentinel)
- `spring-ai-fin-skills-starter/` -- SPI: ToolProvider (L0 sentinel)
- `spring-ai-fin-knowledge-starter/` -- SPI: LayoutParser, DocumentSourceConnector (L0 sentinel)
- `spring-ai-fin-governance-starter/` -- SPI: PolicyEvaluator (L0 sentinel)
- `spring-ai-fin-persistence-starter/` -- SPI: RunRepository, IdempotencyRepository, ArtifactRepository (L0 sentinel)

### Sidecar adapter starters (enabled=false by default; L0)

- `spring-ai-fin-mem0-starter/` -- Mem0 REST adapter for LongTermMemoryRepository
- `spring-ai-fin-graphmemory-starter/` -- Graphiti REST adapter for GraphMemoryRepository
- `spring-ai-fin-docling-starter/` -- Docling REST adapter for LayoutParser
- `spring-ai-fin-langchain4j-profile/` -- LangChain4j alternate framework profile

### Supporting directories

- `third_party/` -- OSS attribution + third-party notices

### L2 -- Per-module (refresh-active only)

#### `agent-platform/` submodules

- [`agent-platform/web/ARCHITECTURE.md`](../../agent-platform/web/ARCHITECTURE.md) -- Spring Web controllers, OpenAPI, exception handling.
- [`agent-platform/auth/ARCHITECTURE.md`](../../agent-platform/auth/ARCHITECTURE.md) -- Spring Security + Keycloak + JWT validation.
- [`agent-platform/tenant/ARCHITECTURE.md`](../../agent-platform/tenant/ARCHITECTURE.md) -- TenantBinder + RLS GUC + assertion trigger.
- [`agent-platform/idempotency/ARCHITECTURE.md`](../../agent-platform/idempotency/ARCHITECTURE.md) -- Idempotency-Key + Postgres dedup.
- [`agent-platform/bootstrap/ARCHITECTURE.md`](../../agent-platform/bootstrap/ARCHITECTURE.md) -- Spring Boot main + PostureBootGuard.
- [`agent-platform/config/ARCHITECTURE.md`](../../agent-platform/config/ARCHITECTURE.md) -- Spring Cloud Config + per-tenant overrides.
- [`agent-platform/contracts/ARCHITECTURE.md`](../../agent-platform/contracts/ARCHITECTURE.md) -- DTO records + OpenAPI surface.

#### `agent-runtime/` submodules

- [`agent-runtime/run/ARCHITECTURE.md`](../../agent-runtime/run/ARCHITECTURE.md) -- run lifecycle + RunController + RunOrchestrator.
- [`agent-runtime/llm/ARCHITECTURE.md`](../../agent-runtime/llm/ARCHITECTURE.md) -- LlmRouter + Spring AI ChatClient + cost telemetry.
- [`agent-runtime/tool/ARCHITECTURE.md`](../../agent-runtime/tool/ARCHITECTURE.md) -- MCP tool registry + per-tenant allowlist.
- [`agent-runtime/action/ARCHITECTURE.md`](../../agent-runtime/action/ARCHITECTURE.md) -- ActionGuard 5-stage chain (Authenticate / Authorize / Bound / Execute / Witness) + audit log.
- [`agent-runtime/memory/ARCHITECTURE.md`](../../agent-runtime/memory/ARCHITECTURE.md) -- L0/L1/L2 tiered memory (Caffeine, Postgres, pgvector).
- [`agent-runtime/outbox/ARCHITECTURE.md`](../../agent-runtime/outbox/ARCHITECTURE.md) -- at-least-once outbox + OutboxPublisher.
- [`agent-runtime/temporal/ARCHITECTURE.md`](../../agent-runtime/temporal/ARCHITECTURE.md) -- durable workflow + activity boundaries.
- [`agent-runtime/observability/ARCHITECTURE.md`](../../agent-runtime/observability/ARCHITECTURE.md) -- custom metrics + cardinality guard + JSON logs.

### Module-level

- [`agent-eval/ARCHITECTURE.md`](../../agent-eval/ARCHITECTURE.md) -- W4 evaluation harness.

### Cross-cutting (single active path each)

- [`docs/cross-cutting/posture-model.md`](../cross-cutting/posture-model.md) -- dev/research/prod posture semantics.
- [`docs/cross-cutting/security-control-matrix.md`](../cross-cutting/security-control-matrix.md) -- per-control owner / posture / test (5-stage ActionGuard).
- [`docs/cross-cutting/trust-boundary-diagram.md`](../cross-cutting/trust-boundary-diagram.md) -- TB-1..TB-4 boundaries.
- [`docs/cross-cutting/secrets-lifecycle.md`](../cross-cutting/secrets-lifecycle.md) -- Vault paths + rotation cadence.
- [`docs/cross-cutting/supply-chain-controls.md`](../cross-cutting/supply-chain-controls.md) -- image digest + SBOM + Dependabot.
- [`docs/cross-cutting/observability-policy.md`](../cross-cutting/observability-policy.md) -- cardinality budget + label scheme + sample rates.
- [`docs/cross-cutting/non-functional-requirements.md`](../cross-cutting/non-functional-requirements.md) -- latency, throughput, availability, durability, cost, capacity SLOs per posture.
- [`docs/cross-cutting/threat-model.md`](../cross-cutting/threat-model.md) -- STRIDE per trust boundary + cross-cutting threats.
- [`docs/cross-cutting/api-conventions.md`](../cross-cutting/api-conventions.md) -- REST surface conventions: error codes, pagination, versioning, RFC-7807.
- [`docs/cross-cutting/data-model-conventions.md`](../cross-cutting/data-model-conventions.md) -- naming, IDs (UUIDv7), timestamps, RLS, schema spine, Java type ownership.
- [`docs/cross-cutting/deployment-topology.md`](../cross-cutting/deployment-topology.md) -- per-posture topology, replicas, HA / DR, rollout, capacity / cost.
- [`docs/cross-cutting/failure-modes-catalog.md`](../cross-cutting/failure-modes-catalog.md) -- per-module runtime failure modes + observability.
- [`docs/cross-cutting/oss-bill-of-materials.md`](../cross-cutting/oss-bill-of-materials.md) -- exact OSS version pins + U0..U4 verification ladder + per-dep API surface + integration contract.
- [`docs/cross-cutting/interaction-sequences.md`](../cross-cutting/interaction-sequences.md) -- end-to-end sequence diagrams (happy path + 3 failure paths + Temporal long-run + idempotent retry).
- [`docs/cross-cutting/v1-customer-profile.md`](../cross-cutting/v1-customer-profile.md) -- reference Tier-1 financial-services customer profile anchoring NFR numbers.
- [`docs/cross-cutting/design-decisions.md`](../cross-cutting/design-decisions.md) -- ADR-style register of 15 major architectural decisions + 5 deferred.

## Governance corpus

- [`docs/governance/architecture-status.yaml`](architecture-status.yaml) -- capability + finding ledger.
- [`docs/governance/decision-sync-matrix.md`](decision-sync-matrix.md) -- L0 -> L1 -> L2 sync per hard decision.
- [`docs/governance/closure-taxonomy.md`](closure-taxonomy.md) -- status enum + forbidden-shortcut list.
- [`docs/governance/maturity-glossary.md`](maturity-glossary.md) -- Rule 12 L0..L4 ladder.
- [`docs/governance/allowlists.yaml`](allowlists.yaml) -- HMAC carve-outs, dev opt-ins.
- [`docs/governance/active-corpus.yaml`](active-corpus.yaml) -- the registry; cycle-9 split into 3 sections.
- [`docs/governance/evidence-manifest.yaml`](evidence-manifest.yaml) -- delivery evidence pointers + dependency mode + Rule 8 eligibility.
- [`docs/governance/current-architecture-index.md`](current-architecture-index.md) -- this file.

## Plans + audit

- [`docs/plans/engineering-plan-W0-W4.md`](../plans/engineering-plan-W0-W4.md)
- [`docs/plans/architecture-systems-engineering-plan.md`](../plans/architecture-systems-engineering-plan.md)
- [`docs/architecture-design-self-audit.md`](../architecture-design-self-audit.md)

## Gates

- `gate/check_architecture_sync.{ps1,sh}` -- architecture-sync gate (cycle-8-evidence-graph-v3 + cycle-9 truth-cut + cycle-14 ci_no_or_true_mask + rule_8_state_machine_coherent + local_only_log_path_enforced rules).
- `gate/run_operator_shape_smoke.{ps1,sh}` -- Rule 8 operator-shape smoke gate (fail-closed; FAIL_NEEDS_BUILD state; NOT in CI until W0 acceptance).
- `gate/test_architecture_sync_gate.sh` -- self-test harness (cycle-14: added local-only evidence-validity fixture).
- [`gate/README.md`](../../gate/README.md)

## Delivery evidence

- [`docs/delivery/README.md`](../delivery/README.md) -- delivery rules.
- [`docs/delivery/2026-05-11-a7756cd.md`](../delivery/2026-05-11-a7756cd.md) -- cycle-18 Phase 0: Maven build unblocked; Spring Boot 4.x API compatibility (authoritative).
- [`docs/delivery/2026-05-10-8505f7d.md`](../delivery/2026-05-10-8505f7d.md) -- cycle-15/16 defect closure: SPI Rule 11 spine, posture fail-fast, doc refresh, ledger sync, ASCII gate fixes (superseded -- see 2026-05-11-a7756cd.md).
- [`docs/delivery/2026-05-10-ae60414.md`](../delivery/2026-05-10-ae60414.md) -- cycle-15/16 architecture-review-readiness pass T-AR-11..T-AR-13 (historical -- was on detached branch fix/cycle-15-defect-closure, never merged; superseded by 2026-05-11-a7756cd.md).
- [`docs/delivery/2026-05-10-97b0827.md`](../delivery/2026-05-10-97b0827.md) -- cycle-15/16 interim delivery (superseded by 8505f7d delivery; see 2026-05-11-a7756cd.md for current authoritative).
- [`docs/delivery/2026-05-10-68c07f1.md`](../delivery/2026-05-10-68c07f1.md) -- W0: milestone gate grep-P locale fix; build_verification.state: green.
- [`docs/delivery/2026-05-10-ec8daca.md`](../delivery/2026-05-10-ec8daca.md) -- W0: Steps 9-12 finishing work (BoM starters + SPI freeze + milestone gate + dev docs); build_verification.state: green.
- [`docs/delivery/2026-05-10-18d637e.md`](../delivery/2026-05-10-18d637e.md) -- W0: Maven Wrapper + Boot 4.0.5 / AI 2.0.0-M5 upgrade + OSS BoM U2 (verified at cd13612) + Tier C manifest (16 entries); build_verification.state: green.
- [`docs/delivery/2026-05-09-c863c2b.md`](../delivery/2026-05-09-c863c2b.md) -- cycle-14 (A1+A2+B1+B2+C1+C2+D1+D2+E1; ASCII fix; two new gate rules; build_verification.state: pending_ci).
- [`docs/delivery/2026-05-08-f98dbae.md`](../delivery/2026-05-08-f98dbae.md) -- cycle-13 Phase B step 1.
- [`docs/delivery/2026-05-08-71b77c6.md`](../delivery/2026-05-08-71b77c6.md) -- cycle-12 Phase A close.
- [`docs/delivery/2026-05-08-2a29eb5.md`](../delivery/2026-05-08-2a29eb5.md) -- cycle-11 OSS BoM + verification ladder.
- [`docs/delivery/2026-05-08-7b1fa8c.md`](../delivery/2026-05-08-7b1fa8c.md) -- cycle-10 self-driven systematic review.
- [`docs/delivery/2026-05-08-e9a692d.md`](../delivery/2026-05-08-e9a692d.md) -- cycle-9 truth-cut evidence.
- [`docs/delivery/2026-05-08-4260a48.md`](../delivery/2026-05-08-4260a48.md) -- 2026-05-08 architecture refresh evidence.
- [`docs/delivery/2026-05-08-cc2e1e3.md`](../delivery/2026-05-08-cc2e1e3.md) -- cycle-8 evidence-graph-v3 evidence.
- (Earlier deliveries are listed under "Historical Rationale" below for traceability.)

Per cycle-3 SHA-current rule, a delivery file is evidence for its named
SHA only -- not for any later SHA, even doc-only commits. The cycle-7+
manifest-enforced two-SHA model accepts an audit-trail-shaped descendant
of the reviewed content SHA.

## Capability maturity (cycle-9 sec-E1: lead with maturity, not percentage)

W0 scaffold landed at commit `97b0827`. Current maturity per capability:

- `agent_platform_facade`: **L1** -- `HealthEndpointIT` + `ApiCompatibilityTest` GREEN
- `spi_compatibility_freeze`: **L1** -- ArchUnit 4 rules GREEN
- `spring_ai_fin_dependencies_bom`: **L1** -- BoM resolves all 9 starters
- `spring_ai_fin_*_starter` (5 core + 4 sidecar): **L0** -- sentinel impls; W1 lands real impls
- All other capabilities from the 2026-05-08 architecture refresh: **L0** (design accepted)

Promotion L0 -> L1 requires code + Rule 4 three-layer tests (per `docs/plans/engineering-plan-W0-W4.md` acceptance gates per wave). Promotion L1 -> L2 requires a stable public contract + snapshot test. L3 requires posture-aware default-on + operator-shape gate PASS. L4 requires third-party extension evidence.

Real readiness is measured by the 32-dim scoring framework (`docs/architecture-meta-reflection-2026-05-08.en.md`); W0 scaffold moved the score from ~0/32 to ~5/32 (R1/R2/R4/R5 partial).

## Historical Rationale (NOT authoritative)

The documents below are NOT part of the active architecture. They are
retained for migration context (transitional) or traceability
(historical). Do not implement against any of them. They are scoped by
`docs/governance/active-corpus.yaml#transitional_rationale` and
`#historical_documents` respectively. The W0 deprecation step archives
them under `docs/v6-rationale/`.

### Pre-refresh L2 docs (cycles 1..8 corpus; transitional)

- `agent-platform/{api, runtime, facade, cli}/ARCHITECTURE.md`
- `agent-runtime/{server, runner, runtime, skill, capability, knowledge, adapters, audit, evolve, posture, auth, action-guard}/ARCHITECTURE.md`

Each carries a "Pre-refresh design rationale (DEFERRED IN refresh)" banner with its disposition (RENAMED / MERGED / DEFERRED).

### Pre-refresh cross-cutting (transitional with MOVED banner)

- `docs/security-control-matrix.md` -> `docs/cross-cutting/security-control-matrix.md`
- `docs/trust-boundary-diagram.md` -> `docs/cross-cutting/trust-boundary-diagram.md`
- `docs/secrets-lifecycle.md` -> `docs/cross-cutting/secrets-lifecycle.md`
- `docs/supply-chain-controls.md` -> `docs/cross-cutting/supply-chain-controls.md`
- `docs/observability/cardinality-policy.md` -> `docs/cross-cutting/observability-policy.md`
- `docs/sidecar-security-profile.md` (deferred until Python sidecar lands; W4+)
- `docs/gateway-conformance-profile.md` (deferred; W2 if Spring Cloud Gateway needs advanced features)

### Pre-refresh plans (transitional)

- `docs/plans/W0-evidence-skeleton.md` -> `docs/plans/engineering-plan-W0-W4.md`
- `docs/plans/roadmap-W0-W4.md` -> `docs/plans/engineering-plan-W0-W4.md`

### Earlier delivery evidence (for traceability)

- `docs/delivery/2026-05-08-7025ac9.md` (cycle-1+2)
- `docs/delivery/2026-05-08-003ed6f.md` (cycle-3)
- `docs/delivery/2026-05-08-a070a77.md` (cycle-4)
- `docs/delivery/2026-05-08-302337f.md` (cycle-5)
- `docs/delivery/2026-05-08-81ff802.md` (cycle-6)
- `docs/delivery/2026-05-08-ba4bcd5.md` (cycle-7)
- `docs/delivery/2026-05-08-d284232.md` (older)

### Banner-marked archives

- `docs/architecture-v5.0.md` (deleted; canonical is `ARCHITECTURE.md`), `docs/architecture-v5.0-review-2026-05-07.md`
- `docs/architecture-review-2026-05-07.md`
- `docs/deep-architecture-security-assessment-2026-05-07.en.md`
- `docs/security-response-2026-05-08.md`
- 10 review-cycle inputs (`docs/systematic-architecture-*-cycle-*.en.md`, etc.)
- `docs/architecture-meta-reflection-2026-05-08.en.md`
- `docs/systematic-architecture-remediation-cycle-8-response.en.md`
- `docs/systematic-architecture-remediation-cycle-9-response.en.md`

## Rule for future updates

When a new authoritative L2 lands or a current document is superseded,
update this index in the same PR. The architecture-sync gate's
`active_corpus_no_disposition_in_active` rule (cycle-9 sec-A1) +
`index_active_subset` rule (cycle-9 sec-B2) enforce that the active
hierarchy is a strict subset of `active-corpus.yaml#active_documents`
and that no disposition marker leaks into active state.
