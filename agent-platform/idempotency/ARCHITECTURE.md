# agent-platform/idempotency -- L2 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W1 | Maturity: L0 | Reads: idempotency_dedup | Writes: idempotency_dedup
> Last refreshed: 2026-05-08

## 1. Purpose

Make every POST / PUT / PATCH endpoint idempotent under the
`Idempotency-Key` HTTP header. Same key -> same result; different keys
-> independent results; missing key in research/prod -> 400.

This is the synchronous half of "functional idempotency" (Quality
Attribute 4.1). The asynchronous half (durable side effects under
crashes) is the outbox pattern in `agent-runtime/outbox/`.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Web | (BOM) | filter |
| Spring Boot starter jdbc | 3.5.x | dedup table access |
| PostgreSQL | 16 | UNIQUE INDEX dedup |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `idempotency/IdempotencyFilter.java` | `OncePerRequestFilter` | 100 |
| `idempotency/IdempotencyKey.java` (record) | (tenant_id, key) | 20 |
| `idempotency/IdempotencyRepository.java` | jdbc | 70 |
| `idempotency/IdempotencyResult.java` (record) | cached response | 30 |
| `db/migration/V2_2__idempotency_dedup.sql` | table + UNIQUE INDEX + cleanup job | 80 |

## 4. Public contract

- Header `Idempotency-Key: <opaque-string>`. Max 255 chars; UTF-8.
- Scope: per `(tenant_id, key)`. Two tenants can use the same key
  independently.
- TTL: 24h default (configurable). Cleanup via `pg_cron` daily.
- Response: same status code + body as the original; gateway echoes
  `Idempotent-Replayed: true` header on replays.
- Concurrent retry with same key while original is in-flight: 409.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Missing key on POST | accept | reject 400 | reject 400 |
| TTL | 24h | 24h | 24h |
| Key max length | 255 | 255 | 255 |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `IdempotencyDoubleSubmitIT` | E2E | same key -> same row id, only one DB insert |
| `IdempotencyDifferentTenantsIT` | E2E | same key, different tenants -> independent results |
| `IdempotencyMissingKeyIT` | Integration (research) | missing -> 400 |
| `IdempotencyConcurrentReplayIT` | Integration | second concurrent call returns 409 |
| `IdempotencyCleanupIT` | Integration | rows older than TTL pruned |

## 7. Out of scope

- Cross-replica dedup race: handled by Postgres UNIQUE INDEX (the only
  source of truth).
- Outbox-driven side-effect dedup: `agent-runtime/outbox/`.

## 8. Wave landing

W1 brings the entire module. The `pg_cron` cleanup is configured in W2
when `pg_cron` is added to the Postgres image.

## 9. Risks

- Hot-key contention on UNIQUE INDEX: mitigated by per-tenant key
  scoping; no global hot key.
- Stored response body grows unbounded: only stored if response < 64KB;
  larger responses re-execute (documented).
- Header omitted under heavy retry: on the client side, not the
  platform's problem; documented in customer onboarding.
