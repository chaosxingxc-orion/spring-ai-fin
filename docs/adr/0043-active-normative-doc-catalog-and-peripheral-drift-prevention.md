# ADR-0043: Active Normative Doc Catalog and Peripheral Drift Prevention

> Status: accepted | Date: 2026-05-13 | Deciders: architecture team

## Context

The second-pass review of the post-seventh L0 response identified a **meta-pattern** that recurs
across every review cycle:

> *Central documents get cleaned, but peripheral documents are left with an entry pointing to a
> non-existent or deprecated contract.*

In the second-pass review, this manifested in eight separate findings:

| Peripheral entry-point | Stale reference |
|---|---|
| `docs/contracts/http-api-contracts.md:34` | `PolicyEvaluator returned DENY` (deleted SPI) |
| `agent-platform/README.md:11` | `IdempotencyRepository`, `PolicyEvaluator` (deleted SPIs) |
| `spring-ai-ascend-graphmemory-starter/pom.xml` | "wires Graphiti by default" (no impl exists at W0) |
| `spring-ai-ascend-graphmemory-starter/README.md` | `GraphitiRestGraphMemoryRepository` (class doesn't exist) |
| `docs/cross-cutting/oss-bill-of-materials.md:41,56,71` | 8 non-existent "Glue we own" paths |
| `docs/cross-cutting/oss-bill-of-materials.md:214` | `OssApiProbe` listed under "Active SPI surface" |
| `docs/contracts/contract-catalog.md:71` + `http-api-contracts.md:39` | Uppercase `SPRINGAI_ASCEND_` metrics |
| `contract-catalog.md:98`, `http-api-contracts.md:141`, `agent-platform/README.md:58,60` | Broken internal links |

**Root cause:** No central definition of *"active normative documents"* exists. Each gate rule
rolls its own scan-scope list, which guarantees drift between rule implementations. Gate Rule 18,
for example, scanned only 3 files while two violations lived in files it did not cover.

## Decision Drivers

- Pattern prevention beats reactive patching: every cycle should not repeat the same meta-failure.
- Gate rules should share a single, authoritative definition of "active normative docs".
- Historical documents (ADRs, delivery logs, v6-rationale, archives, reviews) are intentionally
  frozen and must not be required to stay clean of historical references.

## Considered Options

1. **Fix each peripheral entry-point case-by-case** — addresses symptoms but leaves the root
   cause open; the same pattern recurs in the next cycle.
2. **Define a canonical ACTIVE_NORMATIVE_DOCS set and install drift-detection gates** — closes
   the root cause; new gate rules enforce corpus-wide consistency.

## Decision

**Option 2.** Define two canonical sets. Reconcile all peripheral entry-points that violated
them. Install five gate rules (widen Rule 18, add Rules 20–23) to prevent recurrence.

### ACTIVE_NORMATIVE_DOCS (canonical set)

Files whose claims are actively binding on implementers and reviewers:

- `ARCHITECTURE.md`, `README.md`, `CLAUDE.md`, `AGENTS.md`
- `agent-platform/ARCHITECTURE.md`, `agent-platform/README.md`
- `agent-runtime/ARCHITECTURE.md`
- `docs/contracts/**/*.{md,yaml}`
- `docs/cross-cutting/**/*.md`
- `docs/telemetry/**/*.md` (renamed from `docs/observability/` per ADR-0061 §2)
- `docs/governance/**/*.{md,yaml}`
- `third_party/MANIFEST.md`
- All module `pom.xml` descriptions and module-level `README.md` files

### HISTORICAL_EXCLUSIONS (frozen corpus)

These directories contain intentionally frozen historical documents. Their content accurately
reflects decisions made at the time; they are excluded from drift-detection scans:

| Directory | Reason |
|---|---|
| `docs/archive/**` | Archived planning docs; ARCHIVED banner present |
| `docs/reviews/**` | Reviewer feedback and response documents |
| `docs/adr/**` | Immutable decision records; may reference past text and rejected options |
| `docs/delivery/**` | Delivery-log snapshots frozen at commit time |
| `docs/v6-rationale/**` | Pre-refresh design rationale; ARCHIVED banner present |
| `docs/plans/**` | Planning documents — entirely historical; archived alongside peers under `docs/archive/` |
| `third_party/<name>/**` | Cloned OSS repos; not maintained by this project |
| `target/**` | Maven build output |
| `.git/**` | Repository metadata |

This list supersedes the partial exclusion text in ADR-0041 §3. The implementation exclusions
in `gate/check_architecture_sync.ps1` and `gate/check_architecture_sync.sh` Rules 15 and 18
match this list.

## Gate Rules Added / Modified

### Widen Gate Rule 18 (`deleted_spi_starter_names_outside_catalog`)

Previously scanned 3 files only. Now scans the full ACTIVE_NORMATIVE_DOCS corpus (same exclusion
list as Gate Rule 15): any `.md` file not under a HISTORICAL_EXCLUSION directory.

### Gate Rule 20 — `module_metadata_truth`

Module `README.md` files must not reference Java class names that do not exist in the repository.
Specifically: `spring-ai-ascend-graphmemory-starter/README.md` must not reference
`GraphitiRestGraphMemoryRepository` unless a corresponding `.java` file exists.

### Gate Rule 21 — `bom_glue_paths_exist`

`docs/cross-cutting/oss-bill-of-materials.md` must not contain the 8 known ghost implementation
paths (`agent-runtime/llm/ChatClientFactory`, etc.) unless the path exists on disk.

### Gate Rule 22 — `lowercase_metrics_in_contract_docs`

`docs/contracts/*.md` must not contain `SPRINGAI_ASCEND_<lowercase>` metric name patterns.
(Env-var names such as `SPRINGAI_ASCEND_GRAPHITI_BASE_URL` with all-uppercase suffixes remain
acceptable per POSIX convention.)

### Gate Rule 23 — `active_doc_internal_links_resolve`

Markdown links `](relative-path)` in a defined set of active normative docs must resolve to files
that exist on disk. Anchors (`#...`) and external links (`http://`, `https://`) are excluded.

## Document Changes (this cycle)

| Peripheral entry-point | Change |
|---|---|
| `docs/contracts/http-api-contracts.md:34` | PolicyEvaluator → Spring Security AuthorizationManager |
| `docs/contracts/http-api-contracts.md:39` | SPRINGAI_ASCEND_filter_errors_total → lowercase |
| `docs/contracts/http-api-contracts.md:141` | broken link → agent-platform/ARCHITECTURE.md |
| `agent-platform/README.md:11` | deleted SPI names → actual W0 filter chain description |
| `agent-platform/README.md:58,60` | broken links → existing doc paths |
| `spring-ai-ascend-graphmemory-starter/pom.xml` | description → W0 scaffold truth |
| `spring-ai-ascend-graphmemory-starter/README.md` | GraphitiRestGraphMemoryRepository + Cognee → W0 scaffold |
| `docs/cross-cutting/oss-bill-of-materials.md:41,56,71` | "Glue we own" paths → "Planned glue (W2)" |
| `docs/cross-cutting/oss-bill-of-materials.md:208-214` | OssApiProbe out of "Active SPI surface" → "Active probes" |
| `docs/contracts/contract-catalog.md:71` | Uppercase metrics → lowercase |
| `docs/contracts/contract-catalog.md:98` | Broken "See also" paths → repaired links |

## §4 Constraint

**§4 #40:** The ACTIVE_NORMATIVE_DOCS corpus is the canonical domain for contract-truth
claims. Every peripheral entry-point in that corpus must agree with the central truth established
by the architecture, ADR, and Java source layers. Gate Rules 18 (widened), 20, 21, 22, and 23
enforce this at commit time. See ADR-0043.

## References

- `docs/governance/architecture-status.yaml`
- `gate/check_architecture_sync.ps1` (Rules 18–23)
- `gate/check_architecture_sync.sh` (mirror)
- ADR-0041 §3 (superseded partial exclusion list)
- Second-pass review: `docs/reviews/2026-05-13-post-seventh-l0-readiness-second-pass.en.md`
