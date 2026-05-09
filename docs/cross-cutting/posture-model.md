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

Posture is set by a single env var `APP_POSTURE`, default `dev`. Read
once at boot. Never branched on at call sites; consumers use
`AppPosture.requiresStrict()` or specific predicates.

## 3. Boot guard

`agent-platform/bootstrap/PostureBootGuard.java` runs at
`ApplicationStartedEvent`. It refuses to start (exit 1, structured log
+ Prometheus increment) if any required key for the active posture is
missing. The required-key matrix lives in
`agent-platform/bootstrap/RequiredConfig.java`.

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

Per L1 / L2 module's own posture table. Consolidated examples:

| Aspect | Module | dev | research | prod |
|---|---|---|---|---|
| HS256 JWT | `agent-platform/auth` | accept w/ warn | reject (unless BYOC carve-out) | reject (unless BYOC carve-out) |
| Missing tenant_id claim | `agent-platform/tenant` | warn | reject 401 | reject 401 |
| Missing Idempotency-Key on POST | `agent-platform/idempotency` | accept | reject 400 | reject 400 |
| Mock LLM provider | `agent-runtime/llm` | yes | no | no |
| OPA outage | `agent-runtime/action` | warn-allow | fail-closed deny | fail-closed deny |
| Outbox sink mock | `agent-runtime/outbox` | log only | real bus | real bus |
| Run > 30s without Temporal | `agent-runtime/run` | warn | reject | reject |
| Cardinality budget | `agent-runtime/observability` | unbounded | <= 50 | <= 50 |

## 5. Tests

| Test | Layer | Asserts |
|---|---|---|
| `PostureBootGuardDevIT` | Integration | `dev` starts with sparse env |
| `PostureBootGuardResearchIT` | Integration | `research` exits 1 on missing key |
| `PostureBootGuardProdIT` | Integration | `prod` exits 1 on missing key |
| `RequiredConfigContractIT` | Integration | Per-posture required-key matrix matches `RequiredConfig.java` table |
| `PostureBranchingLintIT` | CI | No call site branches on `APP_POSTURE` directly |

## 6. Open issues / deferred

- Posture-aware audit retention policies (per-posture TTL): W4.
- Per-tenant posture override (a tenant in research mode within a prod cluster): W4+ post; would require careful policy design.

## 7. References

- `agent-platform/bootstrap/ARCHITECTURE.md`
- `ARCHITECTURE.md` sec-6.1
- `docs/cross-cutting/security-control-matrix.md`
