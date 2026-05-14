# Engineering Rule History

Narrative companion to `CLAUDE.md`. Captures **why** rules entered or left the
active set. `CLAUDE.md` is the normative contract; this file is the record.

Authority: ADR-0064 (governing principles + cleanup) — promotes `CLAUDE.md` to
the layered "Layer-0 Principles / Layer-1 Rules" structure and sinks
review-cycle scaffolding here.

---

## Lifecycle markers

- **Active** — currently in `CLAUDE.md`, enforced by an entry in `docs/governance/enforcers.yaml`.
- **Deferred** — staged in `docs/CLAUDE-deferred.md` with an explicit re-introduction trigger.
- **Retired** — replaced or merged into another rule; not enforced.

---

## Rules by introduction cycle

| Rule | Introduced | Status | Origin |
|---|---|---|---|
| 1–4 | First cycle | Active | Daily engineering principles — root cause, simplicity, pre-commit, three-layer testing. |
| 5–6 | Second cycle | Active | Class-level patterns — async lifetime, single construction path. |
| 7 | Second cycle | Deferred (W2) | Resilience signal masking — re-arms at first soft-fallback path. |
| 8 | Second cycle | Deferred (W2) | Operator-shape readiness gate — re-arms at first shippable JAR with real external dep. |
| 9 | Second cycle | Active | Self-audit ship gate. |
| 10 | Second cycle | Active | Posture-aware defaults. |
| 11 | Second cycle | Deferred (W1) | Contract-spine completeness — re-arms at first persistent record. |
| 12 | Early cycles | **Retired** | Maturity levels L0–L4 — replaced by binary `shipped:` in `docs/governance/architecture-status.yaml`. |
| 13 | Second cycle | Deferred (W3) | P1 cost-of-use constraints. |
| 14 | Second cycle | Deferred (W3) | P3 self-evolution constraints. |
| 15 | Third-review cycle | Deferred (W2) | Streamed handoff mode conformance. |
| 16 | Third-review cycle | Deferred (W2) | Cognitive resource arbitration. |
| 17 | Third-review cycle | Deferred (W2) | Degradation authority + resume re-authorization. |
| 18 | Third-review cycle | Deferred (W4) | Eval harness gate. |
| 19 | Third-review cycle | Deferred (W2) | Runtime hook conformance. |
| 20 | Third-review cycle | Active | Run state transition validity. ADR-0020. |
| 21 | Third-review cycle | Active | Tenant propagation purity. ADR-0023. |
| 22 | Third-review cycle | Deferred (W2) | PayloadCodec discipline. ADR-0022. |
| 23 | Third-review cycle | Deferred (W2) | Suspension write atomicity. ADR-0024. |
| 24 | Third-review cycle | Deferred (W2) | RunLifecycle re-authorization. |
| 25 | Fourth-review cycle | Active | Architecture-text truth gate. ADR-0025/0026/0027. |
| 26 | Fifth-review cycle | Deferred (W2) | Skill lifecycle conformance. ADR-0030. |
| 27 | Fifth-review cycle | Deferred (W3) | Untrusted skill sandbox mandate. ADR-0030. |
| 28 | Fifth-review cycle | Active (L1 governing) | Code-as-Contract. ADR-0059. Forbids prose-only constraints. |
| 29 | Layer-0 governing principles cycle (2026-05-14) | Active | Business/platform decoupling enforcement. ADR-0064. |
| 30 | Layer-0 governing principles cycle (2026-05-14) | Active | Competitive baselines required. ADR-0065. |
| 31 | Layer-0 governing principles cycle (2026-05-14) | Active | Independent module evolution. ADR-0066. |
| 32 | Layer-0 governing principles cycle (2026-05-14) | Active | SPI + DFX + TCK co-design. ADR-0067. |
| 33 | Layered 4+1 + Graph wave (2026-05-14) | Active | Layered 4+1 discipline — every architecture artefact declares level: + view: front-matter; phase-released L0/L1 docs are frozen. ADR-0068. |
| 34 | Layered 4+1 + Graph wave (2026-05-14) | Active | Architecture-Graph truth — docs/governance/architecture-graph.yaml is generated from authoritative inputs and validated for DAG-ness + endpoint resolution + anchor resolution + idempotency. ADR-0068. |

## Gate-Rule additions (Layer-1 enforcement scripts, not engineering rules)

The following are gate-script rules in `gate/check_architecture_sync.sh` introduced by the W1 + Phase-M waves. They enforce CLAUDE.md Rules 33-34; they are not themselves engineering rules.

| Gate Rule | Cycle | Status | Origin |
|---|---|---|---|
| 37 | W1 Layered 4+1 + Graph (2026-05-14) | Active | architecture_artefact_front_matter — every ADR.yaml / L2.md / ARCHITECTURE.md declares level: + view:. Enforcer E55. |
| 38 | W1 Layered 4+1 + Graph (2026-05-14) | Active | architecture_graph_well_formed — graph builds without validation errors. Enforcer E56. |
| 39 | W1 Layered 4+1 + Graph (2026-05-14) | Active | review_proposal_front_matter — docs/reviews/*.md declare affects_level: + affects_view:. Enforcer E57. |
| 40 | W1 Layered 4+1 + Graph (2026-05-14) | Active | enforcer_reachable_from_principle — every enforcer has at least one rule→enforcer edge. Enforcer E58. |
| 41 | Phase M (2026-05-14) | Active | enforcer_anchor_resolves — every artefact anchor resolves to a real method/heading/key. Enforcer E60. |
| 42 | Phase M (2026-05-14) | Active | architecture_graph_idempotent — twice-run graph build is byte-identical. Enforcer E61. |
| 43 | Phase M (2026-05-14) | Active | new_adr_must_be_yaml — highest-numbered ADR is .yaml, not .md. Enforcer E62. |
| 44 | Phase M (2026-05-14) | Active | frozen_doc_edit_path_compliance — modifications to freeze_id-tagged files require an accompanying docs/reviews/*.md proposal. Enforcer E63. |

---

## Retired-rule notes

### Rule 12 — Maturity L0–L4

Originally a four-step maturity ladder (`L0` design → `L1` impl → `L2` tested →
`L3` shipped → `L4` audited). Replaced because in practice every audit reduced
to a binary "is the row in `architecture-status.yaml` marked `shipped: true`
and backed by a real test class?". Multiple maturity buckets produced status
drift and gave reviewers an excuse to claim partial credit. The binary
`shipped:` + the `tests:` evidence list is the truth.

---

## Cleanup notes (2026-05-14)

The following content moved out of `CLAUDE.md` into this file:

- Narrative paragraph ("Twelve active rules. Rules 1–4 are daily-use…") — replaced by the Layer-0 / Layer-1 framing in `CLAUDE.md`.
- Per-rule "added in N-th review cycle" annotations — captured in the table above.
- "Rule 12 replaced by binary `shipped:`" sentence — captured in the retired-rule note above.
- "Constraint Coverage by First Principle" section — moved to [`principle-coverage.yaml`](principle-coverage.yaml) (Phase M retired the prior `.md` form per ADR-0068).
- "W0 posture coverage" table inside Rule 10 — moved to [`posture-coverage.md`](posture-coverage.md).
