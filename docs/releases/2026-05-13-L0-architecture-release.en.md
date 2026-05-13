# spring-ai-ascend L0 Architecture Release — 2026-05-13

> Status: **L0 architecturally ready**
> HEAD SHA: (updated after commit)
> Review cycles: 9 passes (2nd reviewer → post-seventh third-pass)
> Released: 2026-05-13

---

## Executive Summary

The spring-ai-ascend W0 runtime kernel is architecturally ready for L0 release. The architecture went through nine structured review cycles, each one categorizing defects into defined patterns, doing systematic self-audits beyond the reviewer's named symptoms, and landing structural (gate-enforced) prevention mechanisms for each pattern class. The final 4-shape defect model — REF-DRIFT, HISTORY-PARADOX, PERIPHERAL-DRIFT, GATE-PROMISE-GAP — defines the lens any future reviewer should use, and each shape now has a dedicated gate rule that prevents recurrence.

The W0 kernel is intentionally small. W1–W4 capabilities are staged as design contracts (ADRs + architecture-status.yaml deferred rows), not premature implementation. Nothing that is not shipped at W0 is described as shipped.

---

## Architecture Baseline at Release

| Metric | Value |
|--------|-------|
| §4 constraints | 43 (#1–#43) |
| Active ADRs | 45 (ADR-0001–ADR-0045) |
| Active gate rules | 25 (PowerShell + bash parity) |
| Active engineering rules | 11 (Rules 1–6, 9–10, 20–21, 25) |
| Deferred engineering rules | 14 (with documented re-introduction triggers) |
| Gate self-test cases | 24 (covering Rules 1–6, 16, 19, 22, 24, 25) |
| Maven tests | 101 (all GREEN) |

---

## Capabilities Shipped at W0

### HTTP Edge (agent-platform)

| Capability | Description |
|-----------|-------------|
| `GET /v1/health` | Health probe — no auth required, exempt from tenant/idempotency filters |
| `TenantContextFilter` | Binds `X-Tenant-Id` header to `TenantContextHolder` + MDC `tenant_id`; reads header only at W0 |
| `IdempotencyHeaderFilter` | Validates UUID shape of `Idempotency-Key` on POST/PUT/PATCH; 400 in research/prod on missing key; validation only (no dedup at W0) |
| `AppPostureGate` | Single construction path for posture-aware defaults; dev=permissive+WARN, research/prod=fail-closed |
| `WebSecurityConfig` | Permits `GET /v1/health`; requires auth on all other routes |

### Runtime Kernel (agent-runtime)

| Capability | Description |
|-----------|-------------|
| `Run` entity + DFA | 7 statuses (PENDING, RUNNING, SUSPENDED, SUCCEEDED, FAILED, CANCELLED, EXPIRED); `RunStateMachine` validates every transition |
| `RunLifecycle` SPI | `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`, `Checkpointer` — pure-Java SPIs; no framework imports |
| `RunContext` | Interface: `tenantId()`, `runId()`, `posture()`; sourced from SPIs, not HTTP ThreadLocal |
| Dev-posture executors | `SyncOrchestrator`, `SequentialGraphExecutor`, `IterativeAgentLoopExecutor`, `InMemoryRunRegistry`, `InMemoryCheckpointer` |
| `ResilienceContract` + `YamlResilienceContract` | Posture-aware circuit-breaker and retry configuration |
| Memory SPI scaffold | `GraphMemoryRepository` interface — no adapter ships at W0; Graphiti REST reference lands W1 (ADR-0034) |

### Contract and Guard Layer

| Capability | Description |
|-----------|-------------|
| OpenAPI v1 snapshot | `docs/contracts/openapi-v1.yaml` pinned; `ApiCompatibilityTest` fails if the snapshot diverges from the live spec |
| ArchUnit guards | `OrchestrationSpiArchTest`, `MemorySpiArchTest` (SPI-purity: no Spring imports in SPIs); `TenantPropagationPurityTest` (no HTTP ThreadLocal in runtime) |
| Architecture-sync gate | 25 active rules on PowerShell + bash; covers path existence, version consistency, route exposure, module dep direction, SPI contract truth, wave qualifiers, and 4-shape defect patterns |

---

## Posture Defaults

Set `APP_POSTURE` environment variable:

| Posture | Behavior |
|---------|---------|
| `dev` (default) | Permissive — in-memory backends allowed; missing config emits WARN, not exception |
| `research` | Fail-closed — required config present or ISE; durable persistence expected |
| `prod` | Fail-closed — same as research; stricter enforcement planned for W2 |

`AppPostureGate` is the single construction point; all runtime components receive their posture as a constructor argument, never via a call-site check.

---

## Deferred Capabilities (by wave)

### W1 (next milestone)

| Capability | ADR |
|-----------|-----|
| `IdempotencyStore` dedup (moves from validation to deduplication) | ADR-0027 |
| `TenantContextFilter` JWT `tenant_id` cross-check against `X-Tenant-Id` | ADR-0040 |
| Graphiti REST sidecar adapter (`spring-ai-ascend-graphmemory-starter`) | ADR-0034 |
| Posture boot guard (startup fail on missing required config) | ADR-0006 / §4 #2 |
| Micrometer tenant tag propagation | ADR-0023 |

### W2 (major capability expansion)

| Capability | ADR |
|-----------|-----|
| PostgresCheckpointer (durable run storage) | ADR-0021 |
| `Skill` SPI + `ResourceMatrix` (4 enforceability tiers) | ADR-0030, ADR-0038 |
| `RunDispatcher` + Control/Data/Heartbeat channel isolation | ADR-0031 |
| `PayloadCodec` SPI + CausalPayloadEnvelope write path | ADR-0022, ADR-0028 |
| OTel cross-boundary propagation | ADR-0023 |
| `SET LOCAL app.tenant_id` GUC + RLS policies | ADR-0005 |
| `TenantContextFilter` switch to JDBC GUC injection | §4 #37 |

### W3 (research-grade features)

| Capability | ADR |
|-----------|-----|
| `SandboxExecutor` SPI for `ActionGuard` Bound stage | ADR-0018 |
| Graph DSL conformance and hybrid RAG | — |

### W4 (long-horizon)

| Capability | ADR |
|-----------|-----|
| Temporal Java SDK durable workflows (child-workflow dispatch) | ADR-0003 |
| Dev-time trace replay via MCP server | ADR-0017 |
| `RunPlanSheet` toolset + eval harness | ADR-0032 |

---

## Verification at Release

```
Maven:        101 tests, 0 failures, 0 errors — BUILD SUCCESS
Gate (PS):    25/25 rules PASS — GATE: PASS
Gate (bash):  25/25 rules PASS — GATE: PASS
Self-tests:   24/24 PASS
```

All `shipped: true` capability rows in `docs/governance/architecture-status.yaml` have resolvable evidence on disk (validated by Gate Rule 24).

---

## The 4-Shape Defect Model

The nine review cycles revealed a recurring meta-pattern: each round of central-doc repair left peripheral entry-point drift behind. The third-pass cycle codified this as four defect shapes, each now with a structural prevention mechanism:

| Shape | Structural prevention | Gate rule |
|-------|-----------------------|-----------|
| **REF-DRIFT** — reference resolves but points to wrong file/wave/non-existent artifact | Every evidence field on a `shipped: true` row validated against disk at gate time | Rule 24 (`shipped_row_evidence_paths_exist`) |
| **HISTORY-PARADOX** — document simultaneously active and historical; body stale | `docs/plans/**` entirely historical; module ARCHITECTURE tables distinguish current vs planned | Archive policy + ADR-0043 |
| **PERIPHERAL-DRIFT** — central canonical file correct; README/Javadoc/sidebar still carries old claim | Case-sensitive scan of SPI Javadoc and active markdown for future-wave impl claims without wave qualifier; widened Rule 16a for W1 tenant-model replacement claims | Rule 25 (`peripheral_wave_qualifier`) + Rule 16 (`http_contract_w1_tenant_and_cancel_consistency`) |
| **GATE-PROMISE-GAP** — ARCHITECTURE/ADR prose promises semantic rule; gate enforces narrow literal | PS `-cmatch` for case-sensitive checks; bash `[[:space:]]` for POSIX portability; cross-platform parity tests; self-test coverage for new/strengthened rules | Rules 16a/19/22/24/25 + 24 self-tests |

Any future architecture review should audit using these four shapes before declaring a cycle clean.

---

## Historical Cycle Summary

9 review cycles, 2026-05-12 → 2026-05-13:

| Phase | Focus | Mechanism landed |
|-------|-------|-----------------|
| 2nd reviewer + competitive analysis | Vocabulary, OSS stack, competitive positioning | Ascend-native vocab; 9 YAML rows; deferred rules 18–19 |
| 3rd reviewer | Runtime correctness — lifecycle DFA, SPI tiers, context atomicity | RunStateMachine + EXPIRED; TenantPropagationPurityTest; Rules 20–21 |
| 4th reviewer | Contract drift in code — filter scope, speculative deps, API truth | IdempotencyHeaderFilter narrowed; Rule 25; first 10 gate rules |
| 5th reviewer | Payload and cognitive boundary | CausalPayloadEnvelope; Skill SPI; Rules 26–27 deferred |
| 6th+7th reviewer | Posture enforcement and corpus authority | AppPostureGate; plans archived; single wave authority; Rules 12–14 |
| Post-7th follow-up | HTTP contract consistency | W1 cross-check (not replace); PENDING start; POST /cancel; Rules 15–18 |
| Post-7th 2nd pass | META pattern — active corpus drift | ACTIVE_NORMATIVE_DOCS catalog; test-evidence gate; Rules 19–23 |
| Post-7th 3rd pass | 4-shape defect model canonized | Rules 24–25; Rule 19/22 strengthened; bash cut-field fix; 22→24 self-tests |
| L0 release | Final residual fix — Rule 16a widened | Rule 16a catches "switches-to-JWT" class; agent-platform README corrected |

---

## Known Limitations

The following are known, intentional, and documented:

- **No production-tier durable storage**: PostgresCheckpointer and RLS policies are W2 (ADR-0021). The W0 dev-posture executors use in-memory state that does not survive restart.
- **`IdempotencyStore` is a stub `@Component`**: validates `Idempotency-Key` header format only; no deduplication at W0 (ADR-0027 — W1 promotion).
- **No runtime GraphMemory adapter**: `spring-ai-ascend-graphmemory-starter` registers no bean at W0; the Graphiti REST reference adapter lands at W1 (ADR-0034).
- **Ops runbooks and Helm chart are skeletons**: not deployment-tested in this release; targeted for W1 hardening.
- **JMH performance baseline document exists**: no captured latency/throughput numbers at W0; W4 cadence.
- **9 ADR filenames lag their current titles**: cosmetic mismatch from early title edits; deferred to a dedicated `git mv` commit.

---

## References

- `ARCHITECTURE.md` — full §4 constraint list (#1–#43)
- `docs/adr/README.md` — ADR index (0001–0045)
- `docs/governance/architecture-status.yaml` — capability status ledger with shipped evidence
- `docs/cross-cutting/posture-model.md` — posture matrix
- `gate/check_architecture_sync.ps1` + `gate/check_architecture_sync.sh` — 25 gate rules
- `gate/test_architecture_sync_gate.sh` — 24 self-tests
- `CLAUDE.md` — 11 active engineering rules
