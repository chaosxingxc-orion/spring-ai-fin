# posture — AppPosture + PostureBootGuard (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`posture/` owns the **single most-impactful design lever** in spring-ai-fin: the three-posture model (`dev` / `research` / `prod`). Every fail-closed vs fail-open decision in the platform reads from here.

Owns:

- `AppPosture` — enum `DEV / RESEARCH / PROD`
- `DeploymentShape` — enum `LOCAL_LOOPBACK / BYOC_SINGLE_TENANT / SAAS_MULTI_TENANT`
- `PostureGate` — consumer-facing helpers (`requiresStrict`, `requiresRealLLM`, `requiresJwt`, `requiresWorm`, `permitsInMemoryStore`, `permitsHmac`, `permitsAnonymous`, etc.)
- `Posture.fromEnv()` — single boot-time read
- `PostureBootGuard` — hard boot gate that refuses to start the JVM when the requested posture/shape combination violates the safety matrix in §4

Does NOT own:

- Per-feature flags (deferred to v1.1+)
- Per-tenant overrides (a customer cannot override platform posture)
- Spring profile activation (handled via Spring's `@Profile` annotation tied to posture)

---

## 2. Three postures

```yaml
DEV:
  default: true (when APP_POSTURE unset AND no real-resource configuration is detected)
  permits:
    - in-memory backends OK
    - missing tenant_id warns (not rejects)
    - JWT optional (anonymous claims accepted) — loopback bind only
    - mock LLM provider permitted
    - WORM audit storage optional
  recommended_for:
    - local development
    - unit tests
    - smoke tests

RESEARCH:
  default: false
  enforces:
    - durable backends required
    - tenant_id required (rejected if missing)
    - JWT required:
        - SAAS_MULTI_TENANT -> RS256/ES256 + JWKS (mandatory)
        - BYOC_SINGLE_TENANT -> HS256 carve-out permitted with allowlist entry; otherwise RS256/ES256 + JWKS
    - real LLM required (mock raises 503) only if the route exercises LLM behavior
    - audit logged but WORM-anchoring optional
  recommended_for:
    - integration testing
    - research workloads with real-LLM but non-customer data
    - pre-production staging

PROD:
  default: false
  enforces:
    - all RESEARCH constraints
    - RS256/ES256 + JWKS mandatory regardless of deployment shape
    - WORM-anchored audit required (S3 Object Lock or SeaweedFS WORM)
    - gateway conformance enforced
    - behaviour-version pinning honoured (if customer opted in)
    - PII redaction default-on
    - dual-approval workflow on PII decode
    - bias-audit cadence enforced (MAS FEAT)
    - fallback-zero gate must pass at release HEAD
  recommended_for:
    - regulated production deployment
    - customer-facing SLA tier
```

---

## 3. Consumer pattern (mandatory)

Consumers ask `posture.requires*()` rather than branch on posture name:

```java
// CORRECT
if (posture.requiresJwt()) { /* validate JWT */ }
if (posture.requiresStrict()) { throw new SpineCompletenessException(...); }

// WRONG — couples consumer to posture name
if (posture == AppPosture.PROD) { /* ... */ }
```

This decouples consumers from posture taxonomy. Adding a new posture (e.g., `STAGING`) requires updating `requires*()` helpers in one place; consumers don't change.

---

## 4. PostureBootGuard (hard boot gate)

`PostureBootGuard` runs as a Spring `ApplicationListener<ApplicationEnvironmentPreparedEvent>` and refuses to start the JVM when the requested posture / deployment shape / opt-in flag combination violates the L0 D-block §A3 safety matrix. It is the architectural answer to the largest practical failure mode the security review identified: **a pilot deployment accidentally running permissive dev posture with real data, real sidecars, or real LLM credentials**.

### Boot-time decision matrix

```text
If APP_POSTURE is unset:
  set effective posture = dev
  permit ONLY: loopback bind, no real DB, no real LLM, no sidecar, no external MCP
  if any of {DB_URL points off-loopback, LLM_BASE_URL is non-mock, SIDECAR_ENABLED=true,
            MCP_ENABLED=true, server.address is non-loopback}:
    fail boot with PostureBootGuardException
    reason: "APP_POSTURE unset; refusing to boot with real-resource configuration"

If APP_POSTURE = dev:
  require ALLOW_DEV_WITH_REAL_DB=true to permit a real database
  require ALLOW_DEV_WITH_REAL_LLM=true to permit a real LLM provider credential
  require ALLOW_DEV_NON_LOOPBACK=true to permit non-loopback bind
  require ALLOW_DEV_NON_LOOPBACK_HS256=true (in addition to ALLOW_DEV_NON_LOOPBACK)
    to permit HS256 JWT validation on a non-loopback bind
  any missing opt-in for an enabled real resource -> fail boot

If APP_POSTURE = research:
  require durable DB (in-memory backends fail boot)
  require JWT validation enabled
  require strict tenant spine
  if deployment shape is SAAS_MULTI_TENANT:
    require IssuerRegistry has at least one RS256/ES256 entry
    HS256-only validators fail boot
  if deployment shape is BYOC_SINGLE_TENANT and HmacValidator is active:
    require an allowlist entry in docs/governance/allowlists.yaml acknowledging the carve-out
  require real LLM only if any registered route exercises LLM behavior

If APP_POSTURE = prod:
  require RS256/ES256 + JWKS; HmacValidator must be inactive (boot fails if HmacValidator bean present)
  require gateway conformance check passes (or operator-shape gate flag set)
  require WORM audit storage configured and reachable
  require fallback-zero gate (gate/run_operator_shape_smoke.* MUST have green run for current SHA)
```

### Implementation sketch

```java
@Component
public class PostureBootGuard implements ApplicationListener<ApplicationEnvironmentPreparedEvent> {

    @Override
    public void onApplicationEvent(ApplicationEnvironmentPreparedEvent event) {
        var env = event.getEnvironment();
        var posture = AppPosture.fromEnv(env);
        var shape = DeploymentShape.fromEnv(env);
        var checks = new ArrayList<BootCheck>();

        switch (posture) {
            case DEV -> {
                checks.add(BootCheck.requireOptInForRealResource(env, "ALLOW_DEV_WITH_REAL_DB", "DB_URL"));
                checks.add(BootCheck.requireOptInForRealResource(env, "ALLOW_DEV_WITH_REAL_LLM", "LLM_BASE_URL"));
                checks.add(BootCheck.requireOptInForNonLoopbackBind(env));
                if (env.getProperty("APP_POSTURE") == null) {
                    checks.add(BootCheck.refuseUnsetWithRealResources(env));
                }
            }
            case RESEARCH -> {
                checks.add(BootCheck.requireDurableDb(env));
                checks.add(BootCheck.requireJwt(env));
                checks.add(BootCheck.requireStrictTenantSpine(env));
                if (shape == DeploymentShape.SAAS_MULTI_TENANT) {
                    checks.add(BootCheck.requireJwksIssuer(env));
                    checks.add(BootCheck.refuseHmacOnly(env));
                }
                if (shape == DeploymentShape.BYOC_SINGLE_TENANT) {
                    checks.add(BootCheck.requireHmacCarveOutAllowlistIfHmacActive(env));
                }
            }
            case PROD -> {
                checks.add(BootCheck.requireDurableDb(env));
                checks.add(BootCheck.requireJwksIssuer(env));
                checks.add(BootCheck.refuseHmacEntirely(env));
                checks.add(BootCheck.requireGatewayConformance(env));
                checks.add(BootCheck.requireWormStorage(env));
                checks.add(BootCheck.requireFallbackZeroGateGreenForCurrentSha(env));
            }
        }

        var failures = checks.stream().filter(BootCheck::fails).toList();
        if (!failures.isEmpty()) {
            throw new PostureBootGuardException(posture, shape, failures);
        }
    }
}
```

`PostureBootGuardException` is **terminal** — there is no fallback. The JVM exits non-zero with a structured error pointing at every failed check and the env var that would correct it.

### Identity policy table (verbatim from L0 D-block §A3)

| Context | Permitted JWT algorithms |
|---|---|
| Local dev, loopback | Anonymous OR HS256 |
| Research BYOC single tenant | HS256 with carve-out allowlist + audit alarm; RS256/ES256 also permitted |
| Research SaaS multi-tenant | RS256/ES256 + JWKS only |
| Prod, any deployment shape | RS256/ES256 + JWKS only |

Reflected in `posture.permitsHmac(deploymentShape)`; `auth/JwtValidator` dispatches accordingly.

---

## 5. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Three postures, not two** | dev / research / prod | Two postures conflate "research workloads" with "regulated prod" |
| **AD-2: Boot-time read, not per-call** | `Posture.fromEnv()` once in bootstrap | Avoids re-reading env on hot path; consistent across request lifetime |
| **AD-3: Consumer asks `requires*()`** | Don't branch on posture name | Decouples; new posture = update helpers, not consumers |
| **AD-4: Posture is a JVM-process property** | Not per-tenant; not per-request | Different postures = different deployments; no tenant can override |
| **AD-5: Spring profile activation tied to posture** | `spring.profiles.active=research` etc. | Standard Spring pattern; `application-research.yaml` overrides defaults |
| **AD-6: PostureBootGuard refuses to start the JVM on policy violation** | No "warn and continue" path; misconfiguration is loud and terminal | Closes the largest practical failure mode (dev posture with real resources) |
| **AD-7: DeploymentShape orthogonal to posture** | `LOCAL_LOOPBACK / BYOC_SINGLE_TENANT / SAAS_MULTI_TENANT` declared at boot via `APP_DEPLOYMENT_SHAPE` | The same posture (research) requires different identity policy depending on whether one or many tenants share the deployment |
| **AD-8: Opt-in env vars rather than negative env vars** | `ALLOW_DEV_WITH_REAL_LLM=true`, not `DISABLE_LLM_CHECK=true` | A missing variable defaults to the safer behaviour (negative defaults silently permit; positive opt-ins require an explicit choice) |

---

## 6. Cross-cutting hooks

- **Rule 11**: this IS Rule 11; everything else inherits
- **Rule 8**: operator-shape gate is run under `prod` posture; PostureBootGuard's `requireFallbackZeroGateGreenForCurrentSha` couples the boot gate to the operator-shape gate
- **Rule 6**: single `@Bean AppPosture posture(Environment env)` builder; single `@Bean DeploymentShape deploymentShape(Environment env)` builder
- **Rule 12**: capability maturity L3 requires `posture.requiresStrict()` to default-on the capability
- **Auth** (`../auth/`): `JwtValidator` reads `posture.permitsHmac(deploymentShape)` to dispatch HS256 vs JWKS

---

## 7. Quality

| Attribute | Target | Verification |
|---|---|---|
| Single boot-time read | yes | `tests/unit/PostureBootReadTest` |
| Consumer pattern compliance | no `posture == AppPosture.X` literals in consumers | `ArchitectureRulesTest::posturePatternCompliance` |
| Test coverage of postures | dev + research paths covered for every new contract | `PostureCoverageTest` |
| Boot guard rejects dev-with-real-DB-without-opt-in | JVM exits non-zero | `tests/integration/PostureBootGuardIT` (matrix permutations) |
| Boot guard rejects prod-with-HmacValidator-active | JVM exits non-zero | `tests/integration/PostureBootGuardIT` |
| Boot guard rejects research-SAAS-multi-tenant without JWKS issuer | JVM exits non-zero | `tests/integration/PostureBootGuardIT` |
| Identity policy matrix matches `auth/` dispatch | every posture×shape pair returns the same algorithm decision in `posture` and `auth/JwtValidator` | `tests/integration/IdentityPolicyConsistencyIT` |

---

## 8. Risks

- **Adding a 4th posture (e.g., `STAGING`)**: low risk if consumers use `requires*()` pattern; high risk if they branch on name
- **Posture-aware default-on enforcement**: requires reviewer audit on each capability claiming L3
- **Opt-in flag drift**: every `ALLOW_DEV_*` flag needs a documented expiry / review cadence; tracked in `docs/governance/allowlists.yaml`
- **Boot guard false negative if env var typo**: mitigation — boot guard logs the resolved posture, shape, and active opt-ins at INFO; CI smoke test asserts the expected resolved values

---

## 9. References

- Hi-agent equivalent: `D:/chao_workspace/hi-agent/hi_agent/config/posture.py`
- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- L0 D-6: [`../../ARCHITECTURE.md#d-6-three-posture-model-rule-11`](../../ARCHITECTURE.md)
- Auth: [`../auth/ARCHITECTURE.md`](../auth/ARCHITECTURE.md)
- Systematic-architecture-improvement-plan: [`../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md`](../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md) §4.4
