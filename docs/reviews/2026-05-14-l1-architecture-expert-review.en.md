# L1 Architecture Expert Review

> Repository: spring-ai-ascend  
> Date: 2026-05-14  
> Reviewer stance: Java microservices architecture + agent runtime architecture  
> Reviewed target: `docs/releases/2026-05-14-L1-modular-russell-release.en.md` and current `main` checkout  
> Outcome: L1 direction is strong, but the current release should not yet be treated as fully complete.

## 1. Executive Assessment

The L1 architecture is directionally sound. The team correctly kept L1 focused on Spring module-level executable architecture: JWT validation, tenant claim cross-checking, durable idempotency, posture boot guards, a minimal run HTTP API, and code-backed architecture enforcement. The higher-order agent architecture contracts - dynamic hydration, workflow intermediary, skill topology scheduling, memory ownership, swarm authority, and long-connection containment - are also broadly well placed as design contracts rather than premature Java implementations.

However, the current L1 release still has material gaps in contract truth and verification. The most important issue is not a missing agent concept. It is that several L1 claims are stronger than the executable evidence. This violates the spirit of Rule 28 and reintroduces the older drift pattern that L1 was meant to close.

Recommendation:

- Do not publish a clean "L1 complete" release note yet.
- Treat the current state as an L1 release candidate with remediation required.
- Close the P0 and P1 items below before calling L1 architecture "basically complete."

## 2. Review Method

The review inspected:

- `docs/releases/2026-05-14-L1-modular-russell-release.en.md`
- `docs/governance/enforcers.yaml`
- `docs/governance/architecture-status.yaml`
- `agent-platform/ARCHITECTURE.md`
- `agent-runtime/ARCHITECTURE.md`
- ADRs 0032, 0034, 0049, 0050, 0051, 0052, 0053, 0054, 0055, 0056, 0057, 0058, 0059
- L1 platform code and tests under `agent-platform/src/main/java` and `agent-platform/src/test/java`
- The architecture-sync gate

Verification commands run:

```text
bash gate/check_architecture_sync.sh
./mvnw -am -pl agent-platform -q -DskipTests test-compile
```

Results:

- `test-compile` passed.
- `gate/check_architecture_sync.sh` failed on `release_note_baseline_truth`.

## 3. Root-Cause Summary

Observed failure: `bash gate/check_architecture_sync.sh` fails because the L1 release note lacks the baseline count table required by the release-note baseline truth gate.

Execution path: `gate/check_architecture_sync.sh` reads the canonical counts from `docs/governance/architecture-status.yaml`, scans active release notes under `docs/releases/`, and fails when the L1 release note lacks rows for constraints, ADRs, gate rules, and self-tests.

Root cause statement: the L1 release note presents a current active release artifact without the canonical baseline table required by Gate Rule 28, which causes the architecture-sync gate to fail before delivery can be considered clean.

Evidence: `docs/releases/2026-05-14-L1-modular-russell-release.en.md:287-293` reports verification status, but the command output fails on missing baseline counts; `gate/check_architecture_sync.sh` reports missing rows for `section 4 constraints`, `ADRs`, `gate rules`, and `self-tests`.

## 4. Findings

### P0-1: Architecture-sync gate fails on the L1 release note

The current release note is an active release artifact, but the architecture-sync gate rejects it.

Evidence:

- `docs/releases/2026-05-14-L1-modular-russell-release.en.md:287-293` says the gate is expected to pass, not that the current file actually passes.
- Local verification returned:

```text
FAIL: release_note_baseline_truth -- docs/releases/2026-05-14-L1-modular-russell-release.en.md missing baseline count for 'section 4 constraints'
FAIL: release_note_baseline_truth -- docs/releases/2026-05-14-L1-modular-russell-release.en.md missing baseline count for 'ADRs'
FAIL: release_note_baseline_truth -- docs/releases/2026-05-14-L1-modular-russell-release.en.md missing baseline count for 'gate rules'
FAIL: release_note_baseline_truth -- docs/releases/2026-05-14-L1-modular-russell-release.en.md missing baseline count for 'self-tests'
```

Impact:

- This is a delivery blocker. A release note that fails the architecture gate cannot be the clean L1 release note.
- The release note also mixes "29 base gate rules" and "40 rules/checks." That distinction may be valid, but the canonical baseline expected by the gate must be explicit.

Required fix:

- Add the canonical baseline table expected by Gate Rule 28, or explicitly mark the release note as a frozen historical artifact if it is no longer active.
- Clarify that "40" refers to executed checks or sub-checks, while the canonical baseline still counts "29 active gate rules" if that is the intended governance vocabulary.
- Re-run `bash gate/check_architecture_sync.sh` and record an actual pass, not an expected pass.

### P0-2: Run HTTP contract is overclaimed by enforcer rows

`docs/governance/enforcers.yaml` claims that `RunHttpContractIT` enforces authenticated run creation, initial `PENDING`, full status-code matrix behavior, and terminal cancel conflict behavior. The test file explicitly says those authenticated rows are not implemented yet.

Evidence:

- `docs/governance/enforcers.yaml:41-57` maps E5, E6, and E7 to `RunHttpContractIT` and claims:
  - `POST /v1/runs` returns `PENDING`
  - cancellation is `POST`
  - each status-code matrix row returns the documented status and error code
- `docs/governance/enforcers.yaml:44` references `RunHttpContractIT.java#createReturnsPending`, but no such test method exists.
- `docs/governance/enforcers.yaml:50` references `RunHttpContractIT.java#cancelIsPostNotDelete`, but the actual method is `cancel_route_is_post_not_delete`.
- `docs/governance/enforcers.yaml` references `RunHttpContractIT.java#cancelTerminalReturns409` for E24, but no such test method exists.
- `agent-platform/src/test/java/ascend/springai/platform/web/runs/RunHttpContractIT.java:27-31` states that the full JWT-authenticated matrix is a follow-up.
- `RunHttpContractIT.java:64-110` only covers unauthenticated route shape and public health.

Impact:

- This is an HTTP/API contract truth blocker.
- E5, E7, and E24 are currently evidence-laundering rows: they point to a real file but not to a real assertion.
- Rule 28j checks only file path existence after stripping anchors. It does not validate that a named test method or anchor actually exists, which is exactly how this gap survived.

Required fix:

- Implement the JWT mint helper and add authenticated tests for:
  - `POST /v1/runs` -> 201 and status `PENDING`
  - invalid run request -> 422 `invalid_run_spec`
  - JWT/header tenant mismatch -> 403 `tenant_mismatch`
  - cross-tenant GET -> 404 `not_found`
  - `POST /v1/runs/{id}/cancel` -> 200 `CANCELLED`
  - cancel terminal `SUCCEEDED`, `FAILED`, and `EXPIRED` -> 409 `illegal_state_transition`
  - duplicate mutating request -> 409 idempotency behavior
- Update enforcer rows to point to actual method names.
- Extend Rule 28j so `artifact: path#anchor` validates either a method, heading, or explicit anchor marker, not only the file path.

### P0-3: OpenAPI contract is still W0 additive-only while L1 run APIs are shipped

The release note carries OpenAPI snapshot regeneration as a follow-up, while L1 has already introduced `/v1/runs`. The pinned OpenAPI file still describes a W0 health-only surface.

Evidence:

- `docs/contracts/openapi-v1.yaml:4-5` still describes stability as W0 and version `1.0.0-W0`.
- `docs/contracts/openapi-v1.yaml:13-27` only includes `/v1/health`.
- `docs/contracts/openapi-v1.yaml:54` says W1 will add `/v1/runs`, but the code already has `RunController`.
- `agent-platform/src/test/java/ascend/springai/platform/contracts/OpenApiContractIT.java:23-31` says additive live operations absent from the pinned file are allowed.
- `docs/releases/2026-05-14-L1-modular-russell-release.en.md:300-303` lists OpenAPI snapshot regeneration as a pending follow-up.

Impact:

- L1's public HTTP contract is not pinned.
- The governance text says `OpenApiContractIT` validates the public contract, but today it does not block new undocumented endpoints.
- This is especially important because the run API is the first non-health northbound contract.

Required fix:

- Regenerate and review the pinned OpenAPI snapshot to include:
  - `POST /v1/runs`
  - `GET /v1/runs/{runId}`
  - `POST /v1/runs/{runId}/cancel`
  - request schemas
  - response schemas
  - error envelope schemas
  - tenant and idempotency headers
  - JWT security scheme
- Decide whether additive endpoints should remain allowed. For L1 public API truth, I recommend failing when live exposes an unpinned `/v1/**` operation unless the endpoint is explicitly marked experimental.
- Update `architecture-status.yaml` and `enforcers.yaml` so they describe the real comparator behavior.

### P1-1: Idempotency filter likely consumes the JSON request body before the controller can read it

The L1 idempotency filter drains the request body to compute a hash, then forwards the same `ContentCachingRequestWrapper`. The code comment says the wrapper replays the body, but Spring's official API documentation describes `ContentCachingRequestWrapper` as a caching interceptor for content as it is read, not as a replayable request-body wrapper.

Evidence:

- `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilter.java:126-132` creates `ContentCachingRequestWrapper`, drains `getInputStream().readAllBytes()`, and states downstream layers can read again.
- `IdempotencyHeaderFilter.java:152` forwards `wrapped` to the filter chain.
- The official Spring Framework API says the wrapper caches content read from the input stream and lets it be retrieved as a byte array; it "only caches content as it is being read" and otherwise does not cause content to be read. See Spring Framework `ContentCachingRequestWrapper` Javadoc: https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/util/ContentCachingRequestWrapper.html
- `RunHttpContractIT.java:27-31` does not test the authenticated JSON POST path that would catch this behavior.

Impact:

- Authenticated `POST /v1/runs` with idempotency enabled may reach the controller with an empty body or unreadable body, producing 400/422 instead of 201.
- This risk sits directly on the W1 public API path and on the durable idempotency path, so it should be treated as ship-blocking until proven otherwise.

Required fix:

- Replace `ContentCachingRequestWrapper` with a replayable cached-body request wrapper, or compute the hash in a place that sees the deserialized body without consuming the servlet input stream.
- Add an authenticated integration test that sends a JSON body through the real Spring Security + tenant + idempotency filter chain and asserts `POST /v1/runs` returns 201.
- Include a duplicate-key test through the same HTTP path, not only the store-level tests.

### P1-2: `architecture-status.yaml` is not fully refreshed for L1

The release note acknowledges that two rows are promotion-ready but not rewritten.

Evidence:

- `docs/releases/2026-05-14-L1-modular-russell-release.en.md:310-313` says `http_contract_w1_reconciliation` and `metric_tenant_tag_w1` are promotion-ready but not yet re-written.

Impact:

- This undermines the source-of-truth role of `architecture-status.yaml`.
- A release cannot simultaneously claim L1 truth refresh and carry known stale rows in the canonical ledger.

Required fix:

- Update the two rows before the release note is called complete.
- If the HTTP contract remains partially unverified, do not promote `http_contract_w1_reconciliation`; mark the missing authenticated matrix and OpenAPI snapshot as blockers.

### P1-3: PowerShell architecture gate mirror lacks Rule 28 sub-rules

The release note states the PowerShell gate still carries only the base 29 rules.

Evidence:

- `docs/releases/2026-05-14-L1-modular-russell-release.en.md:304-306` says the 11 Rule 28 sub-rules still need a PowerShell port.
- `gate/check_architecture_sync.ps1` contains the older release-note baseline gate but not the Rule 28a-28j sub-rules visible in `gate/check_architecture_sync.sh`.

Impact:

- This repository is being reviewed in a Windows environment. A non-equivalent PowerShell mirror is not a harmless gap.
- Contributors running only the PowerShell gate can miss L1 Rule 28 violations.

Required fix:

- Port Rule 28a-28j and the meta-check to PowerShell.
- Add parity self-tests that fail when the Bash and PowerShell rule catalogs diverge.

### P1-4: `agent-platform/ARCHITECTURE.md` still contains W0-era contradictions

The file has strong new L1 sections, but its later public contract, test, out-of-scope, wave, and risk sections still describe the older W0/W1 boundary.

Evidence:

- `agent-platform/ARCHITECTURE.md:222-233` lists only W0 shipped tests and omits the new L1 tests.
- `agent-platform/ARCHITECTURE.md:241-246` says JWT validation and Spring Security auth filters are W1 out of scope, even though they are now described earlier as L1 shipped.
- `agent-platform/ARCHITECTURE.md:248-255` lists W1 but omits the run HTTP API and still reads like a plan rather than shipped L1 behavior.
- `agent-platform/ARCHITECTURE.md:260-265` says no JDBC calls at W0 and JWT replay tuning is deferred alongside JWT auth, but W1 now wires JDBC idempotency and JWT validation.

Impact:

- This is the same peripheral-drift class the release says Phase K fixed.
- New contributors will read contradictory module guidance.

Required fix:

- Rewrite sections 4 through 9 of `agent-platform/ARCHITECTURE.md` to match the L1 shipped surface.
- Separate "W0 historical" from "L1 shipped" rather than mixing them in the same tables.
- Include the actual L1 tests and the remaining blocked tests honestly.

### P2-1: Rule 28 meta-enforcement is too weak for the claim it makes

Rule 28 says every architectural constraint must have an executable enforcer. The current meta-check only verifies that `enforcers.yaml` references `CLAUDE.md` and `ARCHITECTURE.md`.

Evidence:

- `gate/check_architecture_sync.sh:1291-1311` implements `constraint_enforcer_coverage` as a baseline presence check, not a full constraint inventory.
- E5/E24 demonstrate the practical gap: enforcer rows can overclaim assertions and point to non-existent anchors while still passing Rule 28j file existence.

Impact:

- Rule 28 is a good architectural principle, but the current executable enforcement is weaker than the prose claim.
- This is acceptable as a bootstrap only if explicitly described as a bootstrap. It should not be represented as full coverage.

Required fix:

- Rename the current meta-check to "baseline_rule28_index_presence" or similar, or strengthen it.
- Add anchor-level validation.
- Add negative self-tests where an enforcer row points to a missing test method and the gate must fail.
- Consider adding explicit constraint IDs to architecture prose to avoid impossible natural-language parsing of every "must" sentence.

## 5. Agent-Architecture Assessment

The agent-oriented architecture is not the weakest part of L1. In fact, the design is mostly disciplined:

- C/S Dynamic Hydration correctly separates `TaskCursor`, `BusinessRuleSubset`, and S-side `RunContext`.
- Workflow Intermediary and Mailbox Backpressure correctly prevent the bus from becoming a direct work executor.
- Rhythm track separation is a good long-horizon agent design choice.
- Memory and knowledge ownership are properly split between C-side business facts and S-side execution trajectory.
- Placeholder preservation is correctly elevated to a future ship-blocking rule.
- Skill topology scheduling correctly distinguishes Java skill SPI from distributed scheduling, bidding, and permission issuance.
- `SpawnEnvelope` correctly names the multi-agent authority propagation problem rather than hiding it behind parent-child run IDs.

The main architecture concern is not that these agent contracts are overdesigned for L1. The concern is that they may become a vocabulary layer without a prioritized executable bridge.

Recommended W2 bridge order:

1. Finish the L1 HTTP contract evidence first.
2. Implement one vertical path from authenticated `HydrationRequest` or `CreateRunRequest` to `Run` creation with tenant, idempotency, and error semantics fully tested.
3. Add `SpawnEnvelope` only when the runtime actually needs multi-child or delegated work.
4. Add memory ownership enforcement only when the first memory adapter writes data.
5. Add skill bidding only when there is more than one eligible capability provider or a real capacity limit.

Do not add more agent vocabulary before the current named contracts have first executable anchors.

## 6. Overdesign Review

The L1 implementation itself is not overbuilt. It adds reasonable Spring platform foundations.

The governance system is at risk of overdesign in one specific way: it has many named enforcer rows, sub-rules, and design-only contracts, but some of the most important rows still do not prove the behavior they claim. That is not fatal, but it means the next iteration should reduce ceremony and increase proof.

Recommended simplification:

- Prefer fewer enforcer rows with stronger end-to-end assertions.
- Make file-and-anchor existence a hard gate.
- Avoid claiming "each status-code matrix row" unless the test names every matrix row.
- Use `shipped: true` carefully for design-only architecture contracts; if necessary, add a second field such as `runtime_shipped: false` or `contract_shipped: true` to prevent ambiguity.

## 7. Proposed Remediation Plan

### Phase R1: Release-note and gate truth

- Add the baseline table to the L1 release note.
- Re-run `bash gate/check_architecture_sync.sh`.
- Port Rule 28a-28j to PowerShell or mark Bash as the only release gate with an explicit ADR decision.

### Phase R2: HTTP contract closure

- Add authenticated `RunHttpContractIT` coverage.
- Add a JWT mint helper for the dev fixture keypair.
- Ensure the idempotency filter does not consume the request body.
- Add duplicate-key HTTP path tests.

### Phase R3: OpenAPI contract closure

- Regenerate and pin the OpenAPI snapshot for `/v1/runs`.
- Add schemas for `CreateRunRequest`, `RunResponse`, and `ErrorEnvelope`.
- Decide whether additive live `/v1/**` operations are allowed.

### Phase R4: Governance hardening

- Validate `artifact#anchor` references.
- Add a negative self-test for missing method anchors.
- Update stale `architecture-status.yaml` rows.
- Rewrite stale sections of `agent-platform/ARCHITECTURE.md`.

### Phase R5: Agent bridge discipline

- Freeze new agent vocabulary additions until one executable bridge exists.
- Prioritize `SpawnEnvelope` and memory/skill contracts only when their first real runtime boundary is implemented.

## 8. Release Recommendation

Current recommendation:

> L1 architecture is promising and mostly well-shaped, but it is not yet cleanly releasable as "basically complete." The release should be recut after the gate failure, HTTP contract evidence gap, OpenAPI snapshot gap, and idempotency body-lifetime risk are closed.

After remediation, the release note should say:

- architecture-sync gate passed with the exact command and date
- authenticated run API contract passed
- OpenAPI snapshot includes all L1 public endpoints
- enforcer anchors resolve to real assertions
- remaining agent contracts are intentionally design-only and wave-qualified

