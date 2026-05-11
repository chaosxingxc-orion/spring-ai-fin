# Posture Model -- cross-cutting policy

> Owner: architecture | Wave: W0 (boot guard) + per-wave strict-mode tests | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Defines the three operational postures (`dev`, `research`, `prod`) and
the boot-time guard that enforces posture-required configuration. Used
by every L1 / L2 module's `Posture-aware defaults` table.

## 2. The three postures

| Posture | Intent | Defaults |
|---|---|---|
| `dev` | Local development, fast iteration | Permissive: warnings only on missing config; in-memory DBs allowed; mocks allowed; HS256 carve-out; no rate limits |
| `research` | Single-tenant or low-volume multi-tenant production-equivalent | Strict: required config must be present; real Postgres; real LLM provider; rate limits on; HS256 only via explicit BYOC carve-out |
| `prod` | High-volume multi-tenant production | Strict + harder: Vault required; OPA enforced; lower rate limits; OTel sample rate 1%; full audit |

Posture is set by a single env var `APP_POSTURE`, default `dev`. Read once at boot via
`application.yml` placeholder `app.posture: ${APP_POSTURE:dev}`. Call sites read
`env.getProperty("app.posture", "dev")` directly; a dedicated `AppPosture` helper is
**deferred to W1** — see `architecture-status.yaml` capability `posture_module_bootstrap`.

## 3. Boot guard — Deferred to W1

> **STATUS: NOT BUILT.** The classes `PostureBootGuard`, `RequiredConfig`, and `AppPosture`
> described below are design intent for W1, not shipped code. Current enforcement: each
> L0 sentinel throws `BeanCreationException` at context load when `app.posture != dev` and the
> starter is enabled. See `architecture-status.yaml` capability `posture_module_bootstrap` (L0).

**Planned (W1):** `agent-platform/bootstrap/PostureBootGuard.java` will run at
`ApplicationStartedEvent` and refuse to start (exit 1) if required keys for the active posture
are missing. The required-key matrix will live in `agent-platform/bootstrap/RequiredConfig.java`.

Planned required-key matrix:

| Key | dev | research | prod |
|---|---|---|---|
| `OIDC_ISSUER_URL` | optional | required | required |
| `OIDC_JWKS_URL` | optional | required | required |
| `DB_URL` | optional (compose default) | required | required |
| `VAULT_URL` | optional | required | required |
| `LLM_PROVIDER_KEYS` (Vault path) | optional | required | required |
| `TEMPORAL_TARGET` | optional | optional (W2-W3) / required (W4) | required (W4) |
| `OPA_URL` | optional | required (W3) | required (W3) |
| `S3_AUDIT_ANCHOR_BUCKET` | optional | optional | required (W4) |

## 4. Enforced-by-posture rules

Currently enforced (as of W0):

| Aspect | Module | dev | research | prod |
|---|---|---|---|---|
| Missing tenant_id claim | `agent-platform/tenant` | warn + dev default | reject 400 | reject 400 |
| Missing Idempotency-Key on POST | `agent-platform/idempotency` | accept | reject 400 | reject 400 |
| L0 sentinel active (sidecar enabled) | all `*-starter` modules | allow | `BeanCreationException` at boot | `BeanCreationException` at boot |

Deferred (W3-W4, not yet implemented):

| Aspect | Module | Target posture |
|---|---|---|
| HS256 JWT carve-out | `agent-platform/auth` | research/prod |
| OPA outage fail-closed | `agent-runtime/action` | research/prod |
| Mock LLM provider rejection | `agent-runtime/llm` | research/prod |
| Run > 30s without Temporal | `agent-runtime/run` | research/prod |
| Cardinality budget | `agent-runtime/observability` | research/prod |

## 5. Tests

Currently shipped:

| Test | Layer | Asserts |
|---|---|---|
| `PostureBindingIT` | Integration | `APP_POSTURE=research` env-var → `app.posture=research` Spring property |
| `TenantContextFilterTest` | Unit | dev/research/prod posture behaviours for missing/invalid header |
| `IdempotencyHeaderFilterTest` | Unit | dev/research/prod posture behaviours for missing/invalid header |
| `*AutoConfigurationTest` (per starter) | Unit | dev allows sentinel; research/prod reject at context load |

Deferred to W1 (class does not exist):

| Test | Blocked on |
|---|---|
| `PostureBootGuardDevIT` | `PostureBootGuard` class (W1) |
| `PostureBootGuardResearchIT` | `PostureBootGuard` class (W1) |
| `PostureBootGuardProdIT` | `PostureBootGuard` class (W1) |
| `RequiredConfigContractIT` | `RequiredConfig` class (W1) |
| `PostureBranchingLintIT` | `AppPosture` class (W1) |

## 6. Open issues / deferred

- Posture-aware audit retention policies (per-posture TTL): W4.
- Per-tenant posture override (a tenant in research mode within a prod cluster): W4+ post; would require careful policy design.

## 7. References

- `agent-platform/bootstrap/ARCHITECTURE.md`
- `ARCHITECTURE.md` sec-6.1
- `docs/cross-cutting/security-control-matrix.md`
