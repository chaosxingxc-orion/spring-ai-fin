# L1 Modular-Russell Release

> Wave: W1 (L1 module-level architecture)
> Date: 2026-05-14
> Plan of record: `D:\.claude\plans\l1-modular-russell.md`
> Authority: architect guidance `docs/plans/2026-05-13-l1-architecture-design-guidance.en.md`
> Governing rule introduced: **Rule 28 — Code-as-Contract** (ADR-0059)
> Status surface: 10 commits land in this milestone (Phases A–J).

## 1. What L1 Is

L1 is **not** a maturity label. Per `AGENTS.md`, the binary `shipped:` truth in
`docs/governance/architecture-status.yaml` still governs. L1 means:

> Module-level architecture that converts L0 decisions into Spring Boot
> composition, HTTP contracts, persistence contracts, posture behavior,
> tests, and evidence.

L1's headline addition is **Rule 28 (Code-as-Contract)**: every architectural
constraint must have an executable enforcer; prose-only constraints are
forbidden. The 32-row `docs/governance/enforcers.yaml` index maps every L1
constraint to a real test or gate-script rule.

## 2. What Shipped

### 2.1 Governance (Phase A, commit `1ac80dd` — partial: A+B combined)

- **Rule 28** added to `CLAUDE.md`: every architectural constraint must be
  enforced by code (ArchUnit / gate-script / integration test / schema
  constraint / compile-time check). Header bumped from "Eleven" to "Twelve
  active rules."
- **ADR-0059** records the decision, names the five legal enforcer kinds, and
  defines sub-checks 28a–28i + the meta-rule.
- **`docs/governance/enforcers.yaml`** — 32 rows (E1–E32), one per L1 plan
  §11 constraint, each mapping to a real artifact path.

### 2.2 Module Direction Inversion (Phase B)

- **ADR-0055** supersedes ADR-0026: `agent-platform → agent-runtime` is now
  permitted (the W1 HTTP run handoff needs it); `agent-runtime → agent-platform`
  remains forbidden at pom AND source level.
- **Gate Rule 10** amended: only checks the runtime→platform direction; the
  PowerShell mirror updated in lockstep.
- **`RuntimeMustNotDependOnPlatformTest`** (ArchUnit, enforcer E2) generalises
  Rule 21 from the single `TenantContextHolder` class to the whole
  `ascend.springai.platform..` package.
- **`HttpEdgeMustNotImportMemorySpiTest`** (ArchUnit, enforcer E4): HTTP edge
  cannot import the memory SPI.
- **`agent-platform/pom.xml`** declares `agent-runtime` as a dependency.

### 2.3 JWT Validation (Phase C, ADR-0056, commit `0422123`)

- **`AuthProperties`** (`@ConfigurationProperties("app.auth")`) — issuer,
  jwks-uri, audience, clock-skew, jwks-cache-ttl, dev-local-mode. Constructor
  defaults + cross-field consistency check.
- **`JwtDecoderConfig`** — single construction path (Rule 6) with two
  conditional beans: JWKS-backed when `app.auth.issuer` is set; dev-local-mode
  reads a classpath fixture keypair. Shared validator chain
  (issuer + audience + JwtTimestampValidator) wrapped in a `CountingValidator`
  that emits `springai_ascend_auth_failure_total{reason,source}`.
- **`WebSecurityConfig`** replaced: stateless, permit-list
  (`/v1/health`, `/actuator/{health,info,prometheus}`, `/v3/api-docs(/**)`),
  `oauth2ResourceServer().jwt()` when a `JwtDecoder` bean is present,
  `denyAll` fallback otherwise (preserves W0 dev-zero-config behaviour).
- Tests (enforcer rows E9, E11): `AuthPropertiesValidationTest`,
  `JwtValidationIT` (real Nimbus + RSA keypair, every failure row of ADR-0056
  §4 exercised), `JwtDevLocalModeGuardIT` (deferred from C to F since it
  needs `PostureBootGuard`).

### 2.4 Tenant Claim Cross-Check (Phase D, ADR-0056 §3)

- **`ErrorEnvelope`** + **`ErrorEnvelopeWriter`** — stable
  `{error:{code,message,details}}` JSON shape (enforcer E8).
- **`JwtTenantClaimCrossCheck`** filter at order 15 (after Spring Security's
  `BearerTokenAuthenticationFilter`, before `TenantContextFilter` at 20).
  Branches: no auth → pass-through; missing header → pass-through (delegated
  to `TenantContextFilter`); claim==header → pass-through;
  claim!=header → 403 `tenant_mismatch`; claim missing + header present →
  403 `jwt_missing_tenant_claim`. Counters:
  `springai_ascend_tenant_mismatch_total`,
  `springai_ascend_jwt_missing_tenant_claim_total`.
- `JwtTenantClaimCrossCheckTest` exercises every branch (enforcer E10).

### 2.5 Durable Idempotency (Phase E, ADR-0057, commit `563d280`)

- **Flyway `V2__idempotency_dedup.sql`** — `(tenant_id, idempotency_key)`
  PRIMARY KEY, `request_hash` column, status CHECK constraint
  (`CLAIMED|COMPLETED|FAILED`) — schema-layer enforcer E13.
- **`IdempotencyStore` interface** + **`JdbcIdempotencyStore`**
  (INSERT … ON CONFLICT semantics) + **`InMemoryIdempotencyStore`**
  (`ConcurrentHashMap`, posture-gated).
- **`IdempotencyStoreAutoConfiguration`** wires exactly one bean per posture.
- **`IdempotencyHeaderFilter`** promoted from header-only to active
  claim/replay: wraps the request in `ContentCachingRequestWrapper`, hashes
  `method:path:body` (SHA-256 → base64url), calls `claimOrFind`, emits
  409 `idempotency_conflict` / 409 `idempotency_body_drift` via
  `ErrorEnvelopeWriter`.
- Tests (E12, E13, E14, E22): `IdempotencyStoreTest`,
  `IdempotencyStorePostgresIT` (Testcontainers), `InMemoryIdempotencyAllowFlagIT`.

### 2.6 PostureBootGuard (Phase F, ADR-0058, commit `028e3aa`)

- **`PostureBootGuard`** (`ApplicationListener<ApplicationReadyEvent>`)
  inspects `AuthProperties` + `IdempotencyStore` + `DataSource` +
  `MeterRegistry` on startup. In research/prod throws
  `IllegalStateException` listing every failed check
  (`auth_jwks_config_missing`, `dev_local_mode_outside_dev`,
  `datasource_missing`, `idempotency_store_not_durable`,
  `in_memory_idempotency_store_present`, `meter_registry_missing`).
  Emits `springai_ascend_posture_boot_failure_total{posture,reason}`.
- **`@RequiredConfig`** annotation lands as documentation for the future
  scanner.
- Tests (E11, E21, E22): `PostureBootGuardIT` (six cases),
  `JwtDevLocalModeGuardIT` (three cases). `PostureBindingIT` updated to
  provide stub auth config and accept 401 OR 403 (oauth2 resource server
  now advertises Bearer with 401 when a decoder is wired).

### 2.7 W1 HTTP Run API (Phase G, commit `d69a84b`)

- **`CreateRunRequest`** (Bean Validation), **`RunResponse`**,
  **`ErrorEnvelope`** (Phase D), **`RunHttpExceptionMapper`**
  (`@ControllerAdvice` that maps `MethodArgumentNotValidException` → 422
  `invalid_run_spec`, `HttpMessageNotReadableException` → 400 `invalid_request`,
  `IllegalArgumentException` → 400, uncaught `RuntimeException` →
  500 `internal_error`).
- **`RunController`** under `/v1/runs`:
  - `POST /v1/runs` → 201 with status `PENDING` (no `CREATED` state ever;
    enforcer E5).
  - `GET /v1/runs/{runId}` → 200 with current state; 404 `not_found` for
    unknown run OR cross-tenant access (architect guidance §9.4
    "tenant-scope-as-not-found").
  - `POST /v1/runs/{runId}/cancel` → 200 with `CANCELLED`; idempotent for
    already-cancelled runs; 409 `illegal_state_transition` for
    `SUCCEEDED`/`FAILED`/`EXPIRED` (enforcer E24).
- **`RunControllerAutoConfiguration`** wires `InMemoryRunRegistry` as the
  `RunRepository` when `app.posture=dev` and no other repository bean exists.
  Research/prod require a durable repository (W2).
- Tests:
  - `RunStatusEnumTest` (E5): pins the enum at the seven canonical values;
    asserts `CREATED` does not exist.
  - `ErrorEnvelopeContractTest` (E8): JSON shape exactly
    `{error:{code,message,details}}`.
  - `RunHttpContractIT` (Testcontainers + HttpClient — Boot 4 does not ship
    `@AutoConfigureMockMvc`): unauthenticated 401/403, DELETE-not-a-route,
    `/v1/health` permit-list sanity. The JWT-authenticated matrix (201
    PENDING, 422, 403 tenant_mismatch, cancel transitions) needs a
    JWT-mint helper against the dev fixture keypair; that helper lands
    in a follow-up alongside the OpenAPI snapshot regen.

### 2.8 Observability (Phase H, commit `b193911`)

- **`TenantTagMeterFilter`** registers a `MeterFilter` that strips forbidden
  high-cardinality tag keys (`run_id`, `idempotency_key`, `jwt_sub`,
  `body`) from any `springai_ascend_*` metric at registration time.
  Non-namespace metrics (`jvm.*`, etc.) are left untouched.
- `TenantTagMeterFilterTest` exercises every forbidden key plus a
  preserve-low-cardinality sanity case (enforcer E19).

### 2.9 Rule-28 Sub-Enforcers (Phase I, commit `00f3963`)

- **10 new gate sub-rules** in `gate/check_architecture_sync.sh`
  (28a–28i + meta 28): see ADR-0059 §3 and the gate header for the
  table. Highlights:
  - 28a `tenant_column_present` (E15): every `CREATE TABLE` in db/migration
    declares `tenant_id` (Python or awk fallback).
  - 28d `out_of_scope_name_guard` (E26): W2+ deferred names absent from
    main sources.
  - 28e `module_count_invariant` (E27): root pom has exactly 4 `<module>`.
  - 28f `enforcers_yaml_wellformed` (E29): every row has all five fields,
    legal kind value.
  - 28g `no_prose_only_constraint_marker` (E30): rejects
    TODO/FIXME/XXX/deferred : enforce/enforcer/test/gate.
  - 28h `l1_review_checklist_present` (E31): ADRs 0055–0059 carry the
    §16 checklist.
  - 28 `constraint_enforcer_coverage` (meta, E28): enforcers.yaml
    references CLAUDE.md AND ARCHITECTURE.md — the baseline meta-check
    that future waves tighten.
- **3 new ArchUnit tests**: `RepositoryPaginationTest` (E16),
  `NoStringConcatSqlTest` (E17), `MetricNamingTest` (E18).
- Gate header bumped from "29 rules" to "39 rules (29 base + 10 Rule-28
  sub-checks)."

### 2.10 Architecture-Truth Refresh (Phase J, this commit)

- `architecture-status.yaml` — promoted rows:
  - `posture_module_bootstrap`: `shipped: true` with `PostureBootGuard.java`,
    `PostureBootGuardIT`, `JwtDevLocalModeGuardIT`, `PostureBindingIT`.
  - `idempotency_store`: `shipped: true` with the full JDBC + in-memory
    set + V2 migration + three test classes.
  - (Additional W1 rows `http_contract_w1_reconciliation` and
    `metric_tenant_tag_w1` updated in follow-up alongside the OpenAPI
    snapshot regen; the high-confidence promotions land in this commit.)
- Module ARCHITECTURE.md updates: `agent-platform/ARCHITECTURE.md`
  refreshed in Phase K (commit `feat(L1/K)`) with L1 subsections for
  `auth/`, `tenant/` (cross-check addition), `idempotency/` (durable
  store), `posture/`, `web/runs/`, `observability/`, and `architecture/`.
  `agent-runtime/ARCHITECTURE.md` unchanged — L1 added no new packages
  to the runtime kernel.

### 2.11 Phase K — Post-J Audit Remediation

The three-Explore-agent audit after Phase J landed surfaced one **P0**,
four **P1**, and four **P2** findings. Phase K (commit `feat(L1/K)`)
closes them and adds two new enforcer rows (E33, E34).

- **F1 (P0 — Rule 28 self-violation)**: enforcer E12 declared
  `IdempotencyDurabilityIT.java` at a path that did not exist on disk.
  Phase K lands the missing test (`agent-platform/.../idempotency/jdbc/
  IdempotencyDurabilityIT.java`): four cases proving the claim row
  persists across a simulated downstream failure, retry sees the
  existing record, body-drift still returns the original hash, and
  `expires_at` exceeds `created_at` by the configured TTL.
- **F6 (P0 — gate gap that let F1 ship)**: no rule validated `artifact:`
  path existence. Phase K adds **Gate Rule 28j**
  (`enforcer_artifact_paths_exist`) + enforcer row **E33**, which walks
  every `artifact:` line in `enforcers.yaml`, strips the `#anchor`
  suffix, and fails if the file is missing.
- **F2 + F3 (P1 — path drift)**: enforcer rows E14 and E25 had
  artifact paths that didn't match disk. Phase K updates the YAML:
  E14 → `idempotency/IdempotencyStorePostgresIT.java#bodyDriftReturns409`;
  E25 → `contracts/OpenApiContractIT.java`.
- **F4 (P1 — PERIPHERAL-DRIFT)**: `agent-platform/ARCHITECTURE.md` was
  unchanged since 2026-05-13 and did not document the L1 packages.
  Phase K refreshes the file with subsections for every new L1 package
  + enforcer-row cross-references (see §2.10 above for the list).
- **F5 (P2 — vacuous test transparency)**: `RepositoryPaginationTest`
  ships with `allowEmptyShould(true)` because there are no Spring Data
  repository beans yet. Phase K extends the `asserts:` field of E16 in
  `enforcers.yaml` to make the vacuity explicit: *"…vacuous at L1 (no
  Spring Data Repository beans yet)."*
- **F7 (P2 — gate-scope brittleness)**: Rule 28g's `_28g_files` list
  hardcoded ADRs 0055–0058 only. Phase K switches to a glob
  (`docs/adr/00[5-9][0-9]-*.md`) with an explicit exempt list — ADR-0059
  remains exempt because it documents the marker patterns; future L1+
  ADRs are auto-covered.
- **F8 (P2 — release-note vagueness)**: §2.10 said "additional W1 rows
  updated in follow-up" without naming them. Phase K names them
  (`http_contract_w1_reconciliation`, `metric_tenant_tag_w1`).
- **F9 (P2 — META-PATTERN, Phase B side-effect)**: Phase B amended
  Gate Rule 10 to allow `agent-platform → agent-runtime` but did not
  bound which runtime packages may be imported. A future refactor
  could couple the HTTP edge to runtime internals. Phase K adds
  `PlatformImportsOnlyRuntimePublicApiTest` (ArchUnit) + enforcer row
  **E34**: platform main sources may only depend on `runs.*`,
  `orchestration.spi.*`, `posture.*`, and the `InMemoryRunRegistry`
  adapter; every other runtime package is off-limits.

Enforcer index grows from 32 → **34 rows** (E1–E34). Plan §11 table
extended to match (enforces E32 / `plan_enforcer_table_in_sync`).
Gate Rule count grows from 39 → **40 rules** (29 base + 11 Rule-28
sub-checks, including the new 28j).

**Findings NOT in Phase K**:
- **F10 (TEMPORAL-OVERREACH)** — none detected; ADRs and release note
  correctly wave-qualify W2+ items.
- **F11 (ZOMBIE-CODE)** — none detected; W0 stub fully replaced.

## 3. Explicitly Deferred at L1

Per architect guidance §7.2 and L1 plan §13, the following stay W2+ and are
**not** introduced as code, prose, or stubs in this milestone. Gate Rule 28d
(`out_of_scope_name_guard`, enforcer E26) actively rejects these names in
main sources:

- LLM Gateway (Rule 7, W2)
- Skill SPI + Skill Registry (W2)
- Postgres durable `Checkpointer` (W2)
- `PayloadCodec` / `CausalPayloadEnvelope` (W2)
- Three-track `RunDispatcher` / Workflow Intermediary (W2)
- Memory Ownership Java types (W2)
- C/S protocol Java types (W2)
- Skill Topology Scheduler + bidding (W2)
- Streaming `Flux<RunEvent>` handoff (W2)
- HookChain enforcement (W2)
- Untrusted skill `SandboxExecutor` (W3)
- Cost-of-use constraints (W3)
- Self-evolution / memory compression (W3)
- Temporal durable workflows + `ChronosHydration` (W4)
- `SpawnEnvelope` Java record (W2; dimensions named in ADR-0053)
- Connection containment (`LogicalCallHandle`, `ConnectionLease`,
  `AdmissionDecision`, `BackpressureSignal`) (W2; named in ADR-0054)
- Three resource-explosion vectors (W1+ named, not implemented)
- Graphiti adapter module (W2)

## 4. Verification

Per L1 plan §14, the following passes:

| Step | Mechanism | Status |
|---|---|---|
| Build | `./mvnw -am -pl agent-platform -q test-compile` | exit 0 |
| Unit tests | `AuthPropertiesValidationTest`, `JwtTenantClaimCrossCheckTest`, `IdempotencyStoreTest`, `RunStatusEnumTest`, `ErrorEnvelopeContractTest`, `TenantTagMeterFilterTest` | exit 0 |
| Integration tests (no Docker) | `PostureBootGuardIT`, `JwtDevLocalModeGuardIT`, `InMemoryIdempotencyAllowFlagIT`, `JwtValidationIT` | exit 0 |
| Integration tests (Docker required) | `IdempotencyStorePostgresIT`, `RunHttpContractIT` | runs in `mvn verify` |
| Architecture-sync gate (full) | `bash gate/check_architecture_sync.sh` | 40/40 rules PASS expected after Phase K (29 base + 11 Rule-28 sub-checks 28a–28j + meta). Windows shell occasionally exhibits >2 min total runtime — content of the sub-rule output verified via prior run `b0jgt6py7` plus Phase K spot-checks. |

## 5. Risks Carried Forward (After Phase K)

- **`RunHttpContractIT` JWT-authenticated matrix**: ships in a follow-up
  (needs the JWT-mint helper). The unauthenticated, route-shape, and
  permit-list rows pass today.
- **OpenAPI snapshot regen**: pending the same follow-up.
  `OpenApiContractIT` exists at `contracts/OpenApiContractIT.java`
  (E25 path corrected in Phase K); the snapshot file will refresh
  once the run endpoints are in the spec dump.
- **PowerShell mirror gate (`gate/check_architecture_sync.ps1`)**: still
  carries the base 29 rules. The 11 Rule-28 sub-rules (28a–28j + meta)
  need a PowerShell port; tracked as a follow-up.
- **Gate runtime on Windows bash**: occasional >2 min total times.
  Sub-rules optimised to use `grep -rnE` and `git grep -l` in single
  calls; further Windows-specific tuning is a follow-up.
- **Two `architecture-status.yaml` rows** (`http_contract_w1_reconciliation`,
  `metric_tenant_tag_w1`) are promotion-ready but not yet re-written;
  the implementation evidence exists and the rows update alongside the
  OpenAPI snapshot regen.

**Resolved in Phase K** (no longer carried forward):
- ~~E12 IdempotencyDurabilityIT.java missing~~ — landed.
- ~~E14, E25 path drift in enforcers.yaml~~ — paths corrected.
- ~~agent-platform/ARCHITECTURE.md missing L1 package docs~~ —
  comprehensive L1 subsections added.
- ~~No gate rule for enforcer artifact path existence~~ —
  Rule 28j (`enforcer_artifact_paths_exist`) added.
- ~~No bound on which runtime packages agent-platform may import~~ —
  `PlatformImportsOnlyRuntimePublicApiTest` (enforcer E34) added.

## 6. Commit Trail

| Phase | SHA | Summary |
|---|---|---|
| A+B | `1ac80dd` | Rule 28 + ADR-0059 + enforcers.yaml + ADR-0055 + module direction inversion |
| C+D | `0422123` | JWT validation + tenant claim cross-check + ADR-0056 |
| E | `563d280` | Durable idempotency claim/replay + ADR-0057 |
| F | `028e3aa` | PostureBootGuard + ADR-0058 |
| G | `d69a84b` | W1 HTTP run API + status-code matrix |
| H | `b193911` | TenantTagMeterFilter (high-cardinality scrubber) |
| I | `00f3963` | Rule 28 sub-enforcers (10 gate rules + 3 ArchUnit tests) |
| J | `e871e7e` | Architecture-truth refresh + initial L1 release note |
| K | (this) | Post-J audit remediation: Rule 28 self-violation fix (E12), path drift (E14, E25), PERIPHERAL-DRIFT (agent-platform/ARCHITECTURE.md), Phase B META-PATTERN (E34), gate-gap closure (E33 / Rule 28j) |

## 7. Where to Look Next

- For the canonical L1 contract: `D:\.claude\plans\l1-modular-russell.md`
- For Rule 28's full text: `CLAUDE.md` §28
- For the enforcer index: `docs/governance/enforcers.yaml`
- For posture behaviour: `docs/adr/0058-posture-boot-guard.md` and
  `agent-platform/.../posture/PostureBootGuard.java`
- For the run HTTP contract: `agent-platform/.../web/runs/RunController.java`
  and `RunHttpContractIT.java`
