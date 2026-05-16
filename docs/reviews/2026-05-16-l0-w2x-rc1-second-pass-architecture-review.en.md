---
affects_level: L0
affects_view: process
proposal_status: review
authors: ["Codex Java Microservices + Agent Architecture Review"]
related_review: docs/reviews/2026-05-17-l0-w2x-post-release-review-response.en.md
related_adrs: [ADR-0071, ADR-0072, ADR-0073, ADR-0074, ADR-0076, ADR-0077]
related_rules: [Rule-1, Rule-9, Rule-25, Rule-43, Rule-45, Rule-46, Rule-48]
affects_artefact:
  - docs/releases/2026-05-16-W2x-engine-contract-wave.en.md
  - docs/contracts/engine-envelope.v1.yaml
  - docs/contracts/engine-hooks.v1.yaml
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookOutcome.java
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java
  - gate/README.md
  - gate/check_architecture_sync.ps1
  - docs/governance/architecture-status.yaml
---

# L0 / W2.x rc1 Second-Pass Architecture Review

> **Date:** 2026-05-16
> **Status:** Pending Architecture Team Review
> **Affects:** L0 process view, with secondary logical and development impact

## 1. Executive Verdict

The architecture team closed the prior high-risk runtime gaps. The current Java runtime shape is much stronger than the previous post-release state:

- `./mvnw.cmd clean verify` is green locally.
- `gate/test_architecture_sync_gate.sh` reports `86/86`.
- `gate/build_architecture_graph.py` regenerates `246 nodes / 323 edges` cleanly.
- The S2C failed-transition path is now backed by an integration enforcer.
- `plan-projection.v1.yaml` is a useful, appropriately design-only bridge between dynamic planning and skill-capacity admission.

However, the corpus should not yet be declared "L0 basically complete" without a small rc2 truth cleanup. The remaining issues are not broad architectural redesigns. They are active contract-truth problems: the Windows gate still presents a stale 29-rule pass surface while the release baseline claims 60 active gate rules; HookOutcome comments still promise Run-state effects that the response explicitly deferred; EngineEnvelope construction validation is overclaimed; and the release note still contains unqualified historical verification/tag lines that contradict the rc1 baseline.

I do not see evidence of major over-design in the W2.x agent-driven surface. The envelope remains shallow, S2C is explicit, memory and knowledge ownership are correctly separated, skill capacity is staged rather than prematurely implemented, and the new plan projection contract is the right minimum bridge for dynamic planning. The concern is truthfulness of the active L0 surface, not excess abstraction.

## 2. Findings

### P0-1: PowerShell gate still passes only the old 29-rule surface while active docs list it as a shipped gate implementation

1. **Observed failure / motivation**: `powershell -ExecutionPolicy Bypass -File gate/check_architecture_sync.ps1` exits successfully with 29 `PASS:` lines, while the active baseline claims 60 active gate rules and the README still describes PowerShell/bash parity.
2. **Execution path**: Windows users follow `gate/README.md`, run the PowerShell gate, and receive `GATE: PASS`; that script stops at Rule 29 and never evaluates Rule 28k or Rules 30-60, including the W1/W2 architecture-graph, skill-capacity, engine-envelope, hooks, S2C, evolution-scope, and schema-first checks.
3. **Root cause**: `gate/check_architecture_sync.ps1` was not ported after the later L1/W1/W2 waves, but `gate/README.md` and `docs/governance/architecture-status.yaml` still present it as a shipped architecture-sync implementation, which makes a stale Windows pass look equivalent to the canonical bash gate.
4. **Evidence**: `gate/check_architecture_sync.ps1:4` names "29 rules"; `gate/check_architecture_sync.ps1:11-40` lists only Rules 1-29; `gate/check_architecture_sync.ps1:1055-1101` ends at `whitepaper_alignment_matrix_present` and then prints `GATE: PASS`; `gate/check_architecture_sync.sh:48` includes Rule 28k and `gate/check_architecture_sync.sh:80-90` includes Rules 55-60; `gate/README.md:19-20` says PowerShell is the Windows gate and bash is line-for-line parity; `docs/governance/architecture-status.yaml:81-87` lists both scripts under the shipped architecture-sync gate while claiming 60 active gate rules.

**Required correction:** Choose one of two explicit postures.

- **Parity posture:** port Rules 28a-28k and 30-60 to `check_architecture_sync.ps1`, add/adjust self-tests, and update README counts.
- **Canonical-bash posture:** mark `check_architecture_sync.ps1` as legacy/deprecated, remove it from shipped implementation rows that imply 60-rule coverage, and make the script fail closed with a clear message when used as a release gate.

The current middle state violates the L0 architecture-text truth standard because a green Windows gate does not mean the same thing as a green release gate.

### P0-2: HookOutcome Run-state semantics are still overclaimed in the active contract and Java SPI Javadoc

1. **Observed failure / motivation**: The response correctly deferred HookOutcome Run-state consumption to Rule 45.b, but active contract comments and Java Javadoc still state that `HookOutcome.Fail` transitions the Run to `FAILED`.
2. **Execution path**: `SyncOrchestrator` calls `hookDispatcher.fire(...)` for `BEFORE_SUSPENSION`, `BEFORE_RESUME`, and `ON_ERROR`; the returned `HookOutcome` is discarded at each call-site. `HookDispatcher` can return `Fail` or `ShortCircuit`, but the orchestrator neither consumes those outcomes nor logs the returned values.
3. **Root cause**: The post-review fix updated `CLAUDE.md` and `CLAUDE-deferred.md`, but did not update the active YAML contract or SPI Javadoc that developers will read while implementing middleware, leaving W2.x behavior documented as if W2 Telemetry Vertical behavior were already live.
4. **Evidence**: `docs/contracts/engine-hooks.v1.yaml:16-21` says outcome consumption is design-only, but `docs/contracts/engine-hooks.v1.yaml:39-43` says a `HookOutcome.Fail` causes the Run to transition to `FAILED`; `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookOutcome.java:29-31` repeats the same Run transition claim; `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java:53-57` says Phase 2 logs outcomes only, but the call-sites at `:87`, `:102`, `:114`, `:138`, `:148`, `:166`, and `:177` discard the return value.

**Required correction:** Update the W2.x contract and Java comments to say exactly what is true today: the dispatcher aggregates outcomes and fail-fasts within the middleware chain; the orchestrator ignores or logs outcomes at W2.x; Run-state consumption of `Fail` and engine bypass for `ShortCircuit` are deferred to Rule 45.b. If "logs outcomes only" remains the contract, add a small helper that records the returned `HookOutcome` at every orchestrator call-site and test that behavior.

### P1-1: EngineEnvelope construction validation is described as stronger than the Java record actually enforces

1. **Observed failure / motivation**: Active architecture text says `EngineEnvelope` validates against the YAML schema on construction, while the Java record only validates required fields and map defaults; `engineType` membership validation is explicitly deferred to Rule 48.c.
2. **Execution path**: Code can construct `EngineEnvelope.of("x", "unknown", payload)` successfully; the mismatch is rejected later by `EngineRegistry.resolve(envelope)` or by registry boot validation, not by the record constructor.
3. **Root cause**: The W2.x schema-first wording conflates three different guarantees: Java record shape mirrors the YAML, required fields are checked in the constructor, and `known_engines` membership is validated by `EngineRegistry` at boot/dispatch. Only the latter two weaker guarantees are live in rc1.
4. **Evidence**: `docs/contracts/engine-envelope.v1.yaml:7-13` says the Java record validates against the schema on construction; `CLAUDE.md:355` states the wave invariant as `yaml schema -> Java type that validates against the schema -> runtime self-validate`; `CLAUDE.md:361` repeats that the record validates against the schema on construction; `agent-runtime/src/main/java/ascend/springai/runtime/engine/EngineEnvelope.java:41-52` only checks `name`, `engineType`, and `payload` null/blank requirements and default maps; `docs/CLAUDE-deferred.md:384-388` explicitly says strict construction validation is deferred and that today the constructor validates only nullability.

**Required correction:** Narrow the wording. For rc1, say: "The Java record mirrors the schema and validates required fields on construction; `known_engines` membership is enforced by `EngineRegistry.resolve(...)` and registry boot validation. Constructor-level membership validation is deferred to Rule 48.c." Do not promote strict construction validation unless the record actually loads or receives the known engine vocabulary.

### P1-2: The release note still contains unqualified stale verification and final-tag language

1. **Observed failure / motivation**: The top of the release note now identifies `v2.0.0-rc1`, but later sections still present old verification counts and the retracted `v2.0.0-w2x-final` tag as if they were current.
2. **Execution path**: A reader starts with the new rc1 baseline table, then reaches the Phase 7 historical block. The "Verification" and final conclusion lines are not visibly superseded at their point of use, so they can be cited as current release evidence.
3. **Root cause**: The response consolidated the canonical counts into the top table but kept old Phase 7 verification and conclusion text without adding local "historical/superseded" qualifiers to the specific stale lines.
4. **Evidence**: `docs/releases/2026-05-16-W2x-engine-contract-wave.en.md:1` names rc1 and `:9` says the prior `v2.0.0-w2x-final` tag was retracted; `:102-105` still says `./mvnw test`, 200 tests, 66 active gate rules, and 219+/272+ graph counts; `:166-168` says the addendum is historical, but `:210` still says the corpus is L0-release-ready and recommends `v2.0.0-w2x-final`.

**Required correction:** Either move the stale Phase 7 verification/final-tag block into an explicitly named "Superseded Phase 7 evidence" subsection with every stale command line marked historical, or replace it with the rc1 evidence: `./mvnw clean verify`, 213 Maven tests, 60 active gate rules, 86 self-tests, 246 graph nodes, 323 graph edges, and tag `v2.0.0-rc1`.

## 3. Agent-Driven Architecture Assessment

The agent-driven parts do not need a broad redesign for L0:

- **Dynamic planning:** `docs/contracts/plan-projection.v1.yaml` is the right level of L0 commitment. It makes the planner-to-scheduler handoff explicit without forcing premature Java runtime classes. The planned W2 promotion points - Java record, `PlanProjector` SPI, and `SkillResourceMatrix.admit(PlanProjection)` - are appropriately staged.
- **Skills and capacity:** The architecture correctly separates declared capacity from runtime admission. The remaining capacity orchestration work belongs to W2/W3 implementation, not rc1 L0 redesign.
- **Memory and knowledge:** The ownership boundary is strong: customer/business knowledge remains client-side by default; server-side memory stores execution and telemetry facts. That avoids both under-design and platform overreach.
- **S2C callbacks:** The repaired failed-transition path is now credible for rc1. The deferred ResilienceContract binding should stay deferred unless W2 introduces real concurrent client-capability pressure.
- **Hooks and middleware:** The surface is acceptable if presented as delivery-only. It becomes overclaimed only when comments promise `Fail -> Run.FAILED` or `ShortCircuit -> engine bypass` before Rule 45.b lands.
- **Engine envelope:** The envelope remains intentionally shallow and is not a universal DSL. That is the correct anti-overdesign decision.

## 4. Recommended rc2 Cleanup

1. Fix the gate posture first: either restore PowerShell parity or make bash the only release gate and downgrade the PowerShell script/documentation.
2. Correct HookOutcome comments and/or add actual outcome logging.
3. Correct EngineEnvelope construction-validation wording.
4. Rewrite the release note's stale Phase 7 verification/tag block so no reader can cite superseded evidence as current.
5. Re-run `./mvnw clean verify`, `bash gate/test_architecture_sync_gate.sh`, `python gate/build_architecture_graph.py`, and the chosen canonical architecture gate.

## 5. Verification Notes From This Review

- `./mvnw.cmd clean verify` passed locally.
- `bash gate/test_architecture_sync_gate.sh` passed locally with `86/86`.
- `python gate/build_architecture_graph.py` passed locally and regenerated `246 nodes / 323 edges` without a diff.
- `powershell -ExecutionPolicy Bypass -File gate/check_architecture_sync.ps1 | Select-String -Pattern '^PASS:' | Measure-Object` returned `29`, confirming the stale Windows gate surface.
- The full bash gate could not be completed in this Windows/Git-Bash local shell within the available timeout, so this review relies on the architecture team's published bash-gate claim plus static cross-checks for bash-vs-PowerShell drift. The stale PowerShell finding does not depend on bash execution success.

## 6. Self-Audit

Open ship-blocking architecture-truth findings remain in this document. The runtime implementation is no longer the main blocker, but L0 should not be declared final while active documents and shipped gate entrypoints make contradictory claims. The rc2 work is small and surgical: it should reduce ambiguity without adding new architectural surface.
