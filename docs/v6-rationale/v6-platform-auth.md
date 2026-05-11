> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# agent-platform/auth -- L2 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W1 | Maturity: L0 | Reads: JWKS | Writes: --
> Last refreshed: 2026-05-08

## 1. Purpose

JWT validation and security filter chain. Rejects unauthenticated
requests at the edge. Extracts the `tenant_id` claim into a decoded
`Authentication` for downstream filters (`tenant/`).

**Not** a user / role store: identity is delegated to an external OIDC
provider (Keycloak default). This module only validates tokens.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Security | 6.x | `SecurityFilterChain` + JWT decoder |
| Spring Security OAuth2 Resource Server | 6.x | JWKS-based JWT validator |
| Nimbus JOSE+JWT | 9.x (transitive) | RS256 / RS512 / EdDSA |
| Keycloak | 25.x (compose only) | Default IdP for dev / single-tenant prod |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `auth/SecurityConfig.java` | `SecurityFilterChain` bean | 120 |
| `auth/JwtTenantClaimExtractor.java` | parse `tenant_id` claim into `Authentication` | 60 |
| `auth/HmacCarveOutValidator.java` | optional HS256 only when posture allows | 80 |
| `auth/AuthExceptionHandler.java` | 401 / 403 mapping | 50 |

## 4. Public contract

Bearer JWT, RS256/RS512/EdDSA only by default. Required claims: `iss`
(matches configured issuer), `aud` (matches our audience), `sub`,
`tenant_id`, `exp`. JWKS URL discovered via `/.well-known/openid-configuration`.

HS256 (HMAC) is **not allowed** in `research`/`prod` postures except as
an explicit BYOC carve-out (single-tenant private deployment). The
carve-out is gated by `auth.hmac_carveout.enabled=true` and a non-null
`APP_JWT_SECRET` -- both must be set.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| HS256 path | accept w/ warning | reject (unless BYOC carve-out) | reject (unless BYOC carve-out) |
| JWKS cache TTL | 5 min | 1 min | 1 min |
| `aud` claim required | warn-only | reject | reject |
| Clock skew tolerance | 60s | 30s | 30s |

`PostureBootGuard` (in `bootstrap/`) refuses to start if
`research`/`prod` is set but the JWKS URL is missing or the carve-out is
ambiguously configured.

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `RS256HappyPathIT` | Integration | valid token -> 200; tenant_id propagated |
| `JwtAlgorithmRejectionIT` | Integration (research) | HS256 -> 401 unless carve-out |
| `JwtExpiredIT` | Integration | exp in past -> 401 |
| `JwksRotationIT` | Integration | rotated key still validates within cache TTL |
| `HmacCarveOutIT` | Integration | HS256 accepted only when carve-out enabled |
| `MissingTenantClaimIT` | Integration | no `tenant_id` claim -> 401 (research/prod) |

## 7. Out of scope

- User CRUD, password reset, role admin: belongs to the IdP.
- Authorization (capability-level): handled by `agent-runtime/action/`.

## 8. Wave landing

W1 brings the entire module. Posture-specific tests run in W1; budget
the W1 wave to include JWKS rotation handling (otherwise prod ops will
fail).

## 9. Risks

- Keycloak ops complexity: dev runs single-node; prod customers may
  use any OIDC provider (Auth0 / Cognito / Azure AD).
- Algorithm-confusion attacks: validator is constructed from explicit
  algorithm allowlist, not from JWT header.
- HS256 carve-out misuse: gated by two env vars + posture; documented
  in `docs/cross-cutting/security-control-matrix.md`.
