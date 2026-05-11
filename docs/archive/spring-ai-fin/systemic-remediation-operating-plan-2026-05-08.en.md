# spring-ai-fin Systemic Remediation Operating Plan

Date: 2026-05-08
Audience: spring-ai-fin architecture and delivery teams
Purpose: stop the repeated reactive review/fix loop and create a convergence-oriented remediation system.

## Executive Summary

The repeated review cycles are not failing because the team is incapable of fixing individual findings. They are failing because the fixes are mostly local responses to the latest reviewer-visible symptom. The underlying architecture governance system still lacks a closed set of executable invariants, an authoritative evidence graph, a mandatory cross-platform gate pipeline, and a minimal runtime artifact that can prove claims.

The pattern is now clear:

1. A review finds a drift or missing proof.
2. The team patches the exact document line or gate pattern.
3. A new drift appears in an adjacent document, platform script, evidence file, or audit-trail commit.
4. The next review reports another inconsistency in the same family.

This is a reactive remediation loop. The team should pause new L2 expansion and move into a short control-plane stabilization program. The goal is not to write more architecture prose. The goal is to make the architecture corpus, evidence model, and gates behave like a small product with tests, schemas, platform parity, release rules, and measurable convergence.

## Diagnosis: Why The Work Is Not Converging

### 1. Findings are being fixed as text defects, not invariant failures

Many fixes changed the exact phrase or document that was called out, but did not turn the underlying rule into a durable invariant. Examples from recent cycles include ActionGuard stage drift, RLS reset vocabulary, HS256 posture wording, operator-shape gate state, manifest freshness, and delivery-log parity. Each was improved, but the enforcement was repeatedly narrower than the failure family.

Root cause:

- The unit of remediation is the individual finding.
- The correct unit of remediation should be the invariant family.

Required shift:

- Every finding must produce an invariant card:
  - invariant name;
  - owner;
  - active corpus scope;
  - positive examples;
  - negative examples;
  - gate rule;
  - self-test fixture;
  - maturity impact;
  - delivery evidence requirement.

### 2. The evidence graph is still optional and partially prose-based

The project now has manifest, delivery files, gate logs, status YAML, current index, and local logs. However, these are still loosely connected. Fields such as `TBD`, `null`, optional platform logs, skipped missing logs, and "stdout PASS is canonical evidence" keep the evidence graph open.

Root cause:

- Evidence is recorded in multiple files, but not validated as a closed graph.

Required shift:

- Treat the manifest as a strict schema, not documentation.
- Delivery-valid evidence must forbid unresolved identity fields.
- Missing required logs must fail.
- The gate must validate every edge:
  - HEAD to reviewed content SHA;
  - evidence commit to parent SHA;
  - delivery file to exact log path;
  - log SHA to accepted SHA;
  - manifest to status ledger;
  - manifest to current index;
  - manifest to Rule 8 state;
  - manifest to platform evidence states.

### 3. Gates are being treated as scripts, not production control-plane software

The gate scripts now carry significant responsibility, but they do not yet have the engineering discipline expected from the system they govern. Recent failures included PowerShell variable-order crashes, POSIX CRLF breakage, platform parity gaps, missing-log skip behavior, and optional self-tests.

Root cause:

- Gate implementation is not covered by mandatory tests, fixtures, schema validation, or platform CI.

Required shift:

- The gate layer needs its own test pyramid:
  - unit-like fixture tests for each rule category;
  - integration tests for full corpus scan;
  - cross-platform CI on Windows and POSIX;
  - negative fixtures proving each rule fails when it should.

### 4. The architecture is still documentation-first, with no runtime anchor

The docs describe strong controls: ActionGuard, RLS, auth posture, prompt security, sidecar security, observability health, and Rule 8. But the repository still has no runnable service artifact, no Maven module tree, no migrations, and no real test tree.

Root cause:

- The team is trying to close architecture findings before there is a minimal executable system that can disprove claims.

Required shift:

- Build a minimal W0 vertical slice as soon as the governance gate is stable:
  - one build system;
  - one Spring Boot service;
  - one authenticated tenant-scoped request path;
  - one durable Postgres-backed transaction path;
  - one operator-shape smoke run;
  - one real failure path with observable metrics.

### 5. There is no convergence metric

The team has many statuses, but no visible metric that tells whether the remediation loop is shrinking. As a result, each cycle can feel productive while the same defect families recur.

Root cause:

- The team tracks addressed findings, not recurrence by root-cause category.

Required shift:

- Track convergence metrics:
  - repeated finding families per cycle;
  - findings fixed by invariant rule rather than prose edit;
  - gate self-test pass rate;
  - cross-platform evidence completeness;
  - number of delivery-valid `TBD` / `null` fields;
  - number of active docs with encoding drift;
  - number of capabilities above L0 backed by real tests.

## Operating Principles For The Reset

1. Stop adding new architecture claims until the evidence control-plane is stable.
2. Convert every recurring finding into an invariant and a negative test.
3. Make missing evidence fail closed.
4. Distinguish local developer convenience from delivery-valid evidence.
5. Require both Windows and POSIX evidence for delivery-valid gate changes.
6. Keep Rule 8 fail-closed until a runnable artifact exists.
7. Do not promote maturity based on prose.
8. Prefer one authoritative machine-readable registry over repeated prose summaries.
9. Preserve historical documents, but exclude them explicitly from active truth.
10. Measure recurrence, not activity.

## Remediation Program

### Phase 0: Stop-The-Line Stabilization

Goal: prevent new drift while the control-plane is repaired.

Duration: 1-2 days.

Actions:

1. Freeze new L2 expansion unless it directly supports the remediation plan.
2. Declare `docs/governance/evidence-manifest.yaml` the only authoritative evidence pointer, but mark current version as not delivery-complete until Phase 1 finishes.
3. Add `.gitattributes` and normalize all shell scripts to LF.
4. Run and record:
   - Windows architecture-sync gate;
   - POSIX architecture-sync gate;
   - gate self-test;
   - Windows operator-shape smoke;
   - POSIX operator-shape smoke.
5. Create a temporary "no promotion" rule: no capability may move above L0/L1 during stabilization.

Exit criteria:

- `gate/check_architecture_sync.sh` runs directly on POSIX.
- `gate/check_architecture_sync.ps1` runs on Windows.
- `gate/test_architecture_sync_gate.sh` passes.
- No delivery-valid manifest field contains `TBD`.
- Missing delivery logs fail.

### Phase 1: Evidence Graph v3

Goal: replace prose evidence conventions with a closed graph.

Duration: 2-4 days.

Actions:

1. Define `evidence-manifest/v3` with required fields:
   - `reviewed_content_sha`;
   - `evidence_commit_sha`;
   - `evidence_commit_parent_sha`;
   - `evidence_commit_classification`;
   - `delivery_file`;
   - `architecture_sync_logs.posix.path`;
   - `architecture_sync_logs.posix.state`;
   - `architecture_sync_logs.windows.path`;
   - `architecture_sync_logs.windows.state`;
   - `operator_shape_logs.posix.state`;
   - `operator_shape_logs.windows.state`;
   - `rule_8.state`;
   - `capability_registry_path`;
   - `current_index_path`.
2. Remove `TBD` and bare `null` from delivery-valid evidence fields.
3. Use explicit states:
   - `pass`;
   - `fail`;
   - `missing_blocker`;
   - `not_applicable`;
   - `historical_only`.
4. Make delivery files include a machine-readable block:

   ```yaml
   evidence:
     kind: architecture_sync
     reviewed_content_sha: <sha>
     evidence_commit_sha: <sha>
     logs:
       posix: gate/log/<sha>-posix.json
       windows: gate/log/<sha>-windows.json
   ```

5. Update both gate scripts so missing required logs fail.
6. Add negative fixtures:
   - missing log;
   - wrong log SHA;
   - stale manifest SHA;
   - audit-trail commit touching disallowed path;
   - delivery file pointing to non-existent log;
   - `TBD` in delivery-valid manifest.

Exit criteria:

- A reviewer can reconstruct the full evidence chain from the manifest alone.
- No delivery file can claim a pass without an existing committed log.
- The same invalid corpus fails on both Windows and POSIX.

### Phase 2: Gate Productization

Goal: make gates reliable enough to govern delivery.

Duration: 3-5 days.

Actions:

1. Split gates into three modes:
   - `local`: useful during edits, dirty tree allowed, evidence never delivery-valid;
   - `ci`: clean tree required, produces platform log;
   - `delivery`: both platform logs required, manifest graph must be complete.
2. Add a gate schema file for log output.
3. Add fixture-based tests for every rule category.
4. Add CI matrix:
   - Windows PowerShell;
   - Ubuntu bash;
   - line-ending check;
   - fixture test suite;
   - delivery graph validation.
5. Make the self-test fail if any required platform is skipped in delivery mode.

Exit criteria:

- Gate changes cannot be merged unless their own tests pass.
- Delivery evidence cannot be generated from a dirty tree.
- Platform parity is proven by CI, not asserted in prose.

### Phase 3: Active Corpus Registry

Goal: stop active-vs-historical document ambiguity.

Duration: 2-3 days.

Actions:

1. Create an active corpus registry:

   ```yaml
   active_documents:
     - path: ARCHITECTURE.md
       layer: L0
       owner: architecture
     - path: agent-runtime/server/ARCHITECTURE.md
       layer: L2
       owner: runtime
   historical_documents:
     - path: docs/security-response-2026-05-08.md
       reason: preserved response history
       active_scan: false
   ```

2. Make gate scan scope derive from this registry.
3. Require every active document to be ASCII or clean UTF-8.
4. Require historical documents to carry a banner and be excluded by registry, not by ad hoc filename patterns.
5. Move repeated status summaries into generated or registry-backed sections.

Exit criteria:

- There is one machine-readable answer to "what is current architecture truth?"
- Historical docs cannot accidentally become active design input.
- Encoding drift is blocked across the active corpus.

### Phase 4: Capability Registry And Maturity Reset

Goal: replace mixed status language with L0-L4 maturity plus evidence state.

Duration: 2-4 days.

Actions:

1. Create `docs/governance/capability-registry.yaml`.
2. For each capability, record:
   - `capability_id`;
   - `owner`;
   - `maturity`;
   - `evidence_state`;
   - `design_docs`;
   - `implementation_paths`;
   - `test_paths`;
   - `operator_gate`;
   - `open_invariants`;
   - `last_delivery_valid_sha`.
3. Rename status values:
   - `design_accepted` -> `evidence_state: design_only`;
   - `implemented_unverified` -> `evidence_state: code_or_gate_exists_unverified`;
   - `test_verified` -> `evidence_state: test_verified`;
   - `operator_gated` -> `evidence_state: operator_gated`.
4. Gate rule: no capability may claim L2+ unless required docs, tests, and evidence fields exist.
5. Gate rule: no capability may claim L3 unless Rule 8 evidence is present.

Exit criteria:

- Maturity is the primary readiness language.
- Prose cannot overstate readiness without registry failure.
- Repeated capability splits no longer require manual ledger edits in many places.

### Phase 5: Minimal W0 Runtime Vertical Slice

Goal: create the first executable anchor for architecture claims.

Duration: 1-2 weeks after Phases 0-4.

Actions:

1. Add root Maven build.
2. Add `agent-platform` Spring Boot module.
3. Add `agent-runtime` module.
4. Add one tenant-scoped endpoint.
5. Add posture boot config.
6. Add one Postgres-backed store with tenant binding.
7. Add one integration test using real Postgres or Testcontainers.
8. Add one E2E public-interface test.
9. Convert operator-shape smoke from artifact-missing to real flow:
   - start long-lived process;
   - hit public endpoint three times;
   - verify no fallback events;
   - verify stage/lifecycle observability;
   - verify cancellation semantics if run lifecycle is included.

Exit criteria:

- Rule 8 still may not fully pass, but it fails on real runtime behavior instead of missing artifact.
- At least one security invariant is proven by executable tests.
- Future architecture claims can be grounded in code paths.

### Phase 6: Security Control Implementation Waves

Goal: implement high-risk controls by vertical slices, not by broad prose.

Recommended order:

1. Tenant identity and RLS path.
2. Auth posture and JWT validation.
3. Run lifecycle and cancellation.
4. ActionGuard side-effect boundary.
5. Audit/evidence chain.
6. Prompt-security taint model.
7. Sidecar trust profile.
8. Observability failure signals.

For each wave:

1. Write invariant card.
2. Write failing unit test.
3. Write failing integration test.
4. Write failing E2E or operator-shape assertion.
5. Implement minimal code.
6. Run all three layers.
7. Update capability registry.
8. Update evidence manifest.
9. Commit one wave only.

Exit criteria:

- No wave closes on prose alone.
- Every promoted capability has executable evidence.

## Root-Cause Review Ceremony

Every new P0/P1 finding should go through this 30-minute template before any fix:

1. What invariant failed?
2. Which files allowed the invariant to drift?
3. Why did the existing gate not catch it?
4. What negative fixture would have caught it?
5. Which registry/schema field should have made the invalid state impossible?
6. Does this finding belong to an existing defect family?
7. What is the smallest fix that prevents the family, not only the symptom?

No fix should start until these seven questions have written answers.

## Convergence Metrics

Track these in every remediation delivery:

| Metric | Target |
|---|---|
| Repeated P0/P1 finding families | decreases every cycle |
| Delivery-valid `TBD` fields | 0 |
| Delivery-valid `null` evidence fields | 0 unless state is explicit |
| Missing required platform logs | 0 |
| Gate self-test pass rate | 100% |
| Active corpus encoding violations | 0 |
| Capabilities above L1 without tests | 0 |
| Capabilities at L3 without Rule 8 PASS | 0 |
| Findings fixed only by prose edit | 0 for P0/P1 |
| Findings with negative fixture | 100% for P0/P1 |

## Team Working Agreement

1. Stop treating reviewer findings as a queue of text edits.
2. Treat every finding as a failed invariant until proven otherwise.
3. Fix the invariant, then fix the text.
4. Do not mark a finding addressed unless the gate or test would catch a recurrence.
5. Do not accept local-only evidence for delivery.
6. Do not use `TBD`, `null`, or stdout-only evidence in delivery-valid records.
7. Do not promote maturity without implementation and tests.
8. Prefer fewer documents with stronger schemas over more documents with repeated summaries.

## 30-Day Target State

By the end of the reset, spring-ai-fin should have:

1. A closed evidence manifest schema.
2. Cross-platform delivery gates that pass in CI.
3. Fixture tests for every architecture-sync rule family.
4. An active corpus registry.
5. A capability registry using L0-L4 as the primary readiness language.
6. No delivery-valid unresolved evidence fields.
7. A minimal runnable W0 service skeleton.
8. At least one tenant-scoped security invariant proven by tests.
9. Rule 8 still fail-closed if the real operator-shape flow is not ready, but failing for concrete runtime reasons rather than missing artifact.
10. A visible convergence dashboard showing repeated finding families trending down.

## Final Recommendation

The team should run one stabilization sprint before accepting more architecture feature work. The sprint should not be measured by number of findings closed. It should be measured by how many recurring finding families are made structurally impossible.

The strongest next move is to build the control-plane first: line endings, gate self-tests, manifest v3, delivery-log hard failure, active corpus registry, and capability registry. Once those are stable, W0 runtime implementation can proceed with far less review churn.
