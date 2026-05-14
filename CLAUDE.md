# CLAUDE.md

## Language Rule

**Translate all instructions into English before any model call.** Never pass Chinese, Japanese, or other non-English text into an LLM prompt, tool argument, or task goal.

---

## Layer 0 — Governing Principles (non-negotiable)

Every Layer-0 principle is operationalised by one or more Layer-1 rules whose enforcer ships in the same PR (Rule 28 — Code-as-Contract). Sub-clauses without a feasible enforcer-today are staged in `docs/CLAUDE-deferred.md` with explicit re-introduction triggers.

- **P-A — Business / Platform Decoupling + Developer Self-Service.** Business code and Platform code are decoupled. Customization-by-source-patch into platform internals is forbidden. All architecture and solution design MUST be developer-friendly: configuration-driven extension, debug-friendly telemetry, and self-service closure (a developer can build, run, and test an agent end-to-end against the platform without platform-team intervention). Enforced by Rule 29.

- **P-B — Four Competitive Pillars.** Platform competitiveness rests on four continuously-improvable dimensions — **Performance** (latency, throughput), **Cost** (per-call + infra), **Developer Onboarding** (time-to-first-agent + surface complexity), **Governance** (tenant isolation, audit, eval, safety). Each dimension MUST have a published baseline that future releases can be measured against. Enforced by Rule 30.

- **P-C — Code-as-Everything, Rapid Evolution, Independent Modules.** Every architectural constraint is code. Modules evolve independently — each builds, tests, and upgrades on its own, with high cohesion and low coupling. Production-environment upgrades are lightweight (BoM + starter pattern + semver compatibility). Enforced by Rule 28 + Rule 31.

- **P-D — SPI-Aligned, DFX-Explicit, Spec-Driven, TCK-Tested.** Every domain module ships an SPI; every platform/domain module declares its Design-for-X posture (releasability, resilience, availability, vulnerability, observability); contracts precede implementation; alternative implementations must pass a TCK to be conformant. Enforced by Rule 32 (TCK content deferred per `CLAUDE-deferred.md` 32.b/32.c).

History of how the rule set evolved: [`docs/governance/rule-history.md`](docs/governance/rule-history.md). Principle ↔ rule mapping: [`docs/governance/principle-coverage.yaml`](docs/governance/principle-coverage.yaml) (machine-readable; the prior `.md` form was retired in Phase M per ADR-0068 — duplicate truth eliminated; humans read the YAML directly or traverse the graph via `docs/governance/SESSION-START-CONTEXT.md`).

---

## Layer 1 — Engineering Rules (enforceable)

### Daily principles

#### Rule 1 — Root-Cause + Strongest-Interpretation Before Plan

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

#### Rule 2 — Simplicity & Surgical Changes

**Minimum code that solves the stated problem. Touch only what the task requires.**

- No speculative features, one-use abstractions, unrequested configurability, or impossible-scenario error handling.
- Reach for a library before inventing a framework; reach for a function before inventing a class hierarchy.
- Do not improve, reformat, or rename adjacent code in the same commit. Match surrounding style exactly.
- Remove only imports/variables/functions that **your** change made unused — leave pre-existing dead code for a separate cleanup commit.
- Commits spanning >1 defect ID or >2 distinct modules must be split.

---

#### Rule 3 — Pre-Commit Checklist

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

#### Rule 4 — Three-Layer Testing, With Honest Assertions

A feature is implementable only when all three layers are designed. A feature is shippable only when all three are green and Rule 9 passes.

- **Layer 1 — Unit**: one function/method per test; mock only external network or fault injection.
- **Layer 2 — Integration**: real components wired together. **Zero mocks on the subsystem under test.** Skip with the test framework's skip annotation if a dependency is absent — never fake it.
- **Layer 3 — E2E**: drive through the public interface (HTTP / CLI / top-level API); assert on observable outputs, not internal variables.

**Test honesty is not optional**: mocking the subsystem under test in integration = mislabeled unit test.

---

### Class / resource patterns

#### Rule 5 — Concurrency / Async Resource Lifetime

**Every async or reactive resource has a lifetime bound to exactly one execution context.**

**Forbidden patterns:**
1. Constructing an async/reactive resource in a constructor of a sync-facing class, then driving it via per-call `asyncio.run` / `block()` / `Mono.block()`.
2. Sharing one client/session across two independent event loops or schedulers.
3. Wrapping an async library with a sync façade that spins a fresh event loop or scheduler per method.

**Required patterns** — pick one: async-native (use under owning context), sync bridge (single durable bridge on dedicated thread), or per-call construction (cheap resources only).

---

#### Rule 6 — Single Construction Path Per Resource Class

**For every shared-state resource, exactly one builder/factory owns construction. All consumers receive the instance by dependency injection.**

Inline fallbacks of the shape `x or DefaultX()` / `x != null ? x : new DefaultX()` are forbidden.

When a class needs tenant scoping, scope is a **required constructor argument**. Missing scope must be a hard error.

---

### Delivery process

#### Rule 9 — Self-Audit is a Ship Gate, Not a Disclosure

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

#### Rule 10 — Posture-Aware Defaults

**Every config knob, fallback path, and persistence backend declares its default behaviour under three postures: `dev` / `research` / `prod`.**

- `dev`: permissive — warnings only, in-memory backends allowed.
- `research` / `prod`: fail-closed — required config present, durable persistence, fallbacks emit metrics.

Posture set by `APP_POSTURE` env var (default `dev`). Read once at startup; never hard-code at call sites. Per-module posture coverage matrix: [`docs/governance/posture-coverage.md`](docs/governance/posture-coverage.md). Tests MUST cover `dev` and `research` paths for any new contract.

---

### Architectural enforcement

#### Rule 20 — Run State Transition Validity

**Every `Run.withStatus(newStatus)` mutation MUST call `RunStateMachine.validate(this.status, newStatus)` before constructing the updated record. Illegal transitions MUST throw `IllegalStateException`.**

Legal DFA: `PENDING → RUNNING | CANCELLED`; `RUNNING → SUSPENDED | SUCCEEDED | FAILED | CANCELLED`; `SUSPENDED → RUNNING | EXPIRED | FAILED | CANCELLED`; `FAILED → RUNNING`; `SUCCEEDED`, `CANCELLED`, `EXPIRED` are terminal.

Enforced by `RunStateMachine.validate(from, to)` (wired into `Run.withStatus` + `Run.withSuspension`) and unit-tested in `RunStateMachineTest`. Architecture reference: §4 #20, ADR-0020.

---

#### Rule 21 — Tenant Propagation Purity

**No production class under `ascend.springai.runtime..` (main sources) may import any class under `ascend.springai.platform..`. The original narrow case — no import of `TenantContextHolder` — remains the specific instance most likely to be violated and is asserted independently as defence-in-depth.**

`TenantContextHolder` is a request-scoped HTTP-edge ThreadLocal (valid only for the duration of an HTTP request). Runtime production code MUST source tenant identity from `RunContext.tenantId()` instead. Timer-driven resumes and async orchestration have no HTTP request and would silently receive null from the ThreadLocal. The L1 generalisation (ADR-0055) extends the ban from the single ThreadLocal class to the whole platform package, because every platform-side class encodes request-scoped or HTTP-edge concerns that have no defined meaning in runtime contexts (timer-driven resumes, async orchestration, Temporal activities).

Enforced by `RuntimeMustNotDependOnPlatformTest` (ArchUnit — broad, L1 contract per ADR-0055) and `TenantPropagationPurityTest` (ArchUnit — narrow, original Rule 21 per ADR-0023). Test classes are intentionally excluded — `TenantContextFilterTest` may read the holder to verify filter behaviour. Architecture reference: §4 #22, ADR-0023 (origin), ADR-0055 (L1 generalisation).

---

#### Rule 25 — Architecture-Text Truth

**Every `shipped: true` row in `docs/governance/architecture-status.yaml` MUST have a non-empty `tests:` list pointing to a real test class. Every `implementation:` path MUST exist on disk. Every prose claim in `ARCHITECTURE.md` / `agent-*/ARCHITECTURE.md` that names an enforcer ("enforced by X", "asserted by X", "tested by X") MUST be backed by X actually performing the named assertion.**

Path-existence violations caught by Gate Rule 7 (`shipped_impl_paths_exist`). Version-drift violations caught by Gate Rule 8 (`no_hardcoded_versions_in_arch`). Route-exposure violations caught by Gate Rule 9 (`openapi_path_consistency`). Module-dep-direction violations caught by Gate Rule 10 (`module_dep_direction`). Prose-enforcer claims without a real enforcer are a ship-blocking finding under Rule 9.

Architecture reference: §4 #24, ADR-0025 / ADR-0026 / ADR-0027.

---

#### Rule 28 — Code-as-Contract (L1 Governing Rule)

**Every active normative constraint MUST be enforced by code, registered in `docs/governance/enforcers.yaml`, and reach at least one of:**

1. An **ArchUnit test** that fails when the constraint is violated.
2. A **gate-script rule** in `gate/check_architecture_sync.sh` that exits non-zero.
3. An **integration test** that asserts the observable behaviour.
4. A **schema constraint** (NOT NULL / UNIQUE / CHECK / PRIMARY KEY) at the storage layer.
5. A **compile-time check** (`@ConfigurationProperties` + `@Valid`, sealed types, package-info enforcement).

**Coverage discipline.** New normative constraints are gate-enforced via the meta-rule `constraint_enforcer_coverage` and sub-checks 28a–28j (path existence, anchor existence, hardcoded versions, prose-only markers, module count, mandatory tags, etc.). Per-sentence audit across `ARCHITECTURE.md` (root + per-module), ADR decision rules, and `docs/plans/*.md` is enforced via PR review under Rule 9 (Self-Audit Ship Gate) — no automated sentence scanner exists today.

**Scope.** Rule 28 covers shipped *and* deferred constraints, positive capabilities *and* negative invariants ("X must NOT happen" requires an enforcer that detects X).

**No deferred enforcers.** The constraint and its enforcer ship in the same PR. "Test deferred to next sprint" is forbidden — drop the constraint or land the enforcer.

**Self-enforcement.** `docs/governance/enforcers.yaml` is the machine-readable cross-reference (every active constraint → ≥ 1 enforcer row → real artifact). Gate Rule 28 (`constraint_enforcer_coverage`) plus sub-checks 28a–28j police the index itself.

Architecture reference: §4 #45, ADR-0059.

---

### Governing principles (Layer-0 enforceable expressions)

#### Rule 29 — Business/Platform Decoupling Enforcement

**Platform code MUST NOT contain business-specific customizations. Business and example code MUST extend the platform via SPI + `@ConfigurationProperties` only — never by patching `*.impl.*` or `ascend.springai.platform..`. The platform MUST ship a runnable quickstart (`docs/quickstart.md`) referenced from `README.md` so a developer reaches first-agent execution without platform-team intervention.**

Enforced by E48 (`SpiPurityGeneralizedArchTest`) and Gate Rule 31 (`quickstart_present`). Architecture reference: §4 #60, ADR-0064. Deferred sub-clauses: quickstart smoke-run in CI (W1 — see `CLAUDE-deferred.md` 29.c).

---

#### Rule 30 — Competitive Baselines Required

**Every release MUST publish `docs/governance/competitive-baselines.yaml` declaring four pillar dimensions — `performance`, `cost`, `developer_onboarding`, `governance` — each with a named `baseline_metric` and a `current_value` (or `N/A` for not-yet-instrumented). The most recent `docs/releases/*.md` release note MUST mention all four pillar names. A regression in any `current_value` MUST be paired with a `regression_adr:` reference in the row.**

Enforced by Gate Rule 32 (`competitive_baselines_present_and_wellformed`) and Gate Rule 33 (`release_note_references_four_pillars`). Architecture reference: §4 #61, ADR-0065. Deferred sub-clauses: git-diff regression-ADR pairing (30.b); measurement automation (W2/W3 — see `CLAUDE-deferred.md` 30.d).

---

#### Rule 31 — Independent Module Evolution

**Every reactor module under `<module>/pom.xml` MUST own a sibling `<module>/module-metadata.yaml` declaring `module`, `kind ∈ {platform | domain | starter | bom | sample}`, `version`, and `semver_compatibility`. Each module MUST build and test in isolation via `mvn -pl <module> -am test`. Inter-module dependency direction is governed by Rule 10 (`module_dep_direction`).**

Enforced by Gate Rule 34 (`module_metadata_present_and_complete`) and existing Gate Rule 10. Architecture reference: §4 #62, ADR-0066. Deferred sub-clauses: runtime semver compatibility enforcement (W2 — see `CLAUDE-deferred.md` 31.b).

---

#### Rule 32 — SPI + DFX + TCK Co-Design

**Every module declared `kind: domain` in `module-metadata.yaml` MUST expose at least one `*.spi.*` package containing ≥ 1 public interface, listed under `spi_packages:`. Every module with `kind: platform` or `kind: domain` MUST publish a `docs/dfx/<module>.yaml` covering five DFX dimensions — `releasability`, `resilience`, `availability`, `vulnerability`, `observability` — each with a non-empty body. The sibling `<module>-tck` reactor module and conformance suite are deferred per `CLAUDE-deferred.md` 32.b / 32.c (W2 trigger).**

Enforced by E48 (`SpiPurityGeneralizedArchTest`), Gate Rule 35 (`dfx_yaml_present_and_wellformed`), and Gate Rule 36 (`domain_module_has_spi_package`). Architecture reference: §4 #63, ADR-0067. Deferred sub-clauses: TCK module scaffolding (32.b), TCK conformance content (32.c), vulnerability-scanner integration (32.d).

---

### Vibe-Coding-era structural discipline

#### Rule 33 — Layered 4+1 Discipline

**Every architecture artefact (`ARCHITECTURE.md` section, `docs/adr/*.yaml`, `docs/L2/*.md`, `docs/reviews/*.md`) MUST declare two front-matter keys: `level: L0 | L1 | L2` and `view: logical | development | process | physical | scenarios`. The root `ARCHITECTURE.md` is the canonical L0 corpus; per-module `agent-*/ARCHITECTURE.md` files are L1; deep technical designs in `docs/L2/` are L2. Each level MUST organise its content under the 4+1 view headings; L2 MAY omit views not relevant to the feature. All change proposals in `docs/reviews/` MUST declare `affects_level:` and `affects_view:`. Phase-released L0/L1 artefacts are read-only — further edits MUST flow through `docs/reviews/`.**

This rule is the in-repo expression of the chief-architect doctrine (`docs/reviews/2026-05-14-architecture-governance-in-vibe-coding-era.en.md`): a flat ADR pile creates "tubular vision and context collapse" for both human reviewers and LLM agents — they remember constraint A and forget constraint B. View × level decomposition keeps each fragment small enough to load fully. The defect taxonomy from nine prior review rounds shows ~50% of all closed defects fall into the text-form drift family; structural decomposition is the primary mitigation.

Enforced by Gate Rule 37 (`architecture_artefact_front_matter`), Gate Rule 39 (`review_proposal_front_matter`), and `ArchitectureLayeringTest` (ArchUnit, agent-platform). Architecture reference: §4 #64, ADR-0068.

---

#### Rule 34 — Architecture-Graph Truth

**`docs/governance/architecture-graph.yaml` is the single machine-readable index of architectural relationships. It MUST be generated, never hand-edited, by `gate/build_architecture_graph.sh` from authoritative inputs (`docs/governance/principle-coverage.yaml`, `enforcers.yaml`, `architecture-status.yaml`, `module-metadata.yaml`, and the `docs/adr/*.yaml` corpus). The graph MUST encode at minimum these edge classes: `principle → rule`, `rule → enforcer`, `enforcer → test`, `enforcer → artefact`, `capability → test`, `module → module` (allowed / forbidden), `adr → adr` (`supersedes` / `extends` / `relates_to`), and `(level, view) → artefact`. The `supersedes` and `extends` sub-graphs MUST be DAGs. Every edge endpoint MUST resolve to a real graph node or file path. The build script MUST be idempotent — re-running on the same inputs MUST produce a byte-identical output.**

This rule operationalises the principle that an LLM cannot traverse what it has not been shown. The pre-existing YAML side-files (`enforcers.yaml`, `architecture-status.yaml`, etc.) are indexes but supply no joins; reasoning about which test ultimately enforces principle P-B today requires chaining through prose ADR citations the model has to ingest sequentially. The graph encodes those joins as first-class edges and the gate validates the joins close.

Enforced by Gate Rule 38 (`architecture_graph_well_formed`) and Gate Rule 40 (`enforcer_reachable_from_principle`). Architecture reference: §4 #65, ADR-0068.

---

## Deferred Rules

See [`docs/CLAUDE-deferred.md`](docs/CLAUDE-deferred.md). Currently deferred: Rules 7, 8, 11, 13, 14, 15, 16, 17, 18, 19, 22, 23, 24, 26, 27 — plus new sub-clauses 29.c, 30.b, 30.d, 31.b, 32.b, 32.c, 32.d. Each has an explicit re-introduction trigger.
