# 0036. Contract-Surface Truth Generalization

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Seventh reviewer (P1.1, P2.4) found the contract catalog listed 10 deleted SPIs
and 8 deleted starter coordinates. Reviewer (P2.4) found status-ledger stale claims and a module-doc
method-name drift. Gate item 9 requested gate coverage for these truth-drift patterns. Cluster 3
self-audit surfaced 12 hidden defects. This ADR generalises Rule 25 (Architecture-Text Truth) with
two new gate rules.

## Context

Rule 25 enforces four specific truth-gate cases (shipped-impl paths, no-hardcoded-versions,
OpenAPI path consistency, module dep direction). It does NOT cover:
- Contract-catalog deleted-name references (7 of 10 listed SPIs were deleted in the Occam pass).
- Module ARCHITECTURE.md method-name drift (`probe.check()` vs actual `probe.probe()`).
- Status-yaml row-to-row contradictions.
- ADR cross-reference staleness.

Each truth-drift fix has been ad-hoc per review cycle. Gate Rules 13 and 14 systematise the two
most common drift patterns.

## Decision Drivers

- Seventh reviewer P1.1: contract-catalog must reflect the current SPI inventory.
- Seventh reviewer P2.4: module-doc method names must exist in the named class.
- Gate item 9: gate must catch these drift patterns at commit time, not review time.
- Hidden defect 3.11: Rule 25 gate covers 4 cases; at least 8 more truth-drift patterns observed.

## Considered Options

1. **Add Gate Rules 13 and 14; rewrite contract-catalog; fix all known drift** — this decision.
2. **LLM-assisted full-repo truth audit on each commit** — too slow; not deterministic.
3. **Manual checklist in PR template** — already tried (Rule 25); insufficient for the deleted-name pattern.

## Decision Outcome

**Chosen option:** Option 1.

### Gate Rule 13 — `contract_catalog_no_deleted_spi_or_starter_names`

`docs/contracts/contract-catalog.md` MUST NOT reference any of the following deleted SPI interface
names or deleted starter coordinates (deleted in the 2026-05-12 Occam pass):

**Deleted SPI names** (interface names in Java source):
`LongTermMemoryRepository`, `ToolProvider`, `LayoutParser`, `DocumentSourceConnector`,
`PolicyEvaluator`, `IdempotencyRepository`, `ArtifactRepository`

**Deleted starter coordinates** (Maven artifact IDs):
`spring-ai-ascend-memory-starter`, `spring-ai-ascend-skills-starter`,
`spring-ai-ascend-knowledge-starter`, `spring-ai-ascend-governance-starter`,
`spring-ai-ascend-persistence-starter`, `spring-ai-ascend-resilience-starter`,
`spring-ai-ascend-mem0-starter`, `spring-ai-ascend-docling-starter`,
`spring-ai-ascend-langchain4j-profile`

Implementation: regex scan of `contract-catalog.md` for any of these strings; FAIL if found.

### Gate Rule 14 — `module_arch_method_name_truth`

For each code-fence block in `agent-platform/ARCHITECTURE.md` and `agent-runtime/ARCHITECTURE.md`
that references a method call in the pattern `<identifier>.<methodName>()`, verify that `methodName`
exists as a declared method in the most recently-compiled class for `<identifier>`.

Implementation: pragmatic regex sweep — scan for patterns like `probe.probe()` and grep for the
method name in the corresponding Java source file. FAIL if the method is absent.

W0 fix covered: `probe.check()` → `probe.probe()` in `agent-runtime/ARCHITECTURE.md` (confirmed
via grep on `OssApiProbe.java`).

### Additional truth fixes shipped this cycle

| File | Defect | Fix |
|---|---|---|
| `contract-catalog.md` | 7 of 10 SPIs deleted; 8 deleted starter coords | Rewritten to reflect 5 active SPIs + 4 design-named deferred (Cluster 3) |
| `agent-runtime/ARCHITECTURE.md:36` | `probe.check()` | `probe.probe()` |
| `architecture-status.yaml` `agent_runtime_kernel` row | "No kernel logic, W2 delivers run lifecycle" | Updated to reflect shipped Run + RunStateMachine + executors |
| `architecture-status.yaml` `orchestration_spi` row | "No reference executor yet (C34)" | Removed — 3 reference executors exist |
| `docs/adr/0016-*` | "ADR-0019 (future)" reversal trigger | Updated to reference ADR-0033 |
| `docs/adr/README.md` | "Last refreshed 2026-05-10" | Updated; rows 0032-0039 added |

### §4 #33 — Contract-Surface Truth Generalization

Extending §4 #24 (Rule 25): the following truth-claim documents are subject to Gate Rules 13 and 14
in addition to the original four gate rules (7, 8, 9, 10):
- `docs/contracts/contract-catalog.md` — subject to Gate Rule 13 (deleted-name scan).
- `agent-platform/ARCHITECTURE.md`, `agent-runtime/ARCHITECTURE.md` — subject to Gate Rule 14 (method-name truth).

### Consequences

**Positive:**
- Deleted-SPI reference drift is now caught at commit time, not review time.
- Module ARCHITECTURE.md method-name drift is caught within one sweep per commit.
- Rule 25 now covers 14 gate rules instead of 4 specific cases; the pattern is extensible.

**Negative:**
- Gate Rule 14's regex sweep may produce false positives if method names collide across classes. Pragmatic: flag and manual-verify if the pattern fires unexpectedly.

## References

- Seventh reviewer P1.1, P2.4, gate item 9: `docs/reviews/2026-05-13-l0-architecture-readiness-agent-systems-review.en.md`
- Rule 25 (Architecture-Text Truth): extended by this ADR
- ADR-0025, ADR-0026, ADR-0027: original Rule 25 ADRs
- `gate/check_architecture_sync.ps1` Gate Rules 13 and 14
- `architecture-status.yaml` row: `contract_surface_truth_gate`
