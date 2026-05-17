---
affects_level: L0
affects_view: scenarios
proposal_status: response
authors: ["Chao Xing (with Claude Opus 4.7)"]
responds_to_review: "self-initiated cross-corpus consistency audit, 2026-05-17"
related_adrs:
  - ADR-0049
  - ADR-0050
  - ADR-0055
  - ADR-0059
  - ADR-0066
  - ADR-0067
  - ADR-0068
  - ADR-0069
  - ADR-0072
  - ADR-0073
related_rules:
  - Rule-28
  - Rule-28e
  - Rule-31
  - Rule-32
  - Rule-33
  - Rule-39
  - Rule-43
  - Rule-44
  - Rule-45
  - Rule-46
  - Rule-47
  - Rule-64
  - Rule-65
  - Rule-66
# Inline cite for gate Rule 44 single-line grep — full list expanded below.
# affects_artefact: ARCHITECTURE.md
affects_artefact:
  - ARCHITECTURE.md
  - docs/contracts/engine-hooks.v1.yaml
  - docs/adr/0049-c-s-dynamic-hydration-protocol.md
  - docs/adr/0050-workflow-intermediary-mailbox-rhythm-track.md
  - docs/adr/0055-permit-platform-to-runtime-direction.md
  - docs/adr/0059-code-as-contract-architectural-enforcement.md
  - docs/adr/0066-independent-module-evolution.md
  - docs/adr/0067-spi-dfx-tck-codesign.md
  - docs/adr/0068-layered-4plus1-and-architecture-graph.yaml
  - docs/adr/0069-l0-ironclad-rules.yaml
  - docs/adr/0072-engine-envelope-and-strict-matching.yaml
  - docs/adr/0073-engine-hooks-and-runtime-middleware.yaml
  - agent-runtime/module-metadata.yaml
  - docs/governance/enforcers.yaml
  - docs/governance/architecture-status.yaml
  - docs/governance/architecture-graph.yaml
  - gate/check_architecture_sync.sh
  - gate/test_architecture_sync_gate.sh
  - gate/README.md
---

# Cross-corpus consistency audit response — 2026-05-17

## Context

Following the six-module materialization PR (2026-05-17, earlier today) — which
added `agent-client`, `agent-bus`, `agent-middleware`, `agent-execution-engine`,
`agent-evolve` and moved `HookPoint`/`HookContext`/`HookOutcome`/`RuntimeMiddleware`/
`HookDispatcher` from `agent-runtime` to `agent-middleware` — a three-track audit
across the four corpora (CLAUDE.md engineering rules + ARCHITECTURE.md prose +
docs/adr/\*.yaml/.md + module-metadata.yaml + governance YAMLs) surfaced
**16 actionable drift findings + 3 structural design flaws** that allow such
drift to recur silently.

This proposal records the audit findings, the remediation, and the three new
prevention rules (Rule 64 / 65 / 66) that close the structural gaps so the
same defect families cannot return undetected.

## Defect categorization

### Category A — Stale class paths after middleware extraction

| # | File:Line | Stale | Corrected |
|---|---|---|---|
| A1 | `docs/contracts/engine-hooks.v1.yaml:8` | `runtime.orchestration.spi.HookPoint` | `middleware.spi.HookPoint` |
| A2 | `docs/adr/0073-engine-hooks-and-runtime-middleware.yaml:68,75` | `agent-runtime/.../orchestration/spi/` + `engine/` | `agent-middleware/spi/` + `agent-middleware/` |

### Category B — Stale module counts

| # | File | Stale | Corrected |
|---|---|---|---|
| B1 | `gate/check_architecture_sync.sh:42` (header comment) | "exactly 4 `<module>` entries" | "exactly 9" + Rule 64 cross-ref |
| B2 | `docs/adr/0055-permit-platform-to-runtime-direction.md:41` | "exactly 4 modules" | "exactly 9 modules" + data-driven note |
| B3 | `docs/adr/0059-code-as-contract-architectural-enforcement.md:69` | Rule 28e table "exactly 4" | references canonical `architecture-status.yaml` value |
| B4 | `docs/adr/0066-independent-module-evolution.md:11` | "four modules today" | dated list of 9 modules |
| B5 | `docs/adr/0067-spi-dfx-tck-codesign.md:69,93` | "exactly 4 modules" | post-write annotation |

### Category C — Stale module list

| # | File | Stale | Corrected |
|---|---|---|---|
| C1 | `docs/adr/0069-l0-ironclad-rules.yaml:235-238` | 4 modules listed under Rule 39 modified-files | expanded to 9 |

### Category D — Metadata-vs-pom drift

| # | File | Drift |
|---|---|---|
| D1 | `agent-runtime/module-metadata.yaml:12-14` | `spi_packages:` lists 2; `runtime.s2c.spi` exists on disk but undeclared |
| D2 | `agent-runtime/module-metadata.yaml:15` | `allowed_dependencies: []` but pom depends on `agent-middleware` after T2.B1 |

### Category E — Prose drift in root ARCHITECTURE.md

| # | File | Drift |
|---|---|---|
| E1 | `ARCHITECTURE.md §2` (lines 75+) | 4-module layout diagram only; missing 5 new modules |

### Category F — Missing post-impl notes on historical ADRs

| # | File | Missing |
|---|---|---|
| F1 | `docs/adr/0049-c-s-dynamic-hydration-protocol.md:123` | renamed `agent-client-sdk` → `agent-client` not noted |
| F2 | `docs/adr/0050-workflow-intermediary-mailbox-rhythm-track.md` | no cross-ref to new `agent-bus/ARCHITECTURE.md` |
| F3 | `docs/adr/0072-engine-envelope-and-strict-matching.yaml` (Consequences) | `agent-execution-engine` materialization not acknowledged |
| F4 | `docs/adr/0068-layered-4plus1-and-architecture-graph.yaml` | graph regeneration not recorded |

### Category G — Structural design flaws (drift-permissive invariants)

| # | Flaw | Closure |
|---|---|---|
| G1 | Module count is hard-coded in 4 places (gate Rule 28e + ADR-0055 + ADR-0059 + ADR-0067) | New **Rule 64** (`module_count_data_driven`) reads canonical count from `architecture-status.yaml#repository_counts.total_reactor_modules` and cross-checks `<module>` count in root `pom.xml`. Future module changes update one file, not four. |
| G2 | No gate cross-check between `module-metadata.yaml#allowed_dependencies` and `pom.xml <dependencies>` | New **Rule 65** (`module_metadata_pom_dep_parity`) asserts every `ascend.springai` sibling artifact declared in a module's pom appears in the same module's metadata `allowed_dependencies`. |
| G3 | No gate cross-check that **every** `**.spi.**` directory is declared in `module-metadata.yaml#spi_packages` | New **Rule 66** (`spi_package_exhaustiveness`) walks `<module>/src/main/java` for every `*/spi/` leaf directory and asserts each corresponding package name appears in metadata's `spi_packages`. |

## Remediation

All 16 drift findings closed via direct edits (Wave 1). Three new gate
sub-rules (Wave 2) added with enforcer rows E94 / E95 / E96 and 6 new
self-test cases. Architecture graph regenerated (Wave 3). Final state:

- **78 active gate rules** (was 75 — Rules 64, 65, 66 added)
- **98 self-test cases** (was 92 — 2 per new rule × 3)
- **96 enforcer rows** (was 93 — E94, E95, E96 added)
- **9 reactor modules** (canonical count now data-driven; Rule 28e becomes a redundant secondary check, kept for historical ADR back-compat)

## Verification

- `./mvnw -T 1C -B verify` → BUILD SUCCESS; 242+ tests green
- `bash gate/check_parallel.sh` → GATE: PASS (78 rules)
- `bash gate/test_architecture_sync_gate.sh` → 98/98 PASS
- `bash gate/build_architecture_graph.sh` twice → byte-identical (Rule 42)
- Grep sweeps confirm no stale `runtime.orchestration.spi.Hook*` or
  `runtime.engine.HookDispatcher` references remain outside test fixtures.

## Why this proposal is the review trigger for ARCHITECTURE.md

`ARCHITECTURE.md` carries `freeze_id: W1-russell-2026-05-14` per Rule 33.
Rule 44 (`frozen_doc_edit_path_compliance`) requires that edits to a
freeze-id-tagged file be accompanied by a `docs/reviews/*.md` proposal
that cites the file under `affects_artefact:`. This proposal is that
review record. The §2 Module Layout update is the only ARCHITECTURE.md
edit in this PR and is enumerated above (Category E1).

## Phase C follow-up

This PR leaves the transitional 9-module shape. The Phase C follow-up
will fold `agent-platform` + the runtime kernel into `agent-service` and
extract the engine surface (`EngineRegistry`, `EngineEnvelope`,
`ExecutorAdapter`, `ExecutorDefinition`, `GraphExecutor`,
`AgentLoopExecutor`) into `agent-execution-engine` once the
Run/RunContext back-dep is resolved. After Phase C the reactor returns
to the 8-module shape that maps 1:1 to the six L0 team-facing concepts
plus the BoM and graphmemory starter. Rule 64 makes this rename
mechanically safe — only `architecture-status.yaml` needs the bump.
