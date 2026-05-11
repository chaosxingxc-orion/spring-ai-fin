# CLAUDE-deferred.md

Rules deferred from `CLAUDE.md` during the 2026-05-12 Occam pass. Each has an explicit
re-introduction trigger. Do not activate these rules before the trigger condition is met.

---

## Rule 8 — Operator-Shape Readiness Gate

**Re-introduction trigger**: first shippable jar with a real external dependency (LLM provider
or database) booting under a process supervisor.

**Rule**: No artifact ships until it runs in the exact operator shape downstream will use.
Green unit tests, green Layer 3 E2E, and a clean self-audit do not authorize delivery alone.

Before any artifact leaves the repo, the following must pass in a clean environment:

1. **Long-lived process** — managed process supervisor (systemd / docker / kubernetes); not a foreground shell run.
2. **Real external dependencies** — real LLM provider, real database — pointing at what downstream will use.
3. **Sequential real-dependency runs (N≥3)** — three back-to-back invocations; each reaches terminal success in ≤ `2 × observed_p95`; fallback count `== 0`.
4. **Cross-context resource stability** — runs 2 and 3 reuse the same client instances as run 1 (Rule 5 stress test).
5. **Lifecycle observability** — each run reports a non-null current stage within 30 s; finished-at populated on terminal.
6. **Cancellation round-trip** — cancel on live run → 200 + terminal; cancel on unknown id → 404.

Gate pass recorded in `docs/delivery/<date>-<sha>.md`. Unrecorded ≠ passed.

---

## Rule 11 — Contract Spine Completeness

**Re-introduction trigger**: first persistent record class committed (e.g., `RunRecord`,
`IdempotencyRecord` with Postgres-backed `IdempotencyStore`, or `ArtifactMetadata`).

**Rule**: Every persistent record must explicitly carry at minimum `tenant_id`, plus the
relevant subset of `{user_id, session_id, run_id, parent_run_id, attempt_id, capability_name}`.

**Pre-commit check**: any new contract DTO / entity must declare a `tenant_id` field unless
marked `// scope: process-internal` with reason. Process-internal value objects (budget structs,
validation results, stage directives) are exempt.
