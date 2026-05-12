# CLAUDE-deferred.md

Rules deferred from `CLAUDE.md`. Each has an explicit re-introduction trigger.
Do not activate these rules before the trigger condition is met.

---

## Rule 7 — Resilience Must Not Mask Signals

**Re-introduction trigger**: first soft-fallback path committed (target: W2 LLM gateway).

**Rule**: Every silent-degradation path emits a loud, structured signal. Required for each fallback branch:

1. **Countable**: named metric counter (e.g. `*_fallback_total`).
2. **Attributable**: `WARNING+` log with run id and trigger reason at the branch entry.
3. **Inspectable**: run metadata carries a `fallback_events` list. Non-empty fallback_events = not "successful".
4. **Gate-asserted**: operator-shape gate asserts fallback counts are zero.

---

## Rule 8 — Operator-Shape Readiness Gate

**Re-introduction trigger**: first shippable jar with a real external dependency (LLM provider
or database) booting under a process supervisor.

**Rule**: No artifact ships until it runs in the exact operator shape downstream will use.
Green unit tests, green Layer 3 E2E, and a clean self-audit do not authorize delivery alone.

Before any artifact leaves the repo, the following must pass in a clean environment:

1. **Long-lived process** — managed process supervisor (systemd / docker / kubernetes); not a foreground shell run.
2. **Real external dependencies** — real LLM provider, real database — pointing at what downstream will use.
3. **Sequential real-dependency runs (N≥3)** — three back-to-back invocations; each reaches terminal success in ≤ `2 × observed_p95`; fallback count `== 0`.
4. **Cross-context resource stability** — runs 2 and 3 reuse the same client instances as run 1 (Rule 5 stress test).
5. **Lifecycle observability** — each run reports a non-null current stage within 30 s; finished-at populated on terminal.
6. **Cancellation round-trip** — cancel on live run → 200 + terminal; cancel on unknown id → 404.

Gate pass recorded in `docs/delivery/<date>-<sha>.md`. Unrecorded ≠ passed.

---

## Rule 11 — Contract Spine Completeness

**Re-introduction trigger**: first persistent record class committed (e.g., `RunRecord`,
`IdempotencyRecord` with Postgres-backed `IdempotencyStore`, or `ArtifactMetadata`).

**Rule**: Every persistent record must explicitly carry at minimum `tenant_id`, plus the
relevant subset of `{user_id, session_id, run_id, parent_run_id, attempt_id, capability_name}`.

**Pre-commit check**: any new contract DTO / entity must declare a `tenant_id` field unless
marked `// scope: process-internal` with reason. Process-internal value objects (budget structs,
validation results, stage directives) are exempt.

---

## Rule 13 — P1 Cost-of-Use Constraints

**Re-introduction trigger**: first context-cache, cost-accounting, or small/large-model handoff capability committed (target: W3).

**Rule (draft)**: Every capability that invokes an LLM call declares its cost profile and cache eligibility. A gate check verifies that:
- Any capability marked `cache_eligible=true` is tested against a real provider cache-hit scenario (not mocked).
- Token budgets are declared in capability metadata; a gate asserts actual usage ≤ declared budget × 1.2.

This rule converts P1 roadmap intent into a pre-commit enforcement path.

---

## Rule 14 — P3 Self-Evolution Constraints

**Re-introduction trigger**: first skill-registry, memory-compression, or knowledge-dedup capability committed (target: W3).

**Rule (draft)**: Every self-modifying capability (skill updates, memory compression, knowledge-source dedup) declares:
- An immutability invariant for its SPI interface (signature frozen unless a new major version is declared).
- A quality floor: recall-at-K ≥ baseline across the regression corpus.
- Monotonicity: updated memory or skills may not reduce retrieval quality below the unmodified baseline.

This rule converts P3 roadmap intent into a pre-commit enforcement path.

---

## Rule 15 — Streamed Handoff Mode Conformance

**Re-introduction trigger**: first `Flux<T>` / SSE return from `Orchestrator` or any northbound controller (target: W2).

**Rule**: Every streaming surface MUST declare and enforce:
- (a) Backpressure strategy (bounded buffer, drop, or error on overflow).
- (b) Cancellation propagation: caller cancel → `RunStatus.CANCELLED` set on the Run.
- (c) Heartbeat cadence ≤ 30 s — positive liveness signal, not absence of error.
- (d) Terminal frame carries `runId` + final `RunStatus` + error payload if applicable.
- (e) Typed progress event shape (`progress | cost | tool_call | partial_output | terminal`) — no raw `Object`.

Composes with: ARCHITECTURE.md §4 #11 (`streamed_handoff_mode`, `orchestrator_cancellation_handshake`).

---

## Rule 16 — Cognitive Resource Arbitration

**Re-introduction trigger**: first `ResilienceContract` consumer that invokes an external tool or skill (not just LLM) (target: W2).

**Rule**: Every skill invocation MUST declare:
- (a) `operationId` in `skill:<name>` namespace.
- (b) Tenant-scoped quota key (prevents one tenant from exhausting shared capacity).
- (c) Global skill capacity key (caps concurrent invocations platform-wide).
- (d) Saturation policy: skill-full suspends the Run (`SUSPENDED + suspendedAt + reason=RateLimited`), not fails it.
- (e) Call-tree budget: parent Run's remaining token/cost budget is propagated through `RunContext` to child Runs.

Composes with: ARCHITECTURE.md §4 #12 (`skill_capacity_matrix`, `call_tree_budget_propagation`); Rule 13 (P1 cost-of-use).

---

## Rule 17 — Degradation Authority and Resume Re-Authorization

**Re-introduction trigger**: first soft-fallback path committed (composes with Rule 7 trigger — W2 LLM gateway).

**Rule**:
- **Degradation authority**: S-side (system) may substitute means only (alternative tool/model/provider) without C-side (caller) approval. Ends-modification (changing the goal, expanding scope, dropping a required action) is surfaced as a typed `BusinessDegradationRequest` to C-side for explicit approval before proceeding.
- **Resume re-authorization**: every resume on a `SUSPENDED` Run MUST re-validate `(request.tenantId == Run.tenantId)`; mismatch returns HTTP 403. Actor identity at resume is captured in an audit envelope (who resumed, when, from which request).

Composes with: ARCHITECTURE.md §4 #14 (`resume_reauthorization_check`, `suspend_reason_taxonomy`); Rule 7 (resilience signal masking).

---

## Rule 18 — Eval Harness Gate

**Re-introduction trigger**: first shipped capability with a golden corpus + LLM-as-judge evaluator committed (target: W4).

**Rule**: Every capability with a `corpus.jsonl` entry under `docs/eval/` MUST pass its declared regression thresholds before merge:

1. **Corpus run**: the eval runner re-runs every input in `docs/eval/<capability>/corpus.jsonl` against the current model + prompt.
2. **Judge evaluation**: the LLM-as-judge (configured model, versioned prompt template) scores each output against the expected.
3. **Threshold gate**: every metric named in `docs/eval/<capability>/thresholds.yaml` must be ≥ its declared threshold; any metric below threshold blocks the merge.
4. **Baseline protection**: a merge that lowers a threshold value without a corresponding corpus expansion MUST include an explicit justification comment in the PR description.

Composes with: ARCHITECTURE.md §4 #18 (`eval_harness_contract`).

---

## Rule 19 — Runtime Hook Conformance

**Re-introduction trigger**: first W2 LLM gateway capability committed (first `ChatClient` call in production code path).

**Rule**: Every LLM invocation, tool call, and agent lifecycle transition MUST be invoked through `HookChain.invoke(...)`, not via a direct provider client call:

1. **No bypass**: an ArchUnit test (`HookChainConformanceTest`) asserts that no class outside the `hookchain` package calls `ChatClient.call(...)`, tool-execution methods, or `AgentLoopExecutor.reason(...)` directly. A violation is a compile-gate failure.
2. **Hook failure safety**: a hook that throws a checked exception MUST be caught; failure is logged at `WARNING+` with `runId` + hook class name; invocation continues. An unchecked exception propagates and fails the invocation — hooks are responsible for safety.
3. **Hook ordering**: hooks execute in `@Order` registration sequence; lower order = earlier execution. `BEFORE_*` hooks run ascending; `AFTER_*` hooks run ascending in the same order (not reversed).
4. **Gate-asserted**: the operator-shape gate asserts that at least one hook (PII filter or token counter) is registered and fires on every real-provider invocation.

Composes with: ARCHITECTURE.md §4 #16 (`runtime_hook_spi`).
