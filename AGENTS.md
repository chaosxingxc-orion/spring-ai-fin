# AGENTS.md

## Language Rule

**Translate all instructions into English before any model call.** Never pass Chinese, Japanese, or other non-English text into an LLM prompt, tool argument, or task goal.

---

## Engineering Rules

**Twelve rules.** Rules 1–4 are daily-use engineering principles. Rules 5–7 are class-level patterns triggered by resource type. Rules 8–9 are delivery gates. Rules 10–12 are platform-contract standards. All rules override default habits; AGENTS.md overrides everything except explicit user instructions.

---

### Rule 1 — Root-Cause + Strongest-Interpretation Before Plan

**Before writing any plan, fix, or feature — surface assumptions, name confusion, and state tradeoffs. Then (a) name the root cause mechanically and (b) choose the strongest valid reading of the requirement.**

Do not pick one reading silently and ship it expecting the requester to ask again. If unclear, stop and ask first.

**(a) Root-cause discipline** — required before any plan:
1. **Observed failure**: exact error message or test output
2. **Execution path**: which function calls which, where it diverges from expectation
3. **Root cause statement**: one sentence — "X happens because Y at line Z, which causes W"
4. **Evidence**: file:line references that confirm the cause, not the symptom

**(b) Strongest-interpretation defaults:**
- "Gate" → **blocking**, not notification
- "Isolation" → **per-tenant/profile scope**, not process scope
- "Persist" → **survives restart**, not in-memory
- "Compatible" → **same signature + same semantics**, not "same name"

**Enforcement**: A PR without the four-line root-cause block is rejected. A PR delivering the weaker reading of an ambiguous requirement without a prior question is rejected.

---

### Rule 2 — Simplicity & Surgical Changes

**Minimum code that solves the stated problem. Touch only what the task requires.**

- No speculative features, one-use abstractions, unrequested configurability, or impossible-scenario error handling.
- Reach for a library before inventing a framework; reach for a function before inventing a class hierarchy.
- Do not improve, reformat, or rename adjacent code in the same commit. Match surrounding style exactly.
- Remove only imports/variables/functions that **your** change made unused — leave pre-existing dead code for a separate cleanup commit.
- Commits spanning >1 defect ID or >2 distinct modules must be split.
- Parallel-dispatch: second agent to commit must rebase — never `git reset --soft` (silently absorbs other agent's work).

---

### Rule 3 — Pre-Commit Checklist

Before every commit, audit every touched file across all dimensions below. Fix defects before committing — "I'll fix it later" is forbidden.

| Dimension | Check |
|-----------|-------|
| **Contract truth** | No empty stubs, `TODO`-bodied methods, or `NotImplementedError`/`UnsupportedOperationException` placeholders shipped on the default path. |
| **Orphan config** | Every parameter / config field / env var is consumed downstream. |
| **Orphan returns** | Every non-void return value is consumed by the caller. |
| **Subsystem connectivity** | No broken DI, unattached components, missing wiring. |
| **Driver-result alignment** | Every decision-driving field produces an observable effect. |
| **Error visibility** | No silent swallow. Every catch re-raises, logs at `WARNING+`, or converts to typed failure. |
| **Exception handler narrowness** | Broad `catch`/`except` must not eat control-flow signals (cancellation, interrupt, gate-pending) without explicit filtering first. |
| **Branch parity** | Async/reactive and sync paths mirror each other's invariants (run id set, context propagated, timers initialized). |
| **Docstring/Javadoc-implementation parity** | Every example in a doc comment compiles and executes without `AttributeError`/`TypeError`/`NoSuchMethodError`. |
| **Test honesty** | No mocks on the unit under test in integration tests. No assertion that accepts failure as success. |
| **Lint green** | Project linter exits 0. No suppression added in the same commit as the offending line. |
| **ID uniqueness** | Runtime IDs from caller or UUID generator. No `run_id='default'` semantic-label fallback. |
| **Fail-fast test sync** | If a PR tightens a silent path to fail-fast (raise, 5xx, hard validation), update all affected tests in the same PR. |

**Smoke + lint** required before commits touching server entry points, runtime adapters, dependency-wiring modules, or any package init/configuration class.

---

### Rule 4 — Three-Layer Testing, With Honest Assertions

A feature is implementable only when all three layers are designed. A feature is shippable only when all three are green **and** Rule 8 passes.

- **Layer 1 — Unit**: one function/method per test; mock only external network or fault injection, with reason in docstring/comment.
- **Layer 2 — Integration**: real components wired together. **Zero mocks on the subsystem under test.** Skip with the test framework's skip annotation if a dependency is absent — never fake it.
- **Layer 3 — E2E**: drive through the public interface (HTTP / CLI / top-level API); assert on observable outputs, not internal variables.

**Test honesty is not optional**: mocking the subsystem under test in integration = mislabeled unit test; accepting any terminal status = documentation, not a test; a test that passes when the subject raises = a lie.

**TDD evidence for new public route handlers**: every new HTTP route handler requires a comment referencing the commit SHA of the failing test (RED stage), e.g. `// tdd-red-sha: <sha>`.

---

### Rule 5 — Concurrency / Async Resource Lifetime

**Every async or reactive resource (HTTP client, connection pool, scheduler, async generator, reactive subscription) has a lifetime bound to exactly one execution context (event loop, scheduler, container).**

**Forbidden patterns:**
1. Constructing an async/reactive resource in a constructor of a sync-facing class, then driving it via per-call `asyncio.run` / `block()` / `Mono.block()`.
2. Sharing one client/session across two independent event loops or schedulers.
3. Passing a resource built in context A into a coroutine/operator on context B.
4. Wrapping an async library with a sync façade that spins a fresh event loop or scheduler per method.

**Required patterns** — pick one per call site:
- **Async-native**: caller is already async/reactive; use the resource under its owning context.
- **Sync bridge**: route through a single durable bridge (persistent loop on dedicated thread; marshals via thread-safe submit).
- **Per-call construction** (cheap resources only): construct and close inside the coroutine/operator.

Every blocking entry into an async runtime must live in an entry point (CLI, test, `main`) or be routed through the sync bridge.

---

### Rule 6 — Single Construction Path Per Resource Class

**For every shared-state resource, exactly one builder/factory owns construction. All consumers receive the instance by dependency injection. Inline fallbacks of the shape `x or DefaultX()` / `x != null ? x : new DefaultX()` are forbidden.**

When a class needs profile/workspace/project/tenant scoping, scope is a **required constructor argument**, not an optional kwarg/parameter with a default. Missing scope must be a hard error, not a silent fresh unscoped instance.

**Forbidden:** inline fallback to default; optional scope with defaults. **Required:** scope as required argument; raises on missing.

---

### Rule 7 — Resilience Must Not Mask Signals

Every silent-degradation path emits a **loud, structured, ship-gate-visible** signal. Required for each fallback branch:

1. **Countable**: named metric counter exposed to the project's metrics surface (e.g. `*_fallback_total`, `*_heuristic_route_total`).
2. **Attributable**: `WARNING+` log with run id and trigger reason at the branch entry.
3. **Inspectable**: run metadata carries a `fallback_events` list. A terminal run with non-empty fallback_events is not "successful" for delivery purposes.
4. **Gate-asserted**: Rule 8's operator-shape gate asserts fallback counts are zero — any non-zero blocks ship.

Introducing or touching a fallback requires all four. A fallback without an alarm bell is a defect disguised as resilience.

---

### Rule 8 — Operator-Shape Readiness Gate

**No artifact ships until it runs in the exact operator shape downstream will use.** Green unit tests, green Layer 3 E2E, and a clean self-audit do not authorize delivery by themselves.

Before any artifact leaves the repo (jar, container, package, deployment bundle), the following must pass in a clean environment mirroring the target deployment:

1. **Long-lived process** — managed process supervisor (systemd / docker / pm2 / kubernetes); not a foreground shell run. Process survives steps 2–6.
2. **Real external dependencies** — real LLM provider, real database, real message bus — pointing at what downstream will use. Mock gateways disqualify.
3. **Sequential real-dependency runs (N≥3)** — three back-to-back invocations of the public entry point, each: reaches terminal success in ≤ `2 × observed_p95`; fallback count `== 0`; emits ≥1 real-dependency request in access log + metric.
4. **Cross-context resource stability** — runs 2 and 3 reuse the same client/adapter instances as run 1 (Rule 5 stress test). No `event loop closed`, no `connection reset`, no `pool exhausted` on call ≥2.
5. **Lifecycle observability** — each run reports a non-null current stage within 30 s; finished-at populated on terminal. Stage `null` for >60 s on a non-terminal run is a FAIL.
6. **Cancellation round-trip** — cancel on a live run → 200 + drives terminal; cancel on unknown id → 404, not 200.

All six hold. Any FAIL blocks ship. The artifact owner records the gate run in `docs/delivery/<date>-<sha>.md`. Unrecorded ≠ passed.

**Gate validity** — a gate pass is valid only for the SHA at which it was recorded. Any subsequent commit touching hot-path files (runtime, server entry, configuration loaders, runtime adapters) invalidates the gate until a fresh run is recorded.

---

### Rule 9 — Self-Audit is a Ship Gate, Not a Disclosure

A self-audit with open findings in a downstream-correctness category **blocks delivery**. Attaching an honest defect list does not authorize shipping with them.

**Ship-blocking categories (any open finding blocks):**
- Model / LLM path (gateway, adapter, streaming, async lifetime, retry, rate-limit)
- Run lifecycle (stage, state machine, cancellation, resume, watchdog)
- HTTP / API contract (path, method, body, status, auth)
- Security boundary (path traversal, shell injection, auth bypass, tenant-scope escape)
- Resource lifetime (async clients, file handles, subprocesses, background tasks, connection pools)
- Observability (missing metric, log, or health signal for a failure path)

**Forbidden:** any phrasing that ships with open ship-blocking findings ("H-level open, shipping anyway", "follow-up PR will fix", "architectural debt, safe to ship"). If leadership accepts the risk: reclassify as **Known-Defect Notice**, signed by name, acknowledged in writing by downstream, user-visible symptoms spelled out per defect.

---

### Rule 10 — Posture-Aware Defaults

**Every config knob, fallback path, and persistence backend declares its default behaviour under three postures: `dev` / `research` / `prod`.**

- `dev` may be permissive: missing scope emits warnings, in-memory backends allowed, schema validation warns and skips.
- `research` and `prod` default to fail-closed: required scope must be present, persistence must be durable, schemas must be validated, fallbacks must emit metrics.

The posture is set by a single environment variable (e.g. `APP_POSTURE={dev,research,prod}`, default `dev`). Read posture once at startup; never hard-code it at call sites.

Tests must cover at least `dev` and `research` paths for any new contract. Every new strict branch gets a test for both dev-allow and research-reject.

---

### Rule 11 — Contract Spine Completeness

**Every persistent record (run, idempotency, artifact, gate, trace, memory write, knowledge-graph node, team event, feedback, evolution proposal) must explicitly carry at minimum `tenant_id`, plus the relevant subset of `{user_id, session_id, team_space_id, project_id, profile_id, run_id, parent_run_id, phase_id, attempt_id, capability_name}`.**

A record that cannot answer "which tenant / project / profile / run / phase / capability does this belong to" cannot enter the research/prod default path.

**Pre-commit check:** any new contract dataclass / DTO / entity must declare a `tenant_id` field unless explicitly marked `// scope: process-internal` (or language equivalent) with reason.

**Process-internal marker**: pure value objects that are process-internal (not stored or transmitted across tenants) may be marked `scope: process-internal` with a rationale comment. Examples: budget structs, validation results, confidence inputs, stage directives. These are exempt from the `tenant_id` requirement.

---

### Rule 12 — Capability Maturity Model

**Status reporting uses L0–L4, not "implemented" or ad-hoc labels.**

| Level | Name | Criterion |
|---|---|---|
| L0 | demo code | happy path only, no stable contract |
| L1 | tested component | unit/integration tests exist, not default path |
| L2 | public contract | schema/API/state machine stable, docs + tests full |
| L3 | production default | research/prod default-on, migration + observability |
| L4 | ecosystem ready | third-party can register/extend/upgrade/rollback without source |

Delivery notices report L-level per capability with evidence (commit SHA + test file + manifest field + posture coverage). Legacy labels (`experimental`, `implemented_unstable`, `public_contract`, `production_ready`) are retired.

A capability cannot move to L3 without: (a) posture-aware default-on, (b) quarantined failure modes, (c) observable fallbacks per Rule 7, (d) doctor/health-check coverage.

---

## Three-Gate Demand Intake

Before accepting any new capability request:

**G1 — Positioning gate**: capability must fit the project's stated layer; anything outside scope → decline and redirect.

**G2 — Abstraction gate**: composable from existing capabilities without new code → provide a composition example, no new code.

**G3 — Verification gate**: new code requires a Rule 4 three-layer test plan AND a Rule 8 gate run plan before delivery authorization.

**G4 — Posture & Spine gate**: declare (a) default behaviour under `dev`/`research`/`prod` postures and (b) which contract-spine fields it carries; otherwise stays at L0–L1 and cannot enter research/prod default path.

---

## Team Members

- lihongkunbit
- masterchubb-ctrl
- YvesZeng
- Basileuswang
- aimerlee860
