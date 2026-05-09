# Systematic Architecture Remediation Plan -- Cycle-9 Response

Date: 2026-05-09
Reviewed input:
`docs/systematic-architecture-remediation-plan-2026-05-09-cycle-9.en.md`.

Stance: every cycle-9 finding is **ACCEPTED**. The reviewer correctly
identifies the structural defect: the 2026-05-08 architecture refresh
landed alongside the cycle-1..8 corpus instead of replacing it,
producing two simultaneous active sources of truth. The 240-dim
self-audit at 100% design-time cap was honest about its rubric but
silent about this overlap because the rubric never asked "is the
active corpus exclusive?". Cycle-9 makes that question its first P0
finding. It is right.

## 1. Per-finding decisions

| Finding | Severity | Verdict | Resolution shipped this cycle |
|---|---|---|---|
| A1 -- Architecture-sync passes while active truth is split | P0 | ACCEPT | New gate rule `active_corpus_no_disposition_in_active`; `active_documents` no longer holds entries with `v7_disposition`. |
| A2 -- Local gate evidence over-readable as delivery | P1 | ACCEPT | Manifest distinguishes `local_semantic_pass` from `delivery_valid_pass`. Delivery files quote `evidence_valid_for_delivery` explicitly. |
| B1 -- Active corpus is a mixed registry | P0 | ACCEPT | active-corpus.yaml split into three exclusive sections: `active_documents`, `transitional_rationale`, `historical_documents`. Transitional entries get `sunset_by`. |
| B2 -- Index still presents pre-refresh hierarchy as active | P0 | ACCEPT | `current-architecture-index.md` primary hierarchy lists only refresh-active docs. Pre-refresh hierarchy moved to "Historical Rationale (NOT authoritative)" section. New gate rule `index_active_subset` enforces. |
| C1 -- ActionGuard has two active designs | P0 | ACCEPT | **5-stage wins.** The 11-stage docs (`agent-runtime/action-guard/ARCHITECTURE.md`, `docs/security-control-matrix.md`) move out of `active_documents` into `historical_documents`. The refresh's `agent-runtime/action/ARCHITECTURE.md` and `docs/cross-cutting/security-control-matrix.md` are the only active models. The 5-stage chain explicitly defines audit-before-action and post-failure-evidence as non-skippable invariants per cycle-9 sec-C1. |
| C2 -- Gate rule still encodes old ActionGuard path | P1 | ACCEPT | `actionguard_pre_post_evidence_missing` rule retired. Replaced by `actionguard_5stage_invariants` rule that binds to `agent-runtime/action/ARCHITECTURE.md` and asserts the 5 stage names + the audit-before-action / post-failure-evidence invariants. |
| D1 -- No runnable runtime artifact | P0 | ACCEPT-AS-CORRECT | Per the user's 2026-05-09 scope instruction ("engineering implementation only needs a plan"), W0 stays as plan only this cycle. Rule 8 remains fail-closed. The plan in `docs/plans/engineering-plan-W0-W4.md` sec-2 (W0) is the deliverable that satisfies cycle-9 D1's "minimum runnable W0 artifact" — when it is executed in code, not before. |
| D2 -- Fake-provider smoke vs Rule 8 confusion | P1 | ACCEPT | Manifest gains `dependency_mode: fake \| real` and `rule_8_eligible: true \| false`. Engineering plan renames "fake-provider sequential smoke" to `ci_operator_shape_smoke`; reserves `rule_8_operator_shape` for real-dependency runs. |
| E1 -- "100% design-time cap" creates closure pressure | P1 | ACCEPT | Self-audit and index drop percentage as the headline. Headline becomes maturity ladder: every refresh capability is L0 by design until W0 lands code + tests. The 240-dim score is reported as a secondary diagnostic, prefixed with "design-only; not a shipping claim; not Rule 8 evidence". |

No findings are rejected.

## 2. Concretely what changes in this cycle

Files modified:

- `docs/governance/active-corpus.yaml` -- split into three sections.
- `docs/governance/current-architecture-index.md` -- single active hierarchy.
- `docs/governance/evidence-manifest.yaml` -- `dependency_mode`, `rule_8_eligible`, `local_semantic_pass` vs `delivery_valid_pass`.
- `docs/governance/architecture-status.yaml` -- cycle-9 findings.
- `gate/check_architecture_sync.{sh,ps1}` -- new rules + ActionGuard rule migration.
- `agent-runtime/action/ARCHITECTURE.md` -- audit-before-action + post-failure-evidence invariants surfaced as named stage requirements.
- `docs/cross-cutting/security-control-matrix.md` -- ActionGuard row references the 5-stage invariants.
- `docs/plans/engineering-plan-W0-W4.md` -- rename fake-smoke vs Rule 8 smoke.
- `docs/architecture-design-self-audit.md` -- maturity-first, percent-secondary; new dim group G7 for "active-corpus exclusivity" so the rubric self-detects cycle-9-class gaps next time.

Files NOT changed:

- The 14 deferred pre-refresh L2 files keep their banners; they leave `active_documents` and enter `historical_documents` per the registry split.
- The 5 pre-refresh cross-cutting paths keep their MOVED banners; they move into `historical_documents`.
- W0 runtime code -- explicitly out of scope for this cycle per user instruction.

## 3. Why the reviewer is right about non-convergence

Cycle-1..8 fixed evidence-graph mechanics; the cycle-8 manifest v3 + delivery_log_exact_binding + ascii_only_active_corpus rules removed multiple recurring symptom families. The 2026-05-08 architecture refresh then introduced a smaller, OSS-first model.

What cycle-9 caught is a higher-order pattern: a refresh that **adds** an authoritative model without **removing** the previous one is not a refresh -- it is a fork. Reviews then keep finding contradictions between the two forks. The fix is not more rules on each fork; it is a truth-cut.

This cycle's commit performs the truth-cut on the documentation surface (which is the user's current scope -- "design only; engineering implementation only needs a plan"). It does NOT yet perform the truth-cut on runtime behavior; that remains W0 per the engineering plan. Cycle-9 D1 explicitly accepts this sequencing.

## 4. New rubric dim group (G7) added

To prevent recurrence, the self-audit gains a 5-dim group G7
"Active-corpus exclusivity":

- G7.1 No `active_documents` entry has a disposition marker.
- G7.2 Every transitional document has a sunset condition.
- G7.3 The current index primary hierarchy is a subset of `active_documents`.
- G7.4 No two active documents disagree on a security-control parameter (stage count, algorithm, posture).
- G7.5 Gate semantic rules bind to active paths only; legacy paths cannot satisfy a refresh-active rule.

G7 is included in the cycle-9 audit re-score.

## 5. Definition of done coverage (cycle-9 review's 10-item checklist)

| Item | Cycle-9 fix |
|---|---|
| 1. `active_documents` has no renamed/moved/merged/replaced/deferred entries | active-corpus.yaml split into 3 sections |
| 2. `current-architecture-index.md` lists one active hierarchy | index restructured |
| 3. ActionGuard has one active model | 5-stage wins; 11-stage docs become historical |
| 4. Gate fails if old ActionGuard model reintroduced as active | new `active_corpus_no_disposition_in_active` rule blocks |
| 5. Security-control matrix in one active path | `docs/security-control-matrix.md` historical; `docs/cross-cutting/security-control-matrix.md` active |
| 6. Rule 8 stays fail-closed until runnable artifact | unchanged; honest |
| 7. Fake-provider smoke clearly non-Rule-8 | manifest + engineering plan rename |
| 8. W0 runtime skeleton exists | DEFERRED per user's 2026-05-09 instruction; plan-only |
| 9. Delivery uses L-level maturity, not percentages | self-audit headline switched |
| 10. Every closure claim ties to code + tests + gate evidence | already required by Rule 12 + Rule 8; cycle-9 re-states explicitly in delivery README |

Item 8 is the only item the user asked us to keep at plan-only. The
remaining 9 items land in this cycle's commit chain.

## 6. Summary

Cycle-9 is a truth-cut cycle. It says: the refresh is correct; the
problem is that it shipped without retiring the previous corpus. This
response fixes that retirement on the documentation side and codifies
"active-corpus exclusivity" as a permanent gate rule + audit dim group
so the same overlap cannot return on the next cycle.

W0 runtime work remains the next deliverable. It is governed by the
existing engineering plan, not by another documentation cycle.
