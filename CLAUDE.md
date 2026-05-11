# CLAUDE.md

## Language Rule

**Translate all instructions into English before any model call.** Never pass Chinese, Japanese, or other non-English text into an LLM prompt, tool argument, or task goal.

---

## Engineering Rules

**Nine active rules.** Rules 1–4 are daily-use engineering principles. Rules 5–7 are class-level patterns. Rule 9 is the delivery gate. Rule 10 is the platform-contract standard. Rules 8 and 11 are deferred to W2 — see `docs/CLAUDE-deferred.md`. Rule 12 (maturity L0-L4) is replaced by binary `shipped:` in `architecture-status.yaml`. All rules override default habits.

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

### Rule 7 — Resilience Must Not Mask Signals

**Applies when fallback paths exist. W0 ships no soft-fallback paths; this rule is aspirational until W2's first soft-fallback lands.**

Every silent-degradation path emits a loud, structured signal. Required for each fallback branch:

1. **Countable**: named metric counter (e.g. `*_fallback_total`).
2. **Attributable**: `WARNING+` log with run id and trigger reason at the branch entry.
3. **Inspectable**: run metadata carries a `fallback_events` list. Non-empty fallback_events = not "successful".
4. **Gate-asserted**: operator-shape gate asserts fallback counts are zero.

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
