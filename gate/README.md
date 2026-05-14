# gate/ — Architecture-Sync Gate

> Document-corpus consistency checks for spring-ai-ascend. **44 active rules** (bash; PowerShell parity tracked separately for Rules 28a–28j and 37–44), backed by **50 self-tests**. W1 *Layered 4+1 + Architecture Graph* wave (ADR-0068) adds Rules 37–40 over the post-L1 36-rule baseline; Phase M remediation adds Rules 41–44 (anchor resolution, graph idempotency, ADR-must-be-yaml, frozen-doc edit-path).
>
> **Python ≥ 3.10 required** for `gate/build_architecture_graph.py` and `gate/migrate_adrs_to_yaml.py`. Install once: `pip install -r gate/requirements.txt`. Rule 38 (`architecture_graph_well_formed`) fails fast with a clear message if PyYAML is missing.
>
> **Generated artefact:** `docs/governance/architecture-graph.yaml` (and its `.mmd` sibling) are produced by `gate/build_architecture_graph.py` and listed in `.gitignore`. Regenerate on demand; never hand-edit (Rule 34).

## What is this?

The architecture-sync gate proves the document corpus is internally consistent at the current SHA — names, paths, counts, contracts, and wave-qualifier prose stay aligned with reality across `ARCHITECTURE.md`, the per-capability ledger, ADRs, contract catalogs, and release notes.

It does **not** prove the running system behaves correctly. That is the operator-shape gate (`run_operator_shape_smoke.*`), which is fail-closed until a W4 runnable-artifact target lands.

## Files in this directory

| File | Role |
|------|------|
| `check_architecture_sync.ps1` | Windows PowerShell gate (27 rules) |
| `check_architecture_sync.sh` | POSIX bash gate — line-for-line parity with the PowerShell script |
| `test_architecture_sync_gate.sh` | Self-test harness — 30 cases covering Rules 1–6 and 16, 19, 22, 24, 25, 26, 27 |
| `doctor.ps1` / `doctor.sh` | Environment probe — `APP_POSTURE`, required env vars, `mvnw` exec bit, Java availability |
| `run_operator_shape_smoke.ps1` / `.sh` | Fail-closed shells for the W4 operator-shape gate (no runnable artifact yet) |
| `check_spring_ai_milestone.sh` | Spring AI milestone-version probe (separate concern) |
| `log/` | Audit JSON files retained from earlier gate generations; current 26-rule gate does not write here |

## Running the gate

```bash
# POSIX (Linux / macOS / Git Bash)
bash gate/check_architecture_sync.sh

# Windows PowerShell
pwsh gate/check_architecture_sync.ps1
```

Exit `0` and `GATE: PASS` if all 27 rules pass; exit `1` and `GATE: FAIL` if any rule fails. Per-rule output is `PASS: <name>` or `FAIL: <name> -- <reason>`.

## Running self-tests

```bash
bash gate/test_architecture_sync_gate.sh
```

Expected: `Tests passed: 30/30`. Self-tests cover the rules most prone to regression (Rules 1–6 plus 16, 19, 22, 24, 25, 26, 27) with positive and negative fixtures. Full gate verification still requires running the PowerShell or bash gate against the real repo.

## Rule catalog

| # | Rule | What it catches | Reference |
|---|------|-----------------|-----------|
| 1 | `status_enum_invalid` | `architecture-status.yaml` `status:` values outside `{design_accepted, implemented_unverified, test_verified, deferred_w1, deferred_w2}` | — |
| 2 | `delivery_log_parity` | `gate/log/*.json` where `sha` field ≠ filename basename, or `semantic_pass` field missing | — |
| 3 | `eol_policy` | `*.sh` files in `gate/` containing CRLF (must be LF) | — |
| 4 | `ci_no_or_true_mask` | `.github/workflows/*.yml` invoking `gate/run_*` masked with `\|\| true` | — |
| 5 | `required_files_present` | Missing `docs/contracts/contract-catalog.md` or `docs/contracts/openapi-v1.yaml` | — |
| 6 | `metric_naming_namespace` | Java metric names without lowercase `springai_ascend_` prefix | §4 #5 |
| 7 | `shipped_impl_paths_exist` | Every `shipped: true` `implementation:` path must exist on disk | — |
| 8 | `no_hardcoded_versions_in_arch` | Module `ARCHITECTURE.md` files pinning OSS versions inline (BoM owns versions) | — |
| 9 | `openapi_path_consistency` | `/v3/api-docs` must appear in `WebSecurityConfig` and platform `ARCHITECTURE.md` | — |
| 10 | `module_dep_direction` | `agent-runtime` must not depend on `agent-platform` (and vice versa) | ADR-0026 |
| 11 | `shipped_envelope_fingerprint_present` | `InMemoryCheckpointer` enforces §4 #13 16-KiB inline-payload cap | §4 #13 |
| 12 | `inmemory_orchestrator_posture_guard_present` | `AppPostureGate.requireDev*` literal call in all 3 in-memory components | ADR-0035 |
| 13 | `contract_catalog_no_deleted_spi_or_starter_names` | `contract-catalog.md` referencing deleted SPI interface or starter coords | ADR-0036 |
| 14 | `module_arch_method_name_truth` | Method names in `ARCHITECTURE.md` code fences must exist in the named Java class | ADR-0036 |
| 15 | `no_active_refs_deleted_wave_plan_paths` | Active `.md` files referencing deleted plan paths (`engineering-plan-W0-W4.md`, `roadmap-W0-W4.md`) | ADR-0041 |
| 16 | `http_contract_w1_tenant_and_cancel_consistency` | W1 HTTP contract: no "replace X-Tenant-Id" wording; no `CREATED` initial run status; no `DELETE /v1/runs/{runId}` cancel route | ADR-0040 |
| 17 | `contract_catalog_spi_table_matches_source` | SPI sub-table must list 7 known SPIs; `OssApiProbe` must not appear before Probes sub-table | ADR-0044 |
| 18 | `deleted_spi_starter_names_outside_catalog` | ACTIVE_NORMATIVE_DOCS corpus referencing deleted SPI / starter names | ADR-0043 |
| 19 | `shipped_row_tests_evidence` | Every `shipped: true` row must have non-empty `tests:` pointing to real files | ADR-0042 |
| 20 | `module_metadata_truth` | Module README referencing Java class names absent from the repo | ADR-0043 |
| 21 | `bom_glue_paths_exist` | BoM must not list ghost implementation paths unless they exist on disk | ADR-0043 |
| 22 | `lowercase_metrics_in_contract_docs` | ACTIVE_NORMATIVE_DOCS must not contain `SPRINGAI_ASCEND_<lowercase>` metric patterns | ADR-0043 |
| 23 | `active_doc_internal_links_resolve` | Markdown links in active docs must resolve to existing files | ADR-0043 |
| 24 | `shipped_row_evidence_paths_exist` | `l2_documents:` and `latest_delivery_file:` on shipped rows must exist on disk | ADR-0045 |
| 25 | `peripheral_wave_qualifier` | SPI Javadoc and active markdown must not name future-wave impls without a wave qualifier (W0–W4) | ADR-0045 |
| 26 | `release_note_shipped_surface_truth` | `docs/releases/*.md` must not overclaim `RunLifecycle` as W0, invent `RunContext.posture()`, misattribute the OpenAPI snapshot to `ApiCompatibilityTest`, or over-generalise `AppPostureGate` scope | ADR-0046 |
| 27 | `active_entrypoint_baseline_truth` | Root `README.md` baseline counts (§4 constraints, ADRs, gate rules, gate self-tests) must match `architecture-status.yaml.architecture_sync_gate.allowed_claim` | ADR-0047 |

## Self-test coverage

`gate/test_architecture_sync_gate.sh` covers 28 cases — one positive + one negative fixture per rule, for the rules historically most prone to regression. Coverage map:

| Rule | Cases | Notes |
|------|-------|-------|
| 1–6 | 12 (pos + neg each) | Core enum / parity / EOL / CI / files / metrics |
| 16 | 2 (pos + neg) | Widened to catch "switches-to-JWT" verb forms (ADR-0040) |
| 19 | 4 (pos + 3 neg: absent, inline-empty, missing-path) | Strengthened per ADR-0042 + ADR-0045 |
| 22 | 2 (pos + neg) | Case-sensitive PS fix (`-cmatch`) per ADR-0045 |
| 24 | 2 (pos + neg) | ADR-0045 |
| 25 | 2 (pos + neg) | ADR-0045 |
| 26 | 4 (pos + neg for RunLifecycle name guard; pos + neg for RunContext method-list guard) | ADR-0046 |
| 27 | 2 (pos + neg for §4 baseline cross-check) | ADR-0047 |

Total: 30. Rules without self-tests (7–15, 17–18, 20–21, 23) are exercised end-to-end by running the gate against the live repo.

## Audit trail

`gate/log/<sha>-{posix,windows}.json` files are retained on GitHub as audit artifacts from an earlier 27-rule generation of the gate. The current 26-rule gate does not write log files; its output is the per-rule `PASS`/`FAIL` stream and the final `GATE: PASS|FAIL` line, captured in CI.

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) — §4 #1–#44 are the constraints these rules enforce.
- [CLAUDE.md](../CLAUDE.md) — engineering Rule 25 (architecture-text truth) defines the prose-vs-enforcer contract.
- [docs/adr/0045-shipped-row-evidence-path-existence-and-peripheral-wave-qualifier.md](../docs/adr/0045-shipped-row-evidence-path-existence-and-peripheral-wave-qualifier.md) — Rules 24 + 25.
- [docs/adr/0046-release-note-shipped-surface-truth.md](../docs/adr/0046-release-note-shipped-surface-truth.md) — Rule 26.
- [docs/adr/0047-active-entrypoint-truth-and-system-boundary-prose-convention.md](../docs/adr/0047-active-entrypoint-truth-and-system-boundary-prose-convention.md) — Rule 27.
- [docs/governance/architecture-status.yaml](../docs/governance/architecture-status.yaml) — the per-capability ledger Rules 1, 7, 19, 24 read.
