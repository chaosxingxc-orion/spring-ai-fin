# agent-platform/tenant -- L2 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W1 | Maturity: L0 | Reads: tenants table | Writes: tx GUC
> Last refreshed: 2026-05-08

## 1. Purpose

Bind every authenticated request to its tenant via the `tenant_id` JWT
claim, and propagate that binding into Postgres as a transaction-scoped
GUC (`SET LOCAL app.tenant_id = :id`). Postgres' RLS policies use this
GUC to filter rows.

The tenant binding is **per-transaction**, not per-connection. The
HikariCP pool is multi-tenant; isolation is achieved by `SET LOCAL`,
which Postgres auto-discards on `COMMIT` / `ROLLBACK`. There is no
per-checkout reset hook -- that approach was rejected (cycle-2 / 3 / 5
in v6 review history).

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Boot starter jdbc | 3.5.x | `JdbcTemplate`, transaction manager |
| HikariCP | 5.x | Pool |
| PostgreSQL JDBC | 42.7+ | Driver |
| Spring Web | (BOM) | request-scoped beans |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `tenant/TenantContext.java` | request-scoped holder | 30 |
| `tenant/TenantBinder.java` | filter; reads `Authentication`, sets context | 80 |
| `tenant/RlsTransactionSynchronization.java` | `TransactionSynchronization` running `SET LOCAL` | 70 |
| `tenant/RlsAssertionTrigger.sql` | DB trigger: every tenant table requires non-empty `app.tenant_id` | 30 |
| `db/migration/V2__tenant_rls.sql` | RLS policies + tenant table + trigger | 120 |

## 4. Public contract

DB-level: every tenant-scoped table has:

```sql
ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;
CREATE POLICY <t>_tenant_isolation ON <t>
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE TRIGGER <t>_assert_tenant
  BEFORE INSERT OR UPDATE ON <t>
  FOR EACH ROW EXECUTE FUNCTION assert_app_tenant_id_set();
```

App-level: `TenantContext.current()` returns the tenant UUID inside any
request-scoped code; throws if accessed outside a request.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| `app.tenant_id` GUC empty at tx start | warn | trigger fails (5xx) | trigger fails (5xx) |
| Cross-tenant query attempt | RLS filter; warn | RLS filter; alert | RLS filter; alert |
| Tenant impersonation header | accept (admin tools) | reject | reject |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `TenantIsolationIT` | E2E | Tenant A's writes invisible to B |
| `GucEmptyAtTxStartIT` | Integration | A query bypassing TenantBinder fails the trigger |
| `MultiQueryTransactionIT` | Integration | Single tx with multiple statements -- all see same tenant |
| `RlsPolicyCoverageIT` | Integration | Every tenant-scoped table has an RLS policy + trigger |

## 7. Out of scope

- Authentication (`auth/`).
- Cross-tenant analytics (future).
- Per-tenant rate limit (`ratelimit/`, lives in `web/` config or its own L2 if it grows).

## 8. Wave landing

W1 brings the entire module. The trigger + RLS policy template is the
key W1 deliverable; without it, `agent-runtime` cannot trust that
queries return only the right tenant's rows.

## 9. Risks

- Engineer forgets to use `JdbcTemplate` transaction; `SET LOCAL`
  outside a transaction is a no-op. Mitigation: `RlsAssertionTrigger`
  fires on the first statement and fails closed.
- HikariCP connection-validation queries running outside a tx: the
  driver's `JDBC.4` validation queries don't read tenant tables;
  verified by `RlsPolicyCoverageIT`.
- `current_setting('app.tenant_id', true)` used over hard `current_setting`
  to avoid 42704 in non-RLS contexts; assertion trigger handles the
  required-set check.
