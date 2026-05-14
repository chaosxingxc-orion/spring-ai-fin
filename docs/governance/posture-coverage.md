# Posture-Aware Defaults — Coverage Ledger

> Companion to `CLAUDE.md` Rule 10. The rule states the contract; this file
> records which modules currently honour it under each posture.

Authority: ADR-0064 (governing principles + cleanup); content originally
inline in `CLAUDE.md` Rule 10 prior to the Layer-0 cleanup.

Postures: `dev` (permissive) / `research` (fail-closed) / `prod` (fail-closed).
Selected via the `APP_POSTURE` environment variable (default `dev`). Read once
at startup; never hard-coded at call sites.

---

## L1 posture coverage

| Module | dev | research | prod |
|--------|-----|----------|------|
| `agent-platform` — tenant filter, idempotency filter, `IdempotencyStore` | warn + permissive | reject / throw | reject / throw |
| `agent-platform` — JWT validation, posture boot guard, `@RequiredConfig` | warn + permissive | reject / throw at startup | reject / throw at startup |
| `agent-runtime` — `SyncOrchestrator`, `InMemoryRunRegistry`, `InMemoryCheckpointer` | permissive (`AppPostureGate.requireDev` passes with WARN) | `IllegalStateException` at construction | `IllegalStateException` at construction |
| `agent-runtime` — `InMemoryCheckpointer` 16-KiB payload cap (§4 #13) | WARN on oversize | throw on oversize | throw on oversize |
| `spring-ai-ascend-graphmemory-starter` | no bean registered | no bean registered | no bean registered |

Tests MUST cover `dev` and `research` paths for any new contract.

---

## Enforcement entry points

- `AppPostureGate.requireDevForInMemoryComponent(...)` — Rule 6 single-construction-path for posture reads.
- `PostureBootGuard` — startup-time fail-closed for `@RequiredConfig` fields under research/prod (E21).
- Gate Rule 12 (`inmemory_orchestrator_posture_guard_present`) — verifies `AppPostureGate.requireDev` appears in all three in-memory components per ADR-0035.
- `docs/cross-cutting/posture-model.md` — canonical posture-truth ledger; every posture-aware component row MUST appear there.

References: `ARCHITECTURE.md` §4 #2, §4 #32; ADR-0035; ADR-0058.
