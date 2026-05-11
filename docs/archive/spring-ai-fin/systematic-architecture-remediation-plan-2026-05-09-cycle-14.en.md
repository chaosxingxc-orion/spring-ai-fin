# Systematic Architecture Remediation Plan - Cycle 14

Date: 2026-05-09
Repository HEAD reviewed: `7976097`
Delivered architecture/content SHA: `f98dbae`
Scope: `D:\chao_workspace\spring-ai-fin`
Review stance: strict architecture review after the cycle-13 Phase B step 1 delivery.

## Executive Verdict

The project has made a meaningful turn. It is no longer only a documentation repository: cycle 13 introduced a Maven multi-module skeleton, a Spring Boot platform entry point, a `/v1/health` endpoint, Flyway migration, Testcontainers integration test, Dockerfile, compose file, and CI workflow. The active-corpus truth-cut also largely worked: the current index now points to refresh-active documents, and the active corpus separates active, transitional, and historical material.

However, the architecture is still not shippable and the next failure mode is now more dangerous than the old documentation drift. The repo has crossed from "no artifact exists" to "an artifact may soon exist", but several controls still behave as if failure is acceptable during the transition.

The most important problem: CI explicitly masks the operator-shape gate with `|| true`. That turns a ship gate into a non-blocking notification. At the same time, the evidence manifest still contains stale operator-shape fields saying `FAIL_ARTIFACT_MISSING` and `unblocks_at: W0`, while the current Rule 8 state says `fail_closed_needs_build` and `unblocks_at: W4`. The architecture-sync gate passes despite this contradiction.

The root problem has therefore changed. The earlier root cause was "no enforced truth-cut." The current root cause is "the truth-cut is incomplete at the transition from design evidence to executable evidence." The team is now adding runtime code, but the gates, manifest semantics, and W0 acceptance criteria have not yet been tightened to treat runtime failure as blocking.

Current posture:

- Current HEAD: `7976097` (`Add cycle-13 Phase B step 1 delivery evidence at f98dbae`).
- Working tree before this review document: clean.
- Architecture-sync gate: Windows local run produced semantic PASS; POSIX local run produced semantic PASS.
- Operator-shape smoke: FAILS with `FAIL_NEEDS_BUILD`, because POMs and source trees exist but no `agent-platform` JAR exists.
- Local verification blocker: this environment has no `mvn`, no `java`, and no `docker`, so Maven compile, integration tests, and image build could not be executed here.
- Runtime artifact state: W0 skeleton exists, but it is not compiled, not packaged, and not operator-run.

No capability should move beyond `implemented_unverified` until Maven compile and `HealthEndpointIT` pass on the exact SHA. No delivery pipeline should tolerate a failing operator-shape gate once a runnable artifact is expected.

## Review Evidence

Commands and observations:

- `git rev-parse --short HEAD` returned `7976097`.
- `git show --name-only --format='%h %s' HEAD` shows an audit-trail commit adding delivery evidence for `f98dbae`.
- `git status --porcelain=v1 -uall` was clean before this review document was added.
- `gate/check_architecture_sync.ps1 -LocalOnly` passed and wrote a Windows log.
- `bash ./gate/check_architecture_sync.sh --local-only` passed and wrote a local POSIX log.
- `gate/run_operator_shape_smoke.ps1` failed with `FAIL_NEEDS_BUILD`.
- `bash ./gate/run_operator_shape_smoke.sh` failed with `FAIL_NEEDS_BUILD`.
- `mvn -version` failed because Maven is not installed in this environment.
- `docker version` failed because Docker is not installed in this environment.
- Recursive inventory now finds `pom.xml`, module POMs, Java files, one SQL migration, Dockerfile, compose, and CI workflow.

## Root-Cause Summary

Observed failure: the latest architecture delivery is internally much closer to convergence, but the new runtime skeleton is not yet protected by a blocking delivery pipeline.

Execution path: cycle 13 adds Maven and Spring Boot artifacts. The operator-shape smoke gate correctly exits 1 with `FAIL_NEEDS_BUILD`. The GitHub Actions workflow then runs the same script with `|| true`, making the failed gate non-blocking. Meanwhile, `docs/governance/evidence-manifest.yaml` updates `rule_8.state` to `fail_closed_needs_build` but leaves `operator_shape_logs` and `operator_shape_evidence.reason` in a stale pre-W0/artifact-missing state. Architecture-sync still passes because it validates selected fields, not the whole Rule 8 evidence state machine.

Root cause statement: runtime convergence is blocked because W0 implementation has started before the delivery gates were upgraded from design-corpus validation to executable-readiness validation; the CI workflow, manifest schema, and status ledger still allow contradictory or non-blocking runtime evidence.

Evidence:

- `.github/workflows/ci.yml:32-33` runs `bash gate/run_operator_shape_smoke.sh || true`.
- `gate/run_operator_shape_smoke.sh:90-94` emits `FAIL_NEEDS_BUILD` or `FAIL_NEEDS_REAL_FLOW` and exits 1.
- `docs/governance/evidence-manifest.yaml:115-124` still records operator-shape logs as `FAIL_ARTIFACT_MISSING` and `unblocks_at: W0`.
- `docs/governance/evidence-manifest.yaml:147-154` records `rule_8.state: fail_closed_needs_build` and `unblocks_at: W4`.
- `docs/governance/evidence-manifest.yaml:141-145` records `dependency_mode: fake` and a stale reason saying pre-W0 has no runnable artifact.
- `agent-platform/bootstrap/ARCHITECTURE.md:8-36` says W0 reads `APP_POSTURE` once and fail-closes when required settings are missing.
- The actual W0 source tree has no `AppPosture.java`, `PostureBootGuard.java`, or `RequiredConfig.java`.

## Findings by Category

### Category A - Delivery Gates and CI Blocking Semantics

#### Finding A1 - P0 - CI masks the operator-shape gate

The operator-shape gate is explicitly non-blocking in CI.

Evidence:

- `.github/workflows/ci.yml:32-33` runs `bash gate/run_operator_shape_smoke.sh || true`.
- `gate/run_operator_shape_smoke.sh` exits 1 for `FAIL_NEEDS_BUILD` and `FAIL_NEEDS_REAL_FLOW`.

Impact:

- A PR can pass CI while the Rule 8 smoke gate is red.
- Once a JAR exists, CI will still tolerate `FAIL_NEEDS_REAL_FLOW`.
- Rule 8 becomes a documentation warning, not a delivery gate.

Correction:

1. Remove `|| true` from the CI operator-shape step.
2. Split the workflow into explicit jobs:
   - `build_verify`: `mvn verify`, blocking.
   - `architecture_sync`: blocking.
   - `operator_shape_smoke`: blocking when W0 acceptance is in scope.
3. If a transitional non-blocking run is needed, name it `operator_shape_report_only` and do not place it in the delivery-valid path.
4. Add a gate rule that rejects `|| true` on any `gate/run_*` command in CI workflows.

Definition of done:

- A failing `run_operator_shape_smoke.*` command fails CI.
- Delivery files cannot cite a CI run where operator-shape was ignored.

#### Finding A2 - P1 - Local-only architecture-sync can still emit delivery-valid evidence

The gate README says local-only runs always produce `evidence_valid_for_delivery=false`, but both architecture-sync implementations compute delivery validity from tree cleanliness and semantic pass only. The `LocalOnly` / `--local-only` flag is not included in the delivery-valid calculation.

Evidence:

- `gate/README.md:28-31` says local-only runs are always non-delivery evidence.
- `gate/check_architecture_sync.ps1:784` computes `$evidenceValidForDelivery = $treeClean -and $semanticPass`.
- `gate/check_architecture_sync.sh:828-830` computes `evidence_valid` from tree cleanliness and semantic pass.
- Neither implementation forces delivery validity to false when local-only mode is set.

Impact:

- A clean-tree local-only run can write a delivery-valid log under `gate/log/`.
- The operator may accidentally commit a local-only log as delivery evidence.
- Windows and POSIX behavior can diverge depending on incidental dirty state.

Correction:

1. Change both scripts so local-only always sets `evidence_valid_for_delivery=false`.
2. Always write local-only logs under `gate/log/local/`.
3. Add a self-test fixture that runs local-only on a clean tree and asserts non-delivery evidence.
4. Keep README, script behavior, and self-test aligned.

Definition of done:

- Clean-tree local-only runs never produce delivery-valid logs.
- The self-test fails if local-only can write under `gate/log/`.

### Category B - Evidence Manifest and Status Ledger Consistency

#### Finding B1 - P0 - Rule 8 evidence state is internally contradictory

The evidence manifest now carries two different operator-shape states: one says no artifact exists, another says a partial artifact exists but needs build.

Evidence:

- `docs/governance/evidence-manifest.yaml:115-124` records `operator_shape_logs` as `missing_blocker`, with reasons based on `FAIL_ARTIFACT_MISSING` and `unblocks_at: W0`.
- `docs/governance/evidence-manifest.yaml:147-154` records `rule_8.state: fail_closed_needs_build`, missing JAR, and `unblocks_at: W4`.
- `docs/delivery/2026-05-08-f98dbae.md:43-46` says Rule 8 advanced to `fail_closed_needs_build`.
- The architecture-sync gate passed despite the contradiction.

Impact:

- The manifest cannot be trusted as a single evidence graph.
- Consumers cannot tell whether W0 is blocked on missing source, missing build, or missing real flow.
- The gate's `rule_8_state_consistency` claim is weaker than the manifest schema suggests.

Correction:

1. Treat `operator_shape_logs`, `operator_shape_evidence`, and `rule_8` as one state machine.
2. Add valid transitions:
   - `fail_closed_artifact_missing`;
   - `fail_closed_needs_build`;
   - `fail_closed_needs_real_flow`;
   - `pass`.
3. For each state, require matching fields:
   - `artifact_present`;
   - `jar_present`;
   - `dependency_mode`;
   - `rule_8_eligible`;
   - `unblocks_at`.
4. Update the gate to fail when these fields disagree.

Definition of done:

- The current manifest has one coherent Rule 8 state.
- A manifest saying `FAIL_ARTIFACT_MISSING` and `fail_closed_needs_build` at the same time fails architecture-sync.

#### Finding B2 - P1 - Maturity language still mixes capability maturity and remediation-item maturity

The delivery file correctly says every refresh capability remains L0 until Maven verification passes, but the status ledger's cycle-13 remediation entries mark several W0 items as `maturity: L1` even though they are still `design_accepted` and uncompiled.

Evidence:

- `docs/delivery/2026-05-08-f98dbae.md:5-7` says every refresh capability remains L0 until local Maven verification and `HealthEndpointIT` pass.
- `docs/governance/architecture-status.yaml:1320-1356` marks the cycle-13 scaffold, W0 skeleton, probe code, operations scaffolding, and tri-state gate entries as `maturity: L1`.
- `docs/delivery/2026-05-08-f98dbae.md:61-63` lists Maven dependency resolution, compile, and verify as pending.

Impact:

- Reviewers cannot tell whether L1 means "tested component" or "remediation task recorded."
- The maturity model loses precision exactly when executable evidence appears.

Correction:

1. Separate capability maturity from remediation-record maturity.
2. Keep cycle-13 remediation records at evidence-state language only, or rename the field to `remediation_record_maturity`.
3. Only promote `agent_platform_facade` or W0 runtime capability to L1 after `mvn verify` and `HealthEndpointIT` pass on the recorded SHA.

Definition of done:

- Capability rows and remediation-record rows no longer use the same `maturity` field with different meanings.
- L1 is used only for tested components.

### Category C - W0 Runtime Skeleton and Posture-Aware Defaults

#### Finding C1 - P0 - W0 posture guard is documented but not implemented

The bootstrap L2 says W0 owns boot-time posture validation. The current code only exposes an `app.posture` property; there is no guard that reads it once, validates required keys, or fail-closes in research/prod.

Evidence:

- `agent-platform/bootstrap/ARCHITECTURE.md:8-11` requires APP_POSTURE reading and fail-closed config validation before serving traffic.
- `agent-platform/bootstrap/ARCHITECTURE.md:24-27` lists `AppPosture.java`, `PostureBootGuard.java`, and `RequiredConfig.java`.
- `agent-platform/bootstrap/ARCHITECTURE.md:34-36` requires non-zero exit plus structured log and metric on missing required keys.
- The source tree contains `PlatformApplication.java`, but no `AppPosture.java`, `PostureBootGuard.java`, or `RequiredConfig.java`.
- `agent-platform/src/main/resources/application.yml:64-67` only stores `app.posture` and `app.sha`.

Impact:

- The app can be started with `APP_POSTURE=research` or `APP_POSTURE=prod` without enforcing the required config matrix.
- Dev defaults for database credentials remain active unless overridden.
- Security documentation promises fail-closed behavior that the runtime does not provide.

Correction:

1. Implement `AppPosture`, `RequiredConfig`, and `PostureBootGuard`.
2. Read posture once at startup and expose it as a bean.
3. For `research` and `prod`, fail startup if required DB, OIDC/JWKS, and Vault settings are absent according to the active wave.
4. Add `PostureBootGuardDevIT`, `PostureBootGuardResearchIT`, and `PostureBootGuardProdIT`.
5. In W0, if full OIDC/Vault checks are intentionally deferred, narrow the bootstrap L2 and security matrix so they do not claim W0 fail-closed posture behavior.

Definition of done:

- `APP_POSTURE=research` with missing required keys exits non-zero before serving traffic.
- `APP_POSTURE=dev` still starts with compose defaults.
- The code, bootstrap L2, and security matrix agree on which wave owns each required key.

#### Finding C2 - P1 - W0 public surface is broader than the posture model allows

The W0 security filter permits OpenAPI and Swagger UI for all postures. The web L2 says Swagger is public only in dev and localhost-only in research/prod.

Evidence:

- `agent-platform/web/ARCHITECTURE.md:38-44` says `/swagger-ui` is dev-public, research/prod localhost-only.
- `agent-platform/src/main/java/fin/springai/platform/web/WebSecurityConfig.java:23` permits `/v3/api-docs/**`, `/swagger-ui/**`, and `/swagger-ui.html` unconditionally.

Impact:

- If the W0 skeleton is deployed under research/prod posture before W1 auth lands, documentation endpoints are exposed.
- This is especially risky because the posture guard is not implemented.

Correction:

1. Gate OpenAPI/Swagger exposure on posture.
2. In W0, expose only `/v1/health` and actuator health endpoints unless `APP_POSTURE=dev`.
3. Add an integration test proving `APP_POSTURE=research` blocks Swagger.

Definition of done:

- Research/prod posture does not expose Swagger or raw OpenAPI over non-local access.

### Category D - Build, Test, and Operator Readiness

#### Finding D1 - P0 - W0 cannot yet be verified as a tested component

The repository has code, but the current environment cannot compile or test it. The delivery file is honest about this, but the architecture must continue to treat the code as unverified until CI or a local environment proves it.

Evidence:

- `mvn -version` fails locally.
- `docker version` fails locally.
- `docs/delivery/2026-05-08-f98dbae.md:61-63` lists dependency resolution, compile, and verify as pending.
- `gate/run_operator_shape_smoke.*` reports `FAIL_NEEDS_BUILD`.

Impact:

- Dependency coordinates, probe imports, Flyway migration, Spring Boot context, and Testcontainers wiring remain unproven.
- A single typo in a dependency or import can invalidate the W0 skeleton.

Correction:

1. Add Maven Wrapper (`mvnw`, `mvnw.cmd`, `.mvn/wrapper/*`) or require CI as the canonical verifier before maturity promotion.
2. Run `mvn -B -ntp --strict-checksums verify` on CI and record the run URL or artifact.
3. Do not promote any runtime capability to L1 until the test pass is attached to the delivery evidence.
4. After build succeeds, rerun operator-shape smoke and record the transition from `FAIL_NEEDS_BUILD` to `FAIL_NEEDS_REAL_FLOW` or better.

Definition of done:

- `mvn verify` passes on `f98dbae` or a later SHA.
- `HealthEndpointIT` passes with real Testcontainers Postgres.
- The evidence manifest records build/test evidence separately from architecture-sync evidence.

#### Finding D2 - P1 - W0 acceptance criteria and current implementation are not aligned

The W0 engineering plan requires more than the current skeleton has delivered.

Evidence:

- `docs/plans/engineering-plan-W0-W4.md:131-133` requires `mvn package`, at least 700 main-source LOC, and at least 200 test LOC.
- Current non-blank Java source count is about 228 main-source lines and 49 test lines.
- Only `HealthEndpointIT` exists; no standalone `FlywayMigrationIT`, `BuildSmokeTest`, `OpenApiContractIT`, or posture guard tests exist yet.

Impact:

- The phrase "W0 minimal skeleton" can be confused with "W0 acceptance complete."
- W0 cannot be considered complete under the project's own plan.

Correction:

1. Rename current state to "W0 skeleton step 1", not "W0 complete."
2. Track remaining W0 acceptance criteria explicitly:
   - Maven package passes;
   - HealthEndpointIT passes;
   - FlywayMigrationIT passes;
   - posture guard tests pass or are consciously moved to W1;
   - LOC gates are revised or satisfied.
3. If the LOC gates are no longer meaningful, replace them with behavior gates and delete the old targets.

Definition of done:

- W0 acceptance criteria are either met or formally revised.
- Delivery documents do not imply W0 completion before those criteria are green.

### Category E - Supply Chain and Build Hygiene

#### Finding E1 - P1 - Docker dependency prefetch masks failures

The Dockerfile ignores failure in the dependency prefetch step.

Evidence:

- `Dockerfile:17` runs `mvn -B -ntp -pl agent-platform -am dependency:go-offline -DskipTests || true`.

Impact:

- Supply-chain, artifact-resolution, checksum, or repository failures can be hidden until a later layer.
- This weakens the stated direction toward reproducible builds and digest-pinned supply chain controls.

Correction:

1. Remove `|| true` from dependency prefetch.
2. If prefetch is only an optimization, delete the prefetch layer rather than tolerating failure.
3. Run Maven with strict checksums in Docker build just as CI does.

Definition of done:

- Dependency-resolution failure fails the image build immediately.

## Systemic Assessment

The team is no longer merely doing reactive documentation repair. The cycle-13 work shows a real shift toward executable architecture. That is good.

The new systemic risk is transitional leniency. Because the team knows W0 is partial, it has allowed red runtime gates to become expected, and in CI that expectation is implemented as `|| true`. That is exactly where convergence can fail again: the project may keep adding code while preserving non-blocking gates, stale manifest fields, and mixed maturity language.

The discipline now needs to change from "make the document corpus coherent" to "make every executable claim block or pass." Any red runtime gate must either:

1. block delivery; or
2. be moved out of the delivery path and explicitly named report-only.

There should be no third state where a gate fails but CI is green and the delivery ledger still looks current.

## Systematic Remediation Plan

### Phase 0 - Stop the CI Bypass

Duration: same day.

Actions:

1. Remove `|| true` from `.github/workflows/ci.yml`.
2. Add a CI-lint rule to architecture-sync: no `|| true` on `gate/run_*`.
3. If a report-only operator probe is needed, create a separately named job that cannot be referenced as delivery evidence.

Exit criteria:

- Red operator-shape smoke fails CI.

### Phase 1 - Repair the Rule 8 Manifest State Machine

Duration: 0.5 day.

Actions:

1. Update `operator_shape_logs` to match the current `FAIL_NEEDS_BUILD` state.
2. Update `operator_shape_evidence.reason` so it no longer says pre-W0/no artifact.
3. Align all `unblocks_at` fields.
4. Extend architecture-sync to verify operator-shape state coherence.

Exit criteria:

- `operator_shape_logs`, `operator_shape_evidence`, and `rule_8` describe the same state.

### Phase 2 - Finish W0 Verification Before Maturity Promotion

Duration: 1-2 days.

Actions:

1. Add Maven Wrapper or rely on CI as the recorded verifier.
2. Run `mvn -B -ntp --strict-checksums verify`.
3. Attach CI run URL or logs to delivery evidence.
4. Keep runtime capabilities below L1 until tests pass.

Exit criteria:

- Maven verify passes on the recorded SHA.
- `HealthEndpointIT` passes with Testcontainers Postgres.

### Phase 3 - Implement or Re-scope the W0 Posture Guard

Duration: 1 day.

Actions:

1. Either implement `AppPosture`, `RequiredConfig`, and `PostureBootGuard`, or move their required behavior from W0 to W1 in all docs.
2. If implemented, add dev/research/prod tests.
3. Restrict Swagger/OpenAPI exposure outside dev.

Exit criteria:

- W0 code and W0 documentation agree on posture fail-closed behavior.

### Phase 4 - Reconcile W0 Acceptance Criteria

Duration: 0.5 day.

Actions:

1. Decide whether LOC gates remain valid.
2. If yes, meet them.
3. If no, replace them with behavior-based gates.
4. Update delivery docs so "W0 skeleton step 1" cannot be read as "W0 accepted."

Exit criteria:

- The next review can measure W0 completion against current, enforceable criteria.

## Definition of Done for the Next Review Cycle

The next review should pass only when:

1. CI fails on a failing operator-shape gate.
2. Local-only architecture-sync never emits delivery-valid evidence.
3. Manifest Rule 8 fields describe one coherent state.
4. Maven compile and verify have run on the reviewed SHA.
5. `HealthEndpointIT` has passed with real Testcontainers Postgres.
6. W0 posture guard is implemented or explicitly re-scoped.
7. Swagger/OpenAPI exposure is posture-aware.
8. Runtime capability maturity remains below L1 until tests pass.
9. W0 acceptance criteria are current and enforceable.
10. Docker build does not mask dependency-resolution failure.

## Final Recommendation

The team should stop broad architecture edits for this cycle and focus on making the new runtime path honestly blocking. The next useful increment is not another design refresh; it is a green or deliberately red executable pipeline whose status cannot be ignored.

Priority order:

1. Remove the CI bypass.
2. Fix the Rule 8 evidence state machine.
3. Prove the Maven build and `HealthEndpointIT`.
4. Implement or re-scope the W0 posture guard.

Once those four are done, the project will have moved from design convergence to executable convergence. That is the point where architecture review can become much stricter and much more useful.
