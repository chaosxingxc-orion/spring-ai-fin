# agent-platform/bootstrap -- L2 architecture (2026-05-08 refresh; cycle-14 re-scope)

> Owner: platform | Wave: W0 (lite) / W1 (full guard) | Maturity: L0 | Reads: env, application.yml | Writes: --
> Last refreshed: 2026-05-09 (cycle-14 C1: re-scoped to W0 lite)

## 1. Purpose

Spring Boot main class + boot-time posture handling.

**W0 lite** (current): the entry point reads `APP_POSTURE` into an `AppPosture` bean. No
required-config validation runs in W0; the app starts regardless of which keys are set.

**W1** adds the full guard: `PostureBootGuard` listens to `ApplicationStartedEvent`,
evaluates `RequiredConfig` for the active posture, and exits non-zero (with a structured
log + metric) if any required key is absent. Until W1 lands, setting `APP_POSTURE=research`
or `APP_POSTURE=prod` does NOT enforce the W1 required-key matrix.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Boot | 3.5.x | `@SpringBootApplication`, lifecycle |
| Spring Boot actuator | (BOM) | health + info |

## 3. Glue we own

### W0 (current)

| File | Purpose | LOC |
|---|---|---|
| `bootstrap/PlatformApplication.java` | main class | 18 |
| `bootstrap/AppPosture.java` | posture enum + `@Bean` (no validation) | 30 |

### W1 (planned)

| File | Purpose | LOC |
|---|---|---|
| `bootstrap/PostureBootGuard.java` | `ApplicationStartedEvent` listener; fail-closes on missing required keys | 120 |
| `bootstrap/RequiredConfig.java` | per-posture required key matrix | 80 |

## 4. Public contract

Single env var `APP_POSTURE = dev | research | prod` (default `dev`).
Read once at startup; injected as `AppPosture` bean.

**W0**: no enforcement — the bean is available but PostureBootGuard does not exist.
**W1**: PostureBootGuard inspects RequiredConfig and refuses to start with a non-zero
exit code (and a structured log line + metric increment) if any required key is missing
for the active posture.

## 5. W1 enforcement matrix (not active in W0)

| Required key | dev | research | prod |
|---|---|---|---|
| `OIDC_ISSUER_URL` | optional | required | required |
| `OIDC_JWKS_URL` | optional | required | required |
| `DB_URL` | optional (defaults to compose) | required | required |
| `VAULT_URL` | optional | required | required |
| `LLM_PROVIDER_KEYS` (Vault path) | optional | required | required |
| `TEMPORAL_TARGET` | optional | optional (W2-W3) / required (W4) | required (W4) |

## 6. Tests

### W0

| Test | Layer | Asserts |
|---|---|---|
| `HealthEndpointIT` | Integration | `/v1/health` responds 200 |

### W1 (planned)

| Test | Layer | Asserts |
|---|---|---|
| `PostureBootGuardResearchIT` | Integration | missing required env in `research` -> exit 1 |
| `PostureBootGuardProdIT` | Integration | missing required env in `prod` -> exit 1 |
| `PostureBootGuardDevIT` | Integration | dev starts even with sparse env |
| `ActuatorHealthIT` | Integration | `/actuator/health/readiness` reflects DB state |

## 7. Out of scope

- Per-tenant config: `agent-platform/config/`.
- Secrets resolution mechanics: Spring Cloud Vault is wired in W2 but defined as policy
  in `docs/cross-cutting/secrets-lifecycle.md`.

## 8. Wave landing

| Wave | Deliverable |
|---|---|
| W0 | `PlatformApplication.java` + `AppPosture.java` (posture marker, no guard) |
| W1 | `PostureBootGuard.java` + `RequiredConfig.java` + per-posture ITs |
| W2 | Extend required-key list with Temporal target |
| W4 | Extend with production-only keys (S3 audit anchor, etc.) |

## 9. Risks

- **Posture confusion in W0**: operators setting `APP_POSTURE=research` before W1 lands
  get dev-permissive behavior. Documentation must make this explicit. Mitigated by the
  W0-lite note above and by CI enforcing the reintroduction of PostureBootGuard in W1.
- Boot-time config drift across waves: `RequiredConfig` (W1) will be the single source;
  tests pin per-posture sets.
- Operator confusion when a key is missing: W1 exit message must include the posture, the
  missing key, and a documentation link.
