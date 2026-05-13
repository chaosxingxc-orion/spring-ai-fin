# Whitepaper Alignment Self-Audit — 2026-05-13

> **Mandatory self-audit per reviewer requirement** in `docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md` §"Mandatory Systematic Self-Audit". Eight required sections; one of two exact conclusion strings.
>
> **Scope of this audit**: the whitepaper-alignment remediation cycle landing in this commit. Audited against the reviewer's eight criteria.
>
> **Honesty stance**: this audit is written to surface gaps, not to optimise positive language. Per reviewer: "be honest, not optimistic; do not force a PASS conclusion".

---

## Section 1 — Whitepaper concept inventory

Major concepts present in `docs/spring-ai-ascend-architecture-whitepaper-en.md`:

1. **W0 cold-state fortress** (Chapter 1) — already shipped.
2. **C/S separation** (§2.1).
3. **Task Cursor** (§2.1–2.3).
4. **N:1 cross-business multiplexing** (§2.2).
5. **Dynamic Hydration** (§2.3).
6. **Three-state cursor handoff: Sync State / Sub-Stream / Yield & Handoff** (§2.3).
7. **Dual-track memory isolation: business ontology (C-side) vs trajectory (S-side)** (§2.4).
8. **Placeholder exemption rule** (§2.4).
9. **Graph mode vs Dynamic mode coexistence** (§3.0).
10. **Full Trace (dynamic) vs Node Snapshot (graph)** (§3.1).
11. **Heterogeneous nesting via interrupt-and-yield** (§3.2).
12. **Lazy mounting + bypass context storage** (§3.3).
13. **Skill Topology Scheduler** (§4.1).
14. **Two-axis resource arbitration (tenant quota × global skill capacity)** (§4.1).
15. **C-side business degradation authority vs S-side compute compensation** (§4.2).
16. **Session/context orthogonal decoupling + memory paging** (§4.3).
17. **Hot migration** (§4.3).
18. **Workflow Intermediary + push-pull mailbox + backpressure** (§5.1).
19. **Three-track physical bus isolation: Control / Data / Rhythm** (§5.2).
20. **Pre-authorized capability access + delegate bidding + permission issuance** (§5.3).
21. **Decentralized rhythm management + Chronos Hydration** (§5.4).
22. **Microservice-dictatorship trap to avoid** (§1.3).
23. **Monolithic asynchronous loss-of-control trap to avoid** (§1.3).

---

## Section 2 — Exact architecture mapping

Each concept → exact current artifact. No substitution of adjacent concepts.

| # | Concept | Exact current artifact | Mapping confidence |
|---|---|---|---|
| 1 | W0 cold-state fortress | ARCHITECTURE.md §5 (shipped capabilities); 101 Maven tests; gate rules 1–29; `RunStateMachine`, `TenantContextFilter`, `IdempotencyHeaderFilter`, `AppPostureGate`, `Run` entity, in-memory executors | Exact |
| 2 | C/S separation | ADR-0049 §"Protocol vocabulary"; ARCHITECTURE.md §4 #47; matrix row "C/S separation" | Exact — named at contract level |
| 3 | Task Cursor | ADR-0049 `TaskCursor` named contract; matrix row "Task Cursor" | Exact — named at contract level |
| 4 | N:1 cross-business multiplexing | Not yet named at contract level. Implicitly compatible with ADR-0048 (multiple Agent Service instances) + ADR-0049 (per-`HydrationRequest` tenant scoping) | **Gap — design-only by composition** |
| 5 | Dynamic Hydration | ADR-0049 `HydrationRequest` + `HydratedRunContext` named contracts | Exact — named at contract level |
| 6 | Sync State / Sub-Stream / Yield & Handoff | ADR-0049 `SyncStateResponse` / `SubStreamFrame` / `YieldResponse` + `ResumeEnvelope` | Exact — named at contract level |
| 7 | Business ontology (C-side) vs trajectory (S-side) ownership | ADR-0051 ownership table; ADR-0034 forward note; matrix rows for ownership | Exact — first-class boundary now |
| 8 | Placeholder exemption rule | ADR-0051 `PlaceholderPreservationPolicy` + `SymbolicReturnEnvelope` | Exact — first-class ship-blocking rule |
| 9 | Graph mode vs Dynamic mode coexistence | ARCHITECTURE.md §4 #9; `Run.mode` (GRAPH \| AGENT_LOOP); `Orchestrator` SPI; reference impls `SequentialGraphExecutor` + `IterativeAgentLoopExecutor` | Exact — shipped at SPI level |
| 10 | Full Trace vs Node Snapshot | ARCHITECTURE.md §4 #9 (dual-mode); matrix row "Full Trace vs Node Snapshot"; `IterativeAgentLoopExecutor` (full trace) + `SequentialGraphExecutor` (node snapshot) | Exact — shipped at reference-impl level |
| 11 | Heterogeneous nesting via interrupt-and-yield | `SuspendSignal` SPI; `Orchestrator.run` catches and dispatches child Run; `NestedDualModeIT` proves 3-level graph↔agent-loop↔graph | Exact — shipped |
| 12 | Lazy mounting + bypass context storage | ARCHITECTURE.md §4 #13 `PayloadStore` SPI; `InMemoryCheckpointer.MAX_INLINE_PAYLOAD_BYTES = 16 KiB`; `PayloadStoreRef` (deferred) | Partial — 16-KiB cap shipped; `PayloadStore` design-only |
| 13 | Skill Topology Scheduler | ADR-0052; ARCHITECTURE.md §4 #50; `SkillResourceMatrix` extended from ADR-0030/0038; matrix row "Skill Topology Scheduler" | Exact — named at contract level |
| 14 | Two-axis arbitration | ADR-0052 ("Horizontal axis: Tenant Quota; Vertical axis: Global Skill Capacity") | Exact |
| 15 | C-side degradation authority | ADR-0049 degradation-authority section (`ComputeCompensation`, `BusinessDegradationRequest`, `GoalMutationProhibition`); matrix row | Exact — first-class red line |
| 16 | Session/context decoupling | ARCHITECTURE.md §4 #9 (Run decoupled from HTTP); §4 #10 (`AgentSubject` deferred); matrix row | Partial — session decoupling shipped; `AgentSubject` long-horizon identity deferred W2 |
| 17 | Hot migration | Not yet named. SPI shape supports it (Checkpointer / RunRepository / SuspendSignal serialize state across JVM per ADR-0024). | **Gap — design-only by composition** |
| 18 | Workflow Intermediary + mailbox + backpressure | ADR-0050; ARCHITECTURE.md §4 #48; matrix row "Workflow Intermediary" | Exact — named at contract level |
| 19 | Three-track physical bus | ADR-0050 (cross-service); ADR-0031 (in-process); ADR-0048 amended; matrix row | Exact — Rhythm restored as independent track |
| 20 | Pre-authorized access + bidding + permission issuance | ADR-0052 `CapabilityRegistry` + `BidRequest`/`BidResponse` + `PermissionEnvelope`; matrix rows | Exact — named at contract level |
| 21 | Chronos Hydration | ADR-0050 `SleepDeclaration` + `WakeupPulse` + `TickEngine` + `ChronosHydration` flow; matrix row | Exact — flow named end-to-end |
| 22 | Microservice-dictatorship trap avoided | ADR-0048 microservice-trap mitigation section ("microservice for Service Layer, NOT per-agent"; inter-agent calls intent-routed through bus) | Exact |
| 23 | Monolithic asynchronous loss-of-control trap avoided | Implicit — `RunStateMachine` DFA enforces lifecycle; `Orchestrator` SPI prevents coroutine free-fall; `SuspendSignal` is checked exception, not implicit `await` | Partial — implicit at code level; not explicitly named as anti-trap |

**Mapping completeness**: 18 of 23 concepts **exactly** mapped at contract level. 5 are **partial or gap** (concepts #4, #12, #16, #17, #23). The 5 gaps are documented in Section 8 (Explicit residual-risk statement).

---

## Section 3 — Contract-equivalence check

For each mapped concept, does the current artifact have the same **boundary**, **authority**, **data ownership**, **failure behavior**, and **lifecycle semantics** as the whitepaper?

| # | Concept | Boundary | Authority | Data ownership | Failure behavior | Lifecycle | Equivalent? |
|---|---|---|---|---|---|---|---|
| 2 | C/S separation | ✓ ADR-0049 C-side / S-side roles match whitepaper | ✓ | ✓ | ✓ (Yield/Resume) | ✓ | Yes |
| 3 | Task Cursor | ✓ opaque to S-side | ✓ C-side authoritative | ✓ C-side owns | ✓ Resume-on-mismatch behavior named | ✓ | Yes |
| 5 | Dynamic Hydration | ✓ | ✓ | ✓ | ✓ Yield-on-hydration-failure | ✓ | Yes |
| 6 | Three-state handoff | ✓ | ✓ | ✓ (non-persistence guidance for SubStreamFrame) | ✓ (YieldResponse expiry → EXPIRED) | ✓ | Yes |
| 7 | Memory ownership | ✓ ADR-0051 ownership table matches whitepaper §2.4 | ✓ delegation contract required | ✓ | ✓ | ✓ | Yes |
| 8 | Placeholder exemption | ✓ ship-blocking | ✓ no resolution without DelegationGrant | ✓ C-side authoritative | ✓ violation = ship-blocking defect | ✓ symbolic preservation through trajectory | Yes |
| 9 | Graph/Dynamic coexistence | ✓ SPI surface unified via `Run.mode` | ✓ executor-local state | ✓ | ✓ via `SuspendSignal` | ✓ shipped at reference-impl level | Yes |
| 10 | Full Trace vs Node Snapshot | ✓ executor type discriminates | ✓ | ✓ | ✓ | ✓ | Yes |
| 11 | Heterogeneous nesting | ✓ `SuspendSignal` is single primitive | ✓ Orchestrator dispatches; child runs in isolated sandbox | ✓ payload addressed via parent-resume | ✓ via `SuspendReason.ChildRun` | ✓ shipped W0 reference | Yes — shipped |
| 12 | Lazy mounting | ✓ 16-KiB cap enforces ref-vs-inline boundary | Partial — `PayloadStore` SPI deferred | ✓ | ✓ posture-aware throw in research/prod | ✓ | Partial — full PayloadStore deferred W2 |
| 13 | Skill Topology Scheduler | ✓ ADR-0052 two-axis | ✓ S-side owns scheduling | ✓ | ✓ `SkillSaturationYield` releases LLM thread | ✓ short-lived `PermissionEnvelope` | Yes |
| 14 | Two-axis arbitration | ✓ | ✓ | ✓ | ✓ | ✓ | Yes |
| 15 | Degradation authority | ✓ `ComputeCompensation` (S-side) vs `BusinessDegradationRequest` (C-side) | ✓ `GoalMutationProhibition` enforces red line | ✓ | ✓ S-side yields with reason on degradation request | ✓ | Yes |
| 16 | Session/context decoupling | ✓ Run not bound to HTTP | Partial — `AgentSubject` identity deferred | ✓ | ✓ | Partial | Partial — long-horizon identity deferred W2 |
| 18 | Workflow Intermediary | ✓ bus-cannot-force-start hard rule | ✓ local admission | ✓ `Mailbox` enqueue → pull | ✓ `AdmissionDecision` variants + `BackpressureSignal` | ✓ | Yes |
| 19 | Three-track bus | ✓ physical isolation | ✓ | ✓ heavy data NEVER on broker | ✓ Track 3 survives Track 1 congestion | ✓ | Yes |
| 20 | Bidding + permission | ✓ pre-authorized | ✓ S-side issues `PermissionEnvelope` | ✓ subsumption-bounded | ✓ envelope `revokeOnYield` | ✓ short expiry | Yes |
| 21 | Chronos Hydration | ✓ end-to-end flow | ✓ TickEngine + WakeupPulse | ✓ snapshot durable before self-destruct | ✓ idempotent WAKEUP | ✓ long-horizon → instant pull-up | Yes |

**Equivalence summary**: 15 of 18 mapped concepts are **fully equivalent** at the contract level. 3 are **partial** (concepts #12, #16, and concept #23 from Section 2 which is mapped only implicitly). The partials are noted in Section 8.

---

## Section 4 — Over-design check

Does any architecture component add platform-owned complexity beyond L0 without a current enforcement rule, implementation plan, or explicit deferral? Special attention to memory categories, graph memory, skill middleware, bus topology, scheduler vocabulary.

**Memory categories (M1–M6)**: 
- ADR-0034 defines six categories from the platform perspective. ADR-0051 amends with ownership boundary. 
- Risk: M1–M6 schema may impose platform-centric structure on memory adapters that prefer their own schemas.
- Mitigation: ADR-0051 forward note in ADR-0034 explicitly says adapters MUST declare ownership; the matrix and ownership-split language soften platform-colonization risk.
- **Verdict**: Not over-designed given the ownership boundary correction.

**Graph memory (`GraphMemoryRepository`)**: 
- SPI exists; no implementation; W1 reference is Graphiti. 
- Risk: SPI could become "the default place to store everything graph-shaped" without ownership clarification.
- Mitigation: ADR-0051 explicit non-default-ownership rule + ADR-0034 forward note.
- **Verdict**: Not over-designed.

**Skill middleware**: 
- ADR-0030 (lifecycle) + ADR-0038 (resource tiers) + ADR-0052 (distributed scheduler).
- Risk: three ADRs for skills could be excessive layering.
- Mitigation: each addresses a distinct concern — Java SPI (0030), enforceability classification (0038), distributed scheduling (0052). The forward notes make the layering explicit.
- **Verdict**: Layered but not over-designed; each layer has a distinct decision boundary.

**Bus topology**: 
- ADR-0031 (in-process three tracks) + ADR-0048 (microservice deployment with data-P2P/control-event-bus) + ADR-0050 (cross-service three tracks with Rhythm restored).
- Risk: three ADRs for one bus concept.
- Mitigation: ADR-0031 is the in-process Java SPI; ADR-0048 is deployment topology; ADR-0050 is the cross-service contract (and amends ADR-0048's heartbeat placement). Each layer is needed.
- **Verdict**: Necessary layering; not over-designed.

**Scheduler vocabulary**: 
- `SkillResourceMatrix`, `CapabilityRegistry`, `BidRequest`, `BidResponse`, `PermissionEnvelope`, `SkillSaturationYield` — six new contracts in ADR-0052.
- Risk: comprehensive vocabulary at L0 without implementation.
- Mitigation: each contract is named because the whitepaper requires it; deferral to W2/W3 is explicit; reviewer P1-1 required this.
- **Verdict**: Whitepaper-mandated vocabulary; not speculative.

**Conclusion of over-design check**: No over-design identified beyond unavoidable layering. All new contracts are either (a) named because the whitepaper requires them, (b) named because the reviewer specifically required them, or (c) preserved at contract level with explicit deferral to a wave.

---

## Section 5 — Gate-coverage check

For every "enforced by", "asserted by", "tested by", or release-baseline claim, name the exact failing gate or label as "socially reviewed only".

| Claim | Gate / Test | Fails on |
|---|---|---|
| README baseline counts match canonical YAML | Gate Rule 27 (`active_entrypoint_baseline_truth`) | Stale README count |
| Release-note baseline counts match canonical YAML OR carry freeze marker | Gate Rule 28 (`release_note_baseline_truth`) — new this cycle | Stale release-note count without freeze marker |
| Whitepaper alignment matrix exists with all 20 required concepts | Gate Rule 29 (`whitepaper_alignment_matrix_present`) — new this cycle | Missing matrix or missing concept row |
| Module dependency direction (agent-platform ⊥ agent-runtime) | `ApiCompatibilityTest` (ArchUnit) | Cross-module import |
| SPI purity (no Spring imports in `*.spi.*`) | `OrchestrationSpiArchTest`, `MemorySpiArchTest` | Framework import in SPI |
| Tenant propagation purity | `TenantPropagationPurityTest` | `TenantContextHolder` imported in `agent-runtime` main |
| `RunStatus` DFA transitions valid | `RunStateMachine.validate()` + `RunStateMachineTest` | Illegal transition |
| 16-KiB checkpoint cap enforced | `InMemoryCheckpointerSizeCapTest` | Over-cap payload in research/prod |
| `AppPostureGate` is single construction-path | Gate Rule 12 (`inmemory_orchestrator_posture_guard_present`) | Missing call site |
| Shipped row evidence paths exist on disk | Gate Rule 24 (`shipped_row_evidence_paths_exist`) | Non-existent l2_documents path |
| Shipped row tests evidence present | Gate Rule 19 (`shipped_row_tests_evidence`) | Empty `tests:` on shipped row |
| Release-note shipped-surface truth | Gate Rule 26 (`release_note_shipped_surface_truth`) | RunLifecycle as W0, RunContext.posture(), etc. |
| ADR-0049 / ADR-0050 / ADR-0051 / ADR-0052 prose | **Socially reviewed only** | N/A — no mechanical gate enforces prose semantics; reviewer review is the verification |
| `BusinessFactEvent` placeholder preservation | **Socially reviewed only** at L0; W3 ship-blocking via `SandboxExecutor` enforcement | N/A at L0 |
| `PermissionEnvelope` signature integrity | **Socially reviewed only** at L0; W3 cryptographic enforcement | N/A at L0 |
| `WorkflowIntermediary` admission control rule | **Socially reviewed only** at L0; W2 enforced by code | N/A at L0 |

**Gate coverage summary**: 12 mechanical gates / tests catch drift at commit time. Several L0 contracts (ADR prose semantics, placeholder preservation, permission signature, intermediary admission rule) are **socially reviewed only at L0**, with enforcement scheduled for W2–W3 implementation. This is honest: contract-level naming at L0; mechanical enforcement at impl waves.

---

## Section 6 — Release-note truth check

Verify that release notes, README, ADR index, `architecture-status.yaml`, and root `ARCHITECTURE.md` all agree on counts, shipped surface, deferred surface, and target-only language **after this PR**.

| Artifact | §4 constraints | ADRs | Gate rules | Self-tests |
|---|---|---|---|---|
| `ARCHITECTURE.md` §1 header (post-PR) | 50 | 52 | 29 | 35 |
| `architecture-status.yaml` `architecture_sync_gate.allowed_claim` (post-PR) | 50 | 52 | 29 | 35 |
| `architecture-status.yaml` `adr_index.allowed_claim` (post-PR) | N/A | 52 (0001–0052) | N/A | N/A |
| `README.md` baseline + range (post-PR) | 50 (`§4 #1–#50`) | 52 (`ADR-0001 … ADR-0052`) | 29 | 35 |
| `docs/releases/2026-05-13-L0-architecture-release.en.md` | 45 (frozen at L0 SHA `82a1397`) | 47 (frozen) | 27 (frozen) | 30 (frozen) |
| `docs/adr/README.md` | N/A | rows for 0049/0050/0051/0052 added (52 total) | N/A | N/A |

The L0 release note is **exempt** by virtue of its freeze marker ("Historical artifact frozen at SHA 82a1397"). All active artifacts agree on 50/52/29/35 post-PR. Gate Rule 27 (README cross-check) and Gate Rule 28 (release-note cross-check, exempting frozen artifacts) both PASS.

---

## Section 7 — Negative-test discipline

For every new gate added during remediation, a negative self-test that intentionally creates the drift and proves the gate fails:

| New gate (this PR) | Positive test | Negative test | Status |
|---|---|---|---|
| Gate Rule 28 (`release_note_baseline_truth`) | `rule28_baseline_pos` — release note with matching counts → PASS | `rule28_baseline_neg` — release note with stale counts, no freeze marker → FAIL (correctly detected) | Both shipped; both PASS in self-test |
| Gate Rule 28 freeze-marker exemption | (same as above) | `rule28_baseline_neg_no_freeze_marker` — release note with stale counts BUT freeze marker → exempt (PASS) | Shipped; PASS in self-test |
| Gate Rule 29 (`whitepaper_alignment_matrix_present`) | `rule29_matrix_pos` — matrix with all 20 concepts → PASS | `rule29_matrix_neg` — matrix missing required concept → FAIL (correctly detected) | Both shipped; both PASS in self-test |

**Negative-test discipline summary**: every new gate ships with both a positive and a negative self-test. The 35-test self-test suite passes in full.

---

## Section 8 — Explicit residual-risk statement

What is not shipped, what is not contract-complete, and what remains outside L0:

**Contract-complete at L0 (named in ADRs + §4 + matrix + governance row):**
- C/S Dynamic Hydration Protocol (ADR-0049)
- Degradation authority red line (ADR-0049)
- Workflow Intermediary + Mailbox + Backpressure (ADR-0050)
- Three-track cross-service bus including restored Rhythm (ADR-0050)
- Chronos Hydration flow (ADR-0050)
- Memory ownership boundary (ADR-0051)
- Placeholder Preservation Policy (ADR-0051)
- BusinessFactEvent emission (ADR-0051)
- Skill Topology Scheduler + bidding (ADR-0052)
- Pre-authorized capability access + PermissionEnvelope (ADR-0052)

**Implementation-deferred to W2** (no Java code at L0):
- Java types for `HydrationRequest`, `TaskCursor`, `BusinessRuleSubset`, `SkillPoolLimit`, `SyncStateResponse`, `SubStreamFrame`, `YieldResponse`, `ResumeEnvelope`
- Java types for `WorkflowIntermediary`, `IntentEvent`, `Mailbox`, `AdmissionDecision`, `BackpressureSignal`, `WorkStateEvent`
- Java types for `BusinessFactEvent`, `OntologyUpdateCandidate`, `DelegationGrant`
- Java types for `SkillResourceMatrix` extension, `BidRequest`/`BidResponse`, `PermissionEnvelope`
- Substrate selection for Track 1 (event bus), Track 2 (P2P), Track 3 (Rhythm)

**Implementation-deferred to W3+**:
- `agent-client-sdk` Maven module (L1 of the three-layer model)
- Sandboxed enforcement of `PlaceholderPreservationPolicy`
- Cryptographic specification of `PermissionEnvelope.signature`
- W4 `TickEngine` durable timer (Temporal-backed)
- W4 full Chronos Hydration end-to-end implementation

**Concept gaps (not yet contract-complete)**:
- **#4 N:1 cross-business multiplexing** — implicit via ADR-0048 + ADR-0049 composition; not named as a first-class contract. Risk: low (W2 streamed surface implementation will surface the contract shape).
- **#17 Hot migration** — implicit via Checkpointer + RunRepository SPI shape; not named. Risk: low (W2 Postgres impl will surface).
- **#23 Monolithic asynchronous loss-of-control trap** — implicit via DFA + SuspendSignal shape; not named as an anti-trap rule. Risk: low (the architecture already rejects coroutine free-fall by structure).

**External dependencies still unresolved**:
- `S-side / C-side` vocabulary collision (three meanings: whitepaper protocol-naming, Rule 17 substitution-authority, ADR-0033 deployment-locus) — parked.
- Whitepaper itself does not yet have a target-vs-shipped split — parked.

**Operational risks**:
- The architecture now has ~50 named contracts at L0 with no Java implementation. Future implementers may find the contract shapes need iteration when meeting real workloads. Mitigation: each contract has an explicit wave-tag for impl; the ADRs note "starting point, not final binding".
- Gate Rule 28 + 29 are new; they may need tuning if real release notes use formats not anticipated. Mitigation: self-tests cover both positive and negative cases; future drift can be added to self-test suite.

---

## Conclusion

`PASS: L0 is whitepaper-aligned at the architecture-contract level, with all non-shipped concepts explicitly mapped as design-only or deferred.`

**Justification**:
- All 5 P0 findings closed (release-note drift, C/S Hydration, Workflow Intermediary, Rhythm track, Memory ownership).
- Both P1 findings closed (Skill topology scheduler, Degradation authority).
- P2-1 closed (Whitepaper alignment matrix).
- ADR-0048 amended (no longer over-claims complete whitepaper realization).
- All 20 reviewer-named whitepaper concepts mapped in the matrix with explicit status.
- Three concept gaps (#4, #17, #23) identified honestly in Section 8 with low risk and forward path.
- Mechanical gates added with positive + negative self-tests (35/35 passing).
- L0 release note frozen at SHA 82a1397; Gate Rule 28 enforces drift detection on future release notes.

**Standing release-note language** (per reviewer's recommendation): future release notes claiming "whitepaper aligned" MUST reference this matrix and acknowledge that contract-level alignment ≠ implementation completion. Implementation completion is wave-tagged (W2–W4).

---

## References

- Reviewer source: `docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md`
- Whitepaper: `docs/spring-ai-ascend-architecture-whitepaper-en.md`
- Whitepaper alignment matrix: `docs/governance/whitepaper-alignment-matrix.md`
- New ADRs: 0049 / 0050 / 0051 / 0052
- Amended ADRs: 0048 / 0034 / 0030 / 0038 / 0031
- New gate rules: 28 / 29 (in `gate/check_architecture_sync.{sh,ps1}`)
- New self-tests: `rule28_baseline_pos` / `rule28_baseline_neg` / `rule28_baseline_neg_no_freeze_marker` / `rule29_matrix_pos` / `rule29_matrix_neg` (in `gate/test_architecture_sync_gate.sh`)
- L0 release note: `docs/releases/2026-05-13-L0-architecture-release.en.md` (frozen at SHA 82a1397)
