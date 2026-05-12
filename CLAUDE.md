# CLAUDE.md

## Language Rule

**Translate all instructions into English before any model call.** Never pass Chinese, Japanese, or other non-English text into an LLM prompt, tool argument, or task goal.

---

## Engineering Rules

**Eleven active rules.** Rules 1–4 are daily-use engineering principles. Rules 5–6 are class-level patterns. Rule 9 is the delivery gate. Rule 10 is the platform-contract standard. Rules 20–21 are architectural enforcement rules added in the third-review cycle. Rule 25 is the architecture-text truth gate added in the fourth-review cycle. Rules 7, 8, and 11 are deferred — see `docs/CLAUDE-deferred.md`. Rules 22–24 are also deferred (W2 trigger). Rules 26–27 are deferred (W2/W3 trigger — skill lifecycle and untrusted sandbox mandate). Rule 12 (maturity L0-L4) is replaced by binary `shipped:` in `architecture-status.yaml`. All rules override default habits.

---

### Rule 1 — Root-Cause + Strongest-Interpretation Before Plan

**Before writing any plan, fix, or feature — surface assumptions, name confusion, and state tradeoffs. Then (a) name the root cause mechanically and (b) choose the strongest valid reading of the requirement.**

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

**Enforcement**: A PR without the four-line root-cause block is rejected.

---

### Rule 2 — Simplicity & Surgical Changes

**Minimum code that solves the stated problem. Touch only what the task requires.**

- No speculative features, one-use abstractions, unrequested configurability, or impossible-scenario error handling.
- Reach for a library before inventing a framework; reach for a function before inventing a class hierarchy.
- Do not improve, reformat, or rename adjacent code in the same commit. Match surrounding style exactly.
- Remove only imports/variables/functions that **your** change made unused — leave pre-existing dead code for a separate cleanup commit.
- Commits spanning >1 defect ID or >2 distinct modules must be split.

---

### Rule 3 — Pre-Commit Checklist

Before every commit, audit every touched file. Fix defects before committing — "I'll fix it later" is forbidden.

| Dimension | Check |
|-----------|-------|
| **Contract truth** | No empty stubs, `TODO`-bodied methods, or `UnsupportedOperationException` placeholders shipped on the default path. |
| **Orphan config** | Every parameter / config field / env var is consumed downstream. |
| **Error visibility** | No silent swallow. Every catch re-raises, logs at `WARNING+`, or converts to typed failure. |
| **Lint green** | Project linter exits 0. No suppression added in the same commit as the offending line. |
| **Test honesty** | No mocks on the unit under test in integration tests. No assertion that accepts failure as success. |

**Smoke + lint** required before commits touching server entry points, runtime adapters, or dependency-wiring modules.

---

### Rule 4 — Three-Layer Testing, With Honest Assertions

A feature is implementable only when all three layers are designed. A feature is shippable only when all three are green and Rule 9 passes.

- **Layer 1 — Unit**: one function/method per test; mock only external network or fault injection.
- **Layer 2 — Integration**: real components wired together. **Zero mocks on the subsystem under test.** Skip with the test framework's skip annotation if a dependency is absent — never fake it.
- **Layer 3 — E2E**: drive through the public interface (HTTP / CLI / top-level API); assert on observable outputs, not internal variables.

**Test honesty is not optional**: mocking the subsystem under test in integration = mislabeled unit test.

---

### Rule 5 — Concurrency / Async Resource Lifetime

**Every async or reactive resource has a lifetime bound to exactly one execution context.**

**Forbidden patterns:**
1. Constructing an async/reactive resource in a constructor of a sync-facing class, then driving it via per-call `asyncio.run` / `block()` / `Mono.block()`.
2. Sharing one client/session across two independent event loops or schedulers.
3. Wrapping an async library with a sync façade that spins a fresh event loop or scheduler per method.

**Required patterns** — pick one: async-native (use under owning context), sync bridge (single durable bridge on dedicated thread), or per-call construction (cheap resources only).

---

### Rule 6 — Single Construction Path Per Resource Class

**For every shared-state resource, exactly one builder/factory owns construction. All consumers receive the instance by dependency injection.**

Inline fallbacks of the shape `x or DefaultX()` / `x != null ? x : new DefaultX()` are forbidden.

When a class needs tenant scoping, scope is a **required constructor argument**. Missing scope must be a hard error.

---

### Rule 20 — Run State Transition Validity [Active]

**Every `Run.withStatus(newStatus)` mutation MUST call `RunStateMachine.validate(this.status, newStatus)` before constructing the updated record. Illegal transitions MUST throw `IllegalStateException`.**

Legal DFA: `PENDING → RUNNING | CANCELLED`; `RUNNING → SUSPENDED | SUCCEEDED | FAILED | CANCELLED`; `SUSPENDED → RUNNING | EXPIRED | FAILED | CANCELLED`; `FAILED → RUNNING`; `SUCCEEDED`, `CANCELLED`, `EXPIRED` are terminal.

Enforced by `RunStateMachine.validate(from, to)` (wired into `Run.withStatus` + `Run.withSuspension`) and unit-tested in `RunStateMachineTest`. Architecture reference: §4 #20, ADR-0020.

---

### Rule 21 — Tenant Propagation Purity [Active]

**No production class under `ascend.springai.runtime.*` (main sources) may import `ascend.springai.platform.tenant.TenantContextHolder`.**

`TenantContextHolder` is a request-scoped HTTP-edge ThreadLocal (valid only for the duration of an HTTP request). Runtime production code MUST source tenant identity from `RunContext.tenantId()` instead. Timer-driven resumes and async orchestration have no HTTP request and would silently receive null from the ThreadLocal.

Enforced at W0 by `TenantPropagationPurityTest` (ArchUnit). Test classes are intentionally excluded — `TenantContextFilterTest` may read the holder to verify filter behaviour. Architecture reference: §4 #22, ADR-0023.

---

### Rule 25 — Architecture-Text Truth [Active]

**Every `shipped: true` row in `docs/governance/architecture-status.yaml` MUST have a non-empty `tests:` list pointing to a real test class. Every `implementation:` path MUST exist on disk. Every prose claim in `ARCHITECTURE.md` / `agent-*/ARCHITECTURE.md` that names an enforcer ("enforced by X", "asserted by X", "tested by X") MUST be backed by X actually performing the named assertion.**

Violations of the path-existence constraint are caught at commit time by Gate Rule 7 (`shipped_impl_paths_exist`). Violations of the version-drift constraint are caught by Gate Rule 8 (`no_hardcoded_versions_in_arch`). Violations of the route-exposure constraint are caught by Gate Rule 9 (`openapi_path_consistency`). Violations of the module-dep-direction constraint are caught by Gate Rule 10 (`module_dep_direction`). Prose-enforcer claims without a real enforcer are a ship-blocking finding under Rule 9.

Architecture reference: §4 #24 (new), ADR-0025/ADR-0026/ADR-0027.

---

### Rule 7 — Resilience Must Not Mask Signals [Deferred to W2]

**Deferred.** No live fallback path exists at W0. Re-introduction trigger: first soft-fallback path committed (target: W2 LLM gateway). Full rule text in `docs/CLAUDE-deferred.md`.

---

### Rule 9 — Self-Audit is a Ship Gate, Not a Disclosure

A self-audit with open findings in a downstream-correctness category **blocks delivery**.

**Ship-blocking categories:**
- Model / LLM path (gateway, adapter, streaming, async lifetime, retry, rate-limit)
- Run lifecycle (stage, state machine, cancellation, resume, watchdog)
- HTTP / API contract (path, method, body, status, auth)
- Security boundary (path traversal, shell injection, auth bypass, tenant-scope escape)
- Resource lifetime (async clients, file handles, subprocesses, connection pools)
- Observability (missing metric, log, or health signal for a failure path)

**Forbidden:** any phrasing that ships with open ship-blocking findings.

---

### Rule 10 — Posture-Aware Defaults

**Every config knob, fallback path, and persistence backend declares its default behaviour under three postures: `dev` / `research` / `prod`.**

- `dev`: permissive — warnings only, in-memory backends allowed.
- `research` / `prod`: fail-closed — required config present, durable persistence, fallbacks emit metrics.

Posture set by `APP_POSTURE` env var (default `dev`). Read once at startup; never hard-code at call sites.

**W0 posture coverage:**

| Module | dev | research | prod |
|--------|-----|----------|------|
| `agent-platform` (tenant, idempotency, IdempotencyStore) | warn + permissive | reject / throw | reject / throw |
| `spring-ai-ascend-graphmemory-starter` | no bean registered | no bean registered | no bean registered |

Tests must cover `dev` and `research` paths for any new contract.

---

## Constraint Coverage by First Principle

**P1 (lower cost-of-use)** and **P3 (self-evolving intelligence)** have no gate-enforced rules at W0 — intentional, because no cost-accounting, context-caching, skill-registry, or memory-compression capability exists yet. Rules 13 (P1) and 14 (P3) are staged in `docs/CLAUDE-deferred.md` with W3 re-introduction triggers; they must be activated before the first W3 capability ships.

**P2 (lower onboarding barrier)** is covered by Architecture §4.7 (SPI purity — clients depend on `java.*` only), Architecture §4.2 (posture model — `dev` permissive default), Architecture §4.6 (OSS-first — glue LOC ≤ 1500), Rule 6 (single `@Bean` construction path), Rule 20 (Run state machine — prevents lifecycle corruption), and Rule 21 (tenant propagation purity — prevents cross-tenant data leaks).

**E1 (OSS-first reuse)** is operationalised by Architecture §4.6 (glue LOC ≤ 1500) and the Occam pass decision rule: "SPI wrapping an OSS Java interface → DELETE."
