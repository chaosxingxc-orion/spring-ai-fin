> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

> **Pre-refresh design rationale (DEFERRED in 2026-05-08 refresh)**
> MOVED to `agent-platform/auth/ARCHITECTURE.md` in the refresh. Auth is a platform-edge concern; runtime trusts the upstream binding.
> The authoritative L0 is `ARCHITECTURE.md`; the
> systems-engineering plan is `docs/plans/architecture-systems-engineering-plan.md`.
> This file is retained as v6 design rationale and will be
> archived under `docs/v6-rationale/` at W0 close.

# auth -- JWT Validation Primitives (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)
>
> **Origin**: posture-aware identity policy (RS256/ES256 + JWKS for research/SaaS-multi-tenant + prod; HS256 only for dev/loopback or explicit BYOC single-tenant carve-out) per L0 D-block sec-A3 and security review sec-P0-2.

---

## 1. Purpose & Boundary

`auth/` owns the **JWT validation primitives** consumed by `agent-platform/runtime/AuthSeam.java`. The platform validates customer-issued JWTs; we never issue them ourselves.

Owns:

- `JwtValidator` -- posture-aware facade dispatching to HS256 or RS256/ES256 validators
- `HmacValidator` -- HMAC-SHA256 validation (HS256), reads `APP_JWT_SECRET`; permitted only under DEV (loopback) or explicit BYOC single-tenant carve-out
- `JwksValidator` -- RS256 / ES256 validation against the issuer's published JWKS; mandatory for research SaaS multi-tenant + prod
- `IssuerRegistry` -- maps `iss` claim -> JWKS URL -> cached JWK set with TTL + jitter; per-issuer trust isolation
- `JwksCache` -- in-process JWK cache with TTL, ETag-aware refresh, and rotation-tolerant lookup by `kid`
- `AuthClaims` -- record carrying `userId`, `tenantId`, `projectId`, `roles`, `expiry`, `issuer`, `audience`, `keyId`
- `ValidationOutcome` -- sealed type: `Valid(claims)` / `Invalid(reason)`
- `RoleSet` -- typed role enum (operator / sre / compliance / inspector / agent)

Does NOT own:

- JWT issuance (customer's IdP -- Keycloak / Okta / AWS Cognito / etc.)
- Filter integration (delegated to `agent-platform/api/JwtAuthFilter`)
- Authorization decisions (capability-level via `../capability/CapabilityPolicy`)
- OAuth2 flows (deferred; v1 receives JWT from customer's IdP via Bearer header only)

---

## 2. Why "validate, don't issue"

Single trust origin: customer's IdP signs the JWT. The platform validates. This:

1. **Decouples auth lifecycle from platform release**. Customer rotates keys without platform involvement.
2. **Reuses customer's existing identity infrastructure**. No platform-specific user database.
3. **Simplifies regulatory audit**. Customer's IdP IS the regulated identity authority; the platform inherits.

What we require from the JWT:

- Algorithm (per posture, see sec-3): RS256 / ES256 (mandatory for research SaaS multi-tenant + prod) or HS256 (only for DEV loopback or explicit BYOC single-tenant carve-out)
- Required claims: `iss` (issuer), `sub` (userId), `tenantId`, `aud` (audience), `exp`, `nbf`, `iat`, `jti`, `kid` (header -- required for asymmetric)
- Optional claims: `projectId`, `roles`

---

## 3. Posture-aware algorithm policy (D-block sec-A3 alignment)

This package implements the L0 D-block sec-A3 identity policy verbatim. The algorithm permitted at validation time is a function of `(posture, deployment_shape, bind_address)`:

| Posture | Deployment shape | Bind | Permitted algorithms | Notes |
|---|---|---|---|---|
| `dev` | local single-developer | loopback | HS256, anonymous | Fast iteration |
| `dev` | any | non-loopback | none unless `ALLOW_DEV_NON_LOOPBACK_HS256=true` AND `ALLOW_DEV_NON_LOOPBACK=true` | Fail boot otherwise (addresses P0-4 + P0-2 jointly; status: design_accepted) |
| `research` | BYOC, single tenant, customer's existing HS256 IdP | any | HS256 with explicit BYOC carve-out + audit alarm | Q-S1 carve-out; documented per-tenant in `docs/governance/allowlists.yaml` |
| `research` | SaaS, multi-tenant | any | RS256 / ES256 with JWKS (mandatory) | Per-issuer trust isolation enforced by `IssuerRegistry` |
| `prod` | any deployment shape | any | RS256 / ES256 with JWKS (mandatory) | No HS256 path under prod, period |

Hard rules (enforced by `JwtValidator` and `PostureBootGuard` in `../posture/`):

- `alg=none` is rejected at every posture and every deployment shape, always.
- HS / RS confusion is rejected: a JWT header advertising `alg=HS256` against an `IssuerRegistry` entry that publishes RSA keys is an automatic INVALID with `reason="alg_confusion"`.
- `kid` header is required for asymmetric algorithms; absent `kid` -> INVALID.
- `iss`, `aud`, `exp`, `nbf`, `iat`, `jti` are validated for asymmetric algorithms; HS256 short paths allowed in dev/BYOC carve-out only.

---

## 4. JwtValidator (facade)

```java
public class JwtValidator {
    private final HmacValidator hmacValidator;          // active under DEV / BYOC carve-out
    private final JwksValidator jwksValidator;          // active under research SaaS + prod
    private final AppPosture posture;                   // injected; read once at boot
    private final DeploymentShape deploymentShape;      // injected; read once at boot
    private final Clock clock;

    public ValidationOutcome validate(String authorizationHeader) {
        if (!authorizationHeader.startsWith("Bearer ")) {
            if (posture.permitsAnonymous() && deploymentShape.isLoopback()) {
                return ValidationOutcome.valid(AuthClaims.anonymous());
            }
            return ValidationOutcome.invalid("missing Bearer prefix");
        }
        var token = authorizationHeader.substring("Bearer ".length());
        var header = JwsHeader.peek(token);

        if ("none".equalsIgnoreCase(header.alg())) {
            return ValidationOutcome.invalid("alg=none rejected");
        }

        // Posture-aware algorithm dispatch.
        if (header.isAsymmetric()) {
            return jwksValidator.validate(token, header);   // RS256 / ES256
        }
        if (header.isSymmetric()) {                          // HS256
            if (!posture.permitsHmac(deploymentShape)) {
                return ValidationOutcome.invalid("HS256 not permitted under current posture/shape");
            }
            return hmacValidator.validate(token, header);
        }
        return ValidationOutcome.invalid("unsupported alg: " + header.alg());
    }
}
```

---

## 5. JwksValidator + IssuerRegistry (research SaaS + prod default)

```java
public class JwksValidator {
    private final IssuerRegistry issuerRegistry;
    private final JwksCache jwksCache;
    private final Clock clock;

    public ValidationOutcome validate(String token, JwsHeader header) {
        var unverified = parseUnverifiedClaims(token);
        var issuer = unverified.iss();
        if (issuer == null) return ValidationOutcome.invalid("missing iss claim");

        var trustEntry = issuerRegistry.lookup(issuer);
        if (trustEntry == null) return ValidationOutcome.invalid("issuer not trusted: " + issuer);

        // HS / RS confusion check: an asymmetric-key issuer must not accept an HS256 token.
        if (!trustEntry.permitsAlg(header.alg())) {
            return ValidationOutcome.invalid("alg_confusion: " + header.alg() + " for issuer " + issuer);
        }

        var jwk = jwksCache.lookup(issuer, header.kid());
        if (jwk == null) return ValidationOutcome.invalid("kid not found in JWKS: " + header.kid());

        try {
            var claims = verifyAndParse(token, jwk);
            if (claims.expiry().isBefore(clock.instant())) return ValidationOutcome.invalid("expired");
            if (claims.notBefore().isAfter(clock.instant())) return ValidationOutcome.invalid("nbf in future");
            if (!trustEntry.audiences().contains(claims.audience())) {
                return ValidationOutcome.invalid("audience mismatch");
            }
            return ValidationOutcome.valid(claims);
        } catch (Exception e) {
            return ValidationOutcome.invalid(e.getMessage());
        }
    }
}
```

`IssuerRegistry` is configured per deployment via `application-{posture}.yaml`:

```yaml
auth:
  issuers:
    - iss: https://idp.bank-a.example.com/
      jwks_url: https://idp.bank-a.example.com/.well-known/jwks.json
      audiences: [springAiAscend-prod]
      permitted_algs: [RS256, ES256]
    - iss: https://idp.bank-b.example.com/
      jwks_url: https://idp.bank-b.example.com/.well-known/jwks.json
      audiences: [springAiAscend-prod]
      permitted_algs: [RS256]
```

`JwksCache` refresh policy:

- TTL: 10 minutes baseline
- ETag-aware: if upstream returns `304 Not Modified`, extend TTL by 10 min
- Rotation-tolerant: a `kid` not in cache triggers a refresh once per minute (rate-limited) before INVALID is returned

---

## 6. HmacValidator (DEV loopback + BYOC carve-out only)

```java
public class HmacValidator {
    private final byte[] hmacSecret;       // 32-byte minimum; from APP_JWT_SECRET
    private final Clock clock;

    public ValidationOutcome validate(String token, JwsHeader header) {
        // Stdlib HS256 validation: java.util.Base64 + javax.crypto.Mac
        try {
            var claims = parseAndVerify(token, hmacSecret);
            if (claims.expiry().isBefore(clock.instant())) return ValidationOutcome.invalid("expired");
            return ValidationOutcome.valid(claims);
        } catch (Exception e) {
            return ValidationOutcome.invalid(e.getMessage());
        }
    }
}
```

`HmacValidator` is constructed only when `posture.permitsHmac(deploymentShape) == true`. `APP_JWT_SECRET` is asserted >= 32 bytes at boot (Rule 8 boot invariant).

---

## 7. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Posture-aware algorithm policy** | RS256/ES256 + JWKS mandatory for research SaaS + prod; HS256 only for DEV loopback or BYOC single-tenant carve-out | L0 D-block sec-A3; addresses P0-2 (status: design_accepted) |
| **AD-2: Validate, don't issue** | Customer's IdP issues | Decouples auth lifecycle; uses existing infrastructure |
| **AD-3: Stdlib JWT parsing for HS256, signature library for RS/ES** | `java.util.Base64` + `javax.crypto.Mac` for HS256; `nimbus-jose-jwt` (or equivalent) for RS256/ES256 | RS256/ES256 require ASN.1 + algorithm-aware verification that stdlib does not provide; HS256 stays minimal |
| **AD-4: Anonymous claims permitted only in DEV + loopback** | Posture-aware passthrough scoped to loopback bind | Refused under research/prod and under non-loopback DEV unless explicitly opted in via `PostureBootGuard` flags |
| **AD-5: 32-byte minimum HMAC secret** | `validateSecret(secret)` at boot | Mirrors hi-agent's secret-length assertion; prevents weak keys |
| **AD-6: Clock injectable** | Test-friendly time control | Common Java pattern |
| **AD-7: ValidationOutcome sealed** | Type-safe success/failure | Java 17 sealed types; compile-time exhaustive switch |
| **AD-8: Per-issuer trust isolation via IssuerRegistry** | Each `iss` value maps to its own JWKS URL + permitted algs + audiences | Prevents cross-issuer key reuse; SaaS multi-tenant requirement |
| **AD-9: JWKS cache TTL + ETag + rate-limited refresh on miss** | 10-min TTL, ETag-aware extension, <=1/min rotation-driven refresh | Tolerates IdP key rotation without blasting the IdP on every request |
| **AD-10: alg=none and alg-confusion always rejected** | Hard boot rule | Closes well-known JWT pitfalls; never overridable |

---

## 8. Cross-cutting hooks

- **Posture (Rule 11)**: dev permits HS256 + anonymous on loopback only; research SaaS / prod require JWKS validation; research BYOC single-tenant HS256 only with carve-out entry in `docs/governance/allowlists.yaml`
- **Boot guard (`PostureBootGuard` in `../posture/`)**: asserts `APP_JWT_SECRET` >= 32 bytes when HmacValidator is active; asserts at least one `IssuerRegistry` entry when JwksValidator is active
- **Rule 7**: validation failures emit `springAiAscend_jwt_validation_errors_total{reason}` + WARNING (no body of token logged for security); JWKS refresh failures emit `springAiAscend_jwks_refresh_errors_total{issuer, reason}`
- **Rule 8**: ActionGuard does not allow side-effects when `AuthClaims.anonymous()`; the operator-shape gate exercises both HS256 and JWKS paths
- **Audit**: every successful auth emits `springAiAscend_jwt_validations_total{tenant_id, role, alg, issuer}` for visibility

---

## 9. Quality

| Attribute | Target | Verification |
|---|---|---|
| HS256 validation latency | <= 5ms p95 | `tests/integration/JwtValidationLatencyIT` |
| RS256/ES256 validation latency (JWKS cache hit) | <= 8ms p95 | `tests/integration/JwksValidationLatencyIT` |
| Reject expired token | 401 returned | `tests/unit/JwtExpiryTest` |
| Reject malformed | 401 returned with reason | `tests/unit/JwtMalformedTest` |
| Reject `alg=none` | 401 always | `tests/unit/AlgNoneRejectedTest` |
| Reject HS/RS confusion | 401; `reason="alg_confusion"` | `tests/integration/AlgConfusionRejectedIT` |
| Reject weak HMAC secret when HmacValidator is active | boot fails if `APP_JWT_SECRET` < 32 bytes AND `HmacValidator` is on the active validator path (DEV loopback or research BYOC single-tenant carve-out per allowlist). Prod and research SaaS multi-tenant reject HmacValidator activation entirely regardless of secret length, so `APP_JWT_SECRET` is not a prod boot input. | `tests/integration/SecretAssertionIT`, `tests/integration/PostureBootGuardIT` |
| Anonymous in dev loopback only | passthrough on loopback; rejected on non-loopback | `tests/integration/DevPostureAuthIT` |
| JWKS rotation tolerated | rotated `kid` resolves after <=1 refresh | `tests/integration/JwksRotationIT` |
| Per-issuer trust isolation | issuer A's key cannot validate issuer B's token | `tests/integration/IssuerTrustIsolationIT` |

## 10. Risks

- **JWKS endpoint outage**: cached JWK still validates; on extended outage (>2 x TTL), boot-warning + counter; fail-closed behaviour configurable per issuer
- **Token replay**: JWT is short-lived (recommended <= 1h); replay window bounded by expiry; `jti` registered in short-TTL replay cache (research/prod)
- **HMAC secret rotation**: 90-day cadence; rotation requires customer + platform coordinated swap; only relevant for BYOC carve-out or DEV
- **HS / RS confusion in misconfigured customer IdP**: hard reject prevents downgrade; PR-time review on `IssuerRegistry` entries

## 11. References

- L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md) sec-D-block A3 (identity policy)
- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- AuthSeam (consumer): [`../../agent-platform/runtime/ARCHITECTURE.md`](../../agent-platform/runtime/ARCHITECTURE.md)
- Posture boot guard: [`../posture/ARCHITECTURE.md`](../posture/ARCHITECTURE.md)
- Security review sec-P0-2: [`../../docs/deep-architecture-security-assessment-2026-05-07.en.md`](../../docs/deep-architecture-security-assessment-2026-05-07.en.md)
- Response sec-P0-2: [`../../docs/security-response-2026-05-08.md`](../../docs/security-response-2026-05-08.md)
- Systematic-architecture-improvement-plan: [`../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md`](../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md) sec-4.2, sec-4.4
- JWT RFC 7519: https://datatracker.ietf.org/doc/html/rfc7519
- JWKS RFC 7517: https://datatracker.ietf.org/doc/html/rfc7517
