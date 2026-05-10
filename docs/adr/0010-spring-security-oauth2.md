# 0010. Keycloak (OSS) as default IdP, but customer can BYO

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Needed an OIDC IdP for dev and a default for customers without their own identity provider.

## Context

The system needs an OIDC identity provider for the development environment and a
default for customers who do not bring their own. Tier-1 financial customers typically
have an existing IdP (Azure AD, Auth0, or a custom OIDC provider); the system must
accept their JWKS endpoint without requiring Keycloak in production.

## Decision Drivers

- Tier-1 customers usually have an IdP; the system must accept their JWKS.
- Keycloak fills the fallback for dev and small-customer cases.
- OIDC is the contract; Keycloak is one conforming implementation.
- Mandating the customer's IdP creates onboarding friction.

## Considered Options

1. Keycloak as default; OIDC interface for customer's own IdP.
2. Mandate customer's IdP -- onboarding friction; breaks dev environment.
3. Build a tiny IdP -- anti-pattern in finserv; unacceptable liability.

## Decision Outcome

**Chosen option:** Option 1 (Keycloak default; any OIDC-compliant IdP supported), because
the OIDC interface abstracts away the specific provider and Keycloak provides a
self-hostable fallback without mandating any cloud service.

### Consequences

**Positive:**
- Customers with existing IdPs can onboard with minimal friction.
- Keycloak covers dev and small-customer cases.
- OIDC abstraction allows future IdP replacement with no application changes.

**Negative:**
- Realm-import and initial-user provisioning is Keycloak-specific and only applies to the default deployment.
- When a customer brings their own IdP, Keycloak-specific tooling is not available.

### Reversal cost

low (configuration swap)

## Pros and Cons of Options

### Option 1: Keycloak default + OIDC interface for customer IdP

- Pro: OIDC abstraction accepts any conforming IdP (Azure AD, Auth0, custom).
- Pro: Keycloak is self-hostable; no cloud vendor dependency.
- Pro: Low onboarding friction for customers with existing IdPs.
- Con: Realm-import tooling is Keycloak-specific; not portable to customer IdPs.

### Option 2: Mandate customer's IdP

- Pro: No IdP to operate by default.
- Con: Blocks development environment setup and small-customer onboarding.
- Con: Customers without an IdP cannot onboard without procurement overhead.

### Option 3: Build a tiny IdP

- Pro: Maximum control over token shape and claims.
- Con: Identity management is a high-security liability; building it is an anti-pattern in finserv.
- Con: Maintenance burden and audit exposure far exceed the benefit.

## References

- `agent-platform/auth/ARCHITECTURE.md`
- `docs/cross-cutting/deployment-topology.md`
