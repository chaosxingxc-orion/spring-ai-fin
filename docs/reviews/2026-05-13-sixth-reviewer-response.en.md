# Response to Sixth Reviewer (LucioIT — Wave 1 Refinement)

**Date:** 2026-05-13
**Reviewer:** LucioIT
**Review document:** `docs/reviews/2026-05-12-architecture-LucioIT-wave-1-request.en.md`
**Combined with:** Seventh reviewer response (`2026-05-13-seventh-reviewer-response.en.md`)
**Methodology:** Findings categorized into 8 clusters; per-cluster systematic self-audit surfaced ~50 hidden defects beyond 12 reviewer-named findings. See [Combined Cluster Summary](#combined-cluster-summary).

---

## Executive Summary

| Finding | Verdict | Cluster |
|---------|---------|---------|
| L1 — Hierarchy by Scope, not by Mode | **PARTIAL ACCEPT** | Cluster 1 |
| L2 — Dual-posture edge / Logical Identity Equivalence | **PARTIAL ACCEPT** | Cluster 5 |
| L3 — Reject SyncOrchestrator; mandate Redis Streams/NATS Day 1 | **REJECT** (with concession) | Cluster 2 + Cluster 7 |

---

## Finding L1 — Hierarchy by Scope, not by Mode (PARTIAL ACCEPT)

### Reviewer claim

The `Run` entity uses `RunMode {GRAPH, AGENT_LOOP}` as a hierarchy discriminator. Runs should be organized by **scope** (STEP_LOCAL vs SWARM federation), not by execution mode. Mode and scope are orthogonal axes.

### Verdict: PARTIAL ACCEPT

The reviewer is correct that mode and scope are orthogonal. A `SWARM` run might be of mode `GRAPH` or `AGENT_LOOP`; the nesting/federation semantics belong to scope, not mode. However, the complete `RunScope` field on the `Run` entity is a W2 change (requires Postgres schema rev). We accept the principle now and name the design-level taxonomy.

### What changed

**ADR-0032** — Scope-Based Run Hierarchy + Planner Contract Minimal:
- `RunScope { STEP_LOCAL | SWARM }` discriminator named at design level; Java field deferred to W2
- `SuspendReason.SwarmDelegation` variant added to the taxonomy (ADR-0019 extension)
- `PlanState` / `RunPlanRef` minimal contract named (full `RunPlanSheet` toolset deferred to W4)

**Shipped code:**
- `RunRepository.findRootRuns(String tenantId)` — new SPI method
- `InMemoryRunRegistry.findRootRuns(String tenantId)` — filters `parentRunId == null` with tenant scoping
- `InMemoryRunRegistryFindRootRunsTest` — 5 tests (happy path, tenant scoping, parent-of-parent filtering)

### What is NOT accepted

- `AgentLoopDefinition.planningEnabled(true)` — the seventh reviewer correctly identified this doesn't exist. The claim has been removed. Replaced with `PlanState`/`RunPlanRef` minimal design names (ADR-0032). Full planner toolset deferred to W4.
- Full `RunScope` Java field at W0 — deferred to W2 alongside Postgres schema revision.

### Hidden defects surfaced (Cluster 1 audit)

| HD | Defect | Status |
|----|--------|--------|
| 1.1 | `Run` has no scope discriminator | Accepted — ADR-0032 names it; W2 binding |
| 1.5 | `planningEnabled` claimed in 3 places but absent | Fixed — false claim removed from all docs |
| 1.6 | `initialContext` is `Map<String,Object>` — migration risk | Acknowledged in ADR-0039 migration path |
| 1.7 | `ReasoningResult.payload` is `Object` — same risk | Acknowledged in ADR-0039 migration path |

---

## Finding L2 — Logical Identity Equivalence / Edge (PARTIAL ACCEPT)

### Reviewer claim

The architecture should explicitly name the principle that a capability designed for cloud deployment must remain functionally equivalent when deployed at a network edge. The "S-side / C-side" vocabulary conflates substitution authority with deployment location.

### Verdict: PARTIAL ACCEPT

The reviewer is correct that the vocabulary conflates two concepts. We accept the naming of deployment-locus as a separate axis. We REJECT adding an `edge` posture variant — the three-posture model (`dev/research/prod`) governs security posture, not deployment topology.

### What changed

**ADR-0033** — Logical Identity Equivalence & Deployment-Locus Vocabulary:
- Three deployment loci named: `S-Cloud` (cloud-hosted server), `S-Edge` (edge-deployed server), `C-Device` (on-device client)
- Logical Identity Equivalence principle: `S-Cloud ≡ S-Edge` for same SPI + same security controls + same tenant isolation
- Rule 17's `S-side / C-side` vocabulary **preserved unchanged** — it expresses substitution authority (who may substitute means vs ends), not deployment location
- No `edge` posture variant introduced

**§4 #30** — Logical identity equivalence constraint added to `ARCHITECTURE.md`

### What is NOT accepted

- **`edge` posture variant** — rejected. Adding a fourth posture (`dev/research/prod/edge`) would explode the posture matrix without providing enforcement benefit. `S-Edge` deployment uses the same `prod` posture requirements.
- **W0–W4 edge-deployment scheduling** — rejected. Post-W4 scope, like A2A federation (ADR-0016).

### Hidden defects surfaced (Cluster 5 audit, LucioIT-relevant slice)

| HD | Defect | Status |
|----|--------|--------|
| 5.1 | "Logical Identity Equivalence" not named anywhere | Fixed — ADR-0033 |
| 5.2 | "S-side / C-side" vocabulary overloaded | Fixed — disambiguation in ADR-0033; Rule 17 preserved |
| 5.7 | "Not in scope" includes "on-device models" but doesn't disambiguate edge locus | Fixed — ADR-0033 §"Out of scope" |

---

## Finding L3 — Reject SyncOrchestrator; mandate Redis Streams/NATS Day 1 (REJECT)

### Reviewer claim

`SyncOrchestrator` is a test scaffold disguised as runtime infrastructure. Mandating Redis Streams or NATS at Day 1 would give real queuing semantics and avoid retrofitting later.

### Verdict: REJECT (with concession)

**Rebuttal — "Temporal-as-God" precedent applies symmetrically.** The same review cycle that rejected mandating Temporal at W0 (ADR-0003 context — deferred from W0 to W4) applies here. Mandating Redis Streams or NATS at W0 would:
1. Import OSS dependencies before the SPI contract is stable
2. Force the dispatch tier into a specific technology before the `RunDispatcher` SPI (ADR-0031) is tested
3. Create a Kafka/Pulsar/NATS choice without a real throughput requirement to differentiate

The principled answer is SPI swap-readiness: `RunDispatcher` (ADR-0031) is the abstraction that lets us swap the dispatch tier at W2 without touching executor code. The technology decision (Redis Streams vs NATS vs Kafka) belongs at W2 when there are real throughput measurements.

**Concession — `SyncOrchestrator` needs a posture guard.** The reviewer is correct that `SyncOrchestrator` can be instantiated in research/prod posture with zero enforcement. This is a genuine defect. We fix it independently of the L3 rejection.

### What changed (concession only)

**Shipped code:**
- `AppPostureGate.requireDevForInMemoryComponent("SyncOrchestrator")` in `SyncOrchestrator` constructor
- `AppPostureGate.requireDevForInMemoryComponent("InMemoryRunRegistry")` in `InMemoryRunRegistry` constructor
- `AppPostureGate.requireDevForInMemoryComponent("InMemoryCheckpointer")` in `InMemoryCheckpointer` constructor (refactored from inline posture read — Rule 6 single-construction-path)
- **ADR-0035** — Posture enforcement single-construction-path
- **Gate Rule 12** — verifies `AppPostureGate.requireDev` literal in all three in-memory components

**Documentation:**
- `docs/cross-cutting/posture-model.md` — complete rewrite; adds rows for all three in-memory components; fixes POST-only drift (should be POST/PUT/PATCH); fixes UOE drift (should be ISE); formalizes dev-warn / research+prod-throw pattern

### Hidden defects surfaced (Cluster 2 audit)

| HD | Defect | Status |
|----|--------|--------|
| 2.1 | `SyncOrchestrator` no posture guard | Fixed — `AppPostureGate` in constructor |
| 2.2 | `InMemoryRunRegistry` no posture guard | Fixed — `AppPostureGate` in constructor |
| 2.3 | `InMemoryCheckpointer` reads `APP_POSTURE` directly (Rule 6 violation) | Fixed — refactored to delegate |
| 2.4 | `posture-model.md` says POST-only — actual filter applies POST/PUT/PATCH | Fixed |
| 2.5 | `posture-model.md` says `UnsupportedOperationException` — actual is `IllegalStateException` | Fixed |
| 2.6 | `posture-model.md` table doesn't list `InMemoryCheckpointer` 16-KiB cap behavior | Fixed — row added |
| 2.7 | No generalised "dev: warn-and-continue; research/prod: throw" pattern in posture-model.md | Fixed — formalised |

---

## Combined Cluster Summary

The combined 8-cluster methodology surfaced defects across both reviewer cycles:

| Cluster | Reviewer findings | Action |
|---------|-------------------|--------|
| 1 — Hierarchy & Scope Taxonomy | 6th L1 + 7th P1.4 | ADR-0032 + findRootRuns shipped |
| 2 — Posture Enforcement | 6th L3 concession + 7th P1.3 | ADR-0035 + AppPostureGate + Gate Rule 12 |
| 3 — Contract-Surface Truth | 7th P1.1 + 7th P2.4 + gate item 9 | ADR-0036 + Gate Rules 13-14 |
| 4 — Wave Authority | 7th P1.2 | ADR-0037 + plans archived |
| 5 — Strategic Boundary Naming | 6th L2 + 7th P1.5 | ADR-0033 + ADR-0034 |
| 6 — Forward-Compatibility Patterns | 7th P2.1 + 7th P2.2 | ADR-0038 + ADR-0039 |
| 7 — Streaming Channel Contract | 7th P2.3 | ADR-0031 terminal-event fix + run_dispatcher_spi row |
| 8 — BoM / Module Reality | 7th P1.1 (second clause) | 8 stale starter coords stripped from pom.xml |

---

## Ship-Now vs Defer Matrix

| Item | Status | Wave |
|------|--------|------|
| `AppPostureGate` + posture guards | Shipped W0 | W0 |
| `RunRepository.findRootRuns` + impl | Shipped W0 | W0 |
| Gate Rules 12-14 | Shipped W0 | W0 |
| ADR-0032 through ADR-0039 | Written W0 | W0 doc |
| §4 #29-#36 | Added W0 | W0 doc |
| `RunScope` Java field on `Run` entity | Deferred | W2 |
| `SuspendReason.SwarmDelegation` in sealed interface | Deferred | W2 |
| Memory taxonomy implementation | Deferred | W2/W3 |
| Redis Streams / NATS dispatch tier | Not in plan | W2+ (SPI-driven) |
| Edge posture variant | Rejected | — |
| `AgentLoopDefinition.planningEnabled` | Removed (false claim) | — |

---

## Test Count

| Module | Tests passing |
|--------|---------------|
| `agent-runtime` | **101** |
| `spring-ai-ascend-graphmemory-starter` | **1** |
| Total | **102** |

---

## Gate Status

```
GATE: PASS — all 14 rules green
```

New rules activated this cycle: Rule 12 (inmemory_orchestrator_posture_guard_present), Rule 13 (contract_catalog_no_deleted_spi_or_starter_names), Rule 14 (module_arch_method_name_truth).
