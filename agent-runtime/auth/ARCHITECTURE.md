# auth — JWT Validation Primitives (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`auth/` owns the **JWT validation primitives** consumed by `agent-platform/runtime/AuthSeam.java`. The platform validates customer-issued JWTs; we never issue them ourselves.

Owns:

- `JwtValidator` — HMAC-SHA256 validation; reads `APP_JWT_SECRET`
- `AuthClaims` — record carrying `userId`, `tenantId`, `projectId`, `roles`, `expiry`
- `ValidationOutcome` — sealed type: `Valid(claims)` / `Invalid(reason)`
- `RoleSet` — typed role enum (operator / sre / compliance / inspector / agent)

Does NOT own:

- JWT issuance (customer's IdP — Keycloak / Okta / AWS Cognito / etc.)
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

- Algorithm: HMAC-SHA256 (HS256) — symmetric secret shared via secure channel
- Required claims: `sub` (userId), `tenantId`, `exp`
- Optional claims: `projectId`, `roles`, `iss` (issuer)

Future v1.1+ may add RS256 (asymmetric) for IdP integration; v1 keeps it minimal.

---

## 3. JwtValidator

```java
public class JwtValidator {
    private final byte[] hmacSecret;       // 32-byte minimum; from APP_JWT_SECRET
    private final Clock clock;
    private final AppPosture posture;
    
    public ValidationOutcome validate(String authorizationHeader) {
        if (!authorizationHeader.startsWith("Bearer ")) {
            if (posture == DEV) {
                return ValidationOutcome.valid(AuthClaims.anonymous());
            }
            return ValidationOutcome.invalid("missing Bearer prefix");
        }
        var token = authorizationHeader.substring("Bearer ".length());
        try {
            var claims = parseAndVerify(token, hmacSecret);
            if (claims.expiry().isBefore(clock.instant())) {
                return ValidationOutcome.invalid("expired");
            }
            return ValidationOutcome.valid(claims);
        } catch (Exception e) {
            return ValidationOutcome.invalid(e.getMessage());
        }
    }
}
```

`parseAndVerify` uses `java.util.Base64` + `javax.crypto.Mac` — stdlib only. No third-party JWT library at v1 (review later if needed).

---

## 4. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: HMAC-SHA256 only at v1** | Symmetric secret | Simpler than asymmetric; sufficient for v1 |
| **AD-2: Validate, don't issue** | Customer's IdP issues | Decouples auth lifecycle; uses existing infrastructure |
| **AD-3: Stdlib JWT parsing** | `java.util.Base64` + `javax.crypto.Mac` | Avoids JJWT or Auth0 lib dependencies; minimal attack surface |
| **AD-4: Anonymous claims permitted in dev** | Posture-aware passthrough | Accelerates dev work; refused under research/prod |
| **AD-5: Hard 32-byte minimum secret length** | `validateSecret(secret)` at boot | Mirrors hi-agent's secret-length assertion; prevents weak keys |
| **AD-6: Clock injectable** | Test-friendly time control | Common Java pattern |
| **AD-7: ValidationOutcome sealed** | type-safe success/failure | Java 17 sealed types; compile-time exhaustive switch |

---

## 5. Cross-cutting hooks

- **Posture (Rule 11)**: `dev` accepts missing/anonymous; `research`/`prod` fail-closed
- **Rule 7**: validation failures emit `springaifin_jwt_validation_errors_total{reason}` + WARNING (no body of token logged for security)
- **Rule 8**: `APP_JWT_SECRET` 32-byte minimum asserted at boot under research/prod
- **Audit**: every successful auth emits `springaifin_jwt_validations_total{tenant_id, role}` for visibility

---

## 6. Quality

| Attribute | Target | Verification |
|---|---|---|
| Validation latency | ≤ 5ms p95 | `tests/integration/JwtValidationLatencyIT` |
| Reject expired token | 401 returned | `tests/unit/JwtExpiryTest` |
| Reject malformed | 401 returned with reason | `tests/unit/JwtMalformedTest` |
| Reject weak secret at boot | research/prod boot fails if `APP_JWT_SECRET` < 32 bytes | `tests/integration/SecretAssertionIT` |
| Anonymous in dev | passthrough | `tests/integration/DevPostureAuthIT` |

## 7. Risks

- **HS256 vs RS256**: customers using keypair-based IdP may need RS256; tracked as v1.1 enhancement
- **Token replay**: JWT is short-lived (recommended ≤ 1h); replay window bounded by expiry
- **Secret rotation**: 90-day cadence; rotation requires customer + platform coordinated swap

## 8. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- AuthSeam (consumer): [`../../agent-platform/runtime/ARCHITECTURE.md`](../../agent-platform/runtime/ARCHITECTURE.md)
- JWT RFC 7519: https://datatracker.ietf.org/doc/html/rfc7519
