# 0005. Row-level security with SET LOCAL transaction-scoped GUC, not per-connection reset

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** HikariCP shares connections across tenants; tenant binding must be transactional, not connection-scoped.

## Context

HikariCP shares database connections across tenants. Any approach that binds tenant
identity to the connection rather than to the transaction creates a race window where
a reused connection can carry a stale tenant GUC into a new request. This was proven
flawed in cycle-2/3/5 reviews of the per-checkout reset approach.

## Decision Drivers

- Postgres semantics auto-discard `SET LOCAL` GUCs on transaction end, eliminating the race window.
- Spring's `TransactionSynchronization` fits cleanly with the SET LOCAL approach.
- A trigger that fires fail-closed when the GUC is empty provides defense in depth.
- Per-tenant connection pools create multi-tenant scaling problems.

## Considered Options

1. `SET LOCAL app.tenant_id` inside every transaction; auto-discarded by Postgres on commit/rollback.
2. Per-checkout reset (`HikariConnectionResetPolicy`) -- proven flawed in cycle-2/3/5 review.
3. Per-tenant connection pool -- simpler isolation; multi-tenant scaling problem.

## Decision Outcome

**Chosen option:** Option 1 (SET LOCAL + assertion trigger on every tenant table), because
Postgres guarantees GUC auto-discard on transaction end, removing the race window that
made Option 2 unsafe, while the trigger enforces fail-closed behavior as defense in depth.

### Consequences

**Positive:**
- No race window: Postgres auto-discards the GUC on commit/rollback.
- Trigger provides fail-closed defense in depth when GUC is absent.
- Integrates cleanly with Spring-managed transactions.

**Negative:**
- Every L2 module that opens a transaction must use a Spring-managed transaction; raw JDBC is forbidden.
- Connection-pool tuning must use HikariCP 5.x with virtual-thread-friendly defaults.

### Reversal cost

medium (changing isolation strategy means rewriting TenantBinder and every assertion trigger)

## Pros and Cons of Options

### Option 1: SET LOCAL app.tenant_id per transaction

- Pro: Postgres auto-discard eliminates the race window on connection reuse.
- Pro: Spring TransactionSynchronization integration is clean.
- Pro: Trigger enforces fail-closed behavior as defense in depth.
- Con: All database access must go through Spring-managed transactions.
- Con: Raw JDBC bypasses the tenant binding and is forbidden.

### Option 2: Per-checkout reset via HikariConnectionResetPolicy

- Pro: Transparent to application code.
- Con: Proven flawed in cycle-2/3/5 reviews; race window between reset and first query.
- Con: Reset policy ordering is not guaranteed under all HikariCP configurations.

### Option 3: Per-tenant connection pool

- Pro: Cleanest isolation; each tenant's pool is completely independent.
- Con: Pool count scales with tenant count; multi-tenant scaling becomes a resource problem.
- Con: Connection overhead is prohibitive when tenant count grows.

## References

- `agent-platform/tenant/ARCHITECTURE.md`
- `docs/cross-cutting/security-control-matrix.md` C3-C5
