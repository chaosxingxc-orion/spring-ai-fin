# spring-ai-fin Architecture Remediation Plan

**Review date:** 2026-05-10  
**Reviewed commit:** `bc82ab0`  
**Review stance:** strict architecture review after the cycle-15/16 repair pass  
**Document purpose:** classify the remaining architecture-design defects and give the team a convergence plan that turns the repository, evidence graph, and gates into one verifiable system.

---

## 1. Executive Summary

The recent repair pass improved the project shape substantially: the repository now has a Maven multi-module skeleton, starter modules, SPI contracts, CI wiring, architecture-sync gates, fail-closed operator-shape scripts, ADRs, runbooks, RLS SQL, and a broader governance ledger.

However, the repair is not yet convergent. The current `main` commit cannot pass Maven project-model validation, yet multiple authoritative documents still claim L1 or GREEN test status. The evidence manifest points to a reviewed SHA that is not reachable from current `HEAD`. The operator-shape gate reads stale ignored build output and therefore reports the wrong fail-closed state. Several gates are still keyword-driven and stale-date-driven rather than evidence-driven.

The main root cause is not a lack of individual fixes. It is that the team is still using a reactive defect-closure workflow instead of an evidence-first release workflow. Architecture claims, maturity levels, delivery files, and gate results are being edited independently instead of being derived from the same current-SHA verification run.

No capability should be promoted, delivered, or described as GREEN until the current SHA passes the build, architecture-sync, and relevant test gates from a clean checkout.

---

## 2. Rule 1 Root-Cause Block

**Observed failure:** `.\mvnw.cmd -B -ntp --strict-checksums verify` fails at current `HEAD` before compilation because `agent-platform/pom.xml` declares local starter dependencies without versions. `gate/check_architecture_sync.ps1 -LocalOnly` and `bash ./gate/check_architecture_sync.sh --local-only` also fail due evidence drift, stale date rules, detached manifest SHA, missing gate logs, and dirty-tree state.

**Execution path:** `agent-platform/pom.xml` adds six `fin.springai:spring-ai-fin-*-starter` dependencies to the test classpath for ArchUnit SPI checks. Maven requires each dependency to have a version unless it is managed by an imported or parent dependency-management section. The external SDK BoM module contains those versions, but the parent POM does not manage them for the reactor and `agent-platform` does not specify them directly. Maven therefore rejects the project model before tests can run. At the same time, governance documents still claim GREEN/L1 evidence from older SHAs, while the manifest points to side-branch SHA `ae60414`, not current `HEAD`.

**Root cause:** The repair process promoted governance and maturity claims without first establishing a clean, current-SHA verification spine; as a result, build metadata, evidence files, and gates drifted apart and the repository can no longer prove the claims it makes.

**Evidence:** `agent-platform/pom.xml:139-168` lacks versions for local starter test dependencies; root `pom.xml:27-49` uses Spring Boot `4.0.5` and a 14-module reactor, while `ARCHITECTURE.md:59` and `docs/plans/engineering-plan-W0-W4.md:69` still describe Spring Boot 3.x/3.5; `docs/governance/evidence-manifest.yaml:61-63` points to `ae60414`, which is not an ancestor of `bc82ab0`; `docs/governance/evidence-manifest.yaml:283-291` says `artifact_present_state: jar_present` and build verification green based on older ignored `target/` output; `docs/delivery/2026-05-10-ae60414.md:50-59` labels checks GREEN while also saying CI is pending.

---

## 3. Findings by Category

### A. Build and Executable Artifact Integrity

#### A1. P0 - Current HEAD cannot build

The current repository cannot complete Maven project-model validation. This invalidates all current-SHA claims about L1 tests, SPI freeze, OpenAPI snapshot tests, starter wiring, and local operator-shape progression.

Evidence:

- `agent-platform/pom.xml:139-168` declares local starter dependencies without `<version>`.
- `.\mvnw.cmd -B -ntp --strict-checksums verify` fails with missing dependency versions for:
  - `spring-ai-fin-memory-starter`
  - `spring-ai-fin-skills-starter`
  - `spring-ai-fin-knowledge-starter`
  - `spring-ai-fin-governance-starter`
  - `spring-ai-fin-persistence-starter`
  - `spring-ai-fin-resilience-starter`

Required correction:

1. Choose one version-management path and make it universal:
   - Preferred: add all local `fin.springai` modules to the root parent `dependencyManagement` with `${project.version}`.
   - Acceptable surgical fix: add `<version>${project.version}</version>` to the six `agent-platform` test dependencies.
2. Run `.\mvnw.cmd -B -ntp --strict-checksums verify` and `bash ./gate/check_architecture_sync.sh` from a clean checkout.
3. Downgrade any L1/GREEN claim that cannot be proven on the current SHA.

Acceptance:

- Maven verify passes at current SHA on Windows and Linux CI.
- The delivery file for the same SHA records the Maven log and exact test suite result.
- No document uses "GREEN" for a check that has not run on that SHA.

#### A2. P0 - Operator-shape gate trusts stale ignored artifacts

`gate/run_operator_shape_smoke.ps1` and `.sh` detect `agent-platform/target/agent-platform-*.jar` and return `FAIL_NEEDS_REAL_FLOW`. At current `HEAD`, that JAR is stale ignored output from an earlier build; the current source cannot build. The correct state is not "needs real flow"; it is "invalid build" or "needs build".

Evidence:

- `agent-platform/target/agent-platform-0.1.0-SNAPSHOT.jar` exists locally but is ignored build output.
- Current Maven verify fails before compilation.
- `gate/run_operator_shape_smoke.ps1:70-85` checks only whether a jar file exists, not whether it was produced by current `HEAD`.
- `docs/governance/evidence-manifest.yaml:283-291` uses old green build evidence and sets `artifact_present_state: jar_present`.

Required correction:

1. The operator gate must never trust existing `target/` output unless it has current-SHA provenance.
2. Add one of these controls:
   - run a clean package step inside the gate before classifying artifact state; or
   - require a build-provenance file inside the artifact containing git SHA, dirty-tree status, build command, and timestamp.
3. Add a new fail-closed state such as `FAIL_INVALID_BUILD` when Maven cannot build.
4. Set `artifact_present_state` from verified build provenance, not from file existence.

Acceptance:

- With current broken POM state, the operator gate reports build invalidity, not real-flow readiness.
- With a clean successful package, the gate records the artifact SHA and only then reports `FAIL_NEEDS_REAL_FLOW`.
- Stale `target/` directories cannot influence delivery evidence.

### B. Evidence Graph and Delivery Integrity

#### B1. P0 - Evidence manifest points to a detached reviewed SHA

The authoritative manifest references reviewed content SHA `ae60414`, but that commit is not reachable from current `HEAD` `bc82ab0`. This breaks the two-SHA audit-trail model and means the manifest is not evidence for the current repository state.

Evidence:

- `docs/governance/evidence-manifest.yaml:61-63` sets `reviewed_content_sha: ae60414`.
- `git merge-base --is-ancestor ae60414 HEAD` returns false.
- `ae60414` is contained only by branch `fix/cycle-15-defect-closure`.
- `docs/governance/current-architecture-index.md:126` names `docs/delivery/2026-05-10-8505f7d.md` as authoritative, while the manifest names `docs/delivery/2026-05-10-ae60414.md`.

Required correction:

1. Decide whether the reviewed content is the side branch or current `main`.
2. If the side branch is intended, merge or rebase it so the reviewed SHA is an ancestor of the final evidence commit.
3. If current `main` is intended, regenerate the manifest and delivery file for `bc82ab0` or its repaired successor.
4. Make `current-architecture-index.md`, `evidence-manifest.yaml`, and delivery files agree on exactly one authoritative delivery.

Acceptance:

- `manifest.reviewed_content_sha` is either equal to `HEAD` or is the single parent of an audit-trail-only evidence commit.
- The manifest delivery file exists and has a matching `gate/log/<sha>-*.json`.
- The current index points to the same delivery file as the manifest.

#### B2. P1 - Delivery files mix "GREEN" with "CI pending"

`docs/delivery/2026-05-10-ae60414.md` describes tests as GREEN while also saying the code was written and CI is pending. That phrasing converts intent into evidence and weakens the governance model.

Evidence:

- `docs/delivery/2026-05-10-ae60414.md:50-54` says several checks are GREEN with "code written, CI pending".
- `docs/delivery/2026-05-10-ae60414.md:59` says `mvn -B verify` is CI pending.
- Current `HEAD` cannot build.

Required correction:

1. Reserve GREEN for an executed command on the reviewed SHA.
2. Use explicit states:
   - `not_run`
   - `local_pass`
   - `ci_pass`
   - `red`
   - `disabled_scaffold`
3. Disallow "GREEN (code written, CI pending)" by architecture-sync gate.

Acceptance:

- No delivery file marks unexecuted checks as GREEN.
- Every GREEN row has command, platform, SHA, and log path.

#### B3. P1 - Maturity ledger is not derived from current evidence

`architecture-status.yaml`, `README.md`, and `ARCHITECTURE.md` contain L1/GREEN claims that are no longer supported after the current Maven failure.

Evidence:

- `README.md:27-41` labels several modules L1.
- `README.md:207` says 15 Maven modules built and `ApiCompatibilityTest` is GREEN.
- `docs/governance/architecture-status.yaml:39-54` marks `agent_platform_facade` L1 with GREEN allowed claim.
- `docs/governance/architecture-status.yaml:1519-1529` marks `spi_compatibility_freeze` L1/test_verified based on older SHA.

Required correction:

1. Treat maturity as a computed state from the latest valid evidence, not a hand-edited statement.
2. Add a gate rule: if `mvn verify` is red for current SHA, no capability may newly claim `test_verified`.
3. Move old successful SHAs into historical evidence, not current readiness claims.

Acceptance:

- Current maturity rows include `latest_delivery_valid_sha` that is reachable from current `HEAD`.
- Any row with `maturity: L1` has passing tests at that SHA.
- README status mirrors the ledger instead of making independent claims.

### C. Gate Semantics and Drift Control

#### C1. P1 - Architecture-sync gate still has stale hard-coded date logic

The gate requires L0 `Last refreshed` to be `2026-05-08`, while the current L0 document was refreshed on `2026-05-10`. A gate that enforces a stale literal blocks legitimate architecture updates and encourages patching the gate instead of verifying freshness.

Evidence:

- `gate/check_architecture_sync.ps1:383-388` requires `2026-05-08`.
- `gate/check_architecture_sync.sh:430-434` requires `2026-05-08`.
- `ARCHITECTURE.md:3` says `2026-05-10`.

Required correction:

1. Replace hard-coded freshness dates with a monotonic or manifest-derived rule.
2. The gate should assert that L0 refresh date is not older than the current authoritative delivery date.
3. If the date is intentionally frozen, document the rule and prevent accidental refresh claims elsewhere.

Acceptance:

- A legitimate new refresh date does not require changing gate source code.
- A stale L0 date relative to manifest delivery still fails.

#### C2. P1 - Security control gate is still keyword-driven

The gate flags the security matrix row for RS256 validation because it sees HS256 and prod on the same line, even though the row says research/prod reject HS256. This is a false positive caused by phrase-level matching.

Evidence:

- `docs/cross-cutting/security-control-matrix.md:16` says `research/prod reject HS256`.
- `gate/check_architecture_sync.ps1:330` and `.sh:381` still report `hs256_prod_conflict` for this row.

Required correction:

1. Split the rule into two semantic checks:
   - HS256 may not be described as a default prod/research validation algorithm.
   - HS256 may appear when the row explicitly says reject, deny, not permitted, carve-out disabled by default, or test-only negative case.
2. Add self-test fixtures for allowed rejection language and forbidden acceptance language.

Acceptance:

- The RS256 row passes.
- A row that says "prod accepts HS256 via APP_JWT_SECRET" fails.
- A row that says "prod rejects HS256" passes.

#### C3. P1 - Gate state machine does not model current build validity

The architecture-sync gate knows about `artifact_present_state` values such as `source_only` and `jar_present`, but it does not validate that the jar was built from the current SHA. The operator gate has the same weakness.

Evidence:

- `docs/governance/evidence-manifest.yaml:283` says `artifact_present_state: jar_present`.
- `gate/check_architecture_sync.ps1:801-811` validates state names but not build provenance.
- Current Maven verify fails.

Required correction:

1. Add `build_verification.state: red` support and make it block L1/test_verified claims.
2. Add `artifact_build_sha` and require it to equal `reviewed_content_sha` or `HEAD`.
3. If `build_verification.state != green`, `artifact_present_state` cannot be `jar_present`.

Acceptance:

- A stale jar cannot produce coherent gate state.
- Build failure forces `rule_8.state` to `fail_closed_needs_build` or `fail_closed_invalid_build`.

### D. Architecture Truth and Version Consistency

#### D1. P1 - Platform version truth is split across POMs and architecture docs

The executable POM uses Spring Boot 4.0.5 and Spring AI 2.0.0-M5, while active planning and L0 architecture text still refer to Spring Boot 3.x/3.5 and Spring AI 1.x.

Evidence:

- Root `pom.xml:27-31` uses Spring Boot `4.0.5`.
- Root `pom.xml:58-60` uses Spring AI `2.0.0-M5`.
- `ARCHITECTURE.md:59` still says Spring Boot 3.x.
- `ARCHITECTURE.md:218` says Spring Boot 3.5 BOM.
- `docs/plans/engineering-plan-W0-W4.md:69` says Spring Boot 3.5.x.
- `docs/plans/engineering-plan-W0-W4.md:315` says Spring AI 1.x.

Required correction:

1. Choose one authoritative platform baseline:
   - stay on Boot 4.0.5 / Spring AI 2.0.0-M5; or
   - revert code to Boot 3.5.x / Spring AI 1.x if the plan is still binding.
2. Update L0, W0-W4 plan, ADRs, BoM policy, and README together in one platform-baseline commit.
3. Add a gate rule that compares root POM versions with active docs.

Acceptance:

- `pom.xml`, `spring-ai-fin-dependencies/pom.xml`, L0, engineering plan, and ADRs all report the same baseline.
- No active document names an obsolete major version unless it is explicitly historical.

#### D2. P2 - Module counts and starter counts are inconsistent

The root reactor currently lists 14 modules. README and delivery documents claim 15 Maven modules, and some L0 text says the BoM pins 9 starters while README says 10 starter coordinates.

Evidence:

- Root `pom.xml:34-49` lists 14 modules.
- `README.md:3-5` says 15 Maven modules.
- `README.md:33` says 10 starter coordinates.
- `ARCHITECTURE.md:233` says 9 starters.

Required correction:

1. Define the counting convention:
   - reactor modules;
   - starter modules only;
   - SDK coordinates;
   - sidecar/profile coordinates.
2. Put that convention in one short table and reference it everywhere.
3. Add a lightweight gate that compares root `<modules>` count with README/L0 module-count claims.

Acceptance:

- No document uses an unqualified module count.
- The root reactor, README, and L0 agree.

### E. Security Control Maturity

#### E1. P1 - RLS artifacts are present but security tests are disabled scaffolds

The RLS SQL artifact exists, but the tenant-isolation tests are disabled and throw `UnsupportedOperationException`. This is acceptable only if the capability stays L0/design-accepted. It is not acceptable as L1 security evidence.

Evidence:

- `agent-platform/src/test/java/fin/springai/platform/security/TenantIsolationIT.java:24` is `@Disabled`.
- `TenantIsolationIT.java:42-46` throws `UnsupportedOperationException`.
- `RlsPolicyCoverageIT.java:20` is `@Disabled`.
- `RlsPolicyCoverageIT.java:38-42` throws `UnsupportedOperationException`.
- `GucEmptyAtTxStartIT.java:25` is `@Disabled`.
- `GucEmptyAtTxStartIT.java:43-48` throws `UnsupportedOperationException`.
- `docs/cross-cutting/security-control-matrix.md:18-20` correctly marks them as L0 scaffold, but `architecture-status.yaml:1796-1805` marks `rls_policy_sql` maturity L1 with no tests.

Required correction:

1. Keep RLS as L0 until at least one real Testcontainers-backed isolation test is green.
2. If `rls_policy_sql` remains L1, clarify that L1 applies only to the SQL artifact presence, not runtime tenant isolation.
3. Add a gate rule: a disabled test cannot appear as evidence for `test_verified` or security-control maturity above L0.

Acceptance:

- Security matrix, status ledger, and delivery docs all distinguish "artifact exists" from "control enforced".
- W1/W2 promotion requires enabled tests against real Postgres schema and real tenant-binding path.

#### E2. P1 - JWT control rows need sharper posture semantics

The security matrix now separates RS256/RS512/EdDSA from HS256 BYOC carve-out, which is good. The posture default for the carve-out row is still too terse for a financial-services security boundary.

Evidence:

- `docs/cross-cutting/security-control-matrix.md:16-17` defines C1 and C2.

Required correction:

1. For C2, explicitly state:
   - disabled by default in all postures;
   - allowed only in named BYOC deployments;
   - cannot share `APP_JWT_SECRET` with platform-internal secrets;
   - must have a rotation procedure and audit event;
   - prod enablement requires operator-signed known-defect or exception record.
2. Add a negative test that proves prod/research reject HS256 when carve-out is disabled.

Acceptance:

- The carve-out cannot be confused with a standard research/prod auth path.
- CI has a negative algorithm-rejection test.

### F. Documentation Hygiene and Onboarding Truth

#### F1. P2 - README is outside active-corpus enforcement but contains authoritative claims

README is a primary onboarding document, but it is not listed in `docs/governance/active-corpus.yaml`. It contains L1/GREEN claims and visual tree content that are not gate-controlled by the active-corpus registry.

Evidence:

- `docs/governance/active-corpus.yaml:49-66` lists L0/L1 docs but not `README.md`.
- `README.md:27-41` contains L1 module claims.
- `README.md:207` contains build/test readiness claims.

Required correction:

1. Either add README to the active corpus or classify it as generated-from-ledger.
2. If README stays outside active corpus, remove maturity and GREEN claims from it and link to the ledger instead.

Acceptance:

- README cannot drift from the governance ledger.
- Architecture-sync gate catches unsupported README readiness claims or README stops making them.

---

## 4. Systemic Diagnosis

The repeated non-convergence is caused by three interacting process flaws:

1. **Evidence is not the source of truth.** The team edits maturity labels, delivery files, and README text separately. This allows claims to survive after the current SHA stops building.
2. **Gates are still mostly textual.** Several rules inspect phrases, dates, or file existence rather than deriving state from executed commands and provenance.
3. **Wave discipline is being bypassed by review-response commits.** The engineering plan says waves must close with green CI, but many repair commits update governance and architecture claims before a fresh current-SHA verification pass.

The corrective move is to stop treating each review finding as a separate patch. The team needs one evidence spine that every document reads from:

`current SHA -> clean build -> tests -> architecture-sync logs -> operator gate state -> evidence manifest -> architecture status -> README/index`

If any upstream step is red, downstream claims must downgrade automatically or fail the gate.

---

## 5. Remediation Plan

### Phase 0 - Stop the bleeding: current-SHA build truth

Owner: platform/build  
Priority: P0  
Target: next commit

Tasks:

1. Fix local module version management so Maven project-model validation passes.
2. Run `.\mvnw.cmd -B -ntp --strict-checksums verify` on Windows.
3. Run `./mvnw -B -ntp --strict-checksums verify` on Linux CI.
4. Mark the current delivery state red until both pass.
5. Remove or downgrade any "GREEN" and L1/test-verified claims not backed by the current SHA.

Exit criteria:

- Maven verify is green at the repaired SHA.
- No current document claims build/test success from older ignored `target/` output.

### Phase 1 - Repair the evidence graph

Owner: architecture governance  
Priority: P0  
Target: immediately after Phase 0

Tasks:

1. Regenerate `docs/governance/evidence-manifest.yaml` for the repaired SHA.
2. Ensure `reviewed_content_sha` is reachable from `HEAD`.
3. Create matching gate logs under `gate/log/<sha>-*.json` for delivery-valid runs.
4. Make `current-architecture-index.md`, manifest, and delivery file point to the same authoritative delivery.
5. Add a gate self-test proving a detached reviewed SHA fails.

Exit criteria:

- Architecture-sync gate passes without `--local-only` in a clean checkout.
- Manifest, index, delivery file, and gate logs agree.

### Phase 2 - Make gates provenance-aware

Owner: gate maintainers  
Priority: P1  
Target: same wave as Phase 1

Tasks:

1. Replace stale-date L0 rule with a manifest-derived freshness rule.
2. Fix HS256/prod rule to allow explicit rejection language and block acceptance language.
3. Add build-provenance checks to operator-shape smoke.
4. Add `build_verification.state: red` handling.
5. Add a rule that forbids GREEN for "code written" or "CI pending" rows.

Exit criteria:

- False positives are covered by self-test fixtures.
- Stale ignored jars cannot advance the Rule 8 state machine.

### Phase 3 - Normalize architecture truth

Owner: architecture + build  
Priority: P1  
Target: before any W1 work begins

Tasks:

1. Choose the platform baseline: Boot 4.0.5 / Spring AI 2.0.0-M5 or Boot 3.5.x / Spring AI 1.x.
2. Update active docs, ADRs, BoM policy, and engineering plan in one commit.
3. Normalize module-count and starter-count language.
4. Add a POM-to-docs version gate.

Exit criteria:

- POMs and active docs agree on every platform major version.
- Module counts are explicit and reproducible.

### Phase 4 - Reframe security maturity as vertical slices

Owner: security/platform  
Priority: P1  
Target: W1/W2 entry

Tasks:

1. Keep RLS runtime isolation at L0 until enabled Testcontainers tests pass.
2. Implement the first full W1 vertical slice:
   - JWT RS256 path;
   - HS256 negative test;
   - tenant context filter;
   - transaction-scoped `SET LOCAL`;
   - RLS schema applied by migration;
   - tenant A/B visibility test.
3. Prohibit disabled tests from counting as maturity evidence.

Exit criteria:

- RLS maturity promotion is based on an enabled test through real Postgres.
- The security matrix, architecture status, and delivery file all report the same maturity level.

### Phase 5 - Convert README and status pages into generated summaries

Owner: documentation governance  
Priority: P2  
Target: after Phase 1

Tasks:

1. Move readiness claims into `architecture-status.yaml` and evidence manifest only.
2. Make README summarize those ledgers or link to them.
3. Add README to active corpus if it keeps maturity labels.

Exit criteria:

- README cannot become a parallel source of truth.
- Onboarding text remains useful without making unverifiable claims.

---

## 6. Recommended Team Operating Model

The team should adopt this rule for all future architecture repair rounds:

1. **No new review-response PR may change maturity labels first.** It must first make the current SHA build and test green.
2. **Every delivery file must be generated after gates run.** Handwritten GREEN tables are not evidence.
3. **Every capability row must point to a reachable evidence SHA.** If the SHA is not reachable from `HEAD`, the row is historical, not current.
4. **Every gate rule must have positive and negative fixtures.** Keyword rules without self-tests will keep creating false positives and blind spots.
5. **Every wave closes only once.** If a later commit breaks build or evidence coherence, the wave is reopened and maturity downgrades until repaired.

---

## 7. Immediate Command Checklist

Run these only after the POM version-management fix:

```powershell
git status --porcelain=v1 -uall
.\mvnw.cmd -B -ntp --strict-checksums verify
gate\check_architecture_sync.ps1
bash gate/test_architecture_sync_gate.sh
gate\run_operator_shape_smoke.ps1
```

```bash
./mvnw -B -ntp --strict-checksums verify
bash ./gate/check_architecture_sync.sh
bash ./gate/test_architecture_sync_gate.sh
bash ./gate/run_operator_shape_smoke.sh
```

Expected outcomes for the next valid repair:

- Maven verify: PASS.
- Architecture-sync: PASS on a clean tree.
- Operator-shape smoke: fail closed with a state that matches the verified artifact state.
- Evidence manifest: points to a reachable SHA and matching gate logs.
- README/status/index: no unsupported GREEN or L1 claims.

---

## 8. Final Recommendation

The architecture team should pause feature expansion and run a short "evidence-spine stabilization" sprint. The target is not to add more architecture text. The target is to make every architecture claim mechanically traceable to the current SHA.

Until this is done, spring-ai-fin should be described as:

> W0 scaffold with significant governance and SPI work in progress; current HEAD build/evidence coherence is red; no runtime capability should be considered delivery-ready.

Once Phase 0 and Phase 1 pass, the project can resume W1 security and tenant-isolation work with a far better chance of convergence.
