# 0011. Spring Cloud Gateway as ingress, not Kong / Traefik

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Edge gateway needed for routing, rate limiting, and header manipulation using the existing Spring Boot stack.

## Context

The system needs an edge gateway for routing, rate limiting, and header manipulation
in front of the application pods. The choice must balance feature coverage against
operational overhead and familiarity for the team already running the Spring Boot stack.

## Decision Drivers

- Same JVM stack as the application; no new tooling or language required.
- RouteLocator is sufficient for v1's small route count.
- K8s Ingress handles TLS termination and DDoS protection upstream.
- Customer can replace the gateway with Kong if their ops team prefers it.

## Considered Options

1. Spring Cloud Gateway 4.x -- Java-native; same Spring Boot stack.
2. Kong / Traefik -- richer plugin ecosystem; separate operational surface.
3. K8s Ingress Controller alone -- minimum features; no rate limiting or header manipulation.

## Decision Outcome

**Chosen option:** Option 1 (Spring Cloud Gateway 4.x in front of the app pods, deployed in W2),
because it requires no new tooling for the team, RouteLocator covers v1's route count,
and the K8s Service abstraction makes replacement straightforward if needed.

### Consequences

**Positive:**
- No new tooling; the team already knows the Spring stack.
- RouteLocator configuration is familiar and sufficient for v1.
- K8s Service abstraction allows future replacement with Kong or Traefik.

**Negative:**
- Extra network hop adds latency (acceptable per NFR p99).
- Richer Kong/Traefik plugin ecosystem is unavailable without replacement.

### Reversal cost

low (behind K8s Service abstractions)

## Pros and Cons of Options

### Option 1: Spring Cloud Gateway 4.x

- Pro: Same JVM stack; no new tooling or operational surface.
- Pro: RouteLocator configuration covers v1 route count.
- Pro: Easy to replace via K8s Service abstraction.
- Con: Extra network hop versus in-process routing.
- Con: Plugin ecosystem is narrower than Kong or Traefik.

### Option 2: Kong / Traefik

- Pro: Richer plugin ecosystem; more advanced rate limiting options.
- Con: Separate operational surface with different configuration language.
- Con: Adds a new tooling dependency for a team already familiar with Spring.

### Option 3: K8s Ingress Controller alone

- Pro: Minimum infrastructure; TLS and basic routing already covered.
- Con: No rate limiting or header manipulation capability.
- Con: Route-level business logic must move into the application.

## References

- `agent-platform/web/ARCHITECTURE.md`
- `docs/cross-cutting/deployment-topology.md`
