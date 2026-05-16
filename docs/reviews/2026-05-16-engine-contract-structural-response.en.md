---
affects_level: L0
affects_view: scenarios
proposal_status: accepted
authors: ["spring-ai-ascend architecture group"]
related_adrs: [ADR-0068, ADR-0069, ADR-0070, ADR-0071, ADR-0072, ADR-0073, ADR-0074, ADR-0075]
related_rules: [Rule-33, Rule-34, Rule-35, Rule-38, Rule-39, Rule-41, Rule-42, Rule-43, Rule-44, Rule-45, Rule-46, Rule-47, Rule-48]
affects_artefact: []
---

# Response to 2026-05-15 L0 Proposal — Runtime-Engine Contract for Heterogeneous Agent Execution

> **Date:** 2026-05-16
> **Status:** Accepted (full proposal absorbed; W2.x Engine Contract Structural Wave triggered)
> **Driver:** `docs/reviews/2026-05-15-l0architecture-lucio It-wave-1-supplement-runtime-engine-contract.en.md`
> **Wave plan:** `D:/.claude/plans/https-github-com-chaosxingxc-orion-spri-compressed-taco.md`

## 1. Background

The 2026-05-15 proposal raises five L0 architectural decisions for heterogeneous engine execution:

1. Lightweight engine configuration envelope (proposal §3, ADR-1)
2. Strict engine matching rule (proposal §4, ADR-2)
3. Runtime-owned middleware via engine lifecycle hooks (proposal §5, ADR-3)
4. Server-to-client (S2C) capability invocation (proposal §6, ADR-4)
5. Server-controlled evolution scope boundary (proposal §7, ADR-5)

Code inspection confirms four of the five concerns are **structurally absent today**, and the fifth (evolution scope) exists only as a metadata label on `module-metadata.yaml` without an in/out scope contract:

| Proposal section | State | Closest existing code |
|---|---|---|
| §3 Engine Envelope | ABSENT | `ExecutorDefinition` is a sealed compute DSL, not a governance/routing surface |
| §4 Strict Matching | ABSENT | `SyncOrchestrator.dispatch()` (`agent-runtime/.../inmemory/SyncOrchestrator.java:86-90`) uses an implicit `instanceof` switch — no engine_type discriminator on `Run` or any envelope |
| §5 Hook Surface + Runtime Middleware | PARTIAL | `SuspendSignal` + `ResilienceContract` exist; no hook framework — Hook SPI was scheduled to unfreeze in W2 Telemetry Vertical |
| §6 S2C Capability Callback | ABSENT | Cursor flow (`RunCursorResponse`, `AsyncRunDispatcher`) is C→S poll only; no callback path |
| §7 Evolution Scope | METADATA-ONLY | Rule 39 names `deployment_plane: evolution`; no in/out scope contract on `RunEvent` or any artefact |

## 2. Scope statement

This response is L0-level (touches governing principles) and primarily scenarios-view (cross-cuts logical / process / physical views). Per ADR-0068, all five new ADRs ship as YAML; per the wave invariant declared below, all five new contracts ship as YAML schemas with runtime-validated Java types — **no new prose-defined enum is permitted in this wave**.

## 3. Root cause / strongest interpretation (Rule 1)

1. **Observed motivation:** the platform commits to heterogeneous agent execution but has no first-class contract for *which engine runs which payload*, *how cross-cutting policies attach*, *how the server reaches client capabilities*, or *which execution data is in evolution scope*.
2. **Execution path:** any new engine integration today must either subclass `ExecutorDefinition` (compile-time wiring), patch `SyncOrchestrator.dispatch()` (forbidden by the spirit of ADR-0066 module independence), or invent a parallel registration path (Rule 6 violation).
3. **Root cause:** the runtime-engine contract is implicit — encoded in the sealed-pattern dispatch at `SyncOrchestrator.java:86-90` and in scattered Java types — rather than declared as a structured contract that both code and governance can reference.
4. **Evidence:** `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java:86-90`; `agent-runtime/src/main/java/ascend/springai/runtime/runs/Run.java:21-44` (no engine_type field); `docs/governance/architecture-graph.yaml` (no engine-contract nodes).

## 4. Proposed change — wave invariant + five ADRs

### 4.1 Wave invariant — "structural downstreaming"

Every new domain-level contract introduced by this wave **MUST** ship in the form:

```
schema (yaml under docs/contracts/)
  → Java type (record / sealed interface, validated against schema on construction)
    → runtime self-validate (registry reads schema at boot, fails fast on mismatch)
```

Rationale: 79 of the last ~158 closed defects belong to family F1 (text-form governance drift). Adding five more prose ADRs without a structural form would deterministically reproduce that family. Rule 48 (Schema-First Domain Contracts, landed in Phase 6) makes this invariant gate-enforced.

### 4.2 ADRs introduced

| ADR | Title | Phase | Schema |
|---|---|---|---|
| ADR-0071 | Engine Contract Structural Wave (umbrella) | 0 | — |
| ADR-0072 | Engine Envelope + Strict Matching | 1 | `docs/contracts/engine-envelope.v1.yaml` |
| ADR-0073 | Engine Lifecycle Hooks + Runtime Middleware | 2 | `docs/contracts/engine-hooks.v1.yaml` |
| ADR-0074 | S2C Capability Callback Protocol | 3 | `docs/contracts/s2c-callback.v1.yaml` |
| ADR-0075 | Evolution Scope Boundary | 4 | `docs/governance/evolution-scope.v1.yaml` |

### 4.3 New L0 principle

**P-M — Heterogeneous Engine Contract & Server-Sovereign Boundary.** The platform supports heterogeneous execution engines through a structured contract surface: a configuration envelope governs registration / routing / observability, strict matching prevents silent reinterpretation, runtime-owned middleware attaches via engine-declared lifecycle hooks, server-to-client capability invocation is an explicit asynchronous protocol bound to the suspend/resume loop, and the evolution mechanism manages only server-controlled execution scope by default. Operationalised by Rules 43–47.

### 4.4 Rules introduced (summary; full text lands in CLAUDE.md at Phase 7)

| Rule | One-liner | Phase |
|---|---|---|
| 43 | Engine Envelope Single Authority — dispatch only via `EngineRegistry` | 1 |
| 44 | Strict Engine Matching — `engine_type=X` only executed by adapter X | 1 |
| 45 | Runtime-Owned Middleware via Engine Hooks | 2 |
| 46 | S2C Callback Envelope + Lifecycle Bound | 3 |
| 47 | Evolution Scope Default Boundary | 4 |
| 48 | Schema-First Domain Contracts | 6 |

### 4.5 Engine Envelope — structural form (Phase 1, ADR-0072)

The envelope is intentionally **shallow** — it is a routing/governance surface, not a universal DSL (per proposal §3.2). The yaml schema declares required metadata (name, identifier, version, owner, engine_type, engine_version, compatibility), optional hint bags (runtime_hints, observability_hints), and an opaque `engine_specific_payload` that the *matched* engine validates. The Runtime never inspects or translates the engine-specific payload (proposal §3.3 risk #2 — hiding semantic differences — and risk #3 — silent behaviour drift — are structurally prevented).

### 4.6 Strict Matching — structural form (Phase 1, ADR-0072)

`EngineRegistry.resolve(envelope)` returns the adapter registered under `envelope.engine_type` or raises `EngineMatchingException`. The Run transitions to `FAILED` with reason `engine_mismatch`. **No fallback policy** — proposal §4.2's "explicit fallback policy" is interpreted in the strongest reading: the Runtime MUST reject; an external layer MAY retry with a corrected envelope.

### 4.7 Hook Surface + Runtime Middleware (Phase 2, ADR-0073)

The hook list (`before_llm_invocation`, `after_llm_invocation`, `before_tool_invocation`, `after_tool_invocation`, `before_memory_read`, `after_memory_write`, `before_suspension`, `before_resume`, `on_error`) is the canonical 9-hook surface declared in `engine-hooks.v1.yaml`. Hook ordering is **declared** (registration order) per proposal §5.4. Hook failure propagation default is **fail-fast**, with per-hook overrides allowed.

W2.x ships the SPI surface (`EngineHookSurface`, `RuntimeMiddleware`, `HookDispatcher`) and wires three hooks (`on_error`, `before_suspension`, `before_resume`) into reference executors — these are the three hook points the existing code already has natural call-sites for. The remaining six hooks (LLM × 2, tool × 2, memory × 2) ship in W2 Telemetry Vertical proper, alongside their first consumers (`TokenCounterHook`, `PiiRedactionHook`, `CostAttributionHook`, `LlmSpanEmitterHook`).

This early unfreeze is bounded: Phase 2 ships only the SPI surface; consumer hooks remain W2 scope. Documented in ADR-0073.

### 4.8 S2C Capability Callback (Phase 3, ADR-0074)

S2C is the **highest-risk** new ADR because it cross-cuts at least five existing rules. The next section (Phase 3a Cross-Rule Co-Design Audit) is the hard gate that MUST pass before any S2C code lands.

### 4.9 Evolution Scope (Phase 4, ADR-0075)

The default in/out scope contract lives in `docs/governance/evolution-scope.v1.yaml`. Every emitted `RunEvent` declares its `evolution_export` value (in_scope / out_of_scope / opt_in). Out-of-scope events MUST NOT be persisted to the evolution plane. Opt-in export requires a future `telemetry-export.v1.yaml` (W3 scope per proposal §7.4).

## 5. Phase 3a — S2C Cross-Rule Co-Design Audit (HARD GATE)

This is the Phase 3 hard gate. Per the wave plan, no S2C code lands until this matrix is reviewed and signed off. The audit answers: **for each existing rule the S2C callback touches, what is the explicit resolution that prevents a Class-3 envelope-propagation gap (cf. fourteenth-cycle SpawnEnvelope 11-dim defect)?**

### 5.1 Audit matrix

| Existing rule | S2C interaction | Resolution |
|---|---|---|
| **Rule 20 — RunStateMachine** | Callback request must suspend the Run; response must resume it; timeout must fail it. | Add `SuspendReason.AwaitClientCallback(UUID callbackId, String capabilityRef, Instant deadline)` filling the existing empty-record placeholder in `SuspendReason.java:37`. Reuse existing transitions: `RUNNING → SUSPENDED` (on signal), `SUSPENDED → RUNNING` (on response), `SUSPENDED → FAILED` (on timeout). **No new RunStatus.** |
| **Rule 35 — Three-Track Channel Isolation** | Callback request, callback response, and in-flight liveness must respect channel separation. | Add three logical mappings to `bus-channels.yaml`: `s2c.callback.request → control` (high-priority intent), `s2c.callback.response → data` (heavy payload allowed), `s2c.callback.heartbeat → rhythm` (liveness). **No new physical channel.** Each mapping documents the inherited 16 KiB cap on `data` (§4 #13). |
| **Rule 38 — No Thread.sleep in Business Code** | The waiting Run must not block a thread between request and response. | Suspension via `SuspendSignal(AwaitClientCallback)` is structurally forbidden from blocking — the `executeLoop` already handles SuspendSignal by persisting checkpoint and unwinding the call stack. Audited: no new `Thread.sleep` introduced in `s2c..` package. ArchUnit E83 enforces. |
| **Rule 41 — Skill Capacity Matrix** | Concurrent S2C callbacks must not saturate the cluster. | Declare new logical skill `s2c.client.callback` in `skill-capacity.yaml` with `capacity_per_tenant`, `global_capacity`, and `queue_strategy: suspend`. Over-cap callers receive `SuspendReason.RateLimited(s2c.client.callback, SKILL_CAPACITY_EXCEEDED)` per existing Rule 41.b path. Integration test E84 asserts the saturation behaviour. |
| **Rule 42 — Sandbox Permission Subsumption** | Client response is untrusted external input. | Runtime MUST validate response against `s2c-callback.v1.yaml` response schema before resume. Invalid response → `RunStatus.FAILED` with reason `s2c_response_invalid`. The validation runs *before* the resumed engine code sees the payload, so logical-vs-physical authority subsumption holds (proposal §6.4 trace correlation requirement is satisfied by the schema's `client_trace_id` field). |

### 5.2 Cross-cutting field propagation contract

To prevent the SpawnEnvelope-style propagation gap, the following fields are **mandatory across all S2C envelopes**:

- `callback_id` (UUID) — primary correlation key, present on request, response, and every log line in between
- `server_run_id` (UUID) — correlates back to the suspending Run
- `trace_id` (W3C 32-char) — correlates with Telemetry Vertical (ADR-0061/0062); MUST equal the suspending Run's trace_id
- `client_trace_id` (W3C 32-char on response only) — runtime correlates client-side execution with server-side
- `idempotency_key` (UUID, request only) — client may retry; runtime dedupes within window
- `capability_ref` (string, request only) — declared client capability id, MUST match a known client capability registry entry (W3 scope; W2.x reference impl uses an in-memory whitelist)

Every field above appears in every implementation (envelope class, transport SPI, response validator, integration test, audit log). The wave plan's Phase 3 enforcers (E81–E84) collectively assert presence of all six fields at every layer.

### 5.3 Audit conclusion

The matrix shows S2C can be added **without modifying any existing rule** — it consumes existing extension points (`SuspendReason` placeholder, `bus-channels.yaml` logical mappings, `skill-capacity.yaml` new skill, existing schema-validation idiom). **No rule supersession; no breaking change to Rules 20/35/38/41/42.**

This audit is the canonical reference for Phase 3. If Phase 3 implementation discovers a forced exception to this matrix, the matrix MUST be updated and re-reviewed before code merges.

## 6. Verification plan

- [ ] Phase 0: doctrine + P-M + ADR-0071 land; `gate/check_architecture_sync.sh` GREEN; `bash gate/build_architecture_graph.sh` regenerates without diff.
- [ ] Phase 1: `EngineRegistry.resolve()` GREEN with positive + mismatch tests; `mvn -pl agent-runtime test` GREEN; new gate rules 55–56 GREEN.
- [ ] Phase 2: hook surface + middleware SPI integration test GREEN; gate rule 57 GREEN.
- [ ] Phase 3: S2C round-trip + saturation + invalid-response + timeout integration tests GREEN; gate rule 58 GREEN.
- [ ] Phase 4: every `RunEvent` declares `evolution_export`; archunit GREEN; gate rule 59 GREEN.
- [ ] Phase 5: boot-time mismatch test GREEN (registered adapter not in `known_engines` → fail-fast).
- [ ] Phase 6: gate rule 60 (`schema_first_domain_contracts`) self-tests positive+negative GREEN.
- [ ] Phase 7: `bash gate/build_architecture_graph.sh && git diff --quiet docs/governance/architecture-graph.yaml`; release note links all 5 ADRs.

## 7. Rollout

- Wave: W2.x (between W1.x Phase 9 and W2 persistence wave)
- Freeze impact: none — this wave creates new artefacts; it does not unfreeze any phase-released L0/L1 artefact

## 8. Self-audit (Rule 9)

No open findings in any ship-blocking category for the response itself. Phase-by-phase ship gates are declared in the wave plan §5.

The five-rule co-design audit (§5 above) is the primary structural mitigation against the historical Class-3 hidden defect family. If a future review finds an S2C interaction not covered by §5.1, that is an audit defect, not a Phase 3 implementation defect — re-open §5 first.

---

## Authority

- ADR-0068 — Layered 4+1 + Architecture Graph as Twin Sources of Truth (front-matter discipline)
- ADR-0069 — Layer-0 Ironclad Rules (P-E..P-L precedent for new L0 principle promotion)
- ADR-0070 — Cursor Flow + Skill Capacity Runtime (precedent for narrowly-scoped runtime activation)
- ADR-0071 — Engine Contract Structural Wave (umbrella; this response is its accompanying review record)
- CLAUDE.md Rule 33, Rule 34 (review proposal front-matter discipline)
- CLAUDE.md Rule 28 (Code-as-Contract — every new constraint ships with enforcer in same wave)
- Gate Rule 39 (`review_proposal_front_matter`) — validates this front-matter
