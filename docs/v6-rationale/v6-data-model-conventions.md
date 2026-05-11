> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# Data Model Conventions -- cross-cutting policy

> Owner: platform + runtime | Wave: W0 (schema spine) + per-wave per-table | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Pins schema, naming, ID, timestamp, audit-column, and multi-tenant
conventions every Flyway migration must follow. Replaces implicit
"do whatever" patterns. Owned jointly by `agent-platform` (platform
tables) and `agent-runtime` (runtime tables).

## 2. Naming

- Tables: snake_case singular nouns. `run`, `outbox_event`,
  `tenant_workspace`, `audit_log`, `tool_registry`. Plural is OK only
  for many-to-many join tables.
- Columns: snake_case nouns. `tenant_id`, `created_at`, `cost_usd`.
- Primary key column: `<table>_id` for surrogate; just `id` is allowed
  on tables that have a natural key + a generated id.
- Foreign key columns: `<referenced_table>_id`.
- Booleans: `is_<adjective>` or `has_<noun>`. `is_active`, `has_pii`.
- Timestamps: `_at` suffix. `created_at`, `started_at`, `finished_at`,
  `expired_at`.
- Counters: `_count` suffix. `retry_count`, `token_count`.
- Money: `_usd` (or `_cents` for integer). Never plain numeric.
- JSON: `<noun>_json` or `<noun>_payload`. Always `jsonb`, not `json`.

## 3. Identifiers

- All surrogate IDs are UUIDv7 (time-ordered) generated at the app via
  `java.util.UUID` + a UUIDv7 helper. Postgres column type:
  `uuid NOT NULL`.
- Reasoning: time-ordered IDs play well with B-tree indexes under
  multi-tenant load; do not require a sequence; safe across replicas.
- ID factories live in `agent-platform/contracts/` (`Ids.runId()`,
  `Ids.tenantId()`, etc.) so every module imports the same generator.
- External IDs (provider IDs, MCP server IDs) are TEXT, not UUID.

## 4. Required columns on every tenant-scoped table

| Column | Type | Default | Notes |
|---|---|---|---|
| `<pk>_id` or `id` | uuid | application | UUIDv7 |
| `tenant_id` | uuid NOT NULL | -- | RLS predicate; assertion trigger fires when GUC empty |
| `created_at` | timestamptz NOT NULL | `now()` | UTC stored |
| `updated_at` | timestamptz NOT NULL | `now()` | trigger updates on UPDATE |
| `version` | integer NOT NULL DEFAULT 0 | -- | optimistic concurrency control |

Optional but encouraged:

| Column | Type | When |
|---|---|---|
| `created_by` | uuid | when an authenticated user is the actor |
| `updated_by` | uuid | same as above |
| `deleted_at` | timestamptz | for soft-delete tables |
| `meta` | jsonb | for extensible non-indexed metadata |

## 5. Multi-tenant patterns

- Every tenant table has a row-level security (RLS) policy:
  ```sql
  ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;
  CREATE POLICY <t>_tenant_isolation ON <t>
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
  ```
- Every tenant table has a `BEFORE INSERT OR UPDATE` trigger that
  raises if `current_setting('app.tenant_id', true)` is empty.
- Index policy: `(tenant_id, <next sort key>)` is the leading B-tree
  composite for any table queried by tenant.
- No table is shared across tenants (no "tenants table without RLS"
  exception except `tenants` itself, which is admin-only).

## 6. Timestamps

- All `timestamptz` (UTC).
- Application generates timestamps; DB `now()` is the default but
  application-set values win.
- Postgres timezone: `UTC` server-wide; pinned in Helm config.

## 7. Soft-delete vs hard-delete

| Policy | Tables |
|---|---|
| Soft-delete (`deleted_at`) | `tool_registry`, `prompt_version`, `tenant_workspace` |
| Hard-delete | `idempotency_dedup` (TTL), `outbox_event` (post-publish), `run_memory` (TTL) |
| Append-only (no delete) | `audit_log`, `run`, `feedback` |

The role used by app code has `DELETE` only on hard-delete tables.

## 8. Indexes

- Always a `(tenant_id, ...)` composite for tenant-queried tables.
- `created_at DESC` index on append-only tables for chronological reads.
- `pgvector` `ivfflat` or `hnsw` index on embedding columns (W3).
- No `lower(...)` functional indexes in v1 (use citext column types if needed).

## 9. JSONB usage

- Use for non-indexed extensible metadata (`meta jsonb`).
- Use for structured payloads where schema evolves (`prompt_payload jsonb`).
- Do NOT use for fields that are queried as primary filters; promote
  to a column.
- Document the JSON schema in the L2 module's doc.

## 10. Migrations (Flyway)

- One migration per logical change; never edit applied migration files.
- File name: `V<num>__<short_name>.sql` (e.g., `V3__run.sql`).
- Numbering pace: per module owner -- platform uses 1-99, runtime
  uses 100-199, eval uses 200-299.
- Per-module migration directory:
  - `agent-platform/src/main/resources/db/migration/`
  - `agent-runtime/src/main/resources/db/migration/`
  - `agent-eval/src/main/resources/db/migration/`
- Composite project Flyway loads all three classpath roots.
- Production migrations always include rollback notes in a comment.

## 11. Reserved schemas / roles

| Role | Grants | Used by |
|---|---|---|
| `app_role` | SELECT/INSERT/UPDATE on tenant tables; INSERT only on `audit_log` and append-only tables | runtime app process |
| `migration_role` | DDL grants | Flyway only |
| `readonly_role` | SELECT only on tenant tables | reporting jobs (W4+) |

## 12. Schema spine (v1 tables; W0..W4)

| Table | Owner | Wave |
|---|---|---|
| `tenants` | platform | W1 (admin-only) |
| `tenant_workspace` | platform | W1 |
| `idempotency_dedup` | platform | W1 |
| `tenant_config` | platform | W2 |
| `health_check` | platform | W0 |
| `run` | runtime | W2 |
| `run_memory` | runtime | W2 |
| `session_memory` | runtime | W2 |
| `long_term_memory` (pgvector) | runtime | W3 |
| `outbox_event` | runtime | W2 |
| `outbox_event_dlq` | runtime | W3 |
| `audit_log` | runtime | W3 |
| `tool_registry` | runtime | W3 |
| `prompt_version` | runtime | W3 |
| `tenant_budget` | runtime | W3 |
| `feedback` | runtime | W3 |
| `eval_run` | eval | W4 |
| `eval_result` | eval | W4 |

Total: 18 tables. Each has its own L2 reference describing schema
(column-by-column) when the table is in its W landing.

## 13. Cross-module Java type ownership

| Type | Owns | Used by |
|---|---|---|
| `Tenant` | `agent-platform/contracts` | platform + runtime |
| `Run` | `agent-platform/contracts` | platform + runtime |
| `RunStatus` (enum) | `agent-platform/contracts` | platform + runtime |
| `IdempotencyKey` | `agent-platform/contracts` | platform |
| `ActionEnvelope` | `agent-runtime/action` | runtime only |
| `LlmRequest` / `LlmResponse` | `agent-runtime/llm` | runtime |
| `ToolDescriptor` | `agent-runtime/tool` | runtime |
| `MemoryScope` (enum) | `agent-runtime/memory` | runtime |

`agent-platform/contracts` is the only module that exports types both
platform and runtime depend on. This avoids cyclic dependencies
between the two modules.

## 14. Tests

| Test | Layer | Asserts |
|---|---|---|
| `RlsPolicyCoverageIT` | Integration | every tenant table has RLS policy + assertion trigger |
| `MigrationConventionLintIT` | CI | every migration file matches `V<num>__<name>.sql` + has rollback comment |
| `IdGenerationIT` | Unit | UUIDv7 monotonicity within a millisecond bucket |
| `TimestampUtcIT` | Integration | DB `created_at` is UTC |
| `JsonbColumnTypeIT` | CI | no `json` column types in any migration (only `jsonb`) |

## 15. Out of scope

- Cross-region sharding / per-region partitioning (W4+).
- Multi-version concurrency beyond `version` column (no separate
  history table in v1).
- Event sourcing (not used).
- CQRS write/read split (W4+ post).

## 16. References

- `agent-platform/tenant/ARCHITECTURE.md` (RLS protocol)
- `agent-platform/contracts/ARCHITECTURE.md` (types + IDs)
- `docs/cross-cutting/security-control-matrix.md` (RLS controls)
