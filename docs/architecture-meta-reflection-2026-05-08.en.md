# Architecture Convergence Analysis and Scoring Framework

Date: 2026-05-08
Author: cycle-8 author, post-cycle reflection (not a remediation cycle).
Audience: anyone deciding what spring-ai-fin should do next.

> Per CLAUDE.md language rule, this document is in English. It is a
> reflection document, not a design or remediation plan; it is excluded
> from `active_documents` in `docs/governance/active-corpus.yaml`.

## 0. Why this document exists

After cycle 8 the user observed: "we have done many review-and-fix
rounds but the work is not converging." This document answers that
observation honestly. It is not another cycle. It does not propose new
gate rules. Its purpose is to define what "done" should mean for this
project so that future decisions can be evaluated, not just executed.

## 1. Executive verdict

The cycle 1..8 loop is not converging because the fix surface IS the
audit surface. We are governing a system that does not exist. The
repository contains:

- Approximately **0 lines** of Java/Kotlin source code.
- Approximately **0 lines** of test code.
- Approximately **0** runnable artifacts (no `pom.xml` at root, no JAR,
  no container image, no migrations).
- Approximately **3800 lines** of governance machinery: gate scripts
  (~1500), evidence manifest (~150), status ledger (~900), active-corpus
  registry (~250), delivery files (~1050 across 8 deliveries).

Every cycle has added more governance and produced zero product. The
review loop will not converge under the current strategy because (a)
auditors will always find drift in 3800 lines of governance, and (b)
several recent cycles' findings were caused by the previous cycles' own
governance additions (eol_policy, manifest_no_tbd, ascii_only_*, etc.).

The next correct move is not cycle 9. The next correct move is to
commit to a directional choice: build the runtime, scope the spec, or
explicitly bound the hybrid. Section 6 lists the three options.

## 2. Root cause: what is actually broken

Three converging failure modes.

### 2.1 Documentation-as-Implementation antipattern

Every L0/L1/L2 ARCHITECTURE.md describes behaviors with **no Java code,
no test, no operational signal** behind them. The docs are treated as
if they were the system. Reviewers find drift in the docs; the team
fixes the docs; the system being described does not change because
there is no system.

Symptom: 17 capabilities in the status ledger, all at maturity L0. The
maturity ladder is intended as a progression L0 -> L4. With everything
stuck at L0, the ladder is just labels on a wishlist.

### 2.2 Self-licking-ice-cream gate

The architecture-sync gate is supposed to detect drift between docs.
But with 35+ active docs and ~600 lines of gate logic, the gate itself
becomes a major source of findings. Of cycle-8's ten new structural
rules, the following exist solely to police governance the gate
introduced in earlier cycles:

- `eol_policy` polices `.gitattributes` which cycle 8 itself added.
- `manifest_no_tbd` polices manifest fields cycle 7 introduced.
- `manifest_no_null_log_slots` polices manifest fields cycle 7
  introduced.
- `delivery_log_exact_binding` polices the platform-suffix log naming
  cycle 5 introduced.

This is the smoking gun. Cycle-8 also had to **hand-craft a JSON log
file** (`gate/log/cc2e1e3-posix.json`) because cycle-8's own new rule
made organic generation impossible at the architectural commit. We are
now solving problems caused by the gate.

### 2.3 Reviewer-only feedback loop

Every signal in the project is either negative ("a reviewer said
something is wrong") or recursive ("the gate said the docs disagree
with the docs"). There is no positive signal: no user, no production
traffic, no incident, no completed customer task. Without positive
signals work feels never-done because there is no objective endpoint.

A complete feedback loop has at least three sources of signal:

| Signal type | Present? | Notes |
|---|---|---|
| Reviewer / auditor (negative) | yes | the only source |
| Internal automated tests | no | no tests exist |
| Real-world user / production / incident | no | no users, no production |

The project is operating on 1 of 3 signals. That is structurally why it
feels like it is not converging.

## 3. Lessons from cycles 1..8

Each cycle's primary finding and the real lesson behind it.

| Cycle | Primary finding(s) | Real lesson |
|---|---|---|
| 1 | ActionGuard 10 vs 11 stages drift; closure-language drift | Numbers and labels in prose drift the moment two docs talk about the same thing. |
| 2 | L1 carried old auth/posture model; gate scope too narrow | L1 docs lag L2 changes when the L1 is revised separately. |
| 3 | PowerShell crashed on path mixing; closure rules narrow | Cross-platform script parity is a moving target without CI. |
| 4 | Locale (`LC_ALL=C`); local-vs-delivery log split; banner-marking | Encoding and locale are part of the gate's correctness contract. |
| 5 | `-posix.json` vs `.json` filenames; cross-platform parity | The convention "one log per gate run" needed an explicit per-platform name. |
| 6 | Manifest staleness; readme drift; two-SHA model needed | The manifest is just another doc that drifts unless the gate enforces edges. |
| 7 | Two-SHA audit-trail; ASCII-only governance; self-test harness | The "audit-trail commit" is itself a workaround for chicken-and-egg between content and evidence. |
| 8 | CRLF in `.sh`; TBD / null; ASCII active corpus; `delivery_log_exact_binding` | The gate's own surface area is now the largest source of findings. |

Pattern: **every cycle's primary finding is about the gate itself, the
manifest itself, or the docs' encoding / format.** No cycle's primary
finding has been about "does the system do its job?" because there is
no system to do a job.

## 4. Meta-level architecture defects

The cycle-1..8 reviews each found "tactical" defects (a phrase here,
a regex there). The defects below are about the project as a whole.
Severity uses the same P0/P1/P2 scale as the cycle reviews so they can
be triaged in the same vocabulary.

### D1 (P0): No artifact

The platform described in ARCHITECTURE.md does not exist as code.
There is no `pom.xml` at the repo root, no Maven multi-module structure,
no Java source, no migrations, no container image, no manifest of any
runnable thing.

Evidence: `gate/run_operator_shape_smoke.{sh,ps1}` exit with
`FAIL_ARTIFACT_MISSING` because they cannot find any of `pom.xml`,
`agent-platform/pom.xml`, `agent-runtime/pom.xml`,
`agent-platform/src/main/java`, `agent-runtime/src/main/java`.

Impact: every other rule (4 testing, 5 async lifetime, 7 resilience,
8 operator-shape, 11 contract spine, 12 maturity) is inapplicable
because there is nothing to apply them to.

### D2 (P0): Documentation-as-Implementation

About 35 active L0 / L1 / L2 / cross-cutting docs describe a fictional
system in great detail. Each doc is treated as authoritative; revisions
require gate sign-off; but the system being described does not compile.

Impact: doc revisions feel like work but produce no behavior change.
Reviewers find drift between docs because docs that describe nothing
are unconstrained by reality.

### D3 (P0): Governance overhead inversion

Approximate ratio: governance LOC / product LOC = `3800 / 0` = infinite.

Each cycle has added more governance. Cycle 8 added the active-corpus
registry, six new gate rules, the ASCII normalization tool, the status
ledger reorder tool, and a meta-response document. None of these
produces a single user-visible behavior.

Impact: the project's largest cost is now meta-work. Every reviewer
correctly finds new drift in the meta-work because there is more
meta-work to drift.

### D4 (P1): No feedback loop from reality

There is no production data, no user, no incident, no SLA. The system
cannot be wrong about anything because nothing happens. All signals are
internal-consistency only.

Impact: the project has no way to learn from being wrong. The reviewer
is the only oracle and the reviewer cannot detect "this design will
break under 10x load" or "this RLS protocol misses a race in
practice."

### D5 (P1): Maturity model meaningless at L0

All 17 capabilities in the status ledger are L0. The L0..L4 ladder
exists but the rungs above L0 are unreachable without code. The cycle-7
addition of "maturity is the primary status" is correct but does not
help when there is only one rung.

Impact: maturity claims do not differentiate capabilities. Status
language is therefore the only useful axis, which the cycle-8 review
correctly downgraded.

### D6 (P1): CLAUDE.md rules out of scope

CLAUDE.md has 12 rules. About this fraction is currently applicable:

| Rule | Applies today? | Why or why not |
|---|---|---|
| 1 root cause | yes | applies to docs |
| 2 simplicity | partial | docs only |
| 3 pre-commit checklist | partial | docs only; orphan-config is doc text |
| 4 three-layer testing | no | no code |
| 5 async resource lifetime | no | no code |
| 6 single construction path | no | no code |
| 7 resilience signals | no | no fallback paths |
| 8 operator-shape gate | no (fail-closed) | no artifact |
| 9 self-audit ship gate | partial | applies to doc deliveries |
| 10 posture-aware defaults | no | no code |
| 11 contract spine | partial | applies to "would-be" data classes |
| 12 maturity ladder | partial | only L0 reachable |

Roughly **3.5 of 12 rules** apply today. We are running 12-rule
discipline on a project that benefits from at most 3 of the rules.

### D7 (P1): No prioritization of risk

Cycle-8 spent the bulk of its effort on `eol_policy`,
`manifest_no_tbd`, `manifest_no_null_log_slots`, and ASCII conversion.
These are governance hygiene. Meanwhile:

- The tenant_id RLS protocol is purely design (P0-3, REM-2026-05-08-3).
- JWT validation is purely design (P0-2).
- Prompt security is purely design (P0-5).
- Audit class model is purely design (P0-8).
- Outbox saga is purely design (P0-10).

Effort is allocated by reviewer salience, not by user impact. The
highest-risk items remain at L0 design after 8 cycles.

### D8 (P2): No "done" criterion

Every cycle finds new findings. There is no exit criterion. Convergence
is impossible because the audit surface IS the governance surface and
auditors will always find drift in governance.

Impact: the team cannot answer "are we done?" or "are we 70% done?"
because there is no endpoint to be 70% of.

### D9 (P2): No external grounding

No industry comparisons, no benchmarks, no users, no SLAs, no
incidents. The project is a closed system being polished. Decisions
like "11-stage ActionGuard" or "`SET LOCAL`-based RLS" or "5-class
audit model" are correct or incorrect only relative to the project's
own internal documents.

Impact: the docs cannot be falsified by reality. They can only be
falsified by other docs, which is what every cycle has done.

### D10 (P2): Reviewer dominance

The cycle pattern is reviewer -> fix -> reviewer -> fix. There is no
positive feedback (a build passing, a test going green, a customer
using a feature). All signals are negative.

Impact: the team's emotional and effort budget is asymmetric: every
cycle is "what is wrong?" and never "what now works?". This biases
work toward defensive moves (more rules, more docs) and away from
productive moves (writing code, getting users).

## 5. Numerical scoring framework

The framework has 5 categories with a total of 32 dimensions. Each
dimension is countable / yes-no / percentage so it cannot be gamed by
prose. The categories are intentionally ordered: R (reality) comes
first because if R is 0/8 the rest are unreachable.

### Category R: Reality (does the system exist?)

| Dim | Metric | Today | W0 done | W4 done |
|---|---|---|---|---|
| R1 | `mvn -q package` exits 0 | 0 | 1 | 1 |
| R2 | Source LOC (Java/Kotlin, non-test) | 0 | >= 1500 | >= 5000 |
| R3 | Test LOC | 0 | >= 1000 | >= 4000 |
| R4 | HTTP endpoints reachable from a started process | 0 | >= 1 | >= 8 |
| R5 | Tests passing (count) | 0 | >= 30 | >= 200 |
| R6 | Long-lived process can start under systemd / docker | no | yes | yes |
| R7 | One real LLM call possible end-to-end | no | yes | yes |
| R8 | One real Postgres transaction with `SET LOCAL` | no | yes | yes |

Score: count of dims at target / 8. **Today: 0 / 8.**

### Category F: Fitness (does it do what it says?)

| Dim | Metric | Today | W2 done | W4 done |
|---|---|---|---|---|
| F1 | Operator-shape gate state | fail_closed_artifact_missing | pass | pass |
| F2 | Tenant isolation E2E test passes | 0 | >= 1 | >= 1 |
| F3 | RLS GUC discard test passes | 0 | >= 1 | >= 1 |
| F4 | ActionGuard 11-stage E2E passes | 0 | >= 1 | >= 1 |
| F5 | Posture boot-fail test (research / prod) | 0 | >= 1 | >= 1 |
| F6 | JWT RS256 / JWKS validation E2E | 0 | >= 1 | >= 1 |
| F7 | Run cancellation 200 round-trip | 0 | >= 1 | >= 1 |
| F8 | Sequential N >= 3 dependency runs (Rule 8 step 3) | 0 | >= 1 | >= 1 |

Score: **Today: 0 / 8.**

### Category G: Governance ROI (proportionate apparatus?)

| Dim | Metric | Today | W0 done | W4 done |
|---|---|---|---|---|
| G1 | Governance LOC / Product LOC | inf | <= 1.0 | <= 0.3 |
| G2 | Governance LOC / Test LOC | inf | <= 1.0 | <= 0.3 |
| G3 | Gate rule count | 22 | 22 | downward trend |
| G4 | Cycle frequency (cycles per week) | ~5 | <= 1 | <= 0.25 |
| G5 | Findings closed by structural rule | 10 / 40 (cycle-8) | 100% of P0/P1 | 100% of P0/P1 |
| G6 | New findings introduced by the gate itself | 11 (cycle 7-8 family) | 0 in next cycle | 0 |

Score: **Today: 0 / 6.**

### Category C: Convergence (is the loop shrinking?)

| Dim | Metric | Today | W0 done | W4 done |
|---|---|---|---|---|
| C1 | Recurring finding families per cycle | 4 (encoding, manifest TBD, delivery-log parity, gate executability) | 0 | 0 |
| C2 | Findings closed by prose edit only | many | 0 | 0 |
| C3 | Findings with negative fixture | 0 / 40 | 100% for P0/P1 | 100% for P0/P1 |
| C4 | New findings introduced by the previous cycle's fix | high | 0 | 0 |
| C5 | (Cycle review effort) / (cycle fix effort) ratio | high (each cycle is days of work) | <= 0.2 | <= 0.2 |

Score: **Today: 0 / 5.**

### Category E: External grounding

| Dim | Metric | Today | W0 done | W4 done |
|---|---|---|---|---|
| E1 | Users / customers exercising the system | 0 | 0 | >= 1 |
| E2 | Production incidents observed | 0 | 0 | >= 1 (source of feedback) |
| E3 | External benchmark references in docs | 0 | >= 1 | >= 3 |
| E4 | Industry-pattern citations vs project-internal citations | 0 / many | >= 1:5 | >= 1:1 |
| E5 | Real-service dependencies verified (Postgres, LLM) | 0 / 0 | >= 2 / 2 | >= 2 / 2 |

Score: **Today: 0 / 5.**

### Aggregate

**Today: 0 / 32.**

After 8 cycles of remediation work, the aggregate score on the 32
dimensions is zero. The work has been on axes that are not in the
framework: gate hygiene, manifest schema, doc encoding. None of those
axes contributes to "does the system exist," "does it work," or "is
the governance proportionate."

## 6. Recommended next move

Three viable paths. Each has a clear acceptance contract.

### Option A: Build W0 (recommended)

Acceptance: R1, R6, R7, R8, F1 all reach target inside 30 days.

Concretely:

1. Add `pom.xml` (multi-module: `agent-platform`, `agent-runtime`).
2. Add one Spring Boot main class.
3. Add one HTTP endpoint that authenticates, opens a tenant-scoped
   transaction, calls one LLM provider, writes one row, returns.
4. Add one E2E test that drives steps 1-4 with a real local Postgres
   (Testcontainers acceptable).
5. Replace `gate/run_operator_shape_smoke.*` with the real flow:
   long-lived process, 3 sequential dependency runs, cancellation.
6. **Decline all governance findings during this 30 days.** Cycle 9
   does not run. The gate's R category (Reality) is the only acceptance
   signal.

After W0 lands, the gate / manifest / status ledger are pruned to fit
the actual surface area of the artifact. Rules that do not apply (D6
list) are removed.

### Option B: Scope to specification artifact

Acceptance: declare explicitly that spring-ai-fin's deliverable is a
reference architecture specification, not a runnable system. Then the
governance machinery is right-sized for a spec, which means much
smaller.

1. Reduce gate scripts to `<= 100 LOC`: closure-language only, no
   manifest enforcement, no eol_policy, no audit_trail_shape, no
   ASCII registry.
2. Reduce manifest to `<= 30 LOC`: just `reviewed_sha` and `delivery_file`.
3. Drop the operator-shape gate entirely.
4. Re-state CLAUDE.md as "spec-authoring rules" not "engineering
   rules." Keep rules 1, 2, 9, 11; drop the rest.
5. Cycle reviews become **scope-stable** (the spec evolves on a
   cadence) not **convergent** (the spec is never "done").

### Option C: Bounded hybrid

Acceptance: pick exactly 3 dimensions from the framework as the only
acceptance criterion for the next 30 days. Recommended trio:
**R1 + R6 + F1** (build, process starts, operator-shape passes).

Decline all governance findings during the window. Re-evaluate after
30 days using the 32-dim score. If R category jumps above 4 / 8,
continue. Otherwise commit to Option B and right-size.

### What this document does NOT recommend

- Cycle 9 with the current strategy. The math is not on its side: the
  gate's surface is currently the largest source of findings, so
  cycle 9 will find new gate-induced findings, and cycle 10 will find
  more.
- Adding more rules to the gate. Every rule added in cycles 5-8 has
  later become a source of findings.
- Promoting any capability above L0 without code + tests + an operator
  gate run. The new `rule_8_state_consistency` rule already enforces
  this and should not be relaxed.

## 7. Lessons retained for future sessions

This document is also a self-correction. Three principles I will hold
in subsequent work on this project:

1. **Demand the artifact.** If a project's gate has been failing
   `FAIL_ARTIFACT_MISSING` for 8 cycles, the next cycle's plan must
   start with "build the artifact," not "improve the gate."
2. **Audit surface = audit subject.** When the auditor and the
   audited surface are the same set of files, finding-rate cannot
   converge to zero. Detect this as a structural problem, not a
   review-process problem.
3. **Negative-only feedback is a smell.** When every signal is "you
   are wrong," the project lacks a positive-feedback channel. Building
   the smallest possible thing that produces a positive signal (a test
   passing, a user using something) is more valuable than another
   round of doc tightening.
