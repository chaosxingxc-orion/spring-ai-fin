# 0015. Defer multi-framework dispatch (Python sidecar, LangChain4j) to W4+

**Status:** accepted (deferred)
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Cycles 1-8 designed an adapter for cross-framework dispatch (Python sidecar via gRPC, LangChain4j as alternative bean); no customer has demanded it.

## Context

Cycles 1-8 designed a multi-framework dispatch adapter supporting a Python sidecar
via gRPC and LangChain4j as an alternative bean. This introduced a sidecar security
profile (UDS / SPIFFE / image digest) as a design tax on a feature that no customer
has requested. Spring AI covers the v1 customer's needs without any second framework.

## Decision Drivers

- Spring AI covers the v1 customer's needs; no second-framework demand has been received.
- The sidecar security profile (UDS / SPIFFE / image digest) was design tax for an unrequested feature.
- When a customer requests it, the adapter pattern is well-understood and small to implement.
- Deferring avoids shipping and maintaining a capability with no current user.

## Considered Options

1. Defer until a customer demands it; document under transitional_rationale.
2. Build now for a hypothetical future customer.
3. Drop entirely from the roadmap.

## Decision Outcome

**Chosen option:** Option 1 (defer until W4+; document under transitional_rationale), because
Spring AI is sufficient for v1, the sidecar security overhead was unjustified without
a customer request, and the adapter pattern makes a future addition a clean increment.

### Consequences

**Positive:**
- No sidecar security complexity (UDS / SPIFFE / image digest) shipped in v1.
- Existing `agent-runtime/adapters/` doc carries a DEFERRED banner for traceability.
- When a customer requests it, the adapter can be added without redesign.

**Negative:**
- Customers who need Python-sidecar or LangChain4j dispatch must wait for W4+.
- Sidecar security profile design sits in transitional_rationale, not active documentation.

### Reversal cost

low (adding the adapter later is a clean increment)

## Pros and Cons of Options

### Option 1: Defer to W4+

- Pro: No unjustified sidecar security overhead in v1.
- Pro: Team focus remains on v1 customer deliverables.
- Pro: Adapter pattern makes future addition a clean increment when demanded.
- Con: Customers requiring Python or LangChain4j dispatch cannot be served until W4+.

### Option 2: Build now

- Pro: Ready when a customer requests it.
- Con: Ships design tax (UDS / SPIFFE / image digest) with no current user.
- Con: Maintenance burden for untested capability increases defect risk.

### Option 3: Drop entirely

- Pro: Zero future maintenance cost.
- Con: Closes off a future customer requirement that may emerge after v1.
- Con: Re-implementing from scratch would be more costly than deferring cleanly.

## References

- cycle-10 systematic review sec-2
- `agent-runtime/adapters/` (carries DEFERRED banner)
