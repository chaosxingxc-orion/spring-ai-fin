# Response: Post-Seventh L0 Readiness Follow-up

**Reviewer:** Post-seventh L0 readiness follow-up  
**Date of findings:** 2026-05-13  
**Response author:** architecture  
**Response date:** 2026-05-13  
**Review input:** `docs/reviews/2026-05-13-post-seventh-l0-readiness-followup.en.md`

---

## 1. Executive Summary

The reviewer's verdict — "do not publish a clean L0 release note yet" — is accepted. The six
findings (four P1 blocking, two P2 polish) are all ACCEPTED and fully addressed in this response
cycle. No findings are rejected.

| Finding | Verdict | Cluster | Status |
|---------|---------|---------|--------|
| P1.1 — active docs reference deleted plan paths | **ACCEPT** | A | Fixed |
| P1.2 — W1 HTTP contract disagreement (tenant + initial status + cancel route) | **ACCEPT** | B | Fixed |
| P1.3 — contract catalog SPI table inaccurate | **ACCEPT** | C | Fixed |
| P1.4 — memory/knowledge sidecar inconsistencies | **ACCEPT** | D | Fixed |
| P2.1 — module-tree comment truth drift | **ACCEPT** | E | Fixed |
| P2.2 — gate rules too narrow | **ACCEPT** | F | Fixed |

**L0 release-gate assessment after this cycle:** All six findings resolved. L0 release note may
now be published.

---

## 2. Per-Finding Response

### P1.1 — Deleted Plan Path References (Cluster A)

**Reviewer-identified hits:** 11 active documents referencing `docs/plans/engineering-plan-W0-W4.md`
(a plan archived to `docs/archive/2026-05-13-plans-archived/` per ADR-0037 in the previous cycle).

**Self-audit additions:** A.HD1 — `docs/adr/0012-valkey-session-cache.md` was not in the
reviewer's list but matched the same pattern; added to fix list. A.HD2 —
`docs/plans/architecture-systems-engineering-plan.md` self-described as a "companion to
`docs/plans/engineering-plan-W0-W4.md`"; archiving its peer without archiving the companion
violates ADR-0037's single-wave-authority principle. A.HD3 — no gate rule prevented recurrence.

**Fixes applied:**

| File | Fix |
|---|---|
| `docs/adr/0012-valkey-session-cache.md` | References → `docs/archive/.../engineering-plan-W0-W4.md (archived per ADR-0037)` |
| `docs/adr/0018-sandbox-executor-spi.md` | Same |
| `docs/adr/0019-suspend-signal-and-suspend-reason-taxonomy.md` | Same |
| `docs/adr/0020-runlifecycle-spi-and-runstatus-formal-dfa.md` | Same |
| `docs/adr/0024-suspension-write-atomicity.md` | Same |
| `docs/adr/0028-causal-payload-envelope-and-semantic-ontology.md` | Same |
| `docs/adr/0030-skill-spi-lifecycle-resource-matrix.md` | Same |
| `docs/adr/0031-three-track-channel-isolation.md` | Same |
| `agent-runtime/ARCHITECTURE.md:64` | → wave authority reference per ADR-0037 |
| `docs/cross-cutting/oss-bill-of-materials.md:310` | → wave authority reference per ADR-0037 |
| `docs/plans/architecture-systems-engineering-plan.md` | Archived to `docs/archive/2026-05-13-plans-archived/` with banner; original deleted |
| `docs/archive/2026-05-13-plans-archived/README.md` | Added third archived doc to table |

**New ADR:** ADR-0041 (Active-Corpus Truth Sweep) formalises the correction strategy and defines
Gate Rule 15. **New Gate Rule:** Rule 15 (`no_active_refs_deleted_wave_plan_paths`) — active `.md`
files (excluding `docs/archive/`, `docs/reviews/`, `third_party/`, `target/`, `.git/`) must not
reference either deleted plan path.

---

### P1.2 — W1 HTTP Contract Disagreement (Cluster B)

**Reviewer-identified contradictions (3):**

1. **Tenant model:** `agent-platform/ARCHITECTURE.md:34-35` and root `ARCHITECTURE.md:149-153`
   said W1 "replaces" `X-Tenant-Id` with JWT. `http-api-contracts.md:19` and `contract-catalog.md`
   already described a cross-check model (keep header + add JWT validation). Decision: keep header
   + add JWT cross-check. This is additive; no W0 client breakage.

2. **Initial run status:** `http-api-contracts.md:92` said `CREATED`. `RunStatus.java` has no
   `CREATED` value. `ARCHITECTURE.md` DFA starts at `PENDING`. Decision: `PENDING`.

3. **Cancel route:** `http-api-contracts.md:110-120` said `POST /v1/runs/{id}/cancel`.
   `openapi-v1.yaml x-w1-note` said `DELETE /v1/runs/{runId}`. Decision: `POST /cancel` — cancel
   is a Rule 20 state transition (`RUNNING → CANCELLED`), not a deletion.

**Self-audit additions:** B.HD1 — lines 34-35 and 74 contradicted the correct :19 wording.
B.HD2 — "W1 hardening step" overstated the change. B.HD3 — no gate cross-checking the 5 docs.
B.HD4 — architecture-status.yaml `deferred_w1` rows for tenant filter need to describe the
chosen model.

**Fixes applied:**

| File | Change |
|---|---|
| `agent-platform/ARCHITECTURE.md:34-35, 74` | "replace" → "add JWT cross-check against X-Tenant-Id" |
| `ARCHITECTURE.md:149-153` | Same |
| `docs/contracts/http-api-contracts.md:92` | `CREATED` → `PENDING` |
| `docs/contracts/openapi-v1.yaml:54 x-w1-note` | DELETE removed; POST /cancel documented |
| `docs/contracts/contract-catalog.md:10` | Added JWT cross-check note per ADR-0040 |

**New ADR:** ADR-0040 (W1 HTTP Contract Reconciliation) is the single canonical W1 HTTP contract
statement. **New Gate Rule:** Rule 16 (`http_contract_w1_tenant_and_cancel_consistency`).

---

### P1.3 — Contract Catalog SPI Table Inaccurate (Cluster C)

**Reviewer-identified problems:**
1. Header claimed "5 active interfaces" (count was wrong).
2. `OssApiProbe` listed as SPI — it is a probe, not an extension point.
3. `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor` missing from table.
4. `GraphMemoryRepository` attributed to wrong module (`spring-ai-ascend-graphmemory-starter`
   is the adapter shell; the SPI interface lives in `agent-runtime`).

**Self-audit additions:** C.HD1 — single table mixed SPIs, probes, data carriers. C.HD2 — no
inclusion rule was stated. C.HD3 — no gate checked SPI table against source.

**Fixes applied:** `docs/contracts/contract-catalog.md §2` completely rewritten with:
- Inclusion rule: "Java `interface` types that represent named public extension points in
  `agent-platform` or `agent-runtime`; not probes, not data carriers, not implementations."
- Four sub-tables: Active SPI interfaces (7) / Data carriers / Probes / Design-named SPIs (deferred)
- Active SPI interfaces: RunRepository, Checkpointer, GraphMemoryRepository (module=agent-runtime),
  ResilienceContract, Orchestrator, GraphExecutor, AgentLoopExecutor
- OssApiProbe moved to Probes sub-table

**New Gate Rule:** Rule 17 (`contract_catalog_spi_table_matches_source`).

---

### P1.4 — Memory/Knowledge Sidecar Inconsistencies (Cluster D)

**Reviewer-identified inconsistencies:** mem0 still claimed a starter adapter that was deleted in
the 2026-05-12 Occam pass. Docling still claimed a `LayoutParser` SPI and `docling-starter`.
Graphiti/Cognee selection claim was ambiguous ("cycle-15 picks one"). langchain4j-profile section
listed a future starter without an ADR. GraphMemoryRepository JavaDoc still said "Cognee — cycle-15
selects one".

**Self-audit additions:** D.HD1 — §4.6 langchain4j profile in oss-bill-of-materials.md contradicted
ARCHITECTURE.md:12 exclusion. D.HD2 — "cycle 15" language referenced the archived cycle convention.
D.HD3 — no gate checked these files for deleted SPI/starter names.

**Fixes applied:**

| File | Fix |
|---|---|
| `third_party/MANIFEST.md:30` | mem0 adapter → "none (evaluation-only; not selected at L0; see ADR-0034)" |
| `third_party/MANIFEST.md:33` | Docling adapter → "none (evaluation-only; deleted in 2026-05-12 Occam pass)" |
| `third_party/MANIFEST.md:53` | "cycle 15 picks one" → "Graphiti selected as W1 reference (ADR-0034); Cognee not selected" |
| `docs/cross-cutting/oss-bill-of-materials.md:153` | Docling → evaluation-only note |
| `docs/cross-cutting/oss-bill-of-materials.md:155-163` | langchain4j-profile section removed; one-line exclusion note |
| `docs/cross-cutting/oss-bill-of-materials.md:303` | "mem0/Graphiti/Docling" → "Graphiti" only |
| `agent-runtime/.../GraphMemoryRepository.java:9-10` | JavaDoc: "Cognee — cycle-15" → "ADR-0034: Graphiti selected; Cognee not selected" |
| `ARCHITECTURE.md:83` | Module-tree comment clarified: "Graphiti W1 ref per ADR-0034; auto-config disabled; full integration W2" |

**New Gate Rule:** Rule 18 (`deleted_spi_starter_names_outside_catalog`) extends Rule 13's deleted-name
scan to `third_party/MANIFEST.md`, `docs/cross-cutting/oss-bill-of-materials.md`, `README.md`.

---

### P2.1 — Module-Tree Comment Truth Drift (Cluster E)

**Reviewer-identified drift:**
1. `ARCHITECTURE.md:41` said "Idempotency-Key dedup" — W0 only validates shape, no dedup.
2. `ARCHITECTURE.md:42` said "dev-posture in-memory store" — `IdempotencyStore` is a stub, not
   registered as bean at W0.
3. `ARCHITECTURE.md:442` said `{"status":"UP"}` — actual response is `{status, sha, db_ping_ns, ts}`.
4. `agent-platform/ARCHITECTURE.md:86` said "no Testcontainers dependency" — `HealthEndpointIT`
   and `OpenApiContractIT` use `@Testcontainers(disabledWithoutDocker = true)`.

**Fixes applied:** All four module-tree / health-response comments corrected inline.

---

### P2.2 — Gate Rules Too Narrow (Cluster F)

**Reviewer assessment:** 14 rules leave several trust gaps: no check for deleted plan path
references in active docs, no cross-check of W1 HTTP contract consistency, no SPI table source
validation, no deleted-name check outside contract-catalog.md.

**Response:** Gate Rules 15–18 added per the specifications in Cluster A–D above. Total gate rules:
14 → 18. Both `gate/check_architecture_sync.ps1` and `gate/check_architecture_sync.sh` updated.

---

## 3. Self-Audit Hidden Defects Surfaced Beyond Reviewer's 12 Named Hits

| Defect | Cluster | Fix |
|---|---|---|
| A.HD1 — `docs/adr/0012-valkey-session-cache.md` stale path | A | Fixed (same as reviewer's list) |
| A.HD2 — `architecture-systems-engineering-plan.md` orphaned as active companion to archived plan | A | Archived to `docs/archive/2026-05-13-plans-archived/` |
| A.HD3 — No gate prevents recurrence of deleted-plan-path references | A | Gate Rule 15 |
| B.HD1 — Lines 34-35/74 contradicted correct :19 JWT cross-check wording | B | Fixed |
| B.HD2 — "W1 hardening step" overstated the JWT change | B | Fixed |
| B.HD3 — No gate cross-checking 5 docs for tenant/cancel consistency | B | Gate Rule 16 |
| B.HD4 — `architecture-status.yaml` `deferred_w1` rows didn't name chosen tenant model | B | Updated `allowed_claim` in new yaml row |
| C.HD1 — Single-table format mixed SPIs, probes, data carriers, starters | C | Split into 4 sub-tables |
| C.HD2 — No inclusion rule stated for SPI sub-table | C | Inclusion rule added |
| C.HD3 — No gate checks SPI table against actual Java source | C | Gate Rule 17 |
| D.HD1 — §4.6 langchain4j profile contradicted ARCHITECTURE.md:12 exclusion | D | Section removed |
| D.HD2 — "cycle 15" language referenced the archived cycle convention | D | "cycle 15" references removed |
| D.HD3 — No gate checks MANIFEST.md / oss-bill-of-materials.md for deleted names | D | Gate Rule 18 |
| E.HD1 — Other tree-comment one-liners may be stale | E | Reviewed ARCHITECTURE.md tree; only 4 stated drift points confirmed |

---

## 4. Gate Rule Extensions (Cluster F)

| Rule | Name | Scope | ADR |
|------|------|-------|-----|
| 15 | `no_active_refs_deleted_wave_plan_paths` | Active `.md` files (excluding archive/reviews/third_party/target/.git) must not contain `docs/plans/engineering-plan-W0-W4.md` or `docs/plans/roadmap-W0-W4.md` | ADR-0041 |
| 16 | `http_contract_w1_tenant_and_cancel_consistency` | (a) No "replace.*X-Tenant-Id" in active docs; (b) `http-api-contracts.md` must not reference `CREATED` as initial status; (c) `openapi-v1.yaml` must not mention `DELETE /v1/runs/{runId}` as cancel | ADR-0040 |
| 17 | `contract_catalog_spi_table_matches_source` | All 7 known SPI interface names must appear in `contract-catalog.md`; `OssApiProbe` must not appear before the `**Probes` sub-table heading | ADR-0041 |
| 18 | `deleted_spi_starter_names_outside_catalog` | Extend Rule 13's deleted-name scan to `third_party/MANIFEST.md`, `docs/cross-cutting/oss-bill-of-materials.md`, `README.md` | ADR-0041 |

---

## 5. L0 Release-Gate Closure Assessment

**Pre-this-cycle state (reviewer's finding):** 6 P1/P2 gaps remained. Clean L0 release note
blocked.

**Post-this-cycle state:**

| Gate item | Pre | Post |
|---|---|---|
| §4 constraint count | 36 | **38** |
| ADR count | 39 | **41** |
| Active gate rules | 14 | **18** |
| Active engineering rules | 11 | 11 (unchanged) |
| Stale plan path references in active docs | 11 hits | **0 hits** |
| W1 HTTP contract contradictions | 3 | **0** |
| Contract catalog SPI table accuracy | Inaccurate | **7 SPIs, 4 sub-tables, inclusion rule** |
| Deleted SPI/starter names in MANIFEST.md/BoM | present | **0 references** |
| Module-tree comment drift | 4 stale | **0 stale** |

**Verdict:** L0 release note may now be published. All six findings are fully resolved.

---

## 6. Test + Gate Count Delta

| Metric | Before | After |
|--------|--------|-------|
| Unit/IT tests | 101 | 101 (no Java changes this cycle) |
| Active gate rules | 14 | **18** |
| §4 constraints | 36 | **38** |
| ADRs | 39 | **41** |
| Active engineering rules | 11 | 11 |

No new Java source files were added. The only Java change was a two-line JavaDoc update in
`GraphMemoryRepository.java`.

---

## 7. Commit Block

```
docs(review): respond to post-seventh L0 readiness follow-up;
+§4 #37-#38, +ADR-0040 W1 HTTP reconciliation, +ADR-0041 active-corpus truth sweep,
+Gate Rules 15-18, +archive architecture-systems-engineering-plan,
+strip mem0/Docling/langchain4j-profile from active BoM/MANIFEST,
+fix module-tree comments (IdempotencyHeaderFilter, IdempotencyStore, health endpoint),
+contract-catalog SPI table split (4 sub-tables, 7 SPIs, inclusion rule),
101 tests pass, 18 gate rules pass
```

Follow-up `chore(gate)`:

```
chore(gate): update latest_semantic_pass_sha to <SHA>; 11 active rules; 18 gate rules
```
