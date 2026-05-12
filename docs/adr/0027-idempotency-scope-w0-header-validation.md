# 0027. Idempotency Scope at W0: Header Validation Only, Dedup Deferred to W1

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Fourth architecture reviewer (F3) identified that `ARCHITECTURE.md:139-141`
and `agent-platform/ARCHITECTURE.md:38-42` describe `IdempotencyHeaderFilter` as deduplicating
requests, returning cached responses, and handling 409 conflicts — behavior not present in
`IdempotencyHeaderFilter.java:31-60`, which only validates UUID shape and never calls
`IdempotencyStore`. This ADR defines what W0 ships and what is deferred to W1, eliminating
the ambiguity.

## Context

The current `IdempotencyHeaderFilter` does three things at W0:

1. Skips `/actuator` and `/v1/health`.
2. Rejects missing `Idempotency-Key` on all non-exempt methods with 400 in research/prod.
3. Validates that the header value is a valid UUID, rejecting malformed values with 400.

It does NOT:
- Check whether a key has been seen before.
- Return a cached previous response.
- Emit 409 for concurrent duplicate requests.
- Interact with `IdempotencyStore` in any way.

`IdempotencyStore` is a registered `@Component` at W0, but it is never injected into
`IdempotencyHeaderFilter`. The `@Component` annotation was premature; the store is effectively
orphan dead code at W0.

Additionally, the architecture claimed the filter applies to "every POST/PUT/PATCH," but the
actual `shouldNotFilter` predicate only skips `/actuator` and `/v1/health` — it does not restrict
to mutating methods. The filter was applying to GET, DELETE, HEAD, and OPTIONS requests as well,
which should not require an idempotency key. This ADR also corrects the method scope.

## Decision Drivers

- Architecture-text truth: the architecture must describe only what is shipped, not what will
  eventually be shipped.
- Method-scope correctness: idempotency semantics apply to state-mutating HTTP methods. GET,
  HEAD, DELETE, and OPTIONS should not require an `Idempotency-Key` (DELETE is idempotent by
  nature; GET/HEAD are safe; OPTIONS is CORS pre-flight).
- W1 wiring path: the architecture must make clear where the dedup logic will land so W1
  engineers have an accurate baseline.

## Considered Options

1. **Implement dedup now** — wire `IdempotencyStore` into the filter; implement
   claim/replay/409-conflict semantics at W0. Benefit: closes the doc/code gap immediately.
   Cost: requires Postgres schema (`idempotency_dedup` table), transaction management, and
   concurrent-key testing — not in W0 scope.

2. **Narrow the architecture text to match current code** — describe W0 = UUID shape
   validation on POST/PUT/PATCH; describe W1 = full dedup. Remove all dedup language from
   W0-scoped sections.

3. **Delete `IdempotencyHeaderFilter` and ship nothing** — defer entirely to W1. Cost: loses
   the useful 400-on-missing protection, which is already wired and tested.

## Decision Outcome

**Chosen option 2: narrow architecture text; add method-scope restriction to code.**

### W0 contract (shipped)

`IdempotencyHeaderFilter`:
- Applies to POST, PUT, and PATCH methods only. GET, DELETE, HEAD, OPTIONS pass through
  without requiring an `Idempotency-Key`.
- On a mutating request: if header is absent → 400 in research/prod (warning + continue in dev).
  If header is present but not a valid UUID → 400 in all postures.
- Does **not** interact with `IdempotencyStore`.

`IdempotencyStore`:
- `@Component` annotation removed (or `@ConditionalOnProperty` guard added); not injected
  anywhere in W0 production code. Wiring deferred to W1.

### W1 contract (deferred)

`IdempotencyHeaderFilter` will:
1. Claim the `(tenant_id, idempotency_key)` pair via `IdempotencyStore.claimOrFind(tenantId, key)`.
2. If `claimOrFind` returns an existing response (replay) → return cached response immediately.
3. If two concurrent requests race on the same key → first caller proceeds; second returns 409.
4. On request completion → write response body to `idempotency_dedup` table with 24h TTL.

### Method scope correction

`IdempotencyHeaderFilter.shouldNotFilter` currently checks only the path (`/actuator`, `/v1/health`).
After this ADR, it also returns `true` (skip filter) when the HTTP method is not POST, PUT, or PATCH.

### Consequences

**Positive:**
- Architecture text matches code — no more false dedup claims.
- GET/HEAD/DELETE/OPTIONS requests no longer rejected for missing idempotency headers.
- `IdempotencyStore` orphan eliminated from W0 Spring context.

**Negative:**
- A consumer who read the old architecture and expected dedup at W0 will not get it.
  (This is a documentation correction, not a behavior regression — the dedup was never
  implemented.)

### Reversal cost

Low: the W1 dedup implementation can add the store wiring without changing the W0 filter
structure. Method-scope addition is backward-compatible (previously accepted methods still work).

## References

- Fourth-reviewer document: `docs/reviews/2026-05-12-architecture-code-consistency-feedback.en.md` (F3)
- Response document: `docs/reviews/2026-05-12-fourth-reviewer-response.en.md`
- §4 #4 (revised idempotency contract)
- `IdempotencyHeaderFilter.java` (implementation)
- `IdempotencyStore.java` (W1 placeholder)
- `architecture-status.yaml` rows: `idempotency_scope_w0`, `idempotency_store_promotion_to_interface`
