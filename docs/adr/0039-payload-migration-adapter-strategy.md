# 0039. Payload Migration Adapter Strategy

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Seventh reviewer (P2.2) found no unified migration path for the payload type
transition that three ADRs commit to independently: ADR-0022 changes `NodeFunction` to typed
payload; ADR-0028 changes `ReasoningResult` and `initialContext`. Cluster 6 self-audit surfaced 8
hidden defects around forward-breaking payload changes without a generalised migration pattern.
This ADR names the single normative payload migration path and adapter wrapper requirement.

## Context

Three future-breaking changes accumulate on `AgentLoopDefinition` without a unified migration plan:

1. **Typed payload** (ADR-0022): `NodeFunction.apply(RunContext, Object)` → `apply(RunContext, Payload)`.
2. **CausalPayloadEnvelope** (ADR-0028): `ReasoningResult.payload` (`Object`) → `CausalPayloadEnvelope`.
3. **`initialContext`** (ADR-0028, future): `Map<String, Object>` → `Map<String, CausalPayloadEnvelope>`.

Without a generalised forward-compat pattern, each change would require a breaking migration of all
`NodeFunction` and `Reasoner` implementations simultaneously. This is an unacceptable migration burden.

## Decision Drivers

- Seventh reviewer P2.2: payload migration adapter missing — must name the migration path.
- Hidden defect 6.4: no unified migration for 3 payload-related ADR changes.
- Hidden defect 6.5: `NodeFunction` no `@Deprecated` plan or adapter wrapper.
- Hidden defect 6.6: `Reasoner` same migration risk.
- Hidden defect 6.8: architecture commits to 3 forward-breaking changes without generalised compat pattern.

## Considered Options

1. **Single normative migration path with adapter wrapper** — this decision.
2. **Parallel run of old and new SPI shapes** — doubles the SPI surface; confusion about which to implement.
3. **Big-bang cutover at W2** — forces all NodeFunction/Reasoner impls to migrate simultaneously.

## Decision Outcome

**Chosen option:** Option 1.

### Single normative payload migration path (§4 #36)

```
raw Object (W0 current)
  → Payload (W2 type alias for the intermediate unstructured form)
    → CausalPayloadEnvelope (W3 typed envelope with SemanticOntology tag, ADR-0028)
```

Each step is a non-breaking additive change when the adapter wrapper is used.

### Adapter wrapper requirement

When typed payload lands (W2), a `PayloadAdapter.wrap(Object)` utility is provided:

```java
// Design-only at W0; ships at W2 alongside NodeFunction signature change.
public final class PayloadAdapter {
    /**
     * Wraps a legacy raw Object payload into a Payload type.
     * Callers with typed payloads pass them directly; this is a migration bridge only.
     */
    public static Payload wrap(Object legacyPayload) { ... }

    /**
     * Lifts a Payload into a CausalPayloadEnvelope with FACT semantics.
     * Callers with typed payloads should use CausalPayloadEnvelope.of(...) directly.
     */
    public static CausalPayloadEnvelope lift(Payload payload) { ... }
}
```

Legacy `NodeFunction` implementations that still use `Object` can bridge via:
```java
NodeFunction legacyFn = (ctx, payload) -> myLogic(payload);
NodeFunction bridged = (ctx, payload) -> legacyFn.apply(ctx, PayloadAdapter.wrap(payload));
```

### `@Deprecated` window requirement

At W2 when `NodeFunction.apply(RunContext, Object)` is replaced by `apply(RunContext, Payload)`:
1. The old `Object`-based signature MUST carry `@Deprecated(since = "0.2.0", forRemoval = true)`.
2. A `NodeFunctionAdapter.wrap(LegacyNodeFunction)` bridge MUST be provided.
3. The old signature is removed in the next MAJOR version only (SemVer).

Same pattern applies to `Reasoner.reason(RunContext, Object, int)` and the
`initialContext: Map<String, Object>` field.

### ADR-0022 and ADR-0028 cross-links

Both ADRs are updated to reference ADR-0039 as the normative migration path for their respective
payload changes. Implementors of ADR-0022 and ADR-0028 MUST follow the adapter wrapper pattern
defined here.

### Consequences

**Positive:**
- Existing `NodeFunction` and `Reasoner` implementations do not need to change at W2 — bridge adapter provides a non-breaking migration window.
- The three payload changes now have a unified migration narrative.
- `@Deprecated` window prevents W2 from creating a breaking change in the same release.

**Negative:**
- Two `PayloadAdapter` methods (`wrap`, `lift`) must be maintained for one MAJOR version.
- The three-step migration path is slightly more complex than a direct cutover.

## References

- Seventh reviewer P2.2: `docs/reviews/2026-05-13-l0-architecture-readiness-agent-systems-review.en.md`
- ADR-0022: PayloadCodec SPI (typed payload introduction at W2)
- ADR-0028: CausalPayloadEnvelope and SemanticOntology (W3 typed envelope)
- `ExecutorDefinition.java` — current `NodeFunction` and `Reasoner` with `Object` payloads
- `architecture-status.yaml` row: `payload_migration_adapter`
