# R1 Correctness Audit of L0 v2 Release Note

Date: 2026-05-13
Reviewer: correctness-reviewer (compound-engineering)
Input: docs/releases/2026-05-13-L0-architecture-release-v2.en.md

## Verdict

PASS-WITH-OBSERVATIONS

The release note's load-bearing claims (baseline counts, ADR citations, Java symbol
references, Gate Rule citations, Gate Rule 26 forbidden phrasings, Gate Rule 28 baseline
match) all resolve against on-disk reality. One observation is a minor stale comment in
the self-test harness header that does not affect runtime behaviour. No P0/P1 blockers.

## Findings

### Finding 1 — Self-test harness header comment is stale (does not match TOTAL=35)

- Severity: P3
- Defect category: PERIPHERAL-DRIFT (comment header vs canonical variable)
- 4-shape label: PERIPHERAL-DRIFT
- Observed: `gate/test_architecture_sync_gate.sh:3-5` reads
  `PARTIAL COVERAGE: covers Rules 1-6 + Rules 16, 19, 22, 24, 25, 26, 27 (30 tests).`
  and `The full gate has 27 active rules; this self-test covers Rules 1-6 and 16/19/22/24/25/26/27.`
  while line 17 sets `TOTAL=35` and the v2 release note (line 37, 204, 297) asserts
  "29 active rules" and "35 self-tests". The harness comment header has not been
  re-synced after Rule 28/29 + 5 new self-tests landed in the thirteenth cycle.
- Execution path: gate self-test prints `Tests passed: N/35` per the script body
  (TOTAL=35), so the test result is correct. Only the header comment drifts.
- Root cause: header comment was authored when the gate had 27 rules and 30 tests;
  the cycle-13 update (Rules 28/29 + 5 self-tests, +2/+5) updated TOTAL=35 but did
  not refresh the comment block at lines 3-5.
- Evidence:
  - `gate/test_architecture_sync_gate.sh:3` — "PARTIAL COVERAGE: covers ... (30 tests)."
  - `gate/test_architecture_sync_gate.sh:5` — "The full gate has 27 active rules"
  - `gate/test_architecture_sync_gate.sh:17` — `TOTAL=35`
  - `gate/check_architecture_sync.sh:955-1061` — Rules 28 and 29 present
  - `docs/governance/architecture-status.yaml:68` — canonical `29 active gate rules; ... 35 gate self-tests`
- Fix proposal: update `gate/test_architecture_sync_gate.sh` lines 3-7 to read
  `PARTIAL COVERAGE: covers Rules 1-6 + Rules 16, 19, 22, 24, 25, 26, 27, 28, 29 (35 tests).`
  and `The full gate has 29 active rules`. No release-note text change needed; the
  v2 note is correct.

## Categorized summary

| Category | P0 | P1 | P2 | P3 |
|----------|----|----|----|----|
| PERIPHERAL-DRIFT (comment header) | 0 | 0 | 0 | 1 |
| REF-DRIFT | 0 | 0 | 0 | 0 |
| HISTORY-PARADOX | 0 | 0 | 0 | 0 |
| GATE-PROMISE-GAP | 0 | 0 | 0 | 0 |
| GATE-SCOPE-GAP | 0 | 0 | 0 | 0 |
| **Total** | **0** | **0** | **0** | **1** |

## Verification trace (evidence the v2 note is correct)

| Check | Result | Evidence |
|-------|--------|----------|
| Baseline §4 = 50 | PASS | `ARCHITECTURE.md:520-621` contains constraints 46-50; YAML `:68` asserts 50; v2 `:32` matches |
| Baseline ADRs = 52 | PASS | `docs/adr/0001..0052` all 20 cited ADRs (0019,0020,0021,0022,0023,0027,0028,0030,0031,0034,0035,0040,0043,0046,0047,0048,0049,0050,0051,0052) resolve on disk |
| Baseline gate rules = 29 | PASS | bash `check_architecture_sync.sh:53-955` headers `Rule 1`..`Rule 29`; PS `check_architecture_sync.ps1:67-1061` headers `Rule 1`..`Rule 29` |
| Baseline self-tests = 35 | PASS | `gate/test_architecture_sync_gate.sh:17` TOTAL=35 |
| Active engineering rules = 11 | PASS | CLAUDE.md preamble enumerates Rules 1-6, 9-10, 20-21, 25 (11 active) |
| Java symbols (12+) resolve | PASS | RunStateMachine, AppPostureGate, SyncOrchestrator, SequentialGraphExecutor, IterativeAgentLoopExecutor, InMemoryRunRegistry, InMemoryCheckpointer, RunContext, OpenApiSnapshotComparator, IdempotencyHeaderFilter, TenantContextFilter, WebSecurityConfig, ResilienceContract, YamlResilienceContract, GraphMemoryRepository, IdempotencyRecord, OrchestrationSpiArchTest, MemorySpiArchTest, ApiCompatibilityTest, TenantPropagationPurityTest — all glob-resolve under `agent-platform/` and `agent-runtime/` |
| Rule 26a (RunLifecycle wave/marker) | PASS | v2 `:60` has `remains design-only for W2 — see ADR-0020`; "remains design" matches 26a marker regex AND "W2" wave qualifier present |
| Rule 26b (RunContext methods) | PASS | v2 `:61` lists only canonical {runId, tenantId, checkpointer, suspendForChild}; v2 `:134` "RunContext" is not in methods context |
| Rule 26c (ApiCompatibilityTest) | PASS | v2 `:72` co-mentions ApiCompatibilityTest with snapshot/OpenAPI but contains "ArchUnit-only" disclaimer + "not the OpenAPI diff" |
| Rule 26d (AppPostureGate scope) | PASS | v2 `:63` explicitly says "Runtime Kernel scope, not HTTP Edge" and "NOT a constructor argument on all runtime components" |
| Rule 28 baseline truth | PASS | v2 table at `:32-38` shows 50/52/29/35; canonical YAML `:68` shows "50 §4 constraints ... 52 ADRs ... 29 active gate rules ... 35 gate self-tests" |
| v1 archive path | PASS | `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md` exists |
| whitepaper-alignment-matrix.md | PASS | `docs/governance/whitepaper-alignment-matrix.md` exists |
| serverless archive ref | PASS | `docs/archive/2026-05-13-serverless-architecture-future-direction.md` exists |
| Gate Rules 15/16/19/22/24/25/26/27/28/29 in both bash + PS | PASS | bash + PS each carry the Rule N headers at matching positions |

## Residual risks

- The v2 note cites "Rule 16a" (`:146`, `:147`, `:249`) as a distinct artifact, but
  Rule 16a is a sub-clause of Rule 16 (verb-class -cmatch tightening), not a separate
  rule number. This is correct usage within the prose; flagging as informational only
  since the 4-shape table treats it as a per-verb pattern, not a rule count.
- Gate Rule 28 currently scans `docs/releases/*.md` (maxdepth 1) — the v2 note lives
  at `docs/releases/2026-05-13-L0-architecture-release-v2.en.md` and is in scope.
  The v1 archived note under `docs/archive/...` is correctly out of scope.
