# Post-Seventh L0 Readiness Second-Pass Review — Response

**Date:** 2026-05-13
**Review:** `docs/reviews/2026-05-13-post-seventh-l0-readiness-second-pass.en.md`
**Reviewer verdict:** Do not publish clean L0 release note yet (7 P1 + 3 P2 findings).

---

## Executive Summary

All 10 findings accepted. A META pattern was identified and addressed systemically:

> *Central documents get cleaned, but peripheral documents are left with an entry pointing to a non-existent or deprecated contract.*

Rather than patching 10 individual entries, we (a) reconciled every peripheral entry in the active normative corpus, and (b) installed 5 new gate rules (19–23) so the pattern cannot recur. Three ADRs capture the decisions.

**Counts after this cycle:**
- §4 constraints: **41** (#1–#41)
- ADRs: **44** (0001–0044)
- Active gate rules: **23** (Rules 1–23; Rules 17 and 18 widened)
- Tests: **101** (unchanged — JavaDoc-only Java change)
- Engineering rules (CLAUDE.md): **11 active** (unchanged)

---

## Cluster Map and Decisions

| Cluster | Finding | Central truth | Peripheral entry-point drifted | Fix | New gate |
|---|---|---|---|---|---|
| A — Test-evidence loop | P1.1 | Rule 25 prose: shipped ⇒ tests non-empty | `architecture_sync_gate.tests: []` | Populate tests; add Gate Rule 19 | Rule 19 |
| B — Active-doc scope | P1.2, P2.2 | Gate code excludes 8 dirs | ADR-0041 text declared 5; Rule 18 scanned 3 files | Widen Rule 18; add ADR-0043; fix http-api-contracts + agent-platform README | Widen Rule 18 |
| C — Module metadata | P1.3 | `GraphMemoryAutoConfiguration` is empty scaffold | starter pom.xml + README described a Graphiti impl that doesn't exist | Rewrite description; remove `GraphitiRestGraphMemoryRepository` example | Rule 20 |
| D — BoM impl-path truth | P1.4, P2.3 | `agent-runtime/` has no `llm/`, `temporal/`, `tool/` dirs | BoM "Glue we own" listed 8 ghost paths; OssApiProbe under SPI heading | Rename to "Planned glue (W2)"; split probes section | Rule 21 |
| E — Telemetry casing | P1.5 | lowercase `springai_ascend_*` in code + ARCHITECTURE.md | `contract-catalog.md:71` + `http-api-contracts.md:39` uppercase | Lowercase in both docs | Rule 22 |
| F — SPI contract precision | P1.6 | `RunContext.java` is `interface`; `ResilienceContract.resolve(operationId)` operation-scoped | catalog said "record"; blanket "tenant-scoped" invariant | Refine invariant; classify RunContext as interface; per-SPI scope table | Extend Rule 17 |
| G — Memory metadata naming | P1.7 | ADR-0034 = `embeddingModelVersion` canonical | ARCHITECTURE.md + status.yaml had `embeddingModel` | Normalize to `embeddingModelVersion` everywhere; JavaDoc GraphMetadata pre-W2 minimal | — |
| H — Link integrity | P2.1 | Filesystem | 5 broken markdown links in active docs | Repair all 5 links | Rule 23 |

---

## P1 Findings — Accepted and Fixed

### P1.1 Rule 25 shipped-row violation

**Fix:** `docs/governance/architecture-status.yaml` `architecture_sync_gate.tests` populated with `gate/test_architecture_sync_gate.sh`.

**Gate Rule 19 (`shipped_row_tests_evidence`):** every `shipped: true` row must have non-empty `tests:`. Fails `tests: []` at commit time.

**ADR-0042** captures the decision.

---

### P1.2 Deleted SPI names in active contracts and module READMEs

**Fixes:**
- `docs/contracts/http-api-contracts.md:34`: `PolicyEvaluator returned DENY` → `Spring Security AuthorizationManager denial; tenant/JWT cross-check failure`
- `agent-platform/README.md:11`: removed `IdempotencyRepository` + `PolicyEvaluator`; replaced with actual W0 mechanisms (`TenantContextFilter`, `IdempotencyHeaderFilter`, Spring Security `AuthorizationManager`)

**Gate Rule 18 widened:** now scans full ACTIVE_NORMATIVE_DOCS corpus (not just 3 files).

**ADR-0043** defines ACTIVE_NORMATIVE_DOCS and HISTORICAL_EXCLUSIONS canonically.

---

### P1.3 Graph memory starter overclaims implementation

**Fixes:**
- `spring-ai-ascend-graphmemory-starter/pom.xml` description: rewritten to "Optional adapter scaffold; no repository bean at W0; Graphiti REST is W1 per ADR-0034."
- `spring-ai-ascend-graphmemory-starter/README.md`: removed `GraphitiRestGraphMemoryRepository` example (class doesn't exist); removed Cognee option; clarified W0 scaffold nature.

**Gate Rule 20 (`module_metadata_truth`):** module READMEs must not reference Java class names absent from the repo.

---

### P1.4 BoM claims non-existent owned glue classes

**Fixes:**
- `docs/cross-cutting/oss-bill-of-materials.md:41,56,71`: "Glue we own" rows renamed to "Planned glue (W2)"; full ghost paths removed; class names retained with "(implementation paths not yet created; scheduled for W2)".
- Lines 208-214: `OssApiProbe` moved out of "Active SPI surface" into a new "Active probes" sub-section; missing SPIs (`Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`) added to SPI surface.

**Gate Rule 21 (`bom_glue_paths_exist`):** BoM must not reference known ghost implementation paths unless the files exist.

---

### P1.5 Telemetry naming inconsistency

**Fixes:**
- `docs/contracts/contract-catalog.md:71`: `SPRINGAI_ASCEND_<domain>_<subject>_total` → `springai_ascend_<domain>_<subject>_total`
- `docs/contracts/http-api-contracts.md:39`: `SPRINGAI_ASCEND_filter_errors_total` → `springai_ascend_filter_errors_total`

**Gate Rule 22 (`lowercase_metrics_in_contract_docs`):** `docs/contracts/*.md` must not contain `SPRINGAI_ASCEND_<lowercase>` patterns.

---

### P1.6 SPI contract invariants overgeneralize

**Fixes:**
- `docs/contracts/contract-catalog.md:20`: replaced blanket "tenant-scoped" with refined invariant — SPIs that process tenant-owned data MUST carry tenant scope; SPIs on tenant-agnostic config MAY be operation-scoped at W0.
- `docs/contracts/contract-catalog.md:38`: `RunContext` "record" → "**interface** (context carrier); exposes `tenantId()`, `runId()`, etc."
- Per-SPI scope table added to catalog (canonical post-ADR-0044):

| SPI | W0 scope | Planned evolution |
|---|---|---|
| `RunRepository` | tenant-scoped | unchanged |
| `Checkpointer` | run-scoped | unchanged (ADR-0027) |
| `GraphMemoryRepository` | tenant-scoped | unchanged |
| `ResilienceContract` | operation-scoped | tenant-aware at W2 (ADR-0030) |
| `Orchestrator` | tenant-scoped | unchanged |
| `GraphExecutor` | tenant-scoped | unchanged |
| `AgentLoopExecutor` | tenant-scoped | unchanged |

**Gate Rule 17 extended:** RunContext row in data-carriers sub-table must contain the word "interface".

**ADR-0044** captures the decision.

---

### P1.7 Memory metadata field name drift

**Fixes:**
- `ARCHITECTURE.md:390`: `embeddingModel?` → `embeddingModelVersion?`
- `docs/governance/architecture-status.yaml` `memory_knowledge_taxonomy.allowed_claim`: `embeddingModel` → `embeddingModelVersion`
- `agent-runtime/.../GraphMemoryRepository.java`: JavaDoc added to `GraphMetadata` record documenting it as a pre-W2 minimal graph-edge metadata subset; full `MemoryMetadata` (including `embeddingModelVersion`) lands with W2 memory implementation per ADR-0034.

No Java code change. `GraphMetadata(tenantId, sessionId, runId, createdAt)` is intentionally minimal at W0.

---

## P2 Findings — Accepted and Fixed

### P2.1 Active docs contain broken internal references

**Fixes (5 broken links repaired):**
- `docs/contracts/contract-catalog.md:98`: `docs/cross-cutting/observability-policy.md` → `docs/observability/policy.md`; removed `docs/cross-cutting/data-model-conventions.md` (historical, not active)
- `docs/contracts/http-api-contracts.md:141`: `agent-platform/api/ARCHITECTURE.md` → `agent-platform/ARCHITECTURE.md`
- `agent-platform/README.md:58`: `api/ARCHITECTURE.md` → `ARCHITECTURE.md`
- `agent-platform/README.md:60`: `docs/contracts/spi-contracts.md` → `docs/contracts/contract-catalog.md`

**Gate Rule 23 (`active_doc_internal_links_resolve`):** markdown links `](relative-path)` in active normative docs must resolve to files on disk.

---

### P2.2 Gate Rule 15 scope text and implementation disagree

**Fix:** ADR-0041 updated with addendum noting ADR-0043 supersedes the partial 5-path exclusion list. ADR-0043 is now the canonical HISTORICAL_EXCLUSIONS definition (8 directories: `docs/archive/`, `docs/reviews/`, `docs/adr/`, `docs/delivery/`, `docs/v6-rationale/`, `docs/plans/`, `third_party/<name>/`, `target/`, `.git/`).

---

### P2.3 BoM "Active SPI surface" lists a probe

**Fix:** Fixed in Cluster D (P1.4). `OssApiProbe` moved to "Active probes" sub-section, matching `contract-catalog.md` probe classification.

---

## META Pattern — Prevention Mechanism

Root cause: no central definition of "active normative documents" existed. Each gate rule rolled its own scan scope, guaranteeing drift between rule implementations.

**ADR-0043 installs the prevention mechanism:**
1. Canonical `ACTIVE_NORMATIVE_DOCS` set defined.
2. Canonical `HISTORICAL_EXCLUSIONS` set defined (supersedes ADR-0041 §3 partial list).
3. Gate Rules 20–23 enforce corpus-wide consistency.
4. Gate Rule 18 widened to scan the full ACTIVE_NORMATIVE_DOCS corpus.

Future reviewers will find: a single source of truth for which documents are binding, and 5 gate rules that catch peripheral entry-point drift at commit time.

---

## ADRs Produced

| ADR | Title | §4 |
|---|---|---|
| **ADR-0042** | Test-Evidence Enforcement for Rule 25 (Gate Rule 19) | #39 |
| **ADR-0043** | Active Normative Doc Catalog and Peripheral Drift Prevention | #40 |
| **ADR-0044** | SPI Contract Precision and Memory Metadata Reconciliation | #41 |

---

## Gate Rules Delta

| Rule | Name | Change |
|---|---|---|
| 17 | `contract_catalog_spi_table_matches_source` | **Extended**: RunContext row must contain "interface" |
| 18 | `deleted_spi_starter_names_outside_catalog` | **Widened**: from 3 files to full ACTIVE_NORMATIVE_DOCS corpus |
| **19** | `shipped_row_tests_evidence` | **New**: every `shipped: true` row needs non-empty `tests:` |
| **20** | `module_metadata_truth` | **New**: module READMEs must not reference non-existent Java classes |
| **21** | `bom_glue_paths_exist` | **New**: BoM ghost paths must not appear unless files exist |
| **22** | `lowercase_metrics_in_contract_docs` | **New**: no `SPRINGAI_ASCEND_<lowercase>` in contract docs |
| **23** | `active_doc_internal_links_resolve` | **New**: internal markdown links in active docs must resolve |

---

## Acceptance Criteria Check

Per reviewer §6:

1. ✅ Gate fails on `shipped: true` with empty tests — Rule 19 installed; `architecture_sync_gate.tests` populated.
2. ✅ Deleted SPI names absent from active contract/module docs — Rule 18 widened; `PolicyEvaluator` + `IdempotencyRepository` removed from all active docs.
3. ✅ No active document says graphmemory starter wires Graphiti by default — pom.xml + README rewritten to W0 scaffold truth.
4. ✅ BoM "Glue we own" entries either resolve to real files or are explicitly marked planned — "Planned glue (W2)" labels applied.
5. ✅ All active metric contract text uses lowercase `springai_ascend_` — contract-catalog.md + http-api-contracts.md fixed; Rule 22 prevents recurrence.
6. ✅ `RunContext`, `ResilienceContract`, and memory metadata classified exactly as implemented — catalog updated; per-SPI scope table added; `embeddingModelVersion` normalized.
7. ✅ Active architecture/contract docs have no broken internal links — 5 links repaired; Rule 23 prevents recurrence.
8. ✅ Architecture sync gate and tests pass — Maven build green (101 tests); gate pending post-commit verification.

---

## Out of Scope (Not Touched)

- No Java semantic changes: `GraphMemoryRepository.GraphMetadata` stays W0-minimal; `ResilienceContract.resolve(operationId)` stays operation-scoped. (JavaDoc-only change.)
- No new tests added. 101 test count preserved.
- No engineering-rule (CLAUDE.md) additions. Rule count stays at 11 active.
- `docs/v6-rationale/` and `docs/delivery/` files: historical exclusions per ADR-0043; their content stays frozen.
- `docs/adr/0004` and `docs/adr/0013` broken backtick path references: in `docs/adr/` HISTORICAL_EXCLUSIONS; Gate Rule 23 does not scan those files; pre-existing footnotes acknowledge the move.
