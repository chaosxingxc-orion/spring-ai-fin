# 0008. OPA sidecar for authorization, not in-process Cedar / custom

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** ActionGuard needs a fast, audit-able authorization decision per side effect.

## Context

The ActionGuard component requires a fast, auditable authorization decision for every
agent side effect. The decision engine must support policy-as-code, allow the security
team to own policies independently of the application team, and provide unit-test
capability for policies in isolation.

## Decision Drivers

- Policy-as-code separation: security team owns Rego, application team owns Java.
- OPA bundle distribution and signing is a solved operational problem.
- Local sidecar latency p99 < 5ms is achievable (proven in industry deployments).
- `opa eval` provides unit-test capability for policies without running the full application.

## Considered Options

1. OPA local sidecar with Rego policy bundle in `ops/opa/policies/`.
2. AWS Cedar -- great policy language; not yet a mature Java SDK.
3. Custom Java authorization -- maximum velocity at v1; minimum durability.
4. Spring Security Authorization -- great for HTTP; not granular for capability-level decisions.

## Decision Outcome

**Chosen option:** Option 1 (OPA sidecar with Rego), because it provides the required
policy-as-code separation, proven sub-5ms sidecar latency, and unit-testable policies
while remaining independent of cloud provider lock-in.

### Consequences

**Positive:**
- Security team can change policies without an application deployment.
- `opa eval` enables policy unit tests in CI.
- OPA bundle signing enforces policy integrity.

**Negative:**
- Each application pod requires an OPA sidecar (~50MB additional memory).
- OPA outage in research/prod mode is fail-closed (authorization denied).

### Reversal cost

medium (one decision adapter; Cedar Java SDK could replace if it matures)

## Pros and Cons of Options

### Option 1: OPA sidecar with Rego

- Pro: Policy-as-code separation between security and application teams.
- Pro: `opa eval` enables isolated policy unit tests.
- Pro: OPA bundle distribution and signing is operationally mature.
- Pro: Sidecar latency p99 < 5ms is achievable.
- Con: Each pod carries an OPA sidecar (~50MB memory overhead).
- Con: OPA outage triggers fail-closed behavior in research/prod.

### Option 2: AWS Cedar

- Pro: Expressive, well-specified policy language.
- Con: Java SDK is not yet mature enough for production use.
- Con: Tighter coupling to AWS tooling than desirable for on-prem deployments.

### Option 3: Custom Java authorization

- Pro: No sidecar overhead; maximum control.
- Con: Security team cannot change policies without an application deployment.
- Con: Hard to audit; no standard policy representation.

### Option 4: Spring Security Authorization

- Pro: Native Spring integration; no sidecar.
- Con: Not granular enough for capability-level authorization decisions.
- Con: Policy is embedded in application code; security team cannot own it independently.

## References

- `agent-runtime/action/ARCHITECTURE.md`
- `docs/cross-cutting/deployment-topology.md`

> NOTE 2026-05-12: `agent-runtime/action/ARCHITECTURE.md` moved to `docs/v6-rationale/v6-action.md` in 2026-05-12 Occam pass.
