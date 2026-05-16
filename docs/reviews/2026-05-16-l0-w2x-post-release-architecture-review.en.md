---
affects_level: L0
affects_view: process
proposal_status: review
authors: ["Codex Java Microservices + Agent Architecture Review"]
related_adrs: [ADR-0032, ADR-0034, ADR-0051, ADR-0052, ADR-0071, ADR-0072, ADR-0073, ADR-0074, ADR-0075, ADR-0076, ADR-0077]
related_rules: [Rule-1, Rule-9, Rule-25, Rule-43, Rule-44, Rule-45, Rule-46, Rule-47, Rule-48]
affects_artefact:
  - docs/releases/2026-05-16-W2x-engine-contract-wave.en.md
  - docs/governance/architecture-status.yaml
  - README.md
---

# L0 / W2.x Post-Release Architecture Review

> **Date:** 2026-05-16
> **Status:** Pending Architecture Team Review
> **Affects:** L0 process view, with secondary logical/development impact

## 1. Executive Verdict

The current L0 corpus is substantially stronger than the pre-W2.x baseline, especially in its schema-first direction, tenant/runtime boundary discipline, and explicit agent-system vocabulary. However, it should **not** be treated as "L0-final" or tagged as `v2.0.0-w2x-final` yet.

The release note says there are no open Rule 9 ship-blocking findings, but current verification contradicts that claim:

- `bash gate/check_architecture_sync.sh` passes.
- `bash gate/test_architecture_sync_gate.sh` passes with `84/84`.
- `./mvnw.cmd -pl agent-runtime test` passes with `143` tests.
- `./mvnw.cmd -pl agent-runtime verify` fails because `S2cCallbackRoundTripIT` has 4 failing cases.

The core issue is not that the architecture is fundamentally wrong. The issue is that several active W2.x contracts now have enforcement gaps: one cited integration enforcer is red when run in the correct Maven phase; S2C lifecycle failure semantics are not actually proven; hook fail-fast semantics are declared but not consumed by the orchestrator; and the release truth gate allows contradictory post-audit counts to coexist.

## 2. Ship-Blocking Findings

### P0-1: The S2C Integration Enforcer Is Red Under `verify`, While The Release Uses `test`

1. **Observed failure / motivation**: `./mvnw.cmd -pl agent-runtime verify` fails in `S2cCallbackRoundTripIT` with 4 failures, while the release note claims the S2C round-trip enforcer is green.
2. **Execution path**: Maven `test` runs Surefire unit tests; `*IT.java` classes run in Failsafe during `verify`; the release verification uses `test`, so it misses the S2C integration class.
3. **Root cause**: `S2cCallbackRoundTripIT` does not enter the S2C path because `AgentLoopDefinition.initialContext` is `Map.of()` at `S2cCallbackRoundTripIT.java:70`, while the reasoner throws `S2cCallbackSignal` only when `payload == null` at line 62; using `mvn test` hides this broken integration enforcer because `*IT.java` runs under Failsafe.
4. **Evidence**: `agent-runtime/src/test/java/ascend/springai/runtime/s2c/S2cCallbackRoundTripIT.java:60`, `:62`, `:70`, `:88`, `:90`; `pom.xml:290`; `pom.xml:307`; command result: `./mvnw.cmd -pl agent-runtime verify` fails with `expected: "loop-done:client-result" but was: "loop-done:{}"` and three "Expecting code to raise a throwable" failures.

Impact:

- Enforcer E82 is currently not reliable evidence for Rule 46.
- The release-note claim "Maven tests GREEN 208" is not reproducible from the correct integration-test phase.
- Rule 4's three-layer testing principle is weakened because an integration enforcer exists but the release command does not run it.

Required remediation:

- Fix the S2C test fixture so it actually throws `S2cCallbackSignal` on the first iteration and only avoids rethrow on resume.
- Change release verification from `mvn test` to at least `mvn verify` for modules that cite `*IT` classes as enforcers.
- Add a gate rule that fails when `docs/governance/enforcers.yaml` references an `*IT.java` class but the release note verifies only `test`.

### P0-2: Rule 46 Declares S2C Failure Transitions, But The Current Code Does Not Prove Or Enforce Them

1. **Observed failure / motivation**: The S2C schema says invalid/error/timeout responses transition the Run to `FAILED`, but the implementation currently throws exceptions from inside the S2C catch block without a local FAILED transition or ON_ERROR hook path.
2. **Execution path**: `SyncOrchestrator.executeLoop()` catches `S2cCallbackSignal`, saves the Run as `SUSPENDED`, calls `handleClientCallback`, and then resumes only if `handleClientCallback` returns normally.
3. **Root cause**: S2C error handling throws `IllegalStateException` from `handleClientCallback` at `SyncOrchestrator.java:223`, `:230`, and `:233`, but those exceptions are thrown inside the `catch (S2cCallbackSignal)` block at line 110 and are not caught by the later `catch (RuntimeException)` branch, which means the documented `SUSPENDED -> FAILED` transition is not guaranteed.
4. **Evidence**: `docs/contracts/s2c-callback.v1.yaml:49`, `:50`, `:55`, `:57`, `:75`, `:78`; `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java:110`, `:120`, `:121`, `:128`, `:206`, `:223`, `:230`, `:233`.

Impact:

- This is a Run lifecycle correctness gap, which Rule 9 lists as ship-blocking.
- Even after fixing P0-1's test fixture, the test suite should assert final Run status and ON_ERROR/diagnostic behavior for invalid response, client error, timeout, transport unavailable, and transport failure.
- The current implementation also waits via `toCompletableFuture().join()` without applying `deadline` or `timeout_seconds`; the contract is named "Lifecycle Bound", but the wait is not time-bounded by the runtime.

Required remediation:

- Add a single S2C failure finalizer in `SyncOrchestrator` that transitions `SUSPENDED -> FAILED`, sets `finishedAt`, records a typed reason, and fires `ON_ERROR`.
- Use an explicit timeout path for `deadline` / skill-capacity timeout, or downgrade the W2.x claim so "deadline" is not declared as enforced.
- Extend `S2cCallbackRoundTripIT` to assert Run status, `finishedAt`, failure reason propagation, and hook attributes for all failure cases.

### P0-3: Rule 45 Declares Hook Fail-Fast Semantics, But Orchestrator Callers Ignore `HookOutcome`

1. **Observed failure / motivation**: `docs/contracts/engine-hooks.v1.yaml` and Rule 45 state that a middleware `Fail` aborts dispatch and transitions the Run to `FAILED`, but `SyncOrchestrator` fires hooks and ignores returned outcomes.
2. **Execution path**: `HookDispatcher.fire()` returns `HookOutcome`; `SyncOrchestrator.executeLoop()` calls it before suspension, before resume, and on error.
3. **Root cause**: `HookDispatcher.fire()` returns non-`Proceed` outcomes at `HookDispatcher.java:58` and fail-fast stops the hook chain at line 72, but `SyncOrchestrator` drops the return value at lines 87, 102, 114, 122, 140, and 151, so middleware rejection cannot abort execution or transition the Run to `FAILED`.
4. **Evidence**: `CLAUDE.md:377`; `docs/contracts/engine-hooks.v1.yaml:33`, `:34`, `:35`, `:36`, `:37`; `agent-runtime/src/main/java/ascend/springai/runtime/engine/HookDispatcher.java:58`, `:69`, `:72`; `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java:87`, `:102`, `:114`, `:122`, `:140`, `:151`.

Impact:

- This is especially risky because Rule 45 names security-sensitive policies as middleware candidates: tool authorization, tenant policy, quota, observability, sandbox routing, checkpoint, and failure handling.
- If a future middleware returns `HookOutcome.Fail("tool_authz_denied")`, the dispatcher will report a fail outcome but the orchestrator will continue.
- E80 proves hook delivery, not hook outcome enforcement.

Required remediation:

- Either implement `HookOutcome` consumption in `SyncOrchestrator` now, or amend Rule 45 / `engine-hooks.v1.yaml` so W2.x explicitly ships "delivery-only" hooks and defers fail-fast outcome semantics with a named deferred clause.
- Add an integration test where a `BEFORE_SUSPENSION` or `BEFORE_RESUME` middleware returns `Fail` and the Run becomes `FAILED`.

### P0-4: Runtime Schema Self-Validation Depends On A Repository-Relative YAML Path That Is Not Packaged

1. **Observed failure / motivation**: `EngineAutoConfiguration` claims the default engine-envelope schema path works for the packaged jar, but Maven reports no `agent-runtime/src/main/resources`, and no POM resource rule packages `docs/contracts/engine-envelope.v1.yaml`.
2. **Execution path**: `EngineAutoConfiguration.engineRegistry()` passes `docs/contracts/engine-envelope.v1.yaml` to `EngineRegistry.validateAgainstSchema`; `EngineRegistry.readYaml()` tries filesystem path first, then classpath resource `"/docs/contracts/engine-envelope.v1.yaml"`.
3. **Root cause**: The YAML exists in the repository `docs/` tree but is not copied into any module resources, so boot from a packaged jar outside the repository root will not find the default schema path despite the comment at `EngineAutoConfiguration.java:34-36`.
4. **Evidence**: `agent-platform/src/main/java/ascend/springai/platform/engine/EngineAutoConfiguration.java:34`, `:35`, `:36`, `:59`, `:65`; `agent-runtime/src/main/java/ascend/springai/runtime/engine/EngineRegistry.java:266`, `:278`, `:285`; Maven output: `skip non existing resourceDirectory ... agent-runtime/src/main/resources`; `rg` found no `<resources>` rule packaging `docs/contracts`.

Impact:

- ADR-0076's runtime self-validation is reliable in repository-root tests, but not proven in packaged deployment.
- This is a platform-contract default issue: production boot may fail unless every deployment overrides `app.engine.envelope-schema-path`.

Required remediation:

- Move canonical contract YAMLs needed at runtime into module resources, or add a Maven resource copy from root `docs/contracts`.
- Add a packaged-jar or classpath-only boot validation test that proves `EngineRegistry.validateAgainstSchema()` works with no repository-relative filesystem path.
- Update the configuration comment if the intended contract is "must configure schema path in deployment".

## 3. Release-Truth And Gate Gaps

### P1-1: The Release Note Contains Conflicting Baselines, And The Canonical Ledger Still Advertises Pre-Audit Counts

1. **Observed failure / motivation**: The release note's top baseline table says 82 self-tests, 87 enforcer rows, and 200 Maven tests; the addendum later says 84 self-tests, 89 enforcer rows, and 208 Maven tests.
2. **Execution path**: Gate Rule 28 validates release-note baselines against `architecture_sync_gate.allowed_claim`, but that ledger still contains the pre-Phase-7 counts.
3. **Root cause**: The Phase 7 addendum changed the effective truth surface without updating the canonical `architecture-status.yaml` allowed claim or README baseline, so the gate passes against stale numbers while the release note later contradicts them.
4. **Evidence**: `docs/releases/2026-05-16-W2x-engine-contract-wave.en.md:17`, `:20`, `:21`, `:167`, `:171`, `:172`; `docs/governance/architecture-status.yaml:87`; `README.md:15`; gate result: `release_note_baseline_truth` passes.

Required remediation:

- Make one canonical post-Phase-7 baseline and update `architecture-status.yaml`, `README.md`, and the release note consistently.
- Extend Gate Rule 28 to detect "Updated counts" / addendum tables, or forbid later contradictory count tables unless marked historical.
- Include `verify` counts separately from `test` counts, because IT coverage is now architecturally meaningful.

### P1-2: Enforcer Labels And Anchors Have Small Truth Smells

Examples:

- `S2cCallbackRoundTripIT` class comment says `enforcers.yaml#E83`, but E83 is the no-`Thread.sleep` ArchUnit test; the S2C round-trip is E82.
- `EngineRegistryBootValidationIT` class comment says `enforcers.yaml#E81`, but runtime self-validation is E84.

These are not the same severity as P0-1/P0-2, but they show that Rule 25 still needs semantic cross-checking beyond "anchor exists".

## 4. Agent-Driven Architecture Assessment

### What Is Strong

- **C/S Dynamic Hydration** is correctly separated from internal `RunContext`. ADR-0049 avoids the common mistake of making platform runtime state the client protocol.
- **Memory and knowledge ownership** is directionally sound. ADR-0051 draws the right line: customer business ontology belongs to C-Side by default; S-Side owns execution trajectory, telemetry, and platform state.
- **Skill topology** correctly distinguishes the Java Skill SPI from the distributed scheduler/capability-bidding layer. That distinction prevents a local interface from being over-claimed as a global resource manager.
- **Engine contract wave** is the right architectural move. A shallow envelope plus strict engine matching is preferable to a universal execution DSL.

### What Is Incomplete For "L0-Final"

Dynamic planning is still under-connected. ADR-0032 names `PlanState` and `RunPlanRef` as W4 design-only contracts, while ADR-0052 requires prediction of skill dependency weight before scheduling. There is no named bridge contract that says how a planned step projects required skills, budgets, permissions, memory access, and expected duration into the `SkillResourceMatrix` / bidding path.

Recommendation:

- Add a minimal `PlanProjection` or `StepDependencyProfile` contract before W2 scheduler work:
  - `planId`, `stepKey`, `requiredSkills[]`, `optionalSkills[]`, `budgetEnvelope`, `permissionRefs[]`, `memoryAccessScope`, `estimatedDuration`, `fallbackClass`.
  - This should be design-level at first, but it closes the gap between "planner" and "skill-capacity scheduler".

Memory SPI comments still risk implying business-knowledge ownership. `GraphMemoryRepository` comments say "tenant's knowledge graph", while ADR-0051 says GraphMemory is not the default owner of business ontology.

Recommendation:

- Amend `GraphMemoryRepository` comments to say "platform or explicitly delegated graph memory", not "tenant's knowledge graph" without qualification.
- Before the Graphiti adapter ships, add an ownership declaration field or metadata type that states `PLATFORM_STATE | DELEGATED_BUSINESS_STATE | BOTH`, plus placeholder-preservation policy.

Skill capacity is runtime-started but not orchestration-bound. `DefaultSkillResilienceContract` can reject over-capacity, but the orchestrator does not yet map S2C capacity or general skill saturation into suspended Run state. Some of this is explicitly deferred, but the release note should not imply the full skill-topology scheduler is ready.

Recommendation:

- Keep the L0 claim at "capacity contract surface exists" until orchestrator admission/yield wiring lands.
- Add a negative test once wiring lands: over-capacity skill use suspends only the dependent step, not the whole run or an LLM inference thread.

## 5. Overdesign Assessment

The corpus is heavy, but not purely overdesigned. The number of named contracts is justified by the problem domain if the team treats L0 as an architecture-control plane, not as shipped API.

The overdesign risk is in wording, not in the concepts:

- Too many design-only contracts are phrased with production-strength MUSTs before Java types, schemas, or gates exist.
- Several release notes mix "contract named" with "runtime shipped", which makes readers overestimate maturity.
- Some active rules include behavior that implementation defers informally, creating the exact text/code drift Rule 48 is trying to prevent.

Containment rule:

- Every design-only contract should have one of three labels in the same paragraph: `design-only`, `schema-shipped`, or `runtime-enforced`.
- Release notes should not count a contract as enforcement unless the verification command runs the exact test phase containing its enforcer.

## 6. Recommended Remediation Order

1. **Stop release finalization** until `./mvnw.cmd -pl agent-runtime verify` is green.
2. Fix `S2cCallbackRoundTripIT` so it actually exercises S2C.
3. Implement or explicitly defer S2C FAILED transitions, timeout/deadline enforcement, and S2C ON_ERROR evidence.
4. Implement or explicitly defer `HookOutcome` consumption semantics.
5. Package runtime-read YAML schemas or make schema-path configuration mandatory in research/prod.
6. Refresh release/README/architecture-status counts and amend the gate for addendum count drift.
7. Add the planner-to-skill projection contract and memory ownership comment cleanup before claiming agent-driven L0 completeness.

## 7. Verification Evidence From This Review

Commands run:

```text
bash gate/check_architecture_sync.sh
# PASS

bash gate/test_architecture_sync_gate.sh
# Tests passed: 84/84

./mvnw.cmd -pl agent-runtime test
# BUILD SUCCESS, Tests run: 143

./mvnw.cmd -pl agent-runtime verify -DskipTests=false
# BUILD FAILURE, S2cCallbackRoundTripIT: 4 failures

./mvnw.cmd -pl agent-runtime "-Dtest=S2cCallbackRoundTripIT,EngineMismatchTransitionsRunToFailedIT,RuntimeMiddlewareInterceptsHooksIT" test
# BUILD FAILURE, same 4 S2cCallbackRoundTripIT failures
```

## 8. Self-Audit Against Rule 9

Open ship-blocking categories:

- **Run lifecycle**: S2C failure transitions and tests are not green/proven.
- **Resource lifetime**: S2C waits are not deadline-bounded despite lifecycle-bound wording.
- **Security boundary / policy middleware**: hook fail-fast outcomes are ignored, so future authz/quota/sandbox middleware may be bypassed.
- **HTTP/API / release contract truth**: release verification uses `test` while citing `*IT` enforcers; count truth is inconsistent across release note, README, and architecture-status.

Conclusion: The corpus is **not** L0-final-ready until the P0 findings are closed.

