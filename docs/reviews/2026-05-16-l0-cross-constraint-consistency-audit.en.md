---
affects_level: L0
affects_view: process
proposal_status: review
authors: ["Codex Java Microservices + Agent Architecture Review"]
related_review: docs/reviews/2026-05-16-l0-w2x-rc1-second-pass-architecture-review.en.md
related_adrs: [ADR-0019, ADR-0055, ADR-0059, ADR-0064, ADR-0072, ADR-0073, ADR-0074, ADR-0077]
related_rules: [Rule-1, Rule-3, Rule-4, Rule-5, Rule-9, Rule-10, Rule-21, Rule-25, Rule-28, Rule-29, Rule-36, Rule-37, Rule-38, Rule-41, Rule-43, Rule-45, Rule-46, Rule-48]
affects_artefact:
  - AGENTS.md
  - README.md
  - ARCHITECTURE.md
  - CLAUDE.md
  - docs/CLAUDE-deferred.md
  - docs/contracts/contract-catalog.md
  - docs/contracts/engine-envelope.v1.yaml
  - docs/contracts/engine-hooks.v1.yaml
  - docs/contracts/s2c-callback.v1.yaml
  - docs/governance/architecture-status.yaml
  - docs/governance/skill-capacity.yaml
  - docs/quickstart.md
  - gate/README.md
  - gate/check_architecture_sync.ps1
  - gate/check_architecture_sync.sh
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java
  - agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookOutcome.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/S2cCallbackEnvelope.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/S2cCallbackResponse.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackSignal.java
  - agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackTransport.java
  - spring-ai-ascend-graphmemory-starter/src/main/java/ascend/springai/runtime/graphmemory/GraphMemoryProperties.java
  - spring-ai-ascend-graphmemory-starter/README.md
---

# L0 Cross-Constraint Consistency Audit

> **Date:** 2026-05-16
> **Status:** Pending Architecture Team Review
> **Scope:** CLAUDE.md, AGENTS.md, root/module ARCHITECTURE.md, ADRs, SPI/Javadocs, contract YAML, gate scripts, release/quickstart developer-facing docs.

## 1. Executive Verdict

The current architecture corpus is no longer failing because of one missing contract. It is failing because several constraint sources now evolved at different speeds. The architecture team has useful local fixes, but the global rule system still has contradictions that can mislead implementers:

- Some active rules are stricter than the Java implementation and ADR consequence sections.
- Some ADRs intentionally carve out behavior that the governing rule still forbids.
- Some gate/docs entries present stale or weaker enforcement as if it were the current release gate.
- Some developer-facing examples claim "runnable" while containing non-compilable pseudo-code.
- Some SPI purity and dependency-direction rules were amended in code/tests but not in root architecture prose.

This audit should be treated as a constraint-reconciliation task. The remediation should not add more architecture surface. It should collapse duplicate truths, mark legitimate exceptions explicitly, and make the active enforcement boundary obvious.

## 2. Ship-Blocking Or High-Risk Conflicts

### P0-1: S2C is declared non-blocking and suspension-based, but W2.x intentionally blocks on CompletionStage.join()

1. **Observed failure / motivation**: CLAUDE Rule 46 says the waiting Run must suspend and "not block a thread"; the shipped W2.x design and implementation block the orchestrator thread on `CompletionStage.join()`.
2. **Execution path**: A reasoner throws `S2cCallbackSignal`; `SyncOrchestrator` catches it, marks the Run suspended, calls `handleClientCallback`, and `handleClientCallback` waits for `transport.dispatch(envelope).toCompletableFuture().join()` before resuming or failing the Run.
3. **Root cause**: ADR-0074 accepted a synchronous W2.x bridge for an asynchronous SPI, but CLAUDE Rule 46 and P-F/P-G/P-H were not narrowed to say "non-blocking is deferred until the W2 async orchestrator"; this creates a direct contradiction between governing rule and accepted implementation.
4. **Evidence**: `CLAUDE.md:23-27` says no synchronous blocking and OS threads must be released; `CLAUDE.md:387` says S2C must suspend and not block a thread; `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java:248-263` documents and executes `join()`; `agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackTransport.java:19-23` says implementations must not block but SyncOrchestrator blocks at W2.x; `docs/adr/0074-s2c-capability-callback.yaml:98` specifies the join step; `docs/adr/0074-s2c-capability-callback.yaml:130-132` admits the orchestrator thread blocks synchronously at W2.x.

**Question for the architecture team:** Is W2.x allowed to violate Rule 46's "not block a thread" clause because the reference orchestrator is explicitly synchronous, or must S2C be downgraded from `runtime_enforced` to "schema/runtime-shape enforced; non-blocking deferred"?

**Recommendation:** Pick one truth:

- **Strict L0 truth:** make S2C W2.x design-only for non-blocking lifecycle semantics, keep only envelope validation/failure transition runtime-enforced, and add `46.c` for async-orchestrator non-blocking promotion.
- **Runtime fix:** change `SyncOrchestrator` to return/schedule a suspended continuation instead of waiting on `join()`. This is larger and probably not appropriate for rc2.

### P0-2: The S2C signal uses an unchecked RuntimeException, contradicting ADR-0019's checked suspension visibility doctrine

1. **Observed failure / motivation**: ADR-0019 explicitly chose checked `SuspendSignal` to make suspend sites compile-time visible and rejected unchecked suspension because it can propagate silently; ADR-0074 introduces `S2cCallbackSignal extends RuntimeException` for a suspension-like control flow.
2. **Execution path**: Executor lambdas can throw `S2cCallbackSignal` without a `throws` declaration; only `SyncOrchestrator` currently catches it before generic `RuntimeException`; any future orchestrator or wrapper that misses this ordering will treat S2C suspension as an error.
3. **Root cause**: The design optimized for `orchestration.spi` purity and source compatibility, but did not amend the earlier suspension-visibility rule or add an equivalent ArchUnit rule requiring every Orchestrator implementation to catch `S2cCallbackSignal` before `RuntimeException`.
4. **Evidence**: `docs/adr/0019-suspend-signal-and-suspend-reason-taxonomy.md:32-33` says `throws SuspendSignal` makes suspend compile-time visible; `:40-43` rejects unchecked exception because suspend can propagate silently; `:55-59` says checked suspension prevents accidental propagation; `agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackSignal.java:17-19` says lambdas may throw it freely; `docs/adr/0074-s2c-capability-callback.yaml:21-24` and `:126` make `RuntimeException` the accepted trigger; `docs/adr/0074-s2c-capability-callback.yaml:136-139` rejects extending `SuspendSignal`.

**Question for the architecture team:** Is S2C a true suspension primitive, or is it a separate runtime interrupt with a weaker visibility model?

**Recommendation:** Add one explicit rule:

- If S2C is a suspension primitive, introduce a java-only `ClientCallbackRequest` carrier inside `orchestration.spi` and make it flow through `SuspendSignal`.
- If S2C is a separate runtime interrupt, add an ArchUnit enforcer that every concrete `Orchestrator` catches `S2cCallbackSignal` before `RuntimeException`, and amend ADR-0019 to name this exception to the checked-suspension doctrine.

### P0-3: Root architecture still forbids platform -> runtime imports, while ADR-0055 and current code explicitly allow them

1. **Observed failure / motivation**: `ARCHITECTURE.md` still states that `agent-platform` must not import `agent-runtime` Java types directly; ADR-0055 says `agent-platform` may depend on `agent-runtime`; current platform production code imports runtime types heavily.
2. **Execution path**: Implementers reading root architecture will avoid imports that the current L1 platform module requires, while tests and ADRs enforce only the reverse direction (`agent-runtime` must not depend on `agent-platform`) plus selected internal-package restrictions.
3. **Root cause**: ADR-0055 amended module dependency direction, but the root architecture dependency paragraph and its enforcer citation were not rewritten to the new "platform may use runtime public API" posture.
4. **Evidence**: `ARCHITECTURE.md:162-164` says `agent-platform` must not import runtime Java types directly; `docs/adr/0055-permit-platform-to-runtime-direction.md:26-30` says `agent-platform` may depend on `agent-runtime` and only the reverse direction is forbidden; `agent-platform/src/main/java/ascend/springai/platform/web/runs/RunController.java:6-9` imports runtime run types; `agent-platform/src/main/java/ascend/springai/platform/engine/EngineAutoConfiguration.java:3-8` imports runtime engine/executor types; `agent-platform/src/test/java/ascend/springai/platform/architecture/PlatformImportsOnlyRuntimePublicApiTest.java:15-36` documents the current public-surface allowlist.

**Recommendation:** Replace the old root paragraph with ADR-0055 semantics: platform may depend on runtime public surfaces (`runs.*`, `orchestration.spi.*`, `posture.*`, `resilience.*`, authorized wiring exceptions); runtime must never depend on platform; HTTP edge must not import memory SPI or internal runtime packages.

### P0-4: SPI purity is defined as `java.*` only, but the new S2C SPI depends on non-java same-domain records

1. **Observed failure / motivation**: Architecture and AGENTS describe SPI purity as "clients depend on `java.*` only"; `runtime.s2c.spi` imports `S2cCallbackEnvelope` and `S2cCallbackResponse` from `runtime.s2c`, and the generalized SPI purity enforcer does not check `java.*`-only purity.
2. **Execution path**: A new SPI package under `ascend.springai..spi..` can depend on arbitrary same-repo domain packages as long as it avoids Spring/platform/inmemory/Micrometer/OTel. This is weaker than the root architecture's stated rule and weaker than AGENTS' first-principle coverage statement.
3. **Root cause**: ADR-0074 preserved `orchestration.spi` purity by moving S2C to `runtime.s2c.spi`, but did not reconcile that move with the broader "all runtime SPI packages import only java.*" claim.
4. **Evidence**: `ARCHITECTURE.md:230-231` says SPI interfaces under `ascend.springai.runtime.*.spi.*` import only `java.*`; `AGENTS.md:174` repeats "SPI purity - clients depend on `java.*` only"; `agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackTransport.java:3-4` imports non-java S2C records; `agent-runtime/src/main/java/ascend/springai/runtime/s2c/spi/S2cCallbackSignal.java:3` imports `S2cCallbackEnvelope`; `agent-runtime/src/test/java/ascend/springai/runtime/architecture/SpiPurityGeneralizedArchTest.java:31-64` forbids Spring/platform/inmemory/Micrometer/OTel but not general non-java dependencies.

**Recommendation:** Choose one:

- Move `S2cCallbackEnvelope` and `S2cCallbackResponse` into `runtime.s2c.spi` and define SPI purity as "only java.* plus types in the same SPI package".
- Or amend root architecture/AGENTS from "java.* only" to "no framework/platform/impl dependencies; same-domain value records allowed when they are part of the SPI contract", then update test names/Javadocs so they no longer overclaim.

### P0-5: The Windows gate remains a stale pass surface while shipped governance still lists it as architecture-sync implementation

This finding is carried forward from the rc1 second-pass review because it is also a cross-constraint conflict.

1. **Observed failure / motivation**: The PowerShell gate exits successfully after 29 rules, while the active baseline claims 60 active gate rules and gate README still advertises parity.
2. **Execution path**: A Windows contributor can run the documented gate, receive `GATE: PASS`, and miss Rule 28k plus Rules 30-60.
3. **Root cause**: Later waves evolved the bash gate only, while docs/governance entries continued to list the PowerShell script as a shipped implementation.
4. **Evidence**: `gate/check_architecture_sync.ps1:4` names 29 rules; `gate/check_architecture_sync.ps1:1055-1101` ends at Rule 29; `gate/check_architecture_sync.sh:48` includes Rule 28k and `:80-90` includes Rules 55-60; `gate/README.md:19-20` claims PowerShell/bash parity; `docs/governance/architecture-status.yaml:81-87` lists both scripts while claiming 60 active gate rules.

**Recommendation:** Either port parity or fail the PowerShell script closed with a canonical-bash message. Do not allow a stale Windows pass to remain a release-gate-looking command.

## 3. Significant P1 Consistency Problems

### P1-1: Active rule counts are inconsistent across AGENTS, README, and architecture-status

1. **Observed failure / motivation**: The active instruction file says eleven active rules; the current baseline says 34 active engineering rules; README has both the updated count and an older "27 active" line.
2. **Execution path**: Agents and contributors load AGENTS.md first, then CLAUDE.md/README/status. They receive mutually incompatible counts and may incorrectly treat Rules 28-48 as non-active.
3. **Root cause**: AGENTS.md was not regenerated after CLAUDE.md grew from the original 11-rule subset; README line-level metadata was partially updated.
4. **Evidence**: `AGENTS.md:11` says "Eleven active rules"; `README.md:15` says 34 active engineering rules and 77 ADRs; `README.md:65` still says ADR-0001 to ADR-0070 and 27 active rules; `docs/governance/architecture-status.yaml:87` says 34 active engineering rules and 77 ADRs.

**Recommendation:** Make AGENTS.md a thin operational wrapper that points to CLAUDE.md for current rule inventory, or generate AGENTS.md from the canonical architecture-status claim. Update README line 65.

### P1-2: Rule 28 says "no deferred enforcers", while the corpus relies on staged deferred sub-clauses and design-only contracts

1. **Observed failure / motivation**: Rule 28 states that shipped and deferred constraints need enforcers and that deferred enforcers are forbidden, but multiple active sections legitimately stage sub-clauses in `docs/CLAUDE-deferred.md` and new contracts use `status: design_only`.
2. **Execution path**: Reviewers can read any "MUST" in CLAUDE/ARCHITECTURE and demand an enforcer today, while the same documents say some sub-clauses are deferred with triggers.
3. **Root cause**: The rule system does not define a crisp taxonomy for `active constraint`, `deferred sub-clause`, `design-only contract`, `schema-shipped`, and `runtime-enforced`.
4. **Evidence**: `CLAUDE.md:203-209` says Rule 28 covers shipped and deferred constraints and forbids deferred enforcers; `CLAUDE.md:11` says sub-clauses without feasible enforcer-today are staged in `docs/CLAUDE-deferred.md`; `CLAUDE.md:415` lists many deferred sub-clauses; `docs/contracts/plan-projection.v1.yaml:27-28` is `design_only` and `runtime_enforced: false`; `docs/reviews/2026-05-17-l0-w2x-post-release-review-response.en.md:54` accepts status labels including `design_only` and `schema_shipped`.

**Recommendation:** Add a short "constraint state taxonomy" to CLAUDE.md: only `runtime_enforced` / `active normative` constraints require an executable enforcer today; `design_only` and deferred sub-clauses require an explicit trigger, owner, and no present-tense runtime claim.

### P1-3: HookOutcome lifecycle semantics are overclaimed outside the controlling W2.x clarification

1. **Observed failure / motivation**: CLAUDE.md correctly says HookOutcome Run-state consumption is deferred, but YAML and Java SPI comments still promise `Fail -> Run.FAILED`.
2. **Execution path**: Middleware authors can rely on `HookOutcome.Fail` aborting a Run even though `SyncOrchestrator` discards returned outcomes.
3. **Root cause**: The post-review clarification was not propagated to the active contract and SPI Javadoc.
4. **Evidence**: `CLAUDE.md:381` says the orchestrator does not consume outcomes at W2.x; `docs/contracts/engine-hooks.v1.yaml:39-43` says `HookOutcome.Fail` transitions the Run to `FAILED`; `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookOutcome.java:29-31` repeats the Run transition claim; `SyncOrchestrator.java:87`, `:102`, `:114`, `:138`, `:148`, `:166`, and `:177` discard the return value.

**Recommendation:** Update comments to "dispatcher-chain fail-fast only" and add actual outcome logging if the phrase "outcomes are logged" remains.

### P1-4: EngineEnvelope construction validation is overclaimed

1. **Observed failure / motivation**: Root rule and YAML say the record validates against the schema on construction; the record only validates required fields and defaults maps.
2. **Execution path**: Unknown `engineType` values can be constructed and are rejected later by registry resolution/boot validation.
3. **Root cause**: The schema-first invariant conflated record shape validation with closed-vocabulary membership validation.
4. **Evidence**: `CLAUDE.md:355` and `:361` say Java type validates against schema on construction; `docs/contracts/engine-envelope.v1.yaml:7-13` says the same; `agent-runtime/src/main/java/ascend/springai/runtime/engine/EngineEnvelope.java:41-52` validates null/blank only; `docs/CLAUDE-deferred.md:384-388` explicitly defers strict construction validation.

**Recommendation:** Narrow rc1 wording to "required-field validation on construction; known-engine membership at registry boot/dispatch; constructor membership deferred to 48.c."

### P1-5: S2C trace ID format is stricter in contract than in Java validation

1. **Observed failure / motivation**: The YAML contract and Java error messages say W3C 32-char lowercase hex, but constructors only check length.
2. **Execution path**: A caller can construct an envelope/response with 32 non-hex or uppercase characters; it passes construction despite violating the contract.
3. **Root cause**: Constructor validation implemented the length half of the schema but not the lowercase-hex character class.
4. **Evidence**: `docs/contracts/s2c-callback.v1.yaml:33` and `:45` require W3C 32-char lowercase hex trace IDs; `agent-runtime/src/main/java/ascend/springai/runtime/s2c/S2cCallbackEnvelope.java:38-40` checks only `traceId.length() != 32`; `agent-runtime/src/main/java/ascend/springai/runtime/s2c/S2cCallbackResponse.java:31-33` checks only `clientTraceId.length() != 32`.

**Recommendation:** Add a shared lowercase-hex validator and tests for uppercase/non-hex rejection, or relax the contract text if the platform accepts broader IDs.

### P1-6: The quickstart is claimed as runnable/self-service, but its first-agent example is pseudo-code and non-compilable

1. **Observed failure / motivation**: Rule 29 and ARCHITECTURE say the platform must ship a runnable quickstart; the current quickstart's first Run example calls a non-existent method.
2. **Execution path**: A developer copies the quickstart snippet; `orchestrator.start(run.runId(), ...)` does not exist because the SPI exposes `run(UUID, String, ExecutorDefinition, Object)`.
3. **Root cause**: Gate Rule 31 only checks file existence and README linkage, so it cannot validate the "runnable first-agent" claim.
4. **Evidence**: `CLAUDE.md:219-221` requires a runnable quickstart but says enforcement is only E48 + `quickstart_present`; `ARCHITECTURE.md:741` repeats the runnable quickstart claim; `docs/quickstart.md:61-66` uses `orchestrator.start(...)`; `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/Orchestrator.java:28` exposes only `run(...)`; `gate/check_architecture_sync.sh:1523-1537` checks only presence/linkage.

**Recommendation:** Either make the snippet compile and add a smoke test, or downgrade the rule to "quickstart document exists" until Rule 29.c lands. Do not claim first-agent self-service from a presence-only gate.

### P1-7: Graph memory configuration violates orphan-config/posture wording

1. **Observed failure / motivation**: Contract catalog says graphmemory requires `base-url` when enabled; README says `base-url` is ignored at W0; the properties class also exposes `apiKey`, which is not documented or consumed.
2. **Execution path**: `springai.ascend.graphmemory.enabled=true` enables an auto-configuration class, but no bean is registered and neither `baseUrl` nor `apiKey` is consumed downstream.
3. **Root cause**: The graphmemory starter kept future adapter properties while the implementation was downgraded to "no bean at W0"; Rule 3's orphan-config rule and Rule 10 posture declaration were not reconciled with that scaffold.
4. **Evidence**: `docs/contracts/contract-catalog.md:75` says graphmemory sidecar adapters require `base-url` when enabled; `spring-ai-ascend-graphmemory-starter/README.md:44-45` says `base-url` is ignored at W0; `spring-ai-ascend-graphmemory-starter/src/main/java/ascend/springai/runtime/graphmemory/GraphMemoryProperties.java:8-17` defines `enabled`, `baseUrl`, and `apiKey`; `GraphMemoryAutoConfiguration.java:9-13` registers no consuming bean; `GraphMemoryAutoConfigurationTest.java:15-20` asserts no `GraphMemoryRepository` bean exists.

**Recommendation:** For rc2, either remove `baseUrl`/`apiKey` until the adapter exists, or mark them explicitly as reserved and update contract-catalog so "required when enabled" applies only once an adapter bean ships. Add posture behavior for `enabled=true` in research/prod if it remains a live knob.

### P1-8: Skill capacity YAML says S2C is enforced by SyncOrchestrator today, but ADR/CLAUDE defer that runtime binding

1. **Observed failure / motivation**: `skill-capacity.yaml` says the matrix is consumed at runtime and names `SyncOrchestrator.handleClientCallback (W2.x)` as enforcer for `s2c.client.callback`; the actual orchestrator does not consult `ResilienceContract.resolve(...)`, and ADR/CLAUDE say the binding is deferred.
2. **Execution path**: Concurrent S2C callbacks are dispatched without capacity admission; only the schema row exists.
3. **Root cause**: The capability row was added to make the contract enumerable, but its `realised_by` field and header comments overstate runtime consumption.
4. **Evidence**: `docs/governance/skill-capacity.yaml:13` says consumed by `ResilienceContract.resolve` at runtime; `docs/governance/skill-capacity.yaml:48-57` names S2C and `SyncOrchestrator.handleClientCallback (W2.x)`; `CLAUDE.md:391` says runtime ResilienceContract integration for S2C is deferred; `docs/contracts/s2c-callback.v1.yaml:73-79` says SyncOrchestrator enforcement is deferred to W2; `SyncOrchestrator.java:254-263` dispatches directly with no capacity resolve call.

**Recommendation:** Change the row to `status: declared_not_consumed` or equivalent until W2 binding lands, and update `realised_by` to name the future enforcer, not W2.x runtime.

### P1-9: Release and entrypoint docs still carry stale counts and verification commands

This overlaps the rc1 second-pass review but remains a cross-source consistency issue:

- `docs/releases/2026-05-16-W2x-engine-contract-wave.en.md:102-105` still lists `./mvnw test`, 200 tests, 66 active gate rules, and old graph counts.
- `docs/releases/2026-05-16-W2x-engine-contract-wave.en.md:210` still recommends the retracted `v2.0.0-w2x-final` tag.
- `README.md:20` still presents `./mvnw clean test` as quick start even though the rc1 evidence baseline switched to `verify` because `test` skips `*IT.java` enforcers.

**Recommendation:** Keep `test` as a fast developer command if desired, but label release verification as `verify` everywhere and remove or locally mark the stale release-note block as superseded historical evidence.

## 4. Cross-Cutting Remediation Plan

1. **Create a single constraint-state vocabulary.** Suggested states: `active_runtime_enforced`, `active_schema_enforced`, `design_only`, `deferred_with_trigger`, `historical_superseded`. Require every contract YAML and major rule paragraph to use one of them when the enforcement is not obvious.
2. **Normalize authority precedence.** ADRs may amend CLAUDE/ARCHITECTURE only if the active prose is updated in the same PR. Otherwise the ADR is an unmerged design decision, not a governing rule.
3. **Fix S2C truth first.** It is the highest-risk conflict because it crosses runtime lifecycle, resource lifetime, callback governance, skill capacity, and SPI purity.
4. **Collapse duplicated counts.** Make AGENTS.md/README/release notes derive counts from `architecture-status.yaml` or stop carrying counts outside the canonical baseline paragraph.
5. **Make gate posture explicit.** Canonical bash-only is acceptable if declared. Stale cross-platform parity is not.
6. **Split "presence gates" from "behavior gates".** A file-existence gate must never be cited as proving runnable behavior. Quickstart, graphmemory config, and design-only contracts need clearer language.

## 5. Questions For The Architecture Team

1. Is `SyncOrchestrator` allowed to block for S2C at W2.x, or should S2C be truthfully downgraded until the async orchestrator lands?
2. Does SPI purity mean literal `java.*` only, or framework/platform/impl-free with same-domain value records allowed?
3. Is S2C a suspension primitive under ADR-0019, or a separate runtime interrupt with a weaker visibility model?
4. Is bash the only canonical release gate now, or must PowerShell parity be restored?
5. Should design-only contracts be allowed to contain `MUST` clauses, or should `MUST` be reserved for active/runtime-enforced constraints?
6. Should quickstart be considered a presence-only developer guide or a compiled/tested first-agent path?
7. Are graphmemory `baseUrl` and `apiKey` live config knobs, or reserved future fields that should not be present under Rule 3?

## 6. Suggested rc2 Acceptance Criteria

- `AGENTS.md`, `README.md`, `architecture-status.yaml`, and the release note agree on active engineering-rule count, ADR count, gate-rule count, and verification command.
- S2C contract status distinguishes envelope/failure-transition enforcement from non-blocking lifecycle and skill-capacity enforcement.
- Root architecture dependency paragraph matches ADR-0055 and the actual platform imports.
- SPI purity wording and ArchUnit tests agree.
- HookOutcome and EngineEnvelope comments match actual runtime behavior.
- Quickstart first-agent snippet compiles or is explicitly marked illustrative.
- Graphmemory config fields are either consumed or removed/reserved with a clear posture matrix.
- The chosen architecture gate command fails if the current 60-rule surface is not evaluated.

## 7. Verification Notes From This Audit

- Static cross-checks used `rg` and direct source reads across CLAUDE.md, AGENTS.md, ARCHITECTURE.md, ADRs, SPI/Javadocs, contract YAML, gate scripts, and developer docs.
- `./mvnw.cmd clean verify` had already passed in the immediate rc1 second-pass review session.
- `gate/test_architecture_sync_gate.sh` had already passed with `86/86` in the immediate rc1 second-pass review session.
- This audit is documentation-only and introduces no runtime code changes.
