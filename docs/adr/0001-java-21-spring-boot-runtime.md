# 0001. Java 21 + Spring Boot 4.0.5 as the runtime baseline

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Needed a JVM stack with virtual threads, modern HTTP, and a mature DI / config story for an agent runtime targeting financial-services operators.

## Context

The project requires a JVM stack with virtual threads, modern HTTP support, and a
mature dependency-injection and configuration story for an agent runtime targeting
financial-services operators. The choice of runtime baseline shapes every module
in the system and cannot be changed without a full re-implementation.

## Decision Drivers

- Spring AI is a Java-first project; any other language means writing the LLM client from scratch.
- Customer environments (Tier-1 financial) overwhelmingly run JVM stacks.
- Virtual threads (Project Loom) eliminate the reactive vs blocking debate for IO-heavy workloads.
- Java 21 LTS is supported until 2031, aligning with customer deployment lifetimes.
- Faster onboarding for Java engineers familiar with the Spring ecosystem.

## Considered Options

1. Java 21 + Spring Boot 4.0.5 -- mainstream + virtual threads + Spring AI native.
2. Kotlin + Ktor / Spring Boot -- terser code; fewer libraries pre-built for finserv compliance audits.
3. Go + chi/gin -- great concurrency model but no Spring AI / no Java-ecosystem tooling.

## Decision Outcome

**Chosen option:** Option 1 (Java 21 LTS + Spring Boot 4.0.5), because it is the only stack
that gives first-class Spring AI integration, virtual-thread IO handling, and proven
acceptance in Tier-1 financial customer environments.

### Consequences

**Positive:**
- First-class Spring AI integration with no custom LLM client layer.
- Broad customer-environment compatibility (JVM shops).
- Virtual threads simplify async IO without reactive overhead.
- LTS lifecycle aligns with deployment contracts.

**Negative:**
- Locked into the JVM ecosystem.
- Library churn risk on Spring Boot major bumps.
- Slower onboarding for Python/Go shops.

### Reversal cost

high (would force re-implementation of every glue module)

## Pros and Cons of Options

### Option 1: Java 21 + Spring Boot 4.0.5

- Pro: Native Spring AI integration.
- Pro: Virtual threads (Loom) for IO-heavy agent workloads.
- Pro: JVM familiarity in Tier-1 finserv customer environments.
- Pro: Java 21 LTS supported until 2031.
- Con: JVM ecosystem lock-in.
- Con: Spring Boot major-version upgrade churn.

### Option 2: Kotlin + Ktor / Spring Boot

- Pro: Terser, more expressive code.
- Con: Fewer compliance-audit-ready libraries for financial services.
- Con: Kotlin-specific idioms unfamiliar to many finserv Java teams.

### Option 3: Go + chi/gin

- Pro: Excellent concurrency model with goroutines.
- Con: No Spring AI; LLM client must be built from scratch.
- Con: No Java ecosystem tooling for finserv compliance.

## References

- `ARCHITECTURE.md` sec-2 (OSS matrix)
- `docs/cross-cutting/oss-bill-of-materials.md` sec-4.1
