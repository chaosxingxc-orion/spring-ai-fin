> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# Security Control Matrix -- cross-cutting policy

> Owner: security | Wave: W0..W4 (per-control wave varies) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Single table mapping each security control to owner module, enforcement
mechanism, posture defaults, named test, and the wave in which it
lands. Replaces the pre-refresh `docs/security-control-matrix.md`.

## 2. Control matrix

| # | Control | Owner module | Enforcement | Posture defaults | Test | Wave | Failure mode |
|---|---|---|---|---|---|---|---|
| C1 | JWT validation (RS256/RS512/EdDSA) | `agent-platform/auth` | Spring Security `oauth2ResourceServer` + JWKS | `research`/`prod` reject HS256 | `RS256HappyPathIT`, `JwtAlgorithmRejectionIT` | W1 | 401 |
| C2 | HS256 BYOC carve-out | `agent-platform/auth` | Two env vars + posture allow | only when `auth.hmac_carveout.enabled=true` | `HmacCarveOutIT` | W1 | 401 if not enabled |
| C3 | Tenant binding | `agent-platform/tenant` | `TenantBinder` filter + `TransactionSynchronization` | required in `research`/`prod` | `TenantIsolationIT` -- `agent-platform/src/test/java/ascend/springai/platform/security/TenantIsolationIT.java` (L0 scaffold, @Disabled until W2) | W1 | RLS hides rows |
| C4 | RLS row visibility | Postgres + `agent-platform/tenant` | RLS policy on every tenant table | `research`/`prod` enforce | `RlsPolicyCoverageIT` -- `agent-platform/src/test/java/ascend/springai/platform/security/RlsPolicyCoverageIT.java` (L0 scaffold, @Disabled until W2) | W1 | empty result |
| C5 | RLS GUC required | Postgres trigger | `BEFORE INSERT/UPDATE` on tenant tables | `research`/`prod` enforce | `GucEmptyAtTxStartIT` -- `agent-platform/src/test/java/ascend/springai/platform/security/GucEmptyAtTxStartIT.java` (L0 scaffold, @Disabled until W2) | W1 | tx fails |
| C6 | Idempotency dedup | `agent-platform/idempotency` | `Idempotency-Key` header + UNIQUE INDEX | required in `research`/`prod` | `IdempotencyDoubleSubmitIT` | W1 | 409 on race |
| C7 | Rate limiting | `agent-platform/web` (Resilience4j) | `@RateLimiter` per endpoint | on in `research`/`prod` | `RateLimitIT` | W1 | 429 |
| C8 | ActionGuard authorization | `agent-runtime/action` | 5-stage chain + OPA query | OPA enforced in `research`/`prod` | `ActionGuardE2EIT` | W3 | 403 |
| C9 | OPA fail-closed | `agent-runtime/action` | degrade-to-deny on outage | enforced in `research`/`prod` | `ActionGuardOpaOutageIT` | W3 | 403 on OPA down |
| C10 | Tool allowlist | `agent-runtime/tool` | per-tenant `tool_registry.enabled` | default deny | `ToolDispatchE2EIT`, `ToolUnknownToTenantIT` | W3 | 403 |
| C11 | Network egress allowlist | `agent-runtime/tool/HttpGetAllowlistTool` | per-call host check | `research`/`prod` enforce | `ToolAllowlistIT` | W3 | tool error |
| C12 | Audit append-only | `agent-runtime/action` + Postgres | INSERT-only role | required in `research`/`prod` | `AuditAppendOnlyIT` | W3 | UPDATE/DELETE fails |
| C13 | Token budget | `agent-runtime/llm` (BudgetGuard) | `tenant_budget` table | required in `research`/`prod` | `BudgetCapIT` | W3 | 429 |
| C14 | Posture boot guard | `agent-platform/bootstrap` | `PostureBootGuard` | enforces in `research`/`prod` | `PostureBootGuardResearchIT`/`ProdIT` | W0/W1 | exit 1 |
| C15 | Secrets via Vault | `agent-runtime/llm` + Spring Cloud Vault | provider-key resolution | required in `research`/`prod` | (W2 IT) | W2 | exit 1 if missing |
| C16 | Supply chain pin | CI + Dockerfile | digest pin + SBOM | required in `prod` | (CI rule) | W0/W2 | build rejected |
| C17 | Cardinality guard | `agent-runtime/observability` | `CardinalityGuard` + lint | `research`/`prod` enforce | `CardinalityBudgetIT` | W2 | bucketed labels |
| C18 | Outbox at-least-once | `agent-runtime/outbox` | `FOR UPDATE SKIP LOCKED` + retry | required in `research`/`prod` | `OutboxAtLeastOnceIT` | W2 | retry until DLQ |
| C19 | Workflow durability | `agent-runtime/temporal` | Temporal workflow + activity boundaries | required in `prod` for runs > 30s | `LongRunResumeIT` | W4 | resumes on crash |
| C20 | Skill plug-in signing | `agent-runtime/tool` | per-tenant capability allowlist | enforced when SPI hot-reload is on | (W4 IT) | W4 | plug-in rejected |

## 3. Cross-references

Each row's `Wave` cell maps to a section in
`docs/plans/engineering-plan-W0-W4.md`. Each row's `Test` cell maps to
a test name in the owner module's L2 doc.

RLS policy artifact: `docs/security/rls-policy.sql` (L0, applied in W2)

## 4. Open issues / deferred

- C19 Workflow durability assumes Temporal Cluster; managed Temporal Cloud is a W4+ optional upgrade.
- Per-customer carve-outs for C2 are tracked separately in `docs/governance/allowlists.yaml`.
- Supply-chain SBOM verification at runtime is W4+ (CI-time pin is sufficient for v1).
