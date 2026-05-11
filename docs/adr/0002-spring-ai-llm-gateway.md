# 0002. Spring AI 2.0.0-M5 as the LLM gateway, not LangChain4j

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Needed a Java client abstraction for multiple LLM providers with prompt caching, tool calling, and vector store integration.

## Context

The system needs a Java client abstraction for multiple LLM providers that covers
prompt caching, tool calling, and vector store integration. The choice determines
how every agent module connects to language models and how vector search is
implemented for memory L2.

## Decision Drivers

- Spring AI's ChatClient maps directly to the needed role; LangChain4j's chain abstraction would require subsetting it.
- Spring AI's VectorStore + pgvector binding eliminates an entire glue module.
- Spring Boot autoconfiguration reduces wiring boilerplate.
- LangChain4j integration can remain a per-tenant alternative bean if a customer demands it.

## Considered Options

1. Spring AI 2.0.0-M5 -- first-class Spring integration; mature ChatClient + VectorStore.
2. LangChain4j -- richer agent abstractions; less Spring-idiomatic.
3. Custom HTTP wrappers per provider -- maximum control; maximum maintenance burden.

## Decision Outcome

**Chosen option:** Option 1 (Spring AI 2.0.0-M5), because it provides the tightest Spring
Boot integration, covers both LLM gateway and vector store needs with a single
dependency surface, and keeps the reversal cost low through the LlmRouter adapter.

### Consequences

**Positive:**
- One dependency surface for LLM gateway + vector store.
- Autoconfiguration cuts wiring boilerplate significantly.
- ChatClient abstraction is provider-agnostic.

**Negative:**
- Tied to Spring AI's API velocity; M-line and release branches require careful pinning.
- Multi-framework dispatch (LangChain4j) is deferred to W4+ as an optional alternative.

### Reversal cost

medium (LlmRouter is the only adapter; provider beans isolate vendor surface)

## Pros and Cons of Options

### Option 1: Spring AI 2.0.0-M5

- Pro: Native Spring Boot autoconfiguration.
- Pro: VectorStore + pgvector binding eliminates glue module.
- Pro: ChatClient abstraction covers all required LLM providers.
- Con: Tied to Spring AI release cadence and API changes.
- Con: M-line versions require disciplined pinning.

### Option 2: LangChain4j

- Pro: Richer out-of-box agent abstractions.
- Con: Less Spring-idiomatic; requires custom wiring.
- Con: Chain abstraction would need subsetting for this use case.

### Option 3: Custom HTTP wrappers per provider

- Pro: Maximum control over request/response shapes.
- Con: Maximum maintenance burden per provider.
- Con: No shared abstraction; every provider change requires parallel updates.

## References

- `agent-runtime/llm/ARCHITECTURE.md`
- `docs/cross-cutting/oss-bill-of-materials.md` sec-3.1

> NOTE 2026-05-12: `agent-runtime/llm/ARCHITECTURE.md` moved to `docs/v6-rationale/v6-llm.md` in 2026-05-12 Occam pass.
