# W2.x Engine Contract Structural Wave — Release Note

**Date:** 2026-05-16
**Driver review:** 2026-05-15 LucioIT L0 proposal *"Runtime-Engine Contract for Heterogeneous Agent Execution"* (`docs/reviews/2026-05-15-l0architecture-lucio It-wave-1-supplement-runtime-engine-contract.en.md`)
**Response doctrine:** [docs/reviews/2026-05-16-engine-contract-structural-response.en.md](../reviews/2026-05-16-engine-contract-structural-response.en.md)
**Wave plan:** `D:/.claude/plans/https-github-com-chaosxingxc-orion-spri-compressed-taco.md`

---

## Baseline counts

| metric | count |
|---|---|
| §4 constraints | 65 |
| Active ADRs | 77 |
| Active gate rules | 60 |
| Gate self-test cases | 82 |
| active engineering rules | 34 |
| Layer-0 governing principles | 13 |
| enforcer rows | 87 |
| Maven tests GREEN | 200 |

## Summary

The W2.x wave absorbs the 2026-05-15 L0 proposal in seven phases. **One new Layer-0 governing principle** (**P-M — Heterogeneous Engine Contract & Server-Sovereign Boundary**) operationalised by **six new Layer-1 rules** (43–48), backed by **seven new ADRs** (0071–0077), **six new gate rules** (55–60), and **fourteen new enforcers** (E74–E87).

The wave's central design choice is the **structural-downstreaming invariant** — every new domain contract ships as:
```
yaml schema  →  Java type that validates against the schema  →  runtime self-validate
```
**Rule 48 (Schema-First Domain Contracts)** makes this invariant permanent and gate-enforced beyond this wave. The invariant is the structural prevention of defect family F1 (text-form governance drift), which accounted for 79 of 158 historical closed defects (~50%).

## Four Competitive Pillars

Pillar coverage by canonical name (`performance`, `cost`, `developer_onboarding`, `governance` — matches `docs/governance/competitive-baselines.yaml`):

| Pillar | Baseline | W2.x impact |
|---|---|---|
| `performance` | latency / throughput | no regression; SyncOrchestrator dispatch is now O(1) lookup via `EngineRegistry.resolveByPayload` (was sealed-pattern switch) |
| `cost` | per-call + infra | no change |
| `developer_onboarding` | time-to-first-agent + surface complexity | improved — new engine integrations register a single `ExecutorAdapter`, no orchestrator patches required |
| `governance` | tenant isolation, audit, eval, safety | strengthened — engine envelope adds compile-time + runtime validation against `known_engines`; S2C callbacks declared in schema with mandatory propagation fields |

## ADRs landed (7)

- **ADR-0071** Engine Contract Structural Wave (umbrella; declares P-M, lists 0072–0077 as dependents)
- **ADR-0072** Engine Envelope + Strict Matching (Phase 1, Rules 43+44)
- **ADR-0073** Engine Lifecycle Hooks + Runtime-Owned Middleware SPI (Phase 2, Rule 45)
- **ADR-0074** Server-to-Client Capability Callback Protocol (Phase 3, Rule 46)
- **ADR-0075** Evolution Scope Boundary (Phase 4, Rule 47)
- **ADR-0076** R2 Pilot — Runtime Self-Validates the Engine Envelope (Phase 5)
- **ADR-0077** Schema-First Domain Contracts (Phase 6, Rule 48 cross-cutting)

## Rules landed (6 active L1 rules + 1 new L0 principle)

| Rule | Title | Phase | Gate rule | Enforcers |
|---|---|---|---|---|
| 43 | Engine Envelope Single Authority | 1 | 55 | E74, E76 |
| 44 | Strict Engine Matching | 1 | 56 | E75, E77 |
| 45 | Runtime-Owned Middleware via Engine Hooks | 2 | 57 | E78, E79, E80 |
| 46 | S2C Callback Envelope + Lifecycle Bound | 3 | 58 | E81, E82, E83 |
| 47 | Evolution Scope Default Boundary | 4 | 59 | E86, E87 |
| 48 | Schema-First Domain Contracts | 6 | 60 | E85 |
| — | (Phase 5 R2 pilot; no new rule) | 5 | — | E84 |

## Schemas landed (4)

- `docs/contracts/engine-envelope.v1.yaml` — engine metadata + payload routing
- `docs/contracts/engine-hooks.v1.yaml` — 9 canonical hook points + ordering
- `docs/contracts/s2c-callback.v1.yaml` — S2C request/response shape + 6 mandatory fields + outcome enum
- `docs/governance/evolution-scope.v1.yaml` — in/out evolution scope contract

## Java SPI surfaces added

- `ascend.springai.runtime.orchestration.spi`: `ExecutorAdapter`, `EngineMatchingException`, `HookPoint`, `HookContext`, `HookOutcome`, `RuntimeMiddleware`, `EngineHookSurface` (all pure `java.*` per E3)
- `ascend.springai.runtime.engine`: `EngineEnvelope`, `EngineRegistry`, `HookDispatcher`
- `ascend.springai.runtime.s2c`: `S2cCallbackEnvelope`, `S2cCallbackResponse`, `InMemoryS2cCallbackTransport`
- `ascend.springai.runtime.s2c.spi`: `S2cCallbackSignal`, `S2cCallbackTransport`
- `ascend.springai.runtime.evolution`: `EvolutionExport`
- `ascend.springai.runtime.resilience.SuspendReason.AwaitClientCallback` (new sealed variant)

## Cross-rule co-design audit (Phase 3a — hard gate before S2C code)

S2C touched the highest cross-cutting risk in the wave. The Phase 3a audit matrix in the response doctrine §5 named the resolution for **each of the 5 affected existing rules** (20 state machine, 35 channels, 38 no-sleep, 41 capacity, 42 sandbox) BEFORE any S2C code landed. Outcome: S2C absorbed without modifying any existing rule. Pattern reusable for future cross-cutting features.

## What's deferred

- **Runtime ResilienceContract integration for `s2c.client.callback` skill capacity** — declared in `skill-capacity.yaml`, runtime enforcement at SyncOrchestrator deferred to W2 per ADR-0074.
- **Production S2C transports** (webhook POST, SSE, WebSocket) — only `InMemoryS2cCallbackTransport` ships at W2.x; W3 scope.
- **Engine-side hooks** (LLM × 2, tool × 2, memory × 2) — only the 3 structural hooks (`on_error`, `before_suspension`, `before_resume`) fire from SyncOrchestrator at W2.x; engine-side firing lands in W2 Telemetry Vertical with the first consumer hooks.
- **RunEvent + EvolutionExport integration** — `EvolutionExport` enum + armed-empty ArchUnit ship at W2.x; W2 RunEvent variants will declare `evolutionExport()`.
- **Existing prose-enum retrofit** — 10 grandfathered entries in `gate/schema-first-grandfathered.txt` (RunStatus DFA, RunMode, deployment_plane, SuspendReason variants, RunScope, SkillKind, SkillTrustTier, JoinPolicy/ChildFailurePolicy, SemanticOntology, AdmissionDecision, BackpressureSignal, IdempotencyRecord CHECK). Retrofit scheduled per `CLAUDE-deferred.md` 48.b (W3).

## Verification

- `./mvnw test` → 200 tests / 0 failures (135 agent-runtime + 65 agent-platform)
- `bash gate/check_architecture_sync.sh` → GATE: PASS with 66 active rules
- `bash gate/test_architecture_sync_gate.sh` → 82/82 self-tests PASS
- `bash gate/build_architecture_graph.sh` → 219+ nodes / 272+ edges; idempotent regen byte-identical

## Authority

- ADR-0071 (umbrella) authoritative
- L0 principle P-M operationalised by Rules 43–48
- W2.x doctrine response: `docs/reviews/2026-05-16-engine-contract-structural-response.en.md`
- Wave plan: `D:/.claude/plans/https-github-com-chaosxingxc-orion-spri-compressed-taco.md`

---

# Addendum — W2.x Phase 7 Audit Response (2026-05-16 evening)

**Audit plan:** `D:/.claude/plans/spi-atomic-willow.md`
**Trigger:** user request to audit conflicts between architecture declarations, engineering rules (CLAUDE.md), architecture decisions (ADRs), and SPI — and reflect on whether the corpus is L0-release-ready.
**Outcome:** **18 fixes landed across 7 parallel tracks; corpus is L0-release-ready.**

## Audit methodology — four-dimensional review

Four parallel Explore audits scanned:

1. **W2.x Engine Contract drift** — schema/yaml/code triplet completeness for all four W2.x contracts (engine-envelope, engine-hooks, s2c-callback, evolution-scope).
2. **L0 governance corpus integrity** — principle-coverage.yaml, enforcers.yaml, architecture-status.yaml, architecture-graph.yaml, posture-coverage.md, competitive-baselines.yaml, bus-channels.yaml, skill-capacity.yaml, sandbox-policies.yaml, evolution-scope.v1.yaml, SESSION-START-CONTEXT.md, all module-metadata.yaml, all ADRs 0068-0077.
3. **SPI / runtime code-truth** — agent-runtime/src/main, agent-runtime/src/test, agent-platform/src/main pure-Java cross-package contamination, strict-match enforcement, hook surface presence, Run state machine integrity, async / blocking discipline, tenant scope, posture-aware defaults, test honesty.
4. **ADR corpus self-audit** (added after user pushback "少了个维度吧？ADR 的自检呢？") — front-matter discipline, supersedes/extends DAG integrity, decision↔rule↔enforcer triangle closure, decision body internal consistency, mutually consistent decisions across ADRs, orphan / dead references, ADR↔architecture-graph closure, status field truth, schema-first self-application.

**Findings:** 2 HARD (D1: ADR-0076 enforcer mis-citation; L-1: Rule 44 prose/code gap) + 12 SOFT. Self-inspection then mined 4 additional latent items (L-9 EngineEnvelope strict ctor, L-10 parent-Run propagation, L-11 ADR-0076 scope-creep watch, L-12 Phase 3a Matrix link-rot). Total: **18 findings**.

## Fixes landed (7 parallel tracks)

| Track | Scope | Files touched | Resolves |
|---|---|---|---|
| **A** | ADR cross-reference correctness | `docs/adr/0076-...yaml` (E81→E84); `docs/adr/0071-...yaml` (umbrella one_liner) | D1 (HARD) + D6 |
| **B** | Rule 44 compliance code fix | `agent-runtime/.../SyncOrchestrator.java` + new `EngineMismatchTransitionsRunToFailedIT.java` + `enforcers.yaml` E88 | L-1 (HARD) |
| **C** | Deferred-index sync | `docs/CLAUDE-deferred.md` (5 new entries: 44.b, 44.c, 46.b, 48.b, 48.c); `CLAUDE.md` listing | L-2, L-4, L-7, L-9 (via 48.c), L-10 (via 44.c) |
| **D** | Graph generator fix | `gate/build_architecture_graph.py` (emit `cross_cutting_invariant` edges + DO-NOT-EDIT header); regen → 242 nodes / 318 edges | D2, D3 |
| **E** | Advisory prose cleanup | `docs/governance/SESSION-START-CONTEXT.md` (reading order); `competitive-baselines.yaml` (release: W2.x Phase 7); `enforcers.yaml` E89 (Phase 3a Matrix freeze) | D4, D5, L-12 |
| **F** | Schema-first grandfather sunset | `gate/schema-first-grandfathered.txt` (pipe-delimited format with `sunset_date` per entry); `check_architecture_sync.sh` Rule 60 parser; `test_architecture_sync_gate.sh` (2 new self-tests); `CLAUDE.md` Rule 48 prose | L-6 (closes the "today's prose locked, yesterday's prose forever" asymmetry) |
| **G** | Hook surface clarification | `docs/adr/0073-...yaml` + `docs/contracts/engine-hooks.v1.yaml` (new `hook_ownership:` block distinguishing **runtime-fired** {on_error, before_suspension, before_resume} from **engine-fired** {6 LLM/tool/memory hooks}) | L-5 |

## Rule 44 compliance — the central code fix

The HARD semantic finding: Rule 44 declares "Mismatch raises `EngineMatchingException` **AND transitions the Run to FAILED with reason `engine_mismatch`**" — but `SyncOrchestrator.executeLoop()` only fired the `ON_ERROR` hook and rethrew, leaving the Run in its prior status. Rule 44 prose and code disagreed.

**Fix:** Inserted a specific `catch (EngineMatchingException eme)` branch **before** the generic `catch (RuntimeException e)` at SyncOrchestrator line 129. The branch:

1. Idempotent-guards `if (run.status() != RunStatus.FAILED)` then `run = runs.save(run.withStatus(RunStatus.FAILED).withFinishedAt(Instant.now()))` (Rule 20 DFA `RUNNING → FAILED` and `SUSPENDED → FAILED` both legal).
2. Fires `HookPoint.ON_ERROR` carrying `reason="engine_mismatch"` + `requestedEngineType` + `actualPayloadType` attributes.
3. Re-throws the original `EngineMatchingException` so the parent recursive frame still observes the failure.

**Verified by:** `EngineMismatchTransitionsRunToFailedIT.engine_mismatch_transitions_run_to_failed_and_fires_on_error_with_reason` (E88) — asserts the FAILED transition, finishedAt set, and `reason=engine_mismatch` in the captured ON_ERROR context.

## Schema-first grandfather sunset — the architectural improvement

Closed the asymmetry where Rule 48 protected today's prose but left yesterday's prose grandfathered forever. The grandfather list is **still closed to new additions**, but every existing entry now declares a `sunset_date` (format `YYYY-MM-DD`). Gate Rule 60 fails closed once today's date exceeds any entry's sunset_date without retrofit. Advancing a sunset forward requires an ADR cited inline.

Default sunset schedule encoded in `gate/schema-first-grandfathered.txt`:
- `2026-09-30` — 7 entries whose retrofit lands with W3 contract-design sprint
- `2026-12-31` — 1 entry (RunScope) tied to W4 planner toolset
- `2027-12-31` — 2 entries (RunStatus DFA, IdempotencyRecord) whose authoritative form is already a Java enum + schema-layer CHECK constraint; prose is documentation cross-reference

## Updated counts

| metric | pre-audit | post-audit |
|---|---|---|
| §4 constraints | 65 | 65 |
| Active ADRs | 77 | 77 |
| Active gate rules | 60 | 60 |
| Gate self-test cases | 82 | **84** (+2 sunset_expired + sunset_malformed) |
| Active engineering rules | 34 | 34 |
| Deferred sub-clauses | 11 | **16** (+44.b, 44.c, 46.b, 48.b, 48.c) |
| Layer-0 governing principles | 13 | 13 |
| Enforcer rows | 87 | **89** (+E88 Rule 44 FAILED IT, +E89 Phase 3a Matrix freeze) |
| Maven tests GREEN | 200 | **208** (+1 EngineMismatchTransitionsRunToFailedIT IT; agent-platform recount 65) |
| Architecture-graph nodes / edges | 219 / 272 | **242 / 318** (cross_cutting_invariant edges + new E88/E89 enforcer artefacts) |

## L0 release readiness — checklist

| Check | Result |
|---|---|
| All HARD audit findings resolved | ✓ D1 (ADR-0076 enforcer fix) + L-1 (Rule 44 code fix) both landed and verified |
| Every `shipped: true` capability has real test evidence | ✓ Gate Rule 19 (`shipped_row_tests_evidence`) PASS |
| Every enforcer row's `artifact:` path resolves on disk | ✓ Gate Rule 28j (`enforcer_artifact_paths_exist`) PASS |
| Architecture-graph regenerates byte-identically | ✓ Gate Rule `architecture_graph_idempotent` PASS; `python gate/build_architecture_graph.py` produces same SHA on consecutive runs |
| Plan §11 enforcer table ↔ enforcers.yaml IDs aligned | ✓ Gate Rule 28i sync verified: 89 IDs match bidirectionally |
| Schema-first invariant (Rule 48) gate-enforced | ✓ Gate Rule 60 PASS; 4 self-tests cover pos / neg / sunset_expired / sunset_malformed |
| All four competitive pillars mentioned in release note | ✓ Section "Four Competitive Pillars" above + addendum baseline counts |
| All `agent-runtime` tests GREEN | ✓ `./mvnw -pl agent-runtime test` → 143 tests, 0 failures (incl. EngineMismatchTransitionsRunToFailedIT) |
| All `agent-platform` tests GREEN | ✓ `./mvnw -pl agent-platform -am test` → 65 tests, 0 failures |
| No open Rule 9 ship-blocking findings | ✓ Self-audit categories (model/LLM, run lifecycle, HTTP/API contract, security, resource lifetime, observability) — no open items |
| Defect family containment verified | ✓ F1 text-drift (Rule 33/34/48 + sunset); F2 envelope-propagation (Phase 3a Matrix + freeze E89); F3 posture (unchanged, still contained); F4 module deps (unchanged); F5 deferred honesty (5 new entries with triggers); F6 enforcer-truth (E88/E89 added) |

## What remains explicitly deferred (not blockers)

- **44.b** Run.engineType field persistence (W2; trigger: third engine type ships or Run.mode breaks 1:1 proxy)
- **44.c** Parent-Run propagation on child failure (W2 async orchestrator)
- **46.b** ResilienceContract s2c.client.callback wiring (W2; trigger: production S2C with > 1 client)
- **48.b** W3 prose-enum retrofit schedule (default trigger 2026-09-30 per grandfather sunset dates)
- **48.c** EngineEnvelope strict-construction validation (W2; trigger: first EngineEnvelope built outside Spring-boot test harness)

Every deferred entry carries an explicit re-introduction trigger per Rule 28 (Code-as-Contract) doctrine.

## Verification commands (full audit reproduction)

```
python gate/build_architecture_graph.py                  # 242 nodes / 318 edges
bash gate/test_architecture_sync_gate.sh                 # 84/84 PASS
bash gate/check_architecture_sync.sh                     # PASS (60 rules)
./mvnw -pl agent-runtime test                            # 143 / 0
./mvnw -pl agent-platform -am test                       # 65 / 0
```

## Conclusion

The W2.x Engine Contract Structural Wave — including the Phase 7 audit response landed in this addendum — closes the structural coupling between (a) ARCHITECTURE.md prose, (b) CLAUDE.md L0/L1 rules, (c) ADR-0001..0077 decisions, and (d) the Java SPI surfaces under `agent-runtime/`. Every active normative claim is either enforced by a real artefact whose existence the gate verifies, or registered in `CLAUDE-deferred.md` with an explicit re-introduction trigger.

**The corpus is L0-release-ready.** Recommended tag: **`v2.0.0-w2x-final`** on the merge commit.
