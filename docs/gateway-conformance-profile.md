# Gateway Security Conformance Profile

**Status**: v1 -- created 2026-05-08 in response to security review sec-P0-9
**Owner**: Platform team (GOV) + Customer infrastructure team
**Companion**: [`security-control-matrix.md`](security-control-matrix.md) sec-10

This profile defines the **deployment-time security requirements** that the north-south gateway must implement. spring-ai-fin is gateway-agnostic by design (Higress recommended, but customers may substitute), so the security guarantee is enforced at deployment via this profile.

---

## 1. Why a conformance profile

The architecture's `/v1/*` filter chain assumes the gateway has already done several controls. If the gateway substitute (AWS API Gateway, Apigee, Nginx, internal gateway) silently drops one, the platform still depends on the missing control. This profile makes the dependency explicit and **machine-verifiable**.

The platform's `/ready` endpoint refuses `prod` readiness unless either:
- (a) Gateway conformance evidence is present (signed conformance attestation file at known location), OR
- (b) Built-in equivalent controls are enabled (Spring filter fallback at the cost of duplication)

---

## 2. Required controls

### 2.1 Authentication

- **JWT/OAuth2 verification** at edge. The gateway must:
  - Verify signature (RS256/ES256/JWKS for production; HS256 only with explicit BYOC carve-out)
  - Verify `exp`, `nbf`, `iat`
  - Verify `iss` against per-tenant allowlist
  - Verify `aud` matches platform audience
  - Reject `alg=none`
  - Reject HS/RS algorithm confusion
- Pass validated claims as forwarded headers (`X-User-Id`, `X-Tenant-Id`, `X-Roles`)
- **mTLS support** (optional but supported)

### 2.2 Header normalization

- **Strip client-supplied** `X-Tenant-Id`, `X-Internal-Trust`, `X-Auth-*` from incoming requests
- **Re-inject** `X-Tenant-Id` from validated JWT claim only (closes spoofing -- Attack Path C variant)
- **Sign** internal trust header `X-Internal-Trust: <gateway-id>:<HMAC>` so the platform can verify the request originated from the gateway, not via direct connection

### 2.3 Rate limiting

- Per-tenant rate limit (configurable; default 1000 req/min per tenant)
- Per-user rate limit (default 60 req/min per user)
- Per-capability rate limit (configurable; e.g., PII decode = 10/hour/user)
- 429 response with `Retry-After` header on exceedance

### 2.4 Body & SSE limits

- Request body max size: 8MB default (configurable)
- SSE concurrent connections per tenant: 100 default
- SSE timeout: 1h max

### 2.5 OPA red-line policies

- Pre-platform OPA decision hook for "absolute deny" rules:
  - Block known-malicious IP ranges
  - Block known-bad user agents
  - Block requests violating regulatory rules (e.g., cross-border data flow per OJK)
- Each OPA decision recorded with `policy_decision_id` for audit

### 2.6 Operator endpoint protection

- IP allowlist for `/diagnostics`, `/actuator/*` endpoints
- Default: deny external; allow only operator subnet
- mTLS required for non-loopback access to operator endpoints

### 2.7 Structured access logs

- Format: JSON
- Required fields: `timestamp, tenant_id, user_id, route, method, status, latency_ms, body_size, response_size, request_id, trace_id`
- Retention: 90 days hot + 7 years cold (compliance)

---

## 3. Verification

### 3.1 At deployment

The customer's deployment automation (Terraform / Helm / Ansible) must produce a **conformance attestation file** at a known path (`/var/run/spring-ai-fin/gateway-conformance.json`) containing:

```json
{
  "gateway_type": "higress" | "aws-apigateway" | "apigee" | "nginx" | "custom",
  "gateway_version": "1.4.0",
  "attested_at": "2026-08-15T10:00:00Z",
  "attested_by": "infra-team@bank-a.com",
  "controls": {
    "jwt_verification": "rs256_jwks",
    "mtls_supported": true,
    "header_normalization": true,
    "rate_limit_tenant": 1000,
    "rate_limit_user": 60,
    "body_size_max_mb": 8,
    "sse_concurrent_per_tenant_max": 100,
    "opa_redline_enabled": true,
    "operator_endpoints_ip_allowlist": ["10.0.0.0/8"],
    "access_log_format": "json",
    "access_log_retention_days": 2555
  },
  "signature": "<HMAC of above using GATEWAY_ATTESTATION_SECRET>"
}
```

### 3.2 At runtime

- Platform's `ReadinessController` reads attestation file at boot
- Verifies HMAC signature against `GATEWAY_ATTESTATION_SECRET` (rotated 90-day)
- Verifies `attested_at` not older than 30 days
- Verifies all `controls` fields meet minimum requirements
- If verification passes: `/ready` returns `gateway_conformance: PASS`
- If fails: `/ready` returns `gateway_conformance: FAIL`; `current_verified_readiness` capped at 70

### 3.3 Built-in fallback

If customer cannot or chooses not to deploy gateway-level controls, the platform's built-in fallback enables Spring filter equivalent:

- `JwtVerificationFilter` (built-in JWKS verification)
- `HeaderNormalizationFilter` (strips client `X-*` headers)
- `RateLimitFilter` (in-process bucket; no global view across replicas)
- `BodySizeLimitFilter` (Spring's standard)
- `OpaRedlineFilter` (in-process OPA SDK)
- `OperatorIpAllowlistFilter` (allowlist from `application.yaml`)
- `StructuredAccessLogFilter` (JSON logback config)

This fallback duplicates work but ensures security. `/ready` reports `gateway_conformance: BUILTIN_FALLBACK`. Performance penalty: ~5ms p95 per request.

---

## 4. Reference: Higress conformance configuration

For customers using Higress (the recommended default), the conformance configuration is:

```yaml
# higress.yaml (excerpt)
plugins:
  jwt-auth:
    enabled: true
    algorithm: ["RS256", "ES256"]
    jwks_endpoints:
      - issuer: "https://idp.bank-a.com"
        jwks_uri: "https://idp.bank-a.com/.well-known/jwks.json"
    audience: "spring-ai-fin"
    forward_claims:
      - sub -> X-User-Id
      - tenantId -> X-Tenant-Id
      - roles -> X-Roles
  
  header-normalization:
    strip_request_headers:
      - X-Tenant-Id
      - X-Internal-Trust
      - X-Auth-*
    inject_request_headers:
      - X-Tenant-Id: "${jwt.claim.tenantId}"
      - X-Internal-Trust: "higress-prod:${hmac(request, GATEWAY_ATTESTATION_SECRET)}"
  
  rate-limit:
    per_tenant: 1000/min
    per_user: 60/min
    per_capability:
      "audit.decode": 10/hour
      "transfer.execute": 100/min
  
  body-limits:
    max_request_size_mb: 8
    sse_concurrent_per_tenant: 100
  
  opa-redline:
    enabled: true
    policy_path: "/etc/higress/redline-policies/"
  
  ip-allowlist:
    paths:
      - "/diagnostics": ["10.0.0.0/8"]
      - "/actuator/*": ["10.0.0.0/8"]
  
  access-log:
    format: json
    fields: [timestamp, tenant_id, user_id, route, method, status, latency_ms, body_size, response_size, request_id, trace_id]
    retention_days: 2555
```

Higress conformance attestation generator script: `tools/gateway-conformance/generate-higress-attestation.sh` (W2.5 deliverable).

---

## 5. Reviewer's acceptance tests (addresses P0-9; status: design_accepted)

| Test | Expected |
|---|---|
| `GatewayConformanceIT.testReadyWithAttestation` | `/ready` returns 200 + `gateway_conformance: PASS` |
| `GatewayConformanceIT.testReadyWithoutAttestationInProd` | `/ready` returns 503 unless built-in fallback enabled |
| `GatewayConformanceIT.testSpoofedTenantHeader` | External client cannot override verified claim -- header stripped + re-injected |
| `GatewayConformanceIT.testMissingRateLimit` | If attestation lacks rate-limit fields, deployment check fails |
| `GatewayConformanceIT.testBuiltInFallback` | Built-in filters enabled when no attestation; `/ready` returns `gateway_conformance: BUILTIN_FALLBACK` |

---

## 6. Maintenance

Profile owned by GOV track. Updates require:

- PR with profile field changes
- Updated attestation schema
- Updated `ReadinessController` validation logic
- Customer migration guide for existing BYOC deployments

Profile minor versions are backward-compatible (add fields with safe defaults). Major versions require customer re-attestation.
