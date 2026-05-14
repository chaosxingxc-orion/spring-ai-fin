---
affects_level: L0
affects_view: scenarios
proposal_status: response
authors: ["Claude (W1 wave executor)"]
related_adrs: [ADR-0068]
related_rules: [Rule-33, Rule-34]
---

# Response — L1 Architecture Expert Review (2026-05-14)

> **Date:** 2026-05-14
> **Reviews this responds to:**
>   - `docs/reviews/2026-05-14-architecture-governance-in-vibe-coding-era.en.md` (Chief Architect Zhengqiu + LucioIT — doctrine)
>   - `docs/reviews/2026-05-14-L0Architecture-LucioIT-wave-1-request.en.md` (LucioIT — W1 L0 draft)
>   - `docs/reviews/2026-05-14-l1-architecture-expert-review.en.md` (L1 expert — release-candidate evaluation)
> **Status:** Synthesis + W1 wave execution log.

## 1. Three reviewers, one converging signal

Three reviewer documents arrived on 2026-05-14:

| Reviewer | Position | Core claim |
|---|---|---|
| **Chief Architect doctrine** | doctrinal | Flat ADR enumerations fail under Vibe Coding because AI agents exhibit "tubular vision and context collapse." Adopt 4+1 Views layered at L0/L1/L2. |
| **LucioIT W1 L0 draft** | acceptance-conditional | The L1 milestone is accepted only if the corpus is re-organised in the 4+1 / L0–L1–L2 idiom with five view-aware merge gates. |
| **L1 architecture expert** | release-blocking | The L1 release-note currently fails the gate; HTTP contract is overclaimed; OpenAPI snapshot is stale; idempotency body-lifetime is broken; ARCHITECTURE.md carries W0/W1 contradictions. |

Read together, the three converge on the same diagnosis from different angles:
**text-form drift between prose corpus and executable reality is the dominant failure mode**, and it shows up at the prose level (chief architect), at the human/LLM-comprehension level (LucioIT), and at the gate-evidence level (L1 expert).

Our own defect taxonomy already proves this empirically — 79 of 158 historical defects (≈50%) sit in the *governance-text drift / peripheral entry-point lag / gate-promise-gap* cluster.

## 2. W1 wave landing — what was executed

ADR-0068 *Layered 4+1 + Architecture Graph as Twin Sources of Truth* is the seed of a single integrated W1 wave that operationalises all three reviewers' converging signal. The wave shipped in this session:

| Artefact | Status | Addresses |
|---|---|---|
| `CLAUDE.md` Rule 33 (Layered 4+1 Discipline) | new | Chief architect Conv. 1, LucioIT §8.2 |
| `CLAUDE.md` Rule 34 (Architecture-Graph Truth) | new | Chief architect Conv. 2 (extended), L1-expert P2-1 (anchor validation) |
| `docs/adr/0068-layered-4plus1-and-architecture-graph.yaml` | new | seed ADR + canonical YAML-ADR shape |
| `docs/adr/ADR-CLASSIFICATION.md` | new | per-ADR (level, view) table for the 67 legacy ADRs |
| `gate/migrate_adrs_to_yaml.py` | new | mechanical bulk migration script |
| `docs/governance/enforcers.yaml` | extended | every row tagged with `level:` + `view:`; rows E55–E59 added for the wave |
| `docs/governance/principle-coverage.yaml` | new | machine form of `.md`; first input to graph |
| `docs/governance/architecture-graph.yaml` | new (generated) | machine-readable join across all relationships |
| `gate/build_architecture_graph.py` + `.sh` | new | generator + validator (idempotent, DAG check, endpoint resolution) |
| `gate/check_architecture_sync.sh` Rules 37–40 | new | front-matter / graph / review-template / reachability gates |
| `gate/test_architecture_sync_gate.sh` | extended | self-tests for Rules 37–40 (cases 38–42); TOTAL bumped 37→42 |
| `ARCHITECTURE.md` (root) | front-matter + §0.4 view map | L0 layered-4+1 transition (Convention 1) |
| `agent-platform/ARCHITECTURE.md` | front-matter + §0.4 view map | L1 layered-4+1 transition |
| `agent-runtime/ARCHITECTURE.md` | front-matter + §0.4 view map | L1 layered-4+1 transition |
| `docs/L2/README.md` | new (scaffold) | L2 directory introduced |
| `docs/reviews/_TEMPLATE.md` | new | Convention 4 — mandatory `affects_level:` + `affects_view:` front-matter |
| `docs/governance/SESSION-START-CONTEXT.md` | new | graph-first reading order for new sessions |
| `docs/governance/rule-history.md` | extended | Rules 33 + 34 logged |

## 3. Per-finding coverage from the L1 expert review

The L1 expert review surfaced 8 distinct findings. Each is mapped below.

### P0-1 — Architecture-sync gate fails on the L1 release note (baseline counts)

**Status — separate follow-up (not W1 wave).** This is a release-note hygiene issue, not a structural one. The fix is mechanical: add the baseline count table to `docs/releases/2026-05-14-L1-modular-russell-release.en.md`. The W1 wave does NOT alter release-note format; the existing Rule 28 baseline-truth gate is sufficient once the table is filled.

**Action:** open a separate small PR adding the baseline counts. The updated numbers after this wave are:

| Baseline metric | Old | New |
|---|---|---|
| §4 constraints | 63 | 65 (adds #64 Rule 33, #65 Rule 34 — to be added when ARCHITECTURE.md §4 is updated) |
| ADRs | 67 | 68 |
| Active gate rules | 36 | 40 |
| Gate self-tests | 37 | 42 |
| Enforcer rows | 54 | 59 |
| Active engineering rules | 32 | 34 |

### P0-2 — Run HTTP contract overclaimed by enforcer rows (E5/E7/E24 point at non-existent test methods)

**Status — covered structurally by W1 wave, content-level fix remains separate.** Rule 34 / Gate Rule 38 / enforcer row E56 explicitly demand that *every `artifact#anchor` reference resolves to a real method or heading*. The W1 graph generator (`gate/build_architecture_graph.py`) marks every `file:` node with `exists:` and the validator fails on `exists: false`. **What W1 does not do** is rename the offending anchors in `enforcers.yaml` (E5, E6, E24 still point at `createReturnsPending` / `cancelTerminalReturns409` which do not exist in the Java source). That content fix needs to be paired with the JWT test fixture work flagged in P1-1 below.

**Action:** as part of the JWT fixture + authenticated `RunHttpContractIT` work, rename or implement the methods so the anchors resolve. W1 makes this a *gate failure* the next time the graph is built; it does not auto-rename code.

### P0-3 — OpenAPI W0/W1 mismatch

**Status — separate follow-up.** Out of W1 wave scope (the W1 wave is structural; OpenAPI regeneration is content). Enforcer row E36 already exists for this gap; the fix is to regenerate `docs/contracts/openapi-v1.yaml` to include `/v1/runs` operations and bump `stability: W1`.

**Action:** standalone PR; deadline = before the next L1 release-candidate cut.

### P1-1 — Idempotency filter consumes request body

**Status — separate follow-up.** Out of W1 wave scope (this is a Java runtime bug, not a governance bug). The fix is to replace `ContentCachingRequestWrapper` with a replayable cached-body wrapper, or move hash computation past deserialization. The W1 wave does NOT change `IdempotencyHeaderFilter.java`.

**Action:** standalone PR (highest priority — ship-blocking for authenticated `POST /v1/runs`).

### P1-2 — `architecture-status.yaml` stale rows

**Status — partial W1 coverage.** The W1 graph generator emits `capability → test` edges and flags `exists: false` artefact endpoints. So a stale row whose `tests:` list points at non-existent files now becomes a gate failure under Rule 38. **What W1 does not do** is rewrite the `http_contract_w1_reconciliation` and `metric_tenant_tag_w1` rows themselves.

**Action:** include the row rewrite in the L1 release-recut PR (alongside P0-1).

### P1-3 — PowerShell gate mirror lacks Rule 28 sub-rules

**Status — separate follow-up.** PowerShell parity is outside W1 wave scope. The new Rule 37–40 gate checks are bash-only at landing; a PowerShell port follows the existing 28a–28j precedent.

**Action:** scheduled for W1.x — port Rules 28a–28j and 37–40 to `gate/check_architecture_sync.ps1` together.

### P1-4 — `agent-platform/ARCHITECTURE.md` W0-era contradictions in §§4–9

**Status — front-matter covered; content rewrite remains.** The W1 wave added the layered-4+1 front-matter and §0.4 view map at the top of `agent-platform/ARCHITECTURE.md`, AND flagged the W0/W1 boundary contradictions explicitly in the §0.4 note. The full rewrite of §§4–9 is the same kind of content-debt that the layered model is designed to expose, not hide. Doing the rewrite *inside* the W1 wave would have collided with the "freeze on release" Convention 3 the reviewers also ask for.

**Action:** open a follow-up proposal under `docs/reviews/` (using the new `_TEMPLATE.md`) declaring `affects_level: L1`, `affects_view: scenarios`, and rewrite §§4–9 of `agent-platform/ARCHITECTURE.md` to match shipped L1 surface. This is the **first real test of Convention 4** (the proposal flow).

### P2-1 — Rule 28 meta-enforcement weaker than its claim

**Status — covered structurally by W1 wave.** Exactly the gap Gate Rule 38 (graph well-formed, enforcer E56) closes — every `artifact#anchor` must resolve. The reviewer's specific recommendation ("add anchor-level validation; add negative self-tests where an enforcer row points to a missing test method") is now executable infrastructure rather than a TODO: the Python graph validator returns non-zero on unresolved anchors, and the bash self-test file carries cases 38–42 demonstrating positive + negative coverage.

**Action:** none additional from W1; the structural gate is in place. If a future PR re-introduces an unresolved anchor, the gate will fail.

## 4. Drift-defect regression demo (W1 §7)

The plan committed to picking one historical text-drift defect and showing that the graph-edge integrity check would have caught it structurally. The chosen example:

**Historical defect.** L0 release (2026-05-13, SHA 82a1397): a release-note baseline-truth check used a regex matching `"replace"` but the actual prose said `"switches to"`. The regex missed the verb form. Rule 16a was widened with `-cmatch` for a verb class; a new self-test was added. This is one occurrence of the GATE-PROMISE-GAP defect shape (ADR-0045).

**Why the graph would have caught it.** The defect existed because two prose sentences described *the same architectural truth* in different verbs:
- the rule body said "tests must replace W0 placeholders before W1 ships"
- the prose said "the gate switches to W1 mode at SHA …"

In the graph, there are not two prose copies of this truth. There is *one node* representing "release-note baseline truth at SHA-X" with *typed edges* to the baseline-counts row in `architecture-status.yaml`. A verb-form change in either prose body is irrelevant — the edge has no verb. A real semantic change shows up as a numerically different `baseline_counts:` value, which Rule 28 already detects on its own.

**Net result:** the defect family is collapsed *at source*. There is no second prose copy to drift from the first, so no regex is asked to police the divergence, so no verb-form gap can open.

## 5. What W1 explicitly does NOT do

To keep the wave reviewable, the following are deferred:

- **Bulk migration of 67 legacy `.md` ADRs to `.yaml`** — script is shipped (`gate/migrate_adrs_to_yaml.py`) and a classification table is shipped (`docs/adr/ADR-CLASSIFICATION.md`); the actual `git mv` happens at PR finalisation.
- **Full re-organisation of `ARCHITECTURE.md` / `agent-*/ARCHITECTURE.md` under 4+1 view headings** — only the `level:`/`view:` front-matter and the §0.4 view map are added; the deep content split (renaming §1, §2, … to live under the appropriate view) is the *first* W1.x follow-up proposal.
- **CODEOWNERS-based freeze enforcement (Convention 3)** — declared as `freeze_id: null` in front-matter today; the actual `CODEOWNERS` machinery + a freeze-respect gate land in W1.x.
- **PowerShell parity for Rules 37–40** — see P1-3 above.

## 6. Reading order for reviewers of this response

1. `docs/governance/SESSION-START-CONTEXT.md` — the new session-start map.
2. `docs/adr/0068-layered-4plus1-and-architecture-graph.yaml` — the seed ADR (also the YAML-ADR shape example).
3. `CLAUDE.md` §"Vibe-Coding-era structural discipline" — Rules 33 + 34 in normative form.
4. `docs/governance/enforcers.yaml` — note the new `level:`/`view:` columns and rows E55–E59.
5. `gate/check_architecture_sync.sh` — Rules 37–40 appended near the bottom.
6. (Optional) run `bash gate/build_architecture_graph.sh --mermaid` and open `docs/governance/architecture-graph.mmd` to see the graph.

## 7. Why this matters — closing argument

The L1 expert review's most consequential observation is not any single P0. It is the framing that *the governance system has become weaker than its prose claim*. Rule 28 says every constraint must have an executable enforcer; in practice we have 24 self-tests just to police the gates. The slope is asymptotic.

The Chief Architect doctrine and the user's complementary structured-LLM ask both point at the same exit: stop maintaining N prose copies of architectural truth and start maintaining one machine-readable graph plus its leaves of rationale prose. The W1 wave is the first cut at that exit. If it holds, the GOVERNANCE-TEXT-DRIFT / PERIPHERAL-DRIFT / GATE-PROMISE-GAP defect families should collapse from ~50% of all closed defects to a long-tail residual confined to rationale paragraphs.

The remaining P0/P1 items from the L1 expert review are content debts that any layered governance model would still require us to pay. The wave does not pretend to pay them. It builds the substrate on which paying them becomes a structural, gate-verifiable act rather than a prose ritual.

---

## Authority

- `CLAUDE.md` Rule 33 (Layered 4+1 Discipline), Rule 34 (Architecture-Graph Truth)
- ADR-0068 (Layered 4+1 + Architecture Graph as Twin Sources of Truth)
- Gate Rules 37 (`architecture_artefact_front_matter`), 38 (`architecture_graph_well_formed`), 39 (`review_proposal_front_matter`), 40 (`enforcer_reachable_from_principle`)
- Enforcer rows E55–E59 in `docs/governance/enforcers.yaml`
