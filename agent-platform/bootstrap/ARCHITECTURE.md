# agent-platform/bootstrap -- L2 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W0 | Maturity: L0 | Reads: env, application.yml | Writes: --
> Last refreshed: 2026-05-08

## 1. Purpose

Spring Boot main class + boot-time guards. The entry point reads
`APP_POSTURE` once, validates required config for that posture, and
fail-closes before serving traffic if a posture-required setting is
missing.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Boot | 3.5.x | `@SpringBootApplication`, lifecycle |
| Spring Boot actuator | (BOM) | health + info |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `bootstrap/PlatformApplication.java` | main class | 30 |
| `bootstrap/AppPosture.java` | posture enum + bean | 50 |
| `bootstrap/PostureBootGuard.java` | `ApplicationStartedEvent` listener | 120 |
| `bootstrap/RequiredConfig.java` | per-posture required keys | 80 |

## 4. Public contract

Single env var `APP_POSTURE = dev | research | prod` (default `dev`).
Read once at startup; injected as `AppPosture` bean.

PostureBootGuard inspects `RequiredConfig` and refuses to start with a
non-zero exit code (and a structured log line + metric increment) if
any required key is missing for the active posture.

## 5. Posture-aware defaults

| Required key | dev | research | prod |
|---|---|---|---|
| `OIDC_ISSUER_URL` | optional | required | required |
| `OIDC_JWKS_URL` | optional | required | required |
| `DB_URL` | optional (defaults to compose) | required | required |
| `VAULT_URL` | optional | required | required |
| `LLM_PROVIDER_KEYS` (Vault path) | optional | required | required |
| `TEMPORAL_TARGET` | optional | optional (W2-W3) / required (W4) | required (W4) |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `PostureBootGuardResearchIT` | Integration | missing required env in `research` -> exit 1 |
| `PostureBootGuardProdIT` | Integration | missing required env in `prod` -> exit 1 |
| `PostureBootGuardDevIT` | Integration | dev starts even with sparse env |
| `ActuatorHealthIT` | Integration | `/actuator/health/readiness` reflects DB state |

## 7. Out of scope

- Per-tenant config: `agent-platform/config/`.
- Secrets resolution mechanics: Spring Cloud Vault is wired here but
  defined as policy in `docs/cross-cutting/secrets-lifecycle.md`.

## 8. Wave landing

W0 brings PlatformApplication + minimal guard. W1 extends required-key
list with auth keys. W2 extends with Temporal target. W4 extends with
production-only keys (S3 audit anchor, etc.).

## 9. Risks

- Boot-time config drift across waves: `RequiredConfig` is the single
  source; tests pin per-posture sets.
- Operator confusion when a key is missing: exit message must include
  the posture, the missing key, and a documentation link.
