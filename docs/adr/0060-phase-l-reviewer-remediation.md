# ADR-0060 — Phase L Reviewer Remediation (Closes P0-1, P0-2, P0-3, P1-1, P1-2, P1-4, P2-1)

- Status: Accepted
- Date: 2026-05-14
- Authority: External L1 architecture expert review at `docs/reviews/2026-05-14-l1-architecture-expert-review.en.md`.
- Scope: L1 release readiness — three release-blocking gaps and four supporting gaps surfaced by the external review.
- Supersedes-in-part: §5 "Risks Carried Forward (After Phase K)" of the L1 release note (rewritten by Phase L).

## Context

The L1 release (v0.1.0-L1 at SHA `4d691ee`) was pushed to GitHub on 2026-05-14. An external L1 architecture expert review followed and identified that the release was **not yet cleanly releasable as "basically complete."** The reviewer's verdict:

> Do not publish a clean "L1 complete" release note yet. Treat the current state as an L1 release candidate with remediation required.

Three release-blocking findings (P0) were confirmed against the source tree:

- **P0-1**: The architecture-sync gate failed on `release_note_baseline_truth` because the L1 release note carried no canonical baseline counts table (§4 constraints / ADRs / gate rules / self-tests).
- **P0-2**: `docs/governance/enforcers.yaml` cited test methods that do not exist in `RunHttpContractIT.java` — E5 (`createReturnsPending`), E6 (`cancelIsPostNotDelete`; actual method is snake_case `cancel_route_is_post_not_delete`), E24 (`cancelTerminalReturns409`). Rule 28j stripped `#anchor` before checking existence; the file-only gate could not detect this drift.
- **P0-3**: `docs/contracts/openapi-v1.yaml` still declared `version: "1.0.0-W0"` with only `/v1/health` documented. `RunController` shipped `POST/GET/CANCEL /v1/runs` operations that were exposed by the live spec but absent from the pinned snapshot. `OpenApiContractIT` only failed when a pinned operation was missing from live; additive endpoints in live passed.

Four supporting findings (P1/P2):

- **P1-1**: Reviewer suspected `IdempotencyHeaderFilter` consumed the request body before the controller. Verified: Spring's `ContentCachingRequestWrapper` does replay (per Javadoc + code comment), so this is **REFUTED**. But the underlying gap — no authenticated end-to-end POST `/v1/runs` test — is real.
- **P1-2**: `architecture-status.yaml` carried two rows (`w1_http_contract_reconciliation`, `micrometer_mandatory_tenant_tag`) as `design_accepted, shipped: false` while L1 had actually shipped the relevant code.
- **P1-4**: `agent-platform/ARCHITECTURE.md` §6–9 still described the W0 boundary as if L1 had not happened (test table, "JWT validation: W1 out of scope", "No JDBC at W0; risk not active").
- **P2-1**: Rule 28 meta-check (`constraint_enforcer_coverage`) was a baseline presence check, not the full constraint inventory implied by its name and ADR-0059's wording.

## Decision

Phase L closes P0-1/2/3 and P1-2/4 and P2-1 in this commit. P1-3 (PowerShell mirror port of 11 Rule-28 sub-rules) is explicitly deferred to W2 per §3 below.

### 1. Anchor-level truth (closes P0-2, hardens P0-2 root cause)

`gate/check_architecture_sync.sh` Rule 28j is strengthened: when an `artifact:` line carries `path#anchor`, after the existing file-existence check, the rule MUST also verify the anchor resolves to a real method (`.java`/`.sh`) or heading (`.md`) inside the target file. Match patterns:

- `.java`: `(void|\)|\>|\>[[:space:]])[[:space:]]+<anchor>[[:space:]]*\(` (test/method definition)
- `.sh`/`.bash`: `<anchor>()` function definition, `function <anchor>`, `# Rule N — <anchor>` comment, OR `(pass_rule|fail_rule) "<anchor>"` (rule-name pattern in the gate script itself)
- `.md`: `^#+[[:space:]].*<anchor>` (heading slug or phrase)
- `.yaml`/`.yml` or other: literal substring presence (loose check)

Two new gate self-tests under `gate/test_architecture_sync_gate.sh` exercise the positive (real anchor passes) and negative (bogus anchor fails) paths. Self-test total grows from 35 to 37. Closes reviewer finding P0-2 (and the gate-promise-gap class it represented).

### 2. Authenticated HTTP contract coverage (closes P0-2 + P1-1 underlying gap)

`agent-platform/src/test/java/.../web/runs/JwtTestFixture.java` lands as a shared test fixture (enforcer E37): generates one stable RSA keypair per JVM and provides `decoder()` + `mint(subject, tenantId)` helpers. Re-uses `JwtDecoderConfig.buildValidator` so the test decoder enforces the same issuer + audience + timestamp chain as production.

`RunHttpContractIT` gains four authenticated `@Test` methods named to match the enforcer-row anchors:

- `createReturnsPending` — POST `/v1/runs` with JSON body + Bearer + matching `X-Tenant-Id` → 201 with status `PENDING` (enforcer E5; **also proves the idempotency filter replays the body to the controller, closing the P1-1 underlying gap**).
- `tenantMismatchReturns403` — JWT claim ≠ `X-Tenant-Id` header → 403 `tenant_mismatch` (enforcer E10).
- `cancelTerminalReturns409` — Plants a SUCCEEDED `Run` directly via `RunRepository`, then HTTP-cancels → 409 `illegal_state_transition` (enforcer E24).
- `duplicateIdempotencyKeyReturns409` — POST twice with same Idempotency-Key but different body → 409 `idempotency_body_drift` (enforcer E22 strengthened).

`enforcers.yaml#E6` anchor is corrected from `cancelIsPostNotDelete` (does not exist) to `cancel_route_is_post_not_delete` (the actual method name). E5 / E24 anchors remain unchanged because the actual methods now exist with those names.

### 3. OpenAPI snapshot pinning + reverse-direction comparator (closes P0-3)

`docs/contracts/openapi-v1.yaml` is regenerated to version `1.0.0-W1` with full paths for `POST /v1/runs`, `GET /v1/runs/{runId}`, `POST /v1/runs/{runId}/cancel`, including:

- `bearerAuth` security scheme (JWT validated against `app.auth.issuer/jwks-uri`, MUST carry `tenant_id` claim).
- `X-Tenant-Id` and `Idempotency-Key` header parameter definitions.
- Schemas `CreateRunRequest`, `RunResponse` (with `RunStatus` enum), `ErrorEnvelope` (`{error:{code,message,details}}`).
- Per-operation response codes 201/400/401/403/404/409/422 with `ErrorEnvelope` references for failure rows.

`agent-platform/src/test/resources/contracts/openapi-v1-pinned.yaml` is synced to match.

`OpenApiSnapshotComparator` gains a new static method `compareNoUndocumentedLivePaths(pinned, live)` that fails when a live `/v1/**` path/operation is NOT documented in the pinned snapshot, unless the live operation carries `x-experimental: true`. Non-`/v1/**` paths (`/actuator/**`, `/v3/api-docs`, springdoc-emitted error endpoints) are tolerated.

`OpenApiContractIT.noUndocumentedV1OperationsExposedByLive` exercises the new comparator (enforcer E36). At L1, this means `POST /v1/runs`, `GET /v1/runs/{runId}`, `POST /v1/runs/{runId}/cancel` MUST appear in `openapi-v1.yaml` — additive live endpoints are no longer silently allowed for the public `/v1/**` namespace.

### 4. Meta-check truthful naming (closes P2-1)

The body of Rule 28 (`constraint_enforcer_coverage`) is annotated to make the scope explicit:

> **L1 scope (Phase L truthful naming, per reviewer P2-1):** baseline presence check only. Verifies that `docs/governance/enforcers.yaml` references `CLAUDE.md` AND `ARCHITECTURE.md`. This is the smallest viable bootstrap meta-check — it does NOT parse every "must"/"forbidden"/"required" sentence in the corpus and cross-reference each one. Full natural-language parsing is deferred (no executable enforcer is feasible without committing to a brittle regex over evolving prose).

The function name `constraint_enforcer_coverage` is retained because many existing references (`CLAUDE.md` §28, `docs/adr/0059-code-as-contract-architectural-enforcement.md`, `docs/governance/enforcers.yaml#E28`) carry that exact identifier. The truthful-naming intent is met by the explicit scope annotation in the rule body; the substantive coverage gap is closed by Rule 28j's anchor-level enforcement, which is the place where prose-vs-code drift actually manifested (P0-2).

### 5. Stale status row promotion (closes P1-2)

`w1_http_contract_reconciliation` is promoted from `design_accepted, shipped: false` to `test_verified, shipped: true` with full `implementation:` and `tests:` lists pointing at the L1 platform code (`RunController`, `JwtDecoderConfig`, `JwtTenantClaimCrossCheck`, `AuthProperties`, `RunHttpContractIT`, `JwtValidationIT`, `JwtTenantClaimCrossCheckTest`, `OpenApiContractIT`, `RunStatusEnumTest`).

(`metric_tenant_tag_w1` was nominally promotion-ready per the L1 release note §5 but does not exist as a row in `architecture-status.yaml`; the L1 capability `TenantTagMeterFilter` strips forbidden high-cardinality tags rather than requiring tenant_id on every metric, which is the existing `micrometer_mandatory_tenant_tag` row's commitment. The strip-filter capability is exercised by enforcer E19 and is wave-qualified as a separate concern.)

### 6. Module ARCHITECTURE.md refresh (closes P1-4)

`agent-platform/ARCHITECTURE.md` §6 is rewritten with an "L1 shipped tests" table listing every L1 test (`AuthPropertiesValidationTest`, `JwtValidationIT`, `JwtDevLocalModeGuardIT`, `JwtTenantClaimCrossCheckTest`, `IdempotencyStoreTest`, `IdempotencyStorePostgresIT`, `IdempotencyDurabilityIT`, `InMemoryIdempotencyAllowFlagIT`, `PostureBootGuardIT`, `RunHttpContractIT`, `RunStatusEnumTest`, `ErrorEnvelopeContractTest`, `TenantTagMeterFilterTest`, `PlatformImportsOnlyRuntimePublicApiTest`, `RuntimeMustNotDependOnPlatformTest`, `HttpEdgeMustNotImportMemorySpiTest`, `JwtTestFixture`). §7 ("Out of scope at L1") removes the "JWT validation: W1" line. §8 ("Wave landing") moves the L1 packages from W1-planned to W1-delivered and explicitly defers PowerShell mirror to W2. §9 ("Risks") rewrites virtual-thread + JDBC pinning from "not active at W0" to "active at L1; HikariCP wired".

## 3. Explicitly deferred (W2 trigger)

**PowerShell mirror port of Rule 28a–28j + Rule 28j hardening (P1-3).** The reviewer recommends porting all 11 Rule-28 sub-checks to `gate/check_architecture_sync.ps1` so contributors running only the PowerShell gate cannot miss L1 Rule 28 violations. Phase L explicitly **does not** land this port. Reasons:

1. The reviewer's verification command was `bash gate/check_architecture_sync.sh`. Bash is the canonical release gate at L1.
2. The 11 sub-checks (28a–28j + meta) contain non-trivial Bash idioms (`mktemp`, `<<<`, process substitution, `while IFS= read`) whose PowerShell equivalents would be substantial work and would re-introduce parity-drift risk if rushed.
3. Phase L's surface is already large (6 commits, ~12 files, 4 new test methods, 1 new test fixture, 1 new ADR, baseline-table updates across YAML/README/release notes).
4. W2 ports the gate-rule mechanism as a single coherent rewrite (incorporates Bash hardening + PowerShell parity + cross-platform self-test harness).

**Re-introduction trigger:** before any W2 commit lands. Tracked under `architecture-status.yaml` row `architecture_sync_gate` (current allowed_claim: "Bash is the only release gate at L1; PowerShell mirror port to W2 per ADR-0060 §3").

## Alternatives considered

- **Rename Rule 28 meta-check to `baseline_rule28_index_presence` (reviewer suggestion).** Rejected because the name `constraint_enforcer_coverage` is referenced in multiple ADRs, the release note, CLAUDE.md, and `enforcers.yaml`. Renaming would induce widespread reference churn for a cosmetic gain. The truthful-naming intent is met by the explicit scope annotation in the rule body.
- **Delete the broken anchors (P0-2 alternative).** Rejected. Removing `#cancelTerminalReturns409` and similar anchors weakens the enforcer rather than fixing the underlying gap. Implementing the real authenticated tests is the load-bearing fix.
- **Allow live `/v1/**` additive endpoints (P0-3 alternative).** Rejected. The L1 surface is public API; additive live endpoints absent from the pinned snapshot is exactly the drift class the snapshot is meant to prevent.

## Consequences

- L1 v0.1.0-L1 tag retained as the release candidate marker. L1 v0.1.0-L1.1 is the cleaned release; the corresponding release note adds §2.12 "Phase L Reviewer Remediation" + Architecture Baseline table.
- Future Rule 28j additions automatically validate any new `#anchor` references. Phase B/C/D/E/F/G/H/I/J/K anchors are all back-validated by this strengthening.
- Future OpenAPI changes MUST update both `docs/contracts/openapi-v1.yaml` and the pinned classpath copy; live additive `/v1/**` endpoints will fail `OpenApiContractIT.noUndocumentedV1OperationsExposedByLive`.
- Future Phase notes (Phase M+) MUST start from `agent-platform/ARCHITECTURE.md`'s current shipped surface; W0-era language in §6–9 is no longer present to confuse the picture.

## L1 Review Checklist (per ADR-0059 §16)

- [x] Identifies the constraint at risk (release-note baseline truth, anchor truth, public-contract truth)
- [x] Names the failure mode (gate fail / overclaimed enforcer / undocumented live endpoint)
- [x] Names the enforcer (Gate Rule 28, Rule 28j strengthening, `OpenApiContractIT.noUndocumentedV1OperationsExposedByLive`, `RunHttpContractIT.{createReturnsPending,tenantMismatchReturns403,cancelTerminalReturns409,duplicateIdempotencyKeyReturns409}`)
- [x] Records the alternative considered (anchor deletion, additive-live tolerance, meta-check rename)
- [x] Lists the test coverage (35 + 2 new self-tests = 37 cases; 4 new RunHttpContractIT methods; 1 new OpenApiContractIT method; updated `w1_http_contract_reconciliation` evidence list)
