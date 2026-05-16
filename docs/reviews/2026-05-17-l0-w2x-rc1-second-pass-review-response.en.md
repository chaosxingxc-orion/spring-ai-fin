---
affects_level: L0
affects_view: process
proposal_status: response
authors: ["Chao Xing (with Claude Opus 4.7)"]
responds_to_review: docs/reviews/2026-05-16-l0-w2x-rc1-second-pass-architecture-review.en.md
related_adrs: [ADR-0071, ADR-0072, ADR-0073, ADR-0074, ADR-0076, ADR-0077]
related_rules: [Rule-1, Rule-9, Rule-25, Rule-28, Rule-43, Rule-45, Rule-46, Rule-48]
affects_artefact:
  - docs/releases/2026-05-16-W2x-engine-contract-wave.en.md
  - docs/contracts/engine-envelope.v1.yaml
  - docs/contracts/engine-hooks.v1.yaml
  - docs/governance/skill-capacity.yaml
  - docs/governance/sandbox-policies.yaml
  - docs/governance/bus-channels.yaml
  - docs/governance/retracted-tags.txt
  - docs/governance/architecture-status.yaml
  - docs/CLAUDE-deferred.md
  - CLAUDE.md
  - README.md
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookOutcome.java
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java
  - gate/check_architecture_sync.ps1
  - gate/check_architecture_sync.sh
  - gate/test_architecture_sync_gate.sh
  - gate/README.md
---

# L0 / W2.x rc1 Second-Pass Review — Response (v2.0.0-rc2)

> **Date:** 2026-05-17
> **Tag:** `v2.0.0-rc2` (supersedes `v2.0.0-rc1`; `v2.0.0-w2x-final` (retracted) remains in `docs/governance/retracted-tags.txt`)
> **Status:** All four reviewer findings closed. Nine additional sites surfaced by category audit also closed. Three new gate sub-rules (61/62/63) added as structural prevention against family recurrence. Six self-tests landed.

## 1. Executive Verdict

We accept the reviewer's verdict that the runtime shape is sound but the document corpus had remaining contract-truth defects that blocked declaring L0 "basically complete." Per the user's instruction we did **not** fix findings case-by-case — we first **categorized** the four findings into three defect families, then ran a corpus-wide audit per family to surface hidden instances of the same patterns. The audit revealed **12 additional sites** (8 F-α + 9 F-β + 5 F-γ; some are dup-sites of the reviewer's seeds). The rc2 commit closes the reviewer's 4 findings, 9 of the hidden sites, and adds 3 small gate sub-rules so each family is structurally prevented from regrowing.

Verification (rc2):

| Check | Result |
|---|---|
| `./mvnw clean verify` | 213 tests, 0 failures, **BUILD SUCCESS** |
| `bash gate/check_architecture_sync.sh` | **GATE: PASS** with 63 active gate rules (60 prior + Rules 61–63 added in rc2) |
| `bash gate/test_architecture_sync_gate.sh` | **92/92** self-tests PASS (86 prior + 6 added in rc2: 2 each for Rules 61/62/63) |
| `python gate/build_architecture_graph.py` | 246 nodes / 323 edges, regenerates idempotently |
| `powershell.exe gate/check_architecture_sync.ps1` | exit **2** with `DEPRECATED` banner (negative-confirmation that A1 deprecation took effect) |

## 2. Defect-Family Categorization

The reviewer's four findings collapse into **three families** that each describe a different breakdown of contract truth. These are structurally distinct from defect family F1 (prose↔enum drift, closed by Rule 48). The existing rule set (Rule 25 Architecture-Text Truth, Rule 28 Code-as-Contract Coverage) does NOT police these failure modes today — which is why they slipped past the prior wave. The new sub-rules 61/62/63 close that gap one family at a time.

| Family | Mechanism | Why prior rules missed it | Reviewer seed |
|---|---|---|---|
| **F-α — Parity-claim without enforcer** | Two artefacts claimed equivalent ("line-for-line parity", "Java type mirrors YAML"). One freezes, the other evolves silently. No test pins them. | Rule 28 demands an enforcer per *constraint*, not per *equivalence claim*. Rule 25 polices prose-named enforcers, not cross-artefact mirror claims. | **P0-1** PS gate vs bash gate |
| **F-β — Deferred-as-live spec drift** | Capability staged across phases. The Phase-N artefact texts the eventual Phase-N+1 runtime effect (Run.FAILED, validation rejection, capacity admission) as if already live. | Rule 28 requires an enforcer per active constraint but does not police YAML/Javadoc *text* describing future behavior. `CLAUDE-deferred.md` tracks the deferral; the contract files re-describe the target. | **P0-2** HookOutcome + **P1-1** EngineEnvelope |
| **F-γ — Stale-evidence local-supersession failure** | Document corrected by prepending new top-of-doc baseline. Stale numbers/tags persist mid-document, unqualified at point of use. A reader landing mid-doc cites stale facts as current. | Rule 25 polices enforcer claims but not numeric/temporal corpus claims (test counts, graph counts, retracted tags). | **P1-2** Release note stale numbers + retracted tag |

## 3. Findings Closure

### P0-1 — Gate posture (F-α α-1, α-2, α-8)

**Closed.** Chose the canonical-bash posture per reviewer's two options. Cost analysis: porting Rules 28a–28j + 30–60 to PowerShell would add ~1000 LOC of duplicate maintenance burden for every future rule; CI never invoked the PS gate; no PS self-test harness exists. The deprecation alternative is ~1 hour of work and eliminates an entire class of drift.

Closure evidence:
- `gate/check_architecture_sync.ps1` replaced with a 41-line fail-closed deprecation stub that prints `DEPRECATED: gate/check_architecture_sync.ps1 was frozen at Rule 29 in 2026-05.` and exits 2. Verified by `powershell.exe gate/check_architecture_sync.ps1; echo $?` → exit 2.
- `docs/governance/architecture-status.yaml#architecture_sync_gate`: `implementation:` now contains only `gate/check_architecture_sync.sh` (canonical). The PS path is moved to a sibling `deprecated_implementations:` array.
- `gate/README.md` rewritten to drop the false "line-for-line parity" claim and the wrong stoplight counts (the old README said 27 PS rules / 44 active bash rules / 50 self-tests; actual was 29/60/86; rc2 baseline is 63/92).
- `gate/README.md` adds explicit declaration that `doctor.ps1`/`doctor.sh` and `run_operator_shape_smoke.ps1`/`.sh` are dev-only helpers — NOT release gates — so the F-α hidden instances α-3 and α-4 are now docs-declared as non-parity (and explicitly rejected as enforcer additions; see §5).
- **Structural prevention:** new gate sub-rule **Rule 61 `legacy_powershell_gate_deprecated`** asserts BOTH (a) the PS script header carries the `DEPRECATED` Write-Host banner AND (b) the PS path is NOT listed under `architecture_sync_gate.implementation:` (the `deprecated_implementations:` sibling is OK). Self-tests: `rule61_legacy_ps_pos` + `rule61_legacy_ps_neg`. A subtle awk bug (`in_cap` did not reset across capabilities because the original exit pattern matched top-level keys, but capability names live at 2-space indent under `capabilities:`) was discovered and fixed by running the rule against the real yaml before declaring rc2 complete — see commit history.

### P0-2 — HookOutcome Run-state overclaim (F-β β-1, β-2, β-3)

**Closed.** The YAML contract, the Java SPI Javadoc, and the orchestrator class comment all promised Run-state effects that Rule 45.b explicitly defers to W2 Telemetry Vertical.

Closure evidence:
- `docs/contracts/engine-hooks.v1.yaml` — the `failure_propagation:` block now opens with an explicit `# IMPORTANT (rc2 truth alignment, P0-2):` paragraph that names what is true today (dispatcher fires hooks; in-chain fail-fast applies; Run lifecycle unaffected) vs the TARGET behavior at Rule 45.b activation. Per-key comments reiterate the TARGET vs TODAY split inline.
- `agent-runtime/.../spi/HookOutcome.java` — `Fail` and `ShortCircuit` Javadocs each gain a `<b>Status (v2.0.0-rc2):</b>` paragraph stating the dispatcher returns the outcome but the orchestrator does NOT consume it; Run-state consumption is deferred to W2 Telemetry Vertical per Rule 45.b.
- `agent-runtime/.../inmemory/SyncOrchestrator.java` — class Javadoc rewritten per user's chosen B3 option (rewrite-comment-only, no helper, no new unit test) to read: "Returned `HookOutcome` is DISCARDED at every call-site; Run-state consumption (Fail abort, ShortCircuit bypass) is deferred to W2 Telemetry Vertical per Rule 45.b. The discard is intentional — the dispatcher already enforces in-chain fail-fast among middlewares, but the Run lifecycle is unaffected today." The 7 call-sites are unchanged (they were already discarding the return value); the comment now matches reality.

### P1-1 — EngineEnvelope construction validation overclaim (F-β β-4, β-5)

**Closed.** Narrowed both the contract YAML and the Rule 43 prose to match what the Java record actually enforces.

Closure evidence:
- `docs/contracts/engine-envelope.v1.yaml` — header rewritten to reviewer's exact suggested wording: "The Java record `ascend.springai.runtime.engine.EngineEnvelope` mirrors this schema and validates REQUIRED FIELDS (nullability, blanks) on construction. `known_engines` membership is enforced by `EngineRegistry.resolve(...)` and registry boot validation (Phase 5 R2 pilot — runtime self-validation; enforcer E84). Constructor-level membership validation is deferred to Rule 48.c."
- `CLAUDE.md` Rule 43 (line 361) and the W2.x §invariant (line 355) — narrowed in the same way; cite Rule 48.c for the deferred construction-time membership check.
- No code change to `EngineEnvelope.java` — the existing nullability validation is what Rule 48.c keeps as the today-baseline.

### P1-2 — Release note stale verification + retracted tag (F-γ γ-1..γ-4)

**Closed.** Rewrote the stale `## Verification` block, replaced the `## Conclusion` recommended-tag line, and added a clear "Superseded — historical narrative only" header above the Phase 7 addendum block.

Closure evidence (all in `docs/releases/2026-05-16-W2x-engine-contract-wave.en.md`):
- `## Verification` (lines 100–105 previously) — old `./mvnw test → 200 tests / 66 active rules / 86/86 self-tests / 219+ nodes / 272+ edges` replaced with rc2-canonical: `./mvnw clean verify → 213 tests`, `bash gate/check_architecture_sync.sh → 63 active gate rules`, `bash gate/test_architecture_sync_gate.sh → 92/92 self-tests`, `python gate/build_architecture_graph.py → 246 nodes / 323 edges`, `pwsh gate/check_architecture_sync.ps1 → exit 2 with DEPRECATED banner`.
- Phase 7 addendum heading now reads `# Addendum — W2.x Phase 7 Audit Response (Superseded by §Baseline counts above — historical narrative only)` with an explicit supersession blockquote. A reader who lands mid-document sees the supersession at the section header.
- `## Conclusion` rewritten to recommend `v2.0.0-rc2` as the canonical tag, with `v2.0.0-w2x-final` flagged as retracted via `docs/governance/retracted-tags.txt`. The label `## Conclusion (Historical — rc2 supersession)` makes the supersession local to the section.
- **Structural prevention:** new gate sub-rule **Rule 63 `release_note_retracted_tag_qualified`** scans every `docs/releases/*.md` line that mentions any tag listed in `docs/governance/retracted-tags.txt` and requires either `(retracted)` on the same line OR a nearest-heading-above containing `Historical` / `Superseded`. Self-tests: `rule63_retracted_tag_pos` + `rule63_retracted_tag_neg`. The new `docs/governance/retracted-tags.txt` (pipe-delimited, comment-tolerant) is the single source of truth for retracted tags.

## 4. Hidden Defects Surfaced by Category Audit (Closed in rc2)

The category audit per defect family revealed 12 additional sites beyond the reviewer's 4. Of these, **9 are closed in rc2** and **3 are explicitly rejected** (see §5).

### F-α hidden defects closed

- **α-2** `architecture-status.yaml` listed both gate scripts as shipped under one `implementation:` row, with `tests:` only naming the bash self-test — closed by the same edit as α-1.
- **α-8** `gate/README.md` numeric drift (27 PS / 44 bash / 50 self-tests vs actual 29/60/86) — closed by the README rewrite.

### F-β hidden defects closed

- **β-6** `docs/governance/skill-capacity.yaml` `s2c.client.callback` row had `enforcer: SyncOrchestrator.handleClientCallback (W2.x); ResilienceContract.resolve (W2 wiring)` — the wording read as live ResilienceContract admission. Narrowed to "Phase 3 transport + response validation only; ResilienceContract.resolve admission deferred to W2 per Rule 46.b". The `queue_strategy: suspend` line also gained a TARGET vs TODAY comment.
- **β-7** `docs/governance/sandbox-policies.yaml` lacked a top-level `status:` field — per-skill rows read as runtime-enforced. Added `status: schema_shipped` with an explanatory comment noting Rule 42.b deferral.
- **β-8** `docs/governance/bus-channels.yaml` in-memory channel stubs (`in_memory_priority_queue_w0` etc.) lacked a top-level `status:` field. Added `status: schema_shipped` with a comment naming Rule 35.b deferral.
- **β-status-everywhere** `docs/governance/skill-capacity.yaml` also got a top-level `status:` field for consistency with the new structural rule.

### F-β structural prevention added

- **Rule 62 `contract_yaml_declares_status`** scans all 8 contract/governance YAMLs (`engine-envelope`, `engine-hooks`, `s2c-callback`, `plan-projection`, `evolution-scope`, `skill-capacity`, `sandbox-policies`, `bus-channels`) and requires a top-level `status:` field with a value in `{design_only, schema_shipped, runtime_enforced}`. Self-tests: `rule62_contract_status_pos` + `rule62_contract_status_neg`. This codifies the W2.x "post-review status label" convention so any new contract YAML must declare its enforcement status at the header, killing F-β recurrence at the structural level.

### F-α deferred (logged with W3 trigger)

- **α-5/α-6/α-7** ArchUnit-mirror enforcer additions for `EngineEnvelope` record-field ↔ YAML, `HookPoint` enum-order ↔ YAML, `EvolutionExport` ↔ YAML. Reviewer asked us to narrow text (closed), not to add new enforcers. Adding ArchUnit tests prematurely risks shipping wrong-shaped enforcers; the existing E77/E78/E86 already pin the more important property (registry coverage matches YAML known_engines / hook-point names). Logged as **Rule 28k.b — Schema↔Java-Shape Parity ArchUnit** in `docs/CLAUDE-deferred.md` with W3 trigger and explicit cross-link back to this response document.

## 5. Findings Rejected (with Rationale)

| Finding | Why rejected |
|---|---|
| **F-α α-3** `doctor.ps1` ↔ `doctor.sh` parity enforcement | Developer environment probe, not a release gate. The remedy is one line in `gate/README.md` declaring asymmetry (delivered in rc2 README rewrite); building parity enforcement would consume W2 budget for no defect-prevention return. |
| **F-α α-4** `run_operator_shape_smoke.ps1` ↔ `.sh` parity enforcement | Same rationale as α-3 — fail-closed smoke shells, not release gates. |
| **F-β β-9** `architecture-status.yaml#spi_compatibility_freeze` "rules 3+4 vacuous at L1" | Already documented in v2.0.0-rc1 post-release response §2.4 as a known limitation that resolves when SDK starters land on test classpath. A third pointer creates noise without information value. |
| **F-γ γ-5** Release note line 104 parenthetical "(v2.0.0-rc1: +2 sunset_expired/malformed + 2 Rule 28k positive/negative)" | The parenthetical is informative metadata noting which sub-deltas land at rc1, not a stale-evidence violation. |

## 6. New Surface Added by rc2 (Summary)

| Surface | Count | Notes |
|---|---|---|
| New gate sub-rules | 3 | Rules 61 / 62 / 63 (one per defect family — F-α / F-β / F-γ) |
| New self-tests | 6 | Positive + negative per new rule |
| New deferred sub-clauses | 1 | Rule 28k.b (Schema↔Java-Shape Parity ArchUnit; W3 trigger) |
| New governance files | 1 | `docs/governance/retracted-tags.txt` (input for Rule 63) |
| New ADRs | 0 | rc2 is a truth-alignment hotfix, not a new architecture decision |
| New enforcers (`enforcers.yaml` rows) | 0 | The 3 new gate sub-rules are pure script-level checks; no new Java enforcer rows. |
| New Java classes / tests | 0 | rc2 is documentation + gate scope only; no Java code change beyond two Javadoc edits in `HookOutcome.java` and `SyncOrchestrator.java`. |

## 7. Verification Snapshot

Ran on 2026-05-17 from `D:\chao_workspace\spring-ai-ascend` (Windows + Git Bash):

```
./mvnw.cmd clean verify
[INFO] BUILD SUCCESS
[INFO] Total time:  35.431 s
Total: 213 Maven tests, 0 failures, 0 errors

bash gate/check_architecture_sync.sh
GATE: PASS    # 63 active rules

bash gate/test_architecture_sync_gate.sh
Tests passed: 92/92

python gate/build_architecture_graph.py
Wrote docs\governance\architecture-graph.yaml: 246 nodes, 323 edges
Graph validation: OK

powershell.exe -ExecutionPolicy Bypass -File gate/check_architecture_sync.ps1
DEPRECATED: gate/check_architecture_sync.ps1 was frozen at Rule 29 in 2026-05.
...
EXIT=2
```

## 8. Self-Audit

Open ship-blocking architecture-truth findings: **none**. The 4 reviewer findings are closed with concrete evidence above. The 9 hidden defects surfaced by category audit are closed in the same commit. The 3 rejected findings are explicitly justified above. The 3 deferred items (α-5/α-6/α-7 ArchUnit enforcers, β-9 vacuous claim, γ-5 parenthetical) all have either an explicit `CLAUDE-deferred.md` entry or a documented rationale in this response.

The rc2 commit is the smallest change that closes contract truth without adding new architectural surface — per the reviewer's instruction "The rc2 work is small and surgical: it should reduce ambiguity without adding new architectural surface." Three new gate sub-rules are the only structural addition; each is a single bash function + 2 self-tests, and each prevents recurrence of one of the three families identified by the category audit.

The corpus is L0-release-ready at tag `v2.0.0-rc2`.
