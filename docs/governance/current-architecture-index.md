# Current Architecture Index

> Per `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-4.en.md` sec-E1.
> This file is the single index of **authoritative** design and governance documents at the current HEAD. Anything not listed here is either historical (banner-marked) or supplementary.

## Hierarchy

### L0 -- System boundary

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) -- platform purpose, scope, decisions, quality, risks across the whole system.

### L1 -- Per-package

- [`agent-platform/ARCHITECTURE.md`](../../agent-platform/ARCHITECTURE.md) -- northbound HTTP facade.
- [`agent-runtime/ARCHITECTURE.md`](../../agent-runtime/ARCHITECTURE.md) -- cognitive runtime kernel.

### L2 -- Per-subsystem (current)

#### `agent-platform/` subsystems

- [`agent-platform/contracts/ARCHITECTURE.md`](../../agent-platform/contracts/ARCHITECTURE.md) -- frozen v1 schema; ContractError record + ContractException class split.
- [`agent-platform/api/ARCHITECTURE.md`](../../agent-platform/api/ARCHITECTURE.md) -- Spring Web routes + filter chain.
- [`agent-platform/runtime/ARCHITECTURE.md`](../../agent-platform/runtime/ARCHITECTURE.md) -- `RealKernelBackend` kernel binding.
- [`agent-platform/facade/ARCHITECTURE.md`](../../agent-platform/facade/ARCHITECTURE.md) -- adaptation between contracts and runtime.
- [`agent-platform/bootstrap/ARCHITECTURE.md`](../../agent-platform/bootstrap/ARCHITECTURE.md) -- `PlatformBootstrap`, posture-aware boot invariants.
- [`agent-platform/cli/ARCHITECTURE.md`](../../agent-platform/cli/ARCHITECTURE.md) -- `ServeCommand` and friends.
- [`agent-platform/config/ARCHITECTURE.md`](../../agent-platform/config/ARCHITECTURE.md) -- minimal v1 settings; HMAC carve-out only when active.

#### `agent-runtime/` subsystems

- [`agent-runtime/server/ARCHITECTURE.md`](../../agent-runtime/server/ARCHITECTURE.md) -- `RunManager`, `DurableBackends`, `TenantBinder`, RLS connection protocol (transaction-scoped `SET LOCAL`).
- [`agent-runtime/runner/ARCHITECTURE.md`](../../agent-runtime/runner/ARCHITECTURE.md) -- TRACE S1-S5 RunExecutor.
- [`agent-runtime/llm/ARCHITECTURE.md`](../../agent-runtime/llm/ARCHITECTURE.md) -- LLM gateway + prompt-section + taint propagation.
- [`agent-runtime/skill/ARCHITECTURE.md`](../../agent-runtime/skill/ARCHITECTURE.md) -- MCP tools + Spring AI Advisors (load-time hygiene only; runtime is ActionGuard).
- [`agent-runtime/capability/ARCHITECTURE.md`](../../agent-runtime/capability/ARCHITECTURE.md) -- capability registry; CapabilityInvoker is internal to ActionGuard Stage 10.
- [`agent-runtime/memory/ARCHITECTURE.md`](../../agent-runtime/memory/ARCHITECTURE.md) -- L0-L3 memory.
- [`agent-runtime/knowledge/ARCHITECTURE.md`](../../agent-runtime/knowledge/ARCHITECTURE.md) -- JSONB glossary + 4-layer retrieval.
- [`agent-runtime/adapters/ARCHITECTURE.md`](../../agent-runtime/adapters/ARCHITECTURE.md) -- multi-framework dispatch + sidecar security binding.
- [`agent-runtime/observability/ARCHITECTURE.md`](../../agent-runtime/observability/ARCHITECTURE.md) -- spine + cardinality budget + emitter failure counter.
- [`agent-runtime/outbox/ARCHITECTURE.md`](../../agent-runtime/outbox/ARCHITECTURE.md) -- three-path write taxonomy + `FinancialWriteClass`.
- [`agent-runtime/posture/ARCHITECTURE.md`](../../agent-runtime/posture/ARCHITECTURE.md) -- `AppPosture` + `PostureBootGuard`.
- [`agent-runtime/auth/ARCHITECTURE.md`](../../agent-runtime/auth/ARCHITECTURE.md) -- JWT primitives (RS256/JWKS + HS256 carve-out).
- [`agent-runtime/action-guard/ARCHITECTURE.md`](../../agent-runtime/action-guard/ARCHITECTURE.md) -- 11-stage authorization pipeline.
- [`agent-runtime/audit/ARCHITECTURE.md`](../../agent-runtime/audit/ARCHITECTURE.md) -- 5-class audit model + WORM anchor.
- [`agent-runtime/evolve/ARCHITECTURE.md`](../../agent-runtime/evolve/ARCHITECTURE.md) -- skill / asset evolution.
- [`agent-runtime/runtime/ARCHITECTURE.md`](../../agent-runtime/runtime/ARCHITECTURE.md) -- Reactor scheduler + harness.

## Governance corpus

- [`docs/governance/architecture-status.yaml`](architecture-status.yaml) -- **the** capability + finding ledger.
- [`docs/governance/decision-sync-matrix.md`](decision-sync-matrix.md) -- L0 -> L1 -> L2 sync per hard decision.
- [`docs/governance/closure-taxonomy.md`](closure-taxonomy.md) -- status enum and forbidden-shortcut taxonomy.
- [`docs/governance/maturity-glossary.md`](maturity-glossary.md) -- Rule 12 L0..L4 ladder.
- [`docs/governance/allowlists.yaml`](allowlists.yaml) -- HMAC carve-outs, dev opt-ins, expiry waves.
- [`docs/governance/current-architecture-index.md`](current-architecture-index.md) -- this file.

## Cross-cutting current docs

- [`docs/security-control-matrix.md`](../security-control-matrix.md) -- controls per `Owner / Enforcement / Posture / Test / Evidence / Failure mode` rows; aligned with cycle-2 server RLS L2 + cycle-3 matrix correction.
- [`docs/trust-boundary-diagram.md`](../trust-boundary-diagram.md) -- ActionGuard 11-stage trust boundaries; transaction-scoped `SET LOCAL` propagation.
- [`docs/sidecar-security-profile.md`](../sidecar-security-profile.md) -- UDS / SPIFFE / image digest; consumed by `agent-runtime/adapters/`.
- [`docs/gateway-conformance-profile.md`](../gateway-conformance-profile.md) -- north-south gateway requirements.
- [`docs/secrets-lifecycle.md`](../secrets-lifecycle.md) -- secrets rotation cadence.
- [`docs/supply-chain-controls.md`](../supply-chain-controls.md) -- image digest pin + SBOM.
- [`docs/observability/cardinality-policy.md`](../observability/cardinality-policy.md) -- raw `tenant_id` label budget registry.

## Plans

- [`docs/plans/W0-evidence-skeleton.md`](../plans/W0-evidence-skeleton.md) -- first runnable wave.
- [`docs/plans/roadmap-W0-W4.md`](../plans/roadmap-W0-W4.md) -- wave plan to v1.

## Gates

- `gate/check_architecture_sync.{ps1,sh}` -- architecture-sync gate (current; cycle-3-expanded with cycle-4 LC_ALL/scope/output-path fixes).
- `gate/run_operator_shape_smoke.{ps1,sh}` -- Rule 8 operator-shape smoke gate (fail-closed pre-W0; produces real evidence after W0 lands).
- [`gate/README.md`](../../gate/README.md) -- gate categories and usage.

## Delivery evidence (current)

- [`docs/delivery/README.md`](../delivery/README.md) -- delivery-file rules (clean tree, evidence_valid_for_delivery, SHA-current, architecture-sync vs Rule 8 classification).
- [`docs/delivery/2026-05-08-7025ac9.md`](../delivery/2026-05-08-7025ac9.md) -- cycle-1+2 first delivery-valid architecture-sync evidence at SHA `7025ac9`.
- [`docs/delivery/2026-05-08-003ed6f.md`](../delivery/2026-05-08-003ed6f.md) -- cycle-3 architecture-sync evidence at SHA `003ed6f`.
- [`docs/delivery/2026-05-08-a070a77.md`](../delivery/2026-05-08-a070a77.md) -- cycle-4 architecture-sync evidence at SHA `a070a77`.
- [`docs/delivery/2026-05-08-302337f.md`](../delivery/2026-05-08-302337f.md) -- cycle-5 architecture-sync evidence at SHA `302337f`.
- [`docs/delivery/2026-05-08-81ff802.md`](../delivery/2026-05-08-81ff802.md) -- cycle-6 architecture-sync evidence at SHA `81ff802`.
- [`docs/delivery/2026-05-08-ba4bcd5.md`](../delivery/2026-05-08-ba4bcd5.md) -- cycle-7 architecture-sync evidence at SHA `ba4bcd5` (current authoritative delivery; gate parity + two-SHA model + ASCII governance + self-test).
- Per cycle-3 SHA-current rule, a delivery file is evidence for its named SHA only -- not for any later SHA, even doc-only commits. The cycle-6 + cycle-7 manifest-enforced two-SHA model (REM-2026-05-08-C7-3) accepts an audit-trail-shaped descendant of the reviewed content SHA.
- The authoritative current-evidence pointer is `docs/governance/evidence-manifest.yaml#reviewed_sha` (cycle-5 F1 + cycle-6 A2). When the manifest's `reviewed_sha` differs from the latest delivery file listed above, the manifest wins and this list is regenerated in the next cycle.

## Historical / superseded (NOT authoritative)

These files describe earlier design positions and are kept for traceability. They fall into two classes:

### Banner-marked (cycle-4 sec-E1)

These files carry a "HISTORICAL DOCUMENT -- DO NOT IMPLEMENT" banner at the top:

- `docs/architecture-v5.0.md`
- `docs/architecture-v5.0-review-2026-05-07.md`
- `docs/architecture-review-2026-05-07.md`
- `docs/deep-architecture-security-assessment-2026-05-07.en.md`
- `docs/security-response-2026-05-08.md`

### Quarantined by gate path-skip (review/remediation cycle inputs)

These files are quarantined by the architecture-sync gate's path-skip list (matching `*systematic-architecture-improvement-plan*` or `*systematic-architecture-remediation-plan*`); they are NOT banner-marked because they are reviewer inputs to specific remediation cycles rather than superseded design documents:

- `docs/systematic-architecture-improvement-plan-2026-05-07.en.md`
- `docs/systematic-architecture-remediation-plan-2026-05-08.en.md`
- `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-2.en.md`
- `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-3.en.md`
- `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-4.en.md`
- `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-5.en.md`

Both classes are excluded from the gate's closure-language and `rls_reset_vocabulary` checks because they legitimately discuss the forbidden phrases in the context of either historical record (banner-marked) or review prose (path-skipped).

## Rule for future updates

When a new authoritative L2 lands or a current document is superseded, update this index in the same PR. The architecture-sync gate's `current_architecture_index_freshness` rule (W2 deliverable) will fail if a superseded file is referenced as authoritative or if a new authoritative file is missing from this index.
