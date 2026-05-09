# Systematic Architecture Remediation Plan - Cycle 9

Date: 2026-05-09
Repository HEAD reviewed: `853db96`
Architecture content SHA under delivery evidence: `4260a48`
Scope: `D:\chao_workspace\spring-ai-fin`
Review stance: strict architecture review after the cycle-8 evidence-graph remediation and the `4260a48` OSS-first architecture refresh.

## Executive Verdict

The project is improving, but it is still not converging.

The latest audit-trail commit, `853db96`, correctly adds delivery evidence for the architecture refresh at `4260a48`. The architecture-sync gate now runs on both Windows and POSIX in local mode and reports internal consistency. That is real progress: the earlier evidence-chain mechanics are no longer the main blocker.

The remaining blocker is deeper. The repository now has a new architecture truth, but the old architecture truth is still active. The active corpus still includes documents explicitly marked as renamed, moved, merged, replaced, or deferred. The current index still exposes pre-refresh L2 documents as part of the active hierarchy. ActionGuard is described as both a 5-stage chain and an 11-stage pipeline. The gate passes because it checks selected drift patterns, not because it proves a single authoritative architecture model.

This means the current repair loop is reactive. The team fixes the last reported symptom, then the next review finds another manifestation of the same root cause: there is no enforced truth-cut from old corpus to new corpus, and there is still no executable runtime artifact anchoring the architecture in operator behavior.

Current posture:

- Current repository HEAD: `853db96` (`Add 2026-05-08 refresh delivery evidence at 4260a48`).
- Reviewed architecture content SHA: `4260a48`.
- Architecture-sync gates: pass in local mode, with `evidence_valid_for_delivery=false` because the current run is local-only and the working tree contains untracked review artifacts.
- Rule 8 operator-shape smoke: still fails closed with `FAIL_ARTIFACT_MISSING`.
- Runtime implementation: still absent; no root `pom.xml`, no module POMs, no Java source tree, no migrations.
- Main architectural risk: multiple active sources of truth remain visible to engineers, reviewers, and future gates.

No capability should be promoted beyond design evidence. The next step should not be another broad documentation refresh. The next step must be a truth-cut followed by W0 executable skeleton work.

## Review Evidence

Commands and observations:

- `git rev-parse --short HEAD` returned `853db96`.
- `git show --name-only --format='%h %s' HEAD` shows `853db96` adds `docs/delivery/2026-05-08-4260a48.md`, governance manifest/status/index updates, and committed `4260a48` gate logs.
- `git status --porcelain=v1 -uall` reports only untracked local artifacts: this review document and `gate/log/29d069a-posix.json`.
- `gate/check_architecture_sync.ps1 -LocalOnly` passes and writes `gate/log/local/853db96-windows.json`.
- `bash ./gate/check_architecture_sync.sh --local-only` passes and writes `gate/log/local/853db96-posix.json`.
- `gate/run_operator_shape_smoke.ps1` fails with `FAIL_ARTIFACT_MISSING`.
- `bash ./gate/run_operator_shape_smoke.sh` fails with `FAIL_ARTIFACT_MISSING`.
- `Get-ChildItem -Recurse -File -Include pom.xml,build.gradle,*.java,*.kt,*.sql` returns no runtime build, source, or migration files.
- `docs/governance/active-corpus.yaml` still lists old documents under `active_documents` while assigning `v7_disposition` values such as `renamed_to`, `moved_to`, `merged_into`, `replaced_by`, and `deferred_in_v7`.
- `docs/governance/current-architecture-index.md` still lists pre-refresh L2 documents under a hierarchy explicitly described as `cycle-1..8 corpus; pending W0 deprecation`.

## Root-Cause Summary

Observed failure: repeated review cycles do not converge; each cycle fixes the latest finding but leaves new contradictions in the architecture corpus.

Execution path: cycle 8 fixed evidence-graph mechanics. The `4260a48` refresh then introduced a smaller OSS-first architecture, including a 5-stage ActionGuard model and new refresh-active L2 files. The audit-trail commit `853db96` added delivery evidence for that refresh. However, old v6 documents remained under `active_documents`, the current index still exposes pre-refresh docs as active hierarchy, and the gate still contains semantic checks for the old ActionGuard document.

Root cause statement: convergence fails because the project performs additive architecture repair without an enforced truth-cut; old and new design surfaces remain simultaneously active, so gates can pass corpus consistency while the architecture still has competing authoritative models.

Evidence:

- `docs/governance/active-corpus.yaml:139` lists `agent-runtime/server/ARCHITECTURE.md` under `active_documents`, while `docs/governance/active-corpus.yaml:143` marks it `renamed_to:agent-runtime/run`.
- `docs/governance/active-corpus.yaml:179` lists `agent-runtime/action-guard/ARCHITECTURE.md` under `active_documents`, while `docs/governance/active-corpus.yaml:183` marks it `renamed_to:agent-runtime/action`.
- `docs/governance/active-corpus.yaml:233` lists `docs/security-control-matrix.md` under `active_documents`, while `docs/governance/active-corpus.yaml:237` marks it `moved_to:docs/cross-cutting/security-control-matrix.md`.
- `docs/governance/current-architecture-index.md:13` says the hierarchy is `cycle-1..8 corpus; pending W0 deprecation`.
- `docs/governance/current-architecture-index.md:56` still lists `agent-runtime/action-guard/ARCHITECTURE.md` as the 11-stage authorization pipeline.
- `ARCHITECTURE.md:387` and `agent-runtime/action/ARCHITECTURE.md:8-13` define the refresh ActionGuard as 5 stages.
- `agent-runtime/action-guard/ARCHITECTURE.md:28-39` and `docs/security-control-matrix.md:62` still define ActionGuard as 11 stages.

## Findings by Category

### Category A - Governance Gate Coverage

#### Finding A1 - P0 - Architecture-sync passes while active truth is still split

The architecture-sync gate passes locally at `853db96`, but the corpus is not semantically single-sourced. A passing gate therefore means "known patterns did not fail," not "the active architecture is coherent."

Evidence:

- Windows architecture-sync local run passes.
- POSIX architecture-sync local run passes.
- `docs/governance/active-corpus.yaml` still keeps renamed/moved/deferred documents in `active_documents`.
- `docs/governance/current-architecture-index.md` still lists old L2 files as active hierarchy.

Impact:

- Reviewers can no longer trust a green architecture-sync gate as proof of one current architecture.
- Engineers can implement against old v6 docs while believing they are following active guidance.
- Future gate rules may reinforce the wrong model because the scan scope still contains transitional material.

Correction:

1. Add a blocking gate rule: no `active_documents` entry may contain `v7_disposition` values such as `renamed_to`, `moved_to`, `merged_into`, `replaced_by`, or `deferred_*`.
2. Require every active document to have exactly one status: `refresh_active`, `legacy_active`, or `historical`.
3. Fail if `current-architecture-index.md` lists any document not marked active in `active-corpus.yaml`.
4. Fail if any active document says it is renamed, moved, deferred, or superseded.

Definition of done:

- Architecture-sync fails on a fixture where an active document has `v7_disposition`.
- The live corpus contains no active document with a disposition marker.
- The current index is generated from, or mechanically validated against, the active corpus.

#### Finding A2 - P1 - Local gate evidence is easy to over-read as delivery evidence

The local architecture-sync runs pass, but the output explicitly says `evidence_valid_for_delivery=false`. This is correct. The risk is interpretive: teams may treat local pass logs as delivery evidence.

Evidence:

- Windows output: `PASS: architecture corpus is internally consistent. evidence_valid_for_delivery=false (local-only or dirty)`.
- POSIX output: same delivery-validity warning.

Impact:

- A local-only pass can be copied into status language as if it were a delivery-valid gate.
- This recreates the previous closure problem in a subtler form.

Correction:

1. Delivery files must quote `evidence_valid_for_delivery` explicitly.
2. The status ledger must distinguish `local_semantic_pass` from `delivery_valid_pass`.
3. CI should reject delivery claims when the latest run was local-only or dirty.

Definition of done:

- A delivery file cannot be marked current authoritative unless its referenced gate log has `evidence_valid_for_delivery=true`, or it explicitly records a named blocker.

### Category B - Active Corpus and Truth-Source Migration

#### Finding B1 - P0 - The active corpus contains documents that the same registry says are not current

`active-corpus.yaml` is currently a mixed registry: it holds both current docs and transitional docs. That defeats its purpose as a machine-readable source of truth.

Evidence:

- `agent-runtime/server/ARCHITECTURE.md` is active but marked renamed to `agent-runtime/run`.
- `agent-runtime/action-guard/ARCHITECTURE.md` is active but marked renamed to `agent-runtime/action`.
- `docs/security-control-matrix.md` is active but marked moved to `docs/cross-cutting/security-control-matrix.md`.
- Similar disposition markers appear across platform, runtime, cross-cutting, and deferred areas.

Impact:

- The corpus cannot answer "which document is authoritative?" without human interpretation.
- Gates inherit the ambiguity.
- Architecture review continues to generate findings from old documents because the system says they are still active.

Correction:

1. Split the registry into three sections:
   - `active_documents`: only authoritative current docs.
   - `transitional_rationale`: old docs retained for bounded migration context.
   - `historical_documents`: documents excluded from current review and gate semantics.
2. Add `sunset_by` and `owner` fields for transitional docs.
3. Gate all security-control and closure-language checks against `active_documents` only.
4. Gate all "stale but retained" docs for mandatory banner text.

Definition of done:

- No `active_documents` entry contains a disposition marker.
- Every transitional document has a sunset date or W0 exit condition.
- Reviewers can identify authoritative L0/L1/L2 docs without reading prose caveats.

#### Finding B2 - P0 - Current index still presents the pre-refresh hierarchy as active

The current index says the hierarchy is pending W0 deprecation, but still lists old docs in the primary hierarchy. This keeps the old architecture operationally alive.

Evidence:

- `docs/governance/current-architecture-index.md:13` says `cycle-1..8 corpus; pending W0 deprecation`.
- `docs/governance/current-architecture-index.md:44` lists `agent-runtime/server/ARCHITECTURE.md`.
- `docs/governance/current-architecture-index.md:56` lists `agent-runtime/action-guard/ARCHITECTURE.md`.
- `docs/governance/current-architecture-index.md:73` lists `docs/security-control-matrix.md`.

Impact:

- The index contradicts the refresh's stated canonical paths.
- Teams can cite the old hierarchy as current.
- The next review cycle will keep finding drift between refresh-active and v6-active docs.

Correction:

1. Replace the primary hierarchy with only refresh-active docs.
2. Move the pre-refresh hierarchy into a separate "Historical Rationale" section.
3. Add a note that historical entries are non-authoritative and excluded from implementation guidance.
4. Add a gate rule that the index primary hierarchy is a subset of active corpus authoritative paths.

Definition of done:

- The index has one active hierarchy.
- Old L2 docs are listed only as historical or transitional rationale.

### Category C - Security-Control Semantics

#### Finding C1 - P0 - ActionGuard has two active designs

The refresh defines ActionGuard as a 5-stage chain. The old active document and old security-control matrix still define it as an 11-stage pipeline with pre/post evidence writers. Both are visible in active architecture paths.

Evidence:

- `ARCHITECTURE.md:387-432` says ActionGuard is collapsed from the old 11-stage model to 5 stages.
- `agent-runtime/action/ARCHITECTURE.md:8-13` says the authoritative refresh design is 5 stages.
- `agent-runtime/action-guard/ARCHITECTURE.md:28-39` still defines 11 stages.
- `docs/cross-cutting/security-control-matrix.md:23` uses the 5-stage chain.
- `docs/security-control-matrix.md:62` uses the 11-stage pipeline.

Impact:

- This is a security-control drift on the side-effect authorization boundary.
- The 5-stage design may be valid, but only if it preserves audit-before-action and terminal evidence as explicit invariants.
- The 11-stage design may be valid, but only if the refresh reverts to it everywhere.
- Keeping both active makes implementation review impossible.

Correction:

1. Pick one ActionGuard model.
2. If 5-stage wins:
   - define audit-before-action as a non-skippable invariant inside the execution stage boundary;
   - define post-failure evidence as unconditional;
   - update old 11-stage docs to historical;
   - update gate rules to check the 5-stage model and its invariants.
3. If 11-stage wins:
   - update L0 and `agent-runtime/action/ARCHITECTURE.md` back to 11 stages;
   - update `docs/cross-cutting/security-control-matrix.md`;
   - remove "collapsed from 11 to 5" language.

Definition of done:

- Exactly one stage count appears in authoritative docs.
- Gate fixtures fail for the losing model.
- The security matrix, L0, L2, and trust-boundary diagram all describe the same enforcement path.

#### Finding C2 - P1 - Gate semantic rules still encode the old ActionGuard path

The gate still checks `agent-runtime/action-guard/ARCHITECTURE.md` for `PreActionEvidenceWriter` and `PostActionEvidenceWriter`. That means the gate has not migrated to the refresh-active `agent-runtime/action/ARCHITECTURE.md` model.

Evidence:

- `gate/check_architecture_sync.ps1:217-224` checks `PreActionEvidenceWriter` and `PostActionEvidenceWriter`.
- `gate/check_architecture_sync.sh:227-231` checks the same old evidence-writer terms.
- The refresh-active file is `agent-runtime/action/ARCHITECTURE.md`, not `agent-runtime/action-guard/ARCHITECTURE.md`.

Impact:

- The gate can pass because the old doc still contains old terms, even if the new authoritative doc omits required invariants.
- The gate is validating survival of a legacy document, not correctness of the refresh model.

Correction:

1. Drive semantic rules from `active-corpus.yaml`.
2. Make ActionGuard gate rules bind to the chosen active path.
3. If 5-stage wins, check invariants rather than pre/post stage names.
4. If 11-stage wins, check explicit stage names and ordering in the active document only.

Definition of done:

- Removing the old `agent-runtime/action-guard` document cannot make the gate blind.
- Breaking the chosen ActionGuard model in the active document fails the gate.

### Category D - Rule 8 and Runtime Reality

#### Finding D1 - P0 - The project still has no runnable runtime artifact

Rule 8 correctly fails closed because the repository has no Maven root, module manifests, Java source trees, or migrations.

Evidence:

- `gate/run_operator_shape_smoke.ps1` reports missing `pom.xml`, `agent-platform/pom.xml`, `agent-runtime/pom.xml`, `agent-platform/src/main/java`, and `agent-runtime/src/main/java`.
- POSIX operator-shape smoke reports the same missing artifacts.
- Recursive file inventory finds no `pom.xml`, `*.java`, `*.kt`, or `*.sql`.

Impact:

- Architecture remains design-only.
- Operator behavior cannot be tested.
- Review loops will continue to be dominated by documentation drift because there is no executable anchor.

Correction:

1. Freeze non-critical architecture prose after the truth-cut.
2. Create the minimal W0 runnable skeleton:
   - root Maven project;
   - `agent-platform` module;
   - `agent-runtime` module;
   - one Spring Boot entry point;
   - one tenant-scoped health/run endpoint;
   - one durable Postgres-backed path or explicit fail-closed dependency check.
3. Make operator-shape smoke fail on real runtime behavior rather than missing artifact.

Definition of done:

- Operator-shape smoke starts a managed long-lived process.
- The gate reaches at least one public endpoint.
- The failure mode moves from `FAIL_ARTIFACT_MISSING` to a real runtime assertion until all Rule 8 criteria pass.

#### Finding D2 - P1 - Fake-provider smoke and Rule 8 evidence are still too easy to confuse

The plans describe fake-provider sequential smoke as a useful CI path, while Rule 8 requires real downstream dependencies. Both are useful, but they must be named and gated differently.

Impact:

- CI smoke may be misreported as Rule 8.
- Delivery evidence may overstate readiness before a real provider/database/message bus run exists.

Correction:

1. Rename fake-provider runs to `ci_operator_shape_smoke`.
2. Reserve `rule_8_operator_shape` for real dependency runs only.
3. Add manifest fields:
   - `dependency_mode: fake|real`;
   - `rule_8_eligible: true|false`;
   - `provider_access_log_evidence`.
4. Fail delivery if `rule_8_eligible=true` and `dependency_mode=fake`.

Definition of done:

- Fake-provider smoke cannot be referenced as Rule 8 evidence in any delivery file.
- Rule 8 pass remains null until real dependencies are used.

### Category E - Maturity, Closure, and Review Psychology

#### Finding E1 - P1 - "100% design-time cap" language creates premature closure pressure

The current index describes the refresh as having a 240-dimension self-audit at 100% design-time cap. The qualifier matters, but the number still creates the impression of completeness while the corpus and ActionGuard model are split.

Evidence:

- `docs/governance/current-architecture-index.md:102` describes `4260a48` as current authoritative delivery with 100% design-time cap.
- Rule 8 still has no runnable artifact.
- Active corpus still contains transitional docs.

Impact:

- Teams may optimize for preserving a score rather than reducing executable risk.
- Review language becomes closure-oriented before implementation exists.

Correction:

1. Replace percentage language with capability maturity levels.
2. Report design audit as "L0/L1 design coverage", not completion.
3. Add a standard phrase: "Design-audit pass is not runtime readiness and not Rule 8 evidence."

Definition of done:

- Delivery files report capability maturity using L0-L4.
- Percent scores cannot be used as shipping claims.

## Systemic Assessment

The repeated non-convergence is not caused by a lack of reviewer effort. It is also not simply caused by careless implementation by the architecture team. The deeper pattern is this:

1. The team has been responsive to findings.
2. The fixes are often local and additive.
3. The architecture corpus has grown multiple layers of compatibility notes, transitional banners, and evidence ledgers.
4. The governance gates validate selected invariants, but do not yet enforce a single current truth.
5. There is still no executable W0 runtime to force architecture decisions into code, tests, and operator behavior.

So the root issue is both:

- insufficient system-level truth management; and
- reactive repair without a hard migration cutover.

The cure is not a larger review checklist. The cure is to reduce the active architecture surface, enforce that reduction mechanically, and then shift effort from prose to a minimal runnable artifact.

## Systematic Remediation Plan

### Phase 0 - Freeze and Assign a Truth-Cut Owner

Duration: 0.5 day

Actions:

1. Freeze non-critical architecture prose.
2. Name one accountable owner for the architecture truth-cut.
3. Define the target active corpus before editing any document.
4. Open one tracking issue: "W0 Truth-Cut and Runtime Anchor".

Exit criteria:

- No new architecture refresh commit is accepted unless it removes ambiguity or enables W0 runtime execution.

### Phase 1 - Make Active Corpus Exclusive

Duration: 1 day

Actions:

1. Move all `v7_disposition` entries out of `active_documents`.
2. Keep only the refresh-active documents in `active_documents`.
3. Move retained old docs into `transitional_rationale` or `historical_documents`.
4. Add a blocking gate test for disposition markers under active docs.

Exit criteria:

- Active corpus has one authoritative path per topic.
- Current index primary hierarchy is a subset of active corpus.

### Phase 2 - Resolve ActionGuard Semantics

Duration: 1 day

Actions:

1. Pick 5-stage or 11-stage as the only active ActionGuard model.
2. Update L0, L2, security matrix, trust-boundary diagram, and gate rules to match.
3. Add negative fixtures for the losing model.
4. Add explicit invariants for audit-before-action and post-failure evidence.

Exit criteria:

- The active docs cannot disagree on ActionGuard stage count.
- The gate validates the active document, not a legacy path.

### Phase 3 - Harden Evidence Semantics

Duration: 0.5 day

Actions:

1. Split `local_semantic_pass` from `delivery_valid_pass` in status language.
2. Add manifest checks for `dependency_mode` and `rule_8_eligible`.
3. Require delivery files to quote whether `evidence_valid_for_delivery` is true.

Exit criteria:

- A local-only pass cannot be accidentally reported as delivery evidence.
- Fake-provider smoke cannot be reported as Rule 8.

### Phase 4 - Build the W0 Runtime Anchor

Duration: 2-3 days

Actions:

1. Add root Maven build.
2. Add `agent-platform` and `agent-runtime` modules.
3. Add minimal Spring Boot runtime.
4. Add tenant-scoped endpoint and explicit posture boot guard.
5. Add one durable path or fail-closed dependency check.
6. Update operator-shape smoke to start the process and hit the public endpoint.

Exit criteria:

- Operator-shape no longer fails because artifacts are missing.
- The failure surface becomes runtime behavior, dependency wiring, or Rule 8 semantics.

### Phase 5 - Convert Review to Evidence-Driven Delivery

Duration: ongoing after W0

Actions:

1. Stop reporting broad architecture scores as closure.
2. Report L0-L4 maturity per capability.
3. Require every P0/P1 closure claim to cite:
   - active document path;
   - implementation file;
   - test file;
   - gate log;
   - delivery evidence file.

Exit criteria:

- Findings close only when design, code, tests, and operator evidence align.

## Definition of Done for the Next Review Cycle

The next review cycle should be considered successful only when:

1. `active_documents` contains no renamed/moved/merged/replaced/deferred documents.
2. `current-architecture-index.md` lists one active hierarchy.
3. ActionGuard has one active model.
4. The architecture-sync gate fails if the old ActionGuard model is reintroduced as active.
5. The security-control matrix exists in one active path.
6. Rule 8 remains fail-closed until a runnable artifact exists.
7. Fake-provider smoke is clearly non-Rule-8.
8. A W0 runtime skeleton exists and is exercised by the operator-shape smoke gate.
9. Delivery language uses L-level maturity, not completion percentages.
10. Every closure claim is tied to code, tests, and gate evidence.

## Final Recommendation

Do not start another broad documentation repair cycle. The team has enough design material. The missing discipline is enforced selection, not more explanation.

Make the truth-cut first: one active corpus, one current index, one ActionGuard model, one security matrix. Then build W0. Once there is a runnable artifact, future architecture reviews can move from text drift to observable behavior. That is the point at which this remediation loop will start to converge.
