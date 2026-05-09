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

## 10. Tenant lifecycle (added cycle-10 per systematic review TEN-1)

The tenant module is the single owner of tenant create / suspend /
delete / export. Four lifecycle states; transitions are explicit.

### 10.1 States

| State | Definition | Reads / writes allowed | Visible in API listings |
|---|---|---|---|
| `pending_provisioning` | row inserted but provisioning incomplete | none | no |
| `active` | normal operating state | all | yes |
| `suspended` | tenant temporarily frozen (billing / abuse / customer pause) | reads only; writes -> 403 TENANT_SUSPENDED | yes |
| `deleted` (soft) | scheduled for hard delete | none | no |

Transitions are admin-API-only: `POST /v1/admin/tenants/{id}:suspend`,
`:reactivate`, `:delete`, `:export`. All admin endpoints require an
admin JWT scope (cycle-10 TEN-2 stepped-up auth).

### 10.2 Create

1. Operator (or onboarding flow) calls `POST /v1/admin/tenants` with
   `{ tenant_name, owner_email, posture, region }`.
2. Row in `tenants` table is inserted with `state=pending_provisioning`.
3. Provisioning job (sync in v1; async via Temporal in W4):
   a. Create Keycloak realm or sub-realm for the tenant.
   b. Create initial admin user.
   c. Allocate per-tenant Vault path (`secret/tenant/<id>/...`).
   d. Optionally seed `tenant_config` defaults.
   e. Flip state to `active`.
4. Return `{ tenant_id, state }`. Failure rolls back; row remains
   `pending_provisioning` for retry.

### 10.3 Suspend / reactivate

- Suspend writes a row to `audit_log` and sets `state=suspended`.
- Cached `tenant_state` in `TenantContext` (loaded by `TenantBinder`)
  is invalidated on next request via 60s TTL.
- Reactivate sets state back to `active` + audit row.

### 10.4 Delete (soft + hard)

Two-step:

1. **Soft delete**: state -> `deleted`; `tenants.deleted_at = now()`.
   Tenant data retained but inaccessible.
2. **Hard delete (scheduled)**: 30 days after soft-delete (configurable
   per posture). Triggered by `pg_cron` job that:
   a. Deletes from every tenant table by `tenant_id` (each table has
      `ON DELETE CASCADE` from the `tenants` row OR a sweep job).
   b. Deletes Keycloak realm.
   c. Deletes Vault path.
   d. Hard-deletes the `tenants` row.
   e. Records hard-delete in a separate `audit_log_archive` (because
      the per-tenant `audit_log` rows are also deleted).

GDPR / data-export contract is part of the **export** action, not
delete. A delete after export is permanent.

### 10.5 Export

`POST /v1/admin/tenants/{id}:export` returns a signed S3 URL to a JSON
+ Parquet bundle:

- All tenant data (run, memory, audit_log, etc.) -- one file per table.
- A manifest with row counts per table + a Merkle root.
- Encrypted with customer-supplied KMS key OR per-tenant Vault key.

Generation is async (Temporal workflow in W4); for v1 it may take
hours for large tenants. Status polled via `GET /v1/admin/tenants/{id}/exports/{export_id}`.

### 10.6 Impersonation (support workflow)

For incident response only. Mechanism (W3+):

- Operator obtains a short-lived (15min) impersonation token via the
  admin API. Action is logged with both operator id and target
  tenant id.
- Token has a special `impersonator` claim; `TenantBinder` records it
  in `audit_log` for every action.
- `research`/`prod`: impersonation requires two-person approval; the
  approval is itself an audit row.

### 10.7 Tests

| Test | Layer | Asserts |
|---|---|---|
| `TenantCreateLifecycleIT` | E2E | provisioning sequence reaches `active` |
| `TenantSuspendBlocksWriteIT` | E2E | suspended tenant returns 403 on POST |
| `TenantSoftDeleteHidesIT` | E2E | soft-deleted tenant invisible to reads |
| `TenantHardDeleteCascadeIT` | E2E (W4) | hard-delete removes data from all tables |
| `TenantExportManifestIT` | E2E (W4) | export bundle contains expected row counts |
| `ImpersonationAuditIT` | Integration | every impersonated action has both ids in audit_log |

### 10.8 Wave landing

- W1: schema (`tenants` table + admin-API skeleton).
- W3: suspend / reactivate; impersonation MVP.
- W4: full delete (soft + hard scheduled); full export; Temporal
  workflow for long-running provisioning.
