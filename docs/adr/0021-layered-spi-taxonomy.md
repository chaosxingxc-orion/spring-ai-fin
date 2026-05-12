# 0021. Layered SPI Taxonomy: Cross-Tier Core vs Tier-Specific Adapters

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Third architecture reviewer raised Issue 3: the claim "same SPI surface across all tiers" in §4 #9 is unattainable — W0 `NodeFunction` carries inline lambdas; W4 requires named `CapabilityRegistry` references, a type-signature-level change. `Checkpointer.java`'s own javadoc contradicts §4 #9 by stating "W4: not needed." Self-audit surfaced four additional gaps: (HD-C.1) `IdempotencyStore` is a `@Component` class not an interface, violating §4 #7 SPI purity; (HD-C.2) two `IdempotencyRecord` types with divergent constructors; (HD-C.3) `ResilienceContract` tier-specificity unclassified; (HD-C.4) `Run.capabilityName` hardcoded to `"orchestrated"`. This ADR establishes a three-layer SPI taxonomy.

## Context

§4 #9 states: "Durability tiers: in-memory (dev/W0) → Postgres checkpoint (W2) → Temporal child workflow
(W4) — **same SPI surface across all tiers**."

The reviewer's evidence:
- `GraphDefinition(Map<String, NodeFunction>, ...)` at W0 → lambdas are values.
- `GraphDefinition(Map<String, String /∗capabilityName∗/>, ...)` at W4 → lambdas replaced by names.
- These are different Java types. The "same SPI surface" claim is false.

`Checkpointer.java` javadoc also contradicts itself: "W4 posture: not needed — Temporal owns state
durability." If W4 bypasses Checkpointer, the SPI is not "the same across all tiers."

Without a formal taxonomy, engineers cannot answer: "Should this new type go in the cross-tier core or
in a tier-specific adapter?"

## Decision Drivers

- A precise taxonomy enables falsifiable constraints ("this SPI is cross-tier; it must not change shape
  between W0 and W4") vs. "this SPI is tier-internal; it is expected to differ per tier."
- The hidden defects (C.1–C.4) all stem from the same missing taxonomy: no rule to classify SPI members.

## Considered Options

1. **Keep "same SPI surface" claim; address the NodeFunction gap by mandating CapabilityRegistry earlier (W2 not W4)** — doesn't fix the taxonomy problem; still overclaims W4 Checkpointer stability.
2. **Remove the cross-tier claim entirely; each tier has its own SPI** — too destructive; `Run`, `RunStatus`, `RunRepository`, `RunContext` ARE genuinely cross-tier stable.
3. **Three-layer taxonomy; revise §4 #9** (this decision) — precise, falsifiable, forward-compatible.

## Decision Outcome

**Chosen option:** Option 3 — three-layer taxonomy.

### Layer 1 — Cross-tier core SPI (stable W0 → W4)

The same Java signatures across all durability tiers. Any change to these types is a breaking SPI change
requiring a major-version declaration (per ADR-0014 versioning policy).

| Type | Role |
|---|---|
| `Run` record | execution entity |
| `RunStatus` enum | state values |
| `RunMode` enum | execution discriminator |
| `RunRepository` interface | persistence SPI |
| `RunContext` interface | per-run context SPI |
| `Orchestrator` (outer signature) | `Object run(UUID, String, ExecutorDefinition, Object)` |
| `RunLifecycle` interface (W2) | cancel / resume / retry |
| `ResilienceContract` interface | per-operation routing (HD-C.3: classified here, not tier-specific) |

### Layer 2 — Tier-specific execution adapters (shape varies per tier)

`ExecutorDefinition` is a Layer-2 type: its internal shape changes between W0 and W4.

| Tier | `NodeFunction` form | `Reasoner` form |
|---|---|---|
| W0 in-process | inline lambda | inline lambda |
| W2 persistent | lambda MUST be registered in `CapabilityRegistry`; name is the durable identity | same |
| W4 Temporal | symbolic reference (capability name only); lambda absent from the definition | same |

**CapabilityRegistry trigger moves from W4 → W2.** Every `ExecutorDefinition` used with
`PostgresOrchestrator` (W2) MUST resolve `NodeFunction`/`Reasoner` by name through `CapabilityRegistry`.
This prevents a wholesale type-signature migration at W4.

`SuspendSignal` is Layer-2 (its internal shape changes with typed `SuspendReason` at W2).

### Layer 3 — Tier-internal SPIs (each tier may use a different implementation or bypass)

| SPI | W0 | W2 | W4 |
|---|---|---|---|
| `Checkpointer` | `InMemoryCheckpointer` | `PostgresCheckpointer` / `RedisCheckpointer` | **bypassed** — Temporal owns durability |
| `IdempotencyStore` | `NoopIdempotencyStore` (stub) | `PostgresIdempotencyStore` | same |
| `PayloadCodec` (W2+) | absent | `JacksonPayloadCodec` (default) | same |

"Bypassed" means `TemporalOrchestrator` does not call `Checkpointer` — Temporal workflow state is the
durable record. This is NOT "the same SPI surface"; it is an explicit tier-bypass documented here.

### Revised §4 #9 closing clause

**Old**: "same SPI surface across all tiers."

**New**: "Stable cross-tier core (Layer 1: `Run`, `RunStatus`, `RunRepository`, `RunContext`,
`Orchestrator`) + tier-specific execution adapters (Layer 2: `ExecutorDefinition` shape varies
W0→W4; `CapabilityRegistry` integration mandatory from W2) + tier-internal SPIs (Layer 3:
`Checkpointer` bypassed at W4 — Temporal owns durability). See ADR-0021."

### Hidden defect dispositions

- **HD-C.1** (`IdempotencyStore` as `@Component class`): Layer-3 SPI; MUST be promoted to `interface`;
  the W0 no-op becomes `NoopIdempotencyStore implements IdempotencyStore`. Cleanup deferred to W1.
  Tracked as `idempotency_store_promotion_to_interface`.
- **HD-C.2** (dual `IdempotencyRecord`): `platform.idempotency.IdempotencyStore.IdempotencyRecord`
  removed; `runtime.idempotency.IdempotencyRecord` is canonical. Deferred alongside HD-C.1.
- **HD-C.3** (`ResilienceContract`): classified Layer-1 (cross-tier stable). No code change.
- **HD-C.4** (`Run.capabilityName = "orchestrated"` hardcode): Layer-2 leakage; resolved at W2 when
  `CapabilityRegistry.register(...)` returns a canonical `capabilityName`.

### Checkpointer javadoc fix (shipped now)

`Checkpointer.java` javadoc is corrected to match the three-tier taxonomy: W0 in-memory, W2 Postgres,
W4 Temporal-bypassed. See the accompanying `Checkpointer.java` edit.

### Consequences

**Positive:**
- Engineers can classify any new SPI type into Layer 1/2/3 using explicit criteria.
- `CapabilityRegistry` trigger at W2 prevents a large-scale migration at W4.
- W4 Temporal bypass is documented and traceable.

**Negative:**
- HD-C.1/C.2 cleanup deferred to W1; `IdempotencyStore` `@Component` inconsistency persists.
- Layer-2 `ExecutorDefinition` shape change from W2 to W4 is still a breaking change for call sites
  that construct `GraphDefinition` with lambdas directly — CapabilityRegistry adoption in W2 avoids this.

### Reversal cost

Low — editorial revision to §4 #9 and a javadoc fix. CapabilityRegistry trigger move is an additive
constraint (W0 code still works with inline lambdas; W2 enforces naming).

## References

- Third-reviewer document: `docs/reviews/Architectural Perspective Review` (Issue 3)
- Response document: `docs/reviews/2026-05-12-third-reviewer-response.en.md` (Cat-C)
- §4 #9 (revised), §4 #15 (CapabilityRegistry trigger W4 → W2)
- `architecture-status.yaml` rows: `layered_spi_taxonomy`, `idempotency_store_promotion_to_interface`,
  `capability_registry_spi` (trigger updated to W2)
