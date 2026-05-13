# spring-ai-ascend L0 Architecture Release — 2026-05-13

> Status: **L0 architecturally ready** (final entrypoint truth review pass complete)
> Semantic release SHA: 82a1397
> Metadata follow-up SHAs: 776d4e7 (set `latest_semantic_pass_sha` to `82a1397`) + contract-review-response delivery (text-corrections + Gate Rule 26) + final entrypoint truth review delivery (boundary prose split + Gate Rule 27)
> Review cycles: 11 passes (2nd reviewer → post-seventh third-pass → L0 release-note contract review → L0 final entrypoint truth review)
> Released: 2026-05-13

---

## Executive Summary

The spring-ai-ascend W0 runtime kernel is architecturally ready for L0 release. The architecture went through nine structured review cycles, each one categorizing defects into defined patterns, doing systematic self-audits beyond the reviewer's named symptoms, and landing structural (gate-enforced) prevention mechanisms for each pattern class. The final 4-shape defect model — REF-DRIFT, HISTORY-PARADOX, PERIPHERAL-DRIFT, GATE-PROMISE-GAP — defines the lens any future reviewer should use, and each shape now has a dedicated gate rule that prevents recurrence.

The W0 kernel is intentionally small. W1–W4 capabilities are staged as design contracts (ADRs + architecture-status.yaml deferred rows), not premature implementation. Nothing that is not shipped at W0 is described as shipped.

---

## Architecture Baseline at Release

| Metric | Value |
|--------|-------|
| §4 constraints | 45 (#1–#45) |
| Active ADRs | 47 (ADR-0001–ADR-0047) |
| Active gate rules | 27 (PowerShell + bash parity) |
| Active engineering rules | 11 (Rules 1–6, 9–10, 20–21, 25) |
| Deferred engineering rules | 14 (with documented re-introduction triggers) |
| Gate self-test cases | 30 (covering Rules 1–6, 16, 19, 22, 24, 25, 26, 27) |
| Maven tests | 101 (all GREEN) |

---

## Capabilities Shipped at W0

### HTTP Edge (agent-platform)

| Capability | Description |
|-----------|-------------|
| `GET /v1/health` | Health probe — no auth required, exempt from tenant/idempotency filters |
| `TenantContextFilter` | Binds `X-Tenant-Id` header to `TenantContextHolder` + MDC `tenant_id`; reads header only at W0 |
| `IdempotencyHeaderFilter` | Validates UUID shape of `Idempotency-Key` on POST/PUT/PATCH; 400 in research/prod on missing key; validation only (no dedup at W0) |
| `WebSecurityConfig` | Permits `GET /v1/health`; requires auth on all other routes |

### Runtime Kernel (agent-runtime)

| Capability | Description |
|-----------|-------------|
| `Run` entity + DFA | 7 statuses (PENDING, RUNNING, SUSPENDED, SUCCEEDED, FAILED, CANCELLED, EXPIRED); `RunStateMachine` validates every transition |
| `Orchestration` SPI | `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`, `Checkpointer`, `ExecutorDefinition`, `RunContext` — pure-Java SPIs (verified by `OrchestrationSpiArchTest`); no framework imports. `RunLifecycle` (cancel/resume/retry) remains design-only for W2 — see ADR-0020 |
| `RunContext` | Interface methods: `runId()`, `tenantId()`, `checkpointer()`, `suspendForChild(parentNodeKey, childMode, childDef, resumePayload)`. Tenant identity is sourced from the runtime context, not from the HTTP ThreadLocal (Rule 21). Posture is **not** carried on `RunContext` at W0; posture is enforced via construction-time `AppPostureGate` calls in in-memory components |
| Dev-posture executors | `SyncOrchestrator`, `SequentialGraphExecutor`, `IterativeAgentLoopExecutor`, `InMemoryRunRegistry`, `InMemoryCheckpointer` |
| `AppPostureGate` | Construction-time posture guard (ADR-0035, Rule 6 single-construction-path). Called by `SyncOrchestrator`, `InMemoryRunRegistry`, `InMemoryCheckpointer` to fail-closed in research/prod when used as in-memory components. Not threaded through every runtime component — only the in-memory ones that require dev-only gating |
| `ResilienceContract` + `YamlResilienceContract` | Posture-aware circuit-breaker and retry configuration |
| Memory SPI scaffold | `GraphMemoryRepository` interface — no adapter ships at W0; Graphiti REST reference lands W1 (ADR-0034) |

### Contract and Guard Layer

| Capability | Description |
|-----------|-------------|
| OpenAPI v1 snapshot | `docs/contracts/openapi-v1.yaml` pinned; `OpenApiContractIT` (via `OpenApiSnapshotComparator`) fails if the pinned snapshot diverges from the live spec at `/v3/api-docs`. `ApiCompatibilityTest` is ArchUnit-only — it enforces SPI purity and module-dependency direction, not the OpenAPI snapshot diff |
| ArchUnit guards | `OrchestrationSpiArchTest`, `MemorySpiArchTest` (SPI-purity: no Spring imports in SPIs); `ApiCompatibilityTest` (no `com.alibaba.cloud.ai.*` imports + agent-platform→agent-runtime dep ban); `TenantPropagationPurityTest` (no HTTP ThreadLocal in runtime) |
| Architecture-sync gate | 27 active rules on PowerShell + bash; covers path existence, version consistency, route exposure, module dep direction, SPI contract truth, wave qualifiers, 4-shape defect patterns, release-note shipped-surface truth, and active-entrypoint baseline truth |

---

## Posture Defaults

Set `APP_POSTURE` environment variable:

| Posture | Behavior |
|---------|---------|
| `dev` (default) | Permissive — in-memory backends allowed; missing config emits WARN, not exception |
| `research` | Fail-closed — required config present or ISE; durable persistence expected |
| `prod` | Fail-closed — same as research; stricter enforcement planned for W2 |

`AppPostureGate.requireDevForInMemoryComponent(name)` is the single construction-time read of `APP_POSTURE` (Rule 6 single-construction-path; ADR-0035). It is called by the three in-memory runtime components that require dev-only gating — `SyncOrchestrator`, `InMemoryRunRegistry`, `InMemoryCheckpointer` — during construction. Posture is **not** threaded through `RunContext` or passed as an argument to every runtime component; only those in-memory ones that must fail-closed in research/prod call the gate.

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
Gate (PS):    27/27 rules PASS — GATE: PASS
Gate (bash):  27/27 rules PASS — GATE: PASS
Self-tests:   30/30 PASS
```

All `shipped: true` capability rows in `docs/governance/architecture-status.yaml` have resolvable evidence on disk (validated by Gate Rule 24). The release-note text itself is validated for shipped-surface truth by Gate Rule 26 — `RunLifecycle`, `RunContext.posture()`, `ApiCompatibilityTest`-as-OpenAPI-snapshot, and `AppPostureGate` placement/breadth overclaims are mechanically rejected before commit.

---

## The 4-Shape Defect Model (+ GATE-SCOPE-GAP)

The first nine review cycles revealed a recurring meta-pattern: each round of central-doc repair left peripheral entry-point drift behind. The third-pass cycle codified this as four defect shapes. The tenth cycle (L0 release-note contract review) surfaced a fifth: **GATE-SCOPE-GAP** — a truth-rule's pattern catalog is exhaustive but its *token catalog* is artifact-specific, so a new artifact class (e.g. `docs/releases/*.md`) entering the active corpus inherits zero instrumentation until a dedicated rule is added. ADR-0046 + Gate Rule 26 close this gap for release notes.

| Shape | Structural prevention | Gate rule |
|-------|-----------------------|-----------|
| **REF-DRIFT** — reference resolves but points to wrong file/wave/non-existent artifact | Every evidence field on a `shipped: true` row validated against disk at gate time | Rule 24 (`shipped_row_evidence_paths_exist`) |
| **HISTORY-PARADOX** — document simultaneously active and historical; body stale | `docs/plans/**` entirely historical; module ARCHITECTURE tables distinguish current vs planned | Archive policy + ADR-0043 |
| **PERIPHERAL-DRIFT** — central canonical file correct; README/Javadoc/sidebar still carries old claim | Case-sensitive scan of SPI Javadoc and active markdown for future-wave impl claims without wave qualifier; widened Rule 16a for W1 tenant-model replacement claims | Rule 25 (`peripheral_wave_qualifier`) + Rule 16 (`http_contract_w1_tenant_and_cancel_consistency`) |
| **GATE-PROMISE-GAP** — ARCHITECTURE/ADR prose promises semantic rule; gate enforces narrow literal | PS `-cmatch` for case-sensitive checks; bash `[[:space:]]` for POSIX portability; cross-platform parity tests; self-test coverage for new/strengthened rules | Rules 16a/19/22/24/25 + 28 self-tests |
| **GATE-SCOPE-GAP** — truth-rule's pattern catalog is right but token catalog doesn't cover a sibling artifact class | Dedicated rule per release artifact: name guards, method-list guards, test-attribution guards, scope-claim guards | Rule 26 (`release_note_shipped_surface_truth`) |

Any future architecture review should audit using these five shapes before declaring a cycle clean.

---

## Historical Cycle Summary

10 review cycles, 2026-05-12 → 2026-05-13:

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
| L0 release-note contract review | Release-note shipped-surface drift caught: P1×2 (`RunLifecycle` SPI label, `RunContext.posture()`), P2 (`ApiCompatibilityTest` test-attribution), P3 (`AppPostureGate` placement + breadth), P4 (HEAD-SHA ambiguity) | ADR-0046 + Gate Rule 26 (`release_note_shipped_surface_truth`) with 4 sub-checks (RunLifecycle name guard, RunContext method-list guard, OpenAPI test attribution, AppPostureGate scope guard); §4 #44; +4 self-tests (24→28); release-note text corrected to match Java surface |
| L0 final entrypoint truth review | Active-entrypoint drift caught: P1 (root README baseline drift — CANONICAL-DRIFT between README counts and `architecture-status.yaml.allowed_claim`), P2 (root + agent-runtime ARCHITECTURE.md §1 system-boundary prose using present tense for W1-W4 capabilities — TEMPORAL-OVERREACH), P3 (header-metadata staleness convention undefined) | ADR-0047 + Gate Rule 27 (`active_entrypoint_baseline_truth`) cross-checks README counts against canonical YAML; §1 boundary prose split into target architecture (W1–W4) vs W0 shipped subset in root + agent-runtime ARCHITECTURE.md; header-metadata convention codified (content-change-tracked, not re-review-tracked); §4 #45; +2 self-tests (28→30); root README baseline already corrected at SHA `0ed6a35` via prior README refresh |

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

- `ARCHITECTURE.md` — full §4 constraint list (#1–#45)
- `docs/adr/README.md` — ADR index (0001–0047)
- `docs/governance/architecture-status.yaml` — capability status ledger with shipped evidence
- `docs/cross-cutting/posture-model.md` — posture matrix
- `gate/check_architecture_sync.ps1` + `gate/check_architecture_sync.sh` — 27 gate rules
- `gate/test_architecture_sync_gate.sh` — 30 self-tests
- `CLAUDE.md` — 11 active engineering rules
- `docs/reviews/2026-05-13-l0-release-note-contract-review.en.md` — tenth-cycle review input
- `docs/reviews/2026-05-13-l0-final-entrypoint-truth-review.en.md` — eleventh-cycle review input
- `docs/adr/0046-release-note-shipped-surface-truth.md` — Gate Rule 26 + GATE-SCOPE-GAP closure
- `docs/adr/0047-active-entrypoint-truth-and-system-boundary-prose-convention.md` — Gate Rule 27 + CANONICAL-DRIFT closure + system-boundary prose convention
