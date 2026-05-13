# Post-Seventh Second-Pass Response L0 Readiness Third-Pass Review

**Reviewer:** Java microservices and agent-architecture reviewer
**Date:** 2026-05-13
**Review input:** `docs/reviews/2026-05-13-post-seventh-l0-readiness-second-pass-response.en.md`
**Review standard:** L0 architecture-text truth, strict agreement between active contracts, gate implementation, and Java source.

---

## 1. Executive Verdict

Do **not** publish a clean L0 release note yet.

The second-pass response fixed most of the previously reported contract drift. The core L0 architecture is now close: the Java microservice boundary is coherent, the W0 runtime kernel is intentionally small, and the agent-driven areas (planning, skill lifecycle, memory/knowledge, channel isolation) are mostly staged correctly as W2/W4 design contracts instead of premature W0 implementation.

The remaining issues are narrower but still release-blocking under Rule 25 and the project's own L0 truth standard:

- one active L2 document is stale but excluded from the new active-doc gates;
- graph-memory scaffold truth is still inconsistent in the root README and JavaDoc;
- Gate Rule 19 does not enforce the full contract that ARCHITECTURE.md and ADR-0042 claim.
- the current PowerShell architecture gate fails Rule 22 because the check is case-insensitive.

These are not reasons to redesign L0. They are final contract-truth repairs before a clean release note.

---

## 2. P1 Blocking Findings

### P1.1 `W0-evidence-skeleton.md` is both referenced as active L2 evidence and excluded as historical

**Observed failure:** `docs/governance/architecture-status.yaml` still lists `docs/plans/W0-evidence-skeleton.md` as an L2 document for the shipped `architecture_sync_gate` capability, but ADR-0043 and Gate Rules 18/23 exclude all `docs/plans/**` content from active normative scans. The file itself contains obsolete W0 requirements that do not match the current codebase.

**Execution path:** Reviewers follow the shipped `architecture_sync_gate` row in `architecture-status.yaml` to its L2 evidence document. That document still requires old `/health` and `/ready` routes, stub run controllers, JPA entities, a decision-sync matrix, and an `operator_gated` status model. The current architecture has moved to `/v1/health`, no W0 `RunsController`, no JPA `RunRecord`, and a different status enum.

**Root cause statement:** `W0-evidence-skeleton.md` remains attached to a shipped capability as active evidence while ADR-0043 classifies `docs/plans/**` as excluded historical material, allowing stale W0 requirements to survive outside the new drift gates.

**Evidence:**

- `docs/governance/architecture-status.yaml:57-63` - `architecture_sync_gate` is shipped and lists `docs/plans/W0-evidence-skeleton.md` as an L2 document.
- `docs/adr/0043-active-normative-doc-catalog-and-peripheral-drift-prevention.md:75` - `docs/plans/**` is listed under `HISTORICAL_EXCLUSIONS` while also saying `W0-evidence-skeleton.md` is active.
- `gate/check_architecture_sync.ps1:591` and `gate/check_architecture_sync.ps1:701` - Rules 18 and 23 exclude `/docs/plans/`.
- `docs/plans/W0-evidence-skeleton.md:12` - requires `/health`, `/ready`, and stub run routes.
- `docs/plans/W0-evidence-skeleton.md:15` and `docs/plans/W0-evidence-skeleton.md:48-49` - require `RunRecord`, `RunStore`, and JPA/Postgres artifacts that do not exist in W0.
- `docs/plans/W0-evidence-skeleton.md:65-66` - references `decision-sync-matrix.md` and `operator_gated`, neither matching current governance.

**Required fix:**

1. Choose one status for `W0-evidence-skeleton.md`.
   - If historical: move it to `docs/archive/...` or remove it from `architecture_sync_gate.l2_documents`.
   - If active: update it to current W0 truth and include it in ACTIVE_NORMATIVE_DOCS scans.
2. Add a gate assertion that every `l2_documents:` path on a `shipped: true` row is either active and scanned, or explicitly marked archived/historical.

---

### P1.2 Graph-memory scaffold truth still drifts in root README and JavaDoc

**Observed failure:** The graph-memory starter POM and module README now correctly say "W0 scaffold; no repository bean; Graphiti REST is W1", but the root README and `GraphMemoryRepository` JavaDoc still read like a Graphiti REST sidecar is the current adapter implementation.

**Execution path:** A user entering through the root README sees `spring-ai-ascend-graphmemory-starter` described as "Sidecar adapter - Graphiti REST". A Java implementer reading the SPI sees "Primary sidecar impl: spring-ai-ascend-graphmemory-starter (Graphiti REST)." Both entry points conflict with the actual starter, which registers no bean, and with the status ledger, which says W1 will wire the real Graphiti REST client.

**Root cause statement:** The graphmemory fix updated the module-local metadata but did not repair all active entry points that describe the starter's W0 behavior.

**Evidence:**

- `README.md:16` - describes `spring-ai-ascend-graphmemory-starter` as "Sidecar adapter - Graphiti REST".
- `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java:9` - JavaDoc says the primary sidecar implementation is the starter "Graphiti REST".
- `spring-ai-ascend-graphmemory-starter/README.md:18-19` - correctly says no Graphiti adapter class ships at W0.
- `spring-ai-ascend-graphmemory-starter/pom.xml:19-21` - correctly says the module is a scaffold and Graphiti REST integration is W1.
- `docs/governance/architecture-status.yaml:95` - correctly says W1 wires the real Graphiti REST client.

**Required fix:**

1. Change `README.md:16` to "Graph memory SPI scaffold; no W0 implementation; Graphiti REST reference lands W1."
2. Change `GraphMemoryRepository` JavaDoc to "W1 reference sidecar: Graphiti REST via the starter; no adapter implementation ships at W0."
3. Extend Gate Rule 20 or Rule 21 to catch "Graphiti REST" W0 overclaims in active README and JavaDoc, not only missing Java class names.

---

### P1.3 Gate Rule 19 implementation is weaker than the Rule 25 / ADR-0042 contract

**Observed failure:** ARCHITECTURE.md and ADR-0042 claim Gate Rule 19 fails shipped rows with `tests: []` or absent tests and that evidence points to real test paths. The PowerShell and shell gate implementations only detect the literal inline pattern `tests: []`.

**Execution path:** A future shipped row can omit `tests:` entirely, declare `tests:` with no list items, or point to a missing file. That would violate Rule 25 and ARCHITECTURE.md #39 but pass current Gate Rule 19.

**Root cause statement:** Gate Rule 19 was implemented as a narrow regex for `tests: []`, while the architectural contract requires semantic validation of non-empty, existing test evidence.

**Evidence:**

- `ARCHITECTURE.md:452-455` - says every shipped row must have non-empty tests pointing to a real test class or script, and Gate Rule 19 fails `tests: []` or absent `tests:`.
- `docs/adr/0042-test-evidence-enforcement-for-rule-25.md:35-36` - says Gate Rule 19 fails empty `tests:` (`[]` or absent).
- `docs/adr/0042-test-evidence-enforcement-for-rule-25.md:63-65` - says the evidence is a non-empty list of real test paths.
- `gate/check_architecture_sync.ps1:617-619` - fails only when a shipped block contains `tests: []`.
- `gate/check_architecture_sync.sh:531-532` - same narrow check.

**Required fix:**

1. Parse each shipped capability block.
2. Fail if `tests:` is missing, inline empty, block-empty, or contains only whitespace.
3. Fail if any listed test path does not exist on disk.
4. Add self-test coverage for each negative case in `gate/test_architecture_sync_gate.sh`.

---

### P1.4 Gate Rule 22 is implemented as a false-positive on Windows PowerShell

**Observed failure:** Fresh verification of `gate/check_architecture_sync.ps1` fails Rule 22 against `docs/contracts/http-api-contracts.md`, even though the file contains the corrected lowercase metric name `springai_ascend_filter_errors_total`.

**Execution path:** Rule 22 uses PowerShell `-match 'SPRINGAI_ASCEND_[a-z]'`. PowerShell regex matching is case-insensitive by default, so the uppercase pattern matches the lowercase compliant metric. The gate therefore fails a document that is already correct under ADR-0043.

**Root cause statement:** The PowerShell implementation of Rule 22 uses case-insensitive matching where the rule requires a case-sensitive uppercase-namespace detector.

**Evidence:**

- `docs/contracts/http-api-contracts.md:39` - metric is lowercase: `springai_ascend_filter_errors_total`.
- `docs/contracts/contract-catalog.md:83` - canonical telemetry contract is lowercase.
- `gate/check_architecture_sync.ps1:682-684` - uses `$content22 -match 'SPRINGAI_ASCEND_[a-z]'`, which is case-insensitive in PowerShell.
- Fresh command result: `powershell -ExecutionPolicy Bypass -File gate/check_architecture_sync.ps1` exits 1 with `FAIL: lowercase_metrics_in_contract_docs`.

**Required fix:**

1. Change the PowerShell check to a case-sensitive regex, for example `-cmatch 'SPRINGAI_ASCEND_[a-z]'`.
2. Add positive and negative self-tests for lowercase metric names and truly uppercase contract metric names.
3. Re-run both PowerShell and POSIX gate variants.

---

## 3. P2 Consistency Findings

### P2.1 Active refresh metadata still points at older review cycles

**Evidence:**

- `docs/governance/architecture-status.yaml:1` - header still says "post-seventh follow-up pass" although second-pass changes were added.
- `docs/contracts/contract-catalog.md:4` - last refreshed text still says "sixth + seventh reviewer response" although ADR-0044 edits are present.
- `docs/cross-cutting/oss-bill-of-materials.md:4` - last refreshed text still says "sixth + seventh reviewer response" although ADR-0043 edits are present.
- `docs/contracts/http-api-contracts.md:4` - still says last refreshed `2026-05-10` despite post-seventh HTTP contract edits.

**Required fix:** Refresh metadata to reflect the actual latest architecture pass, or remove the stale "last refreshed by cycle" labels from active docs.

---

### P2.2 ACTIVE_NORMATIVE_DOCS is broader than the implemented gate scans

**Evidence:**

- `docs/adr/0043-active-normative-doc-catalog-and-peripheral-drift-prevention.md:49-61` includes module `pom.xml` descriptions, module READMEs, `docs/governance/**/*.{md,yaml}`, `third_party/MANIFEST.md`, and other active documents.
- `gate/check_architecture_sync.ps1:586-592` scans only `*.md` and `*.yaml` for Rule 18, so module `pom.xml` descriptions are outside that rule.
- `gate/check_architecture_sync.ps1:626-646` Rule 20 only checks two hard-coded graphmemory ghost class names in module READMEs.
- `gate/check_architecture_sync.ps1:691-721` Rule 23 checks Markdown links only in `*.md`, not YAML or POM metadata.

**Required fix:** Either narrow ADR-0043's claim to the exact implemented gate scope or implement a shared active-corpus enumerator used by Rules 18, 20, 21, 22, and 23.

---

## 4. Agent-Driven Architecture Assessment

No new L0 blocker was found in the agent-driven design areas themselves.

- **Dynamic planning:** `PlanState` and `RunPlanRef` remain design-only and are explicitly deferred. That is appropriate for L0.
- **Skills:** The `Skill` lifecycle and `SkillResourceMatrix` are substantial, but ADR-0038 now qualifies enforcement tiers. This avoids W0 over-implementation while preserving a credible W2 contract.
- **Memory and knowledge:** The six-category taxonomy and `embeddingModelVersion` normalization are coherent. GraphMemory remains intentionally minimal at W0.
- **Channel isolation:** Control/Data/Heartbeat separation and `RunDispatcher` are deferred W2 contracts. No current W0 code pretends to implement them.

The architecture is not materially over-designed for L0 as long as these items remain design-only and are not marketed as shipped runtime behavior.

---

## 5. Acceptance Criteria for Clean L0 Release Note

Before publishing a clean L0 release note:

1. Remove or update `docs/plans/W0-evidence-skeleton.md` as active shipped evidence, and make the gate treatment match its chosen status.
2. Align root README and `GraphMemoryRepository` JavaDoc with the W0 graphmemory scaffold truth.
3. Strengthen Gate Rule 19 to enforce absent, empty, and non-existent test evidence.
4. Fix Rule 22's PowerShell case sensitivity so lowercase compliant metrics pass.
5. Refresh active document metadata after the final pass.
6. Re-run the architecture sync gate and Maven tests.

Once those are done, the correct release note can be clean and positive: L0 is architecturally ready, with W0 runtime kept intentionally small and W2/W4 agent capabilities staged without false implementation claims.
