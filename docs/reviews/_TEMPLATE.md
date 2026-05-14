---
# REQUIRED: edit both values before submitting. The defaults below are valid
# YAML so the gate doesn't fail-open on an unedited copy — but a reviewer who
# leaves them unchanged is misclassifying their proposal. Pick the actual
# level + view for your change.
affects_level: L1                # one of: L0 | L1 | L2
affects_view: scenarios          # one of: logical | development | process | physical | scenarios
proposal_status: draft           # draft | review | accepted | rejected
authors: ["Your Name"]
related_adrs: []                 # e.g. [ADR-0068]
related_rules: []                # e.g. [Rule-33, Rule-34]
affects_artefact: []             # paths of frozen artefacts this proposal unfreezes; empty if none
---

# <Short title — what the proposal changes>

> **Date:** YYYY-MM-DD
> **Status:** Draft / Pending Review / Accepted / Rejected
> **Affects:** declared in front-matter above (see ADR-0068 + CLAUDE.md Rule 33)

## 1. Background

Why are you proposing this? One paragraph. Link to the original defect, issue, review comment, or architectural decision that surfaced the need.

## 2. Scope statement

Which **level** and **view** does this change touch? Cross-check the front-matter above.

- If `affects_level: L0` — you are amending a governing principle. Chief Architect approval required.
- If `affects_level: L1` — you are amending a per-module / per-vertical contract. Module-owner sign-off required.
- If `affects_level: L2` — you are amending a feature-specific technical detail.

If the change touches more than one view, name the **primary** view in front-matter and list secondary ones inline here.

## 3. Root cause / strongest interpretation (Rule 1)

Mandatory four-line block before any plan:

1. **Observed failure / motivation**: <one sentence>
2. **Execution path**: <which function/sequence>
3. **Root cause**: <one sentence — "X happens because Y at line Z, which causes W">
4. **Evidence**: <file:line references>

## 4. Proposed change

What concretely changes:

- Code paths touched: `<list>`
- ADRs introduced / superseded / extended: `<list>`
- Rules introduced / amended: `<list>`
- Gate rules introduced / amended: `<list>`
- Tests introduced / amended: `<list>`

## 5. Alternatives considered

| Alternative | Why rejected |
|---|---|
| A | ... |
| B | ... |

## 6. Verification plan

How will we know it works?

- [ ] `bash gate/check_architecture_sync.sh` passes
- [ ] `bash gate/build_architecture_graph.sh --check` passes
- [ ] New tests pass: `<list>`
- [ ] Manual verification: `<steps>`

## 7. Rollout

- Wave: W1 / W2 / W3 / W4
- Freeze impact: does this require unfreezing a phase-released L0/L1 artefact? If yes, name the artefact and the freeze id.

## 8. Self-audit (Rule 9)

Open findings in any ship-blocking category? `<yes/no + list>`

---

## Authority

- CLAUDE.md Rule 33 (Layered 4+1 Discipline) — every proposal declares `affects_level:` + `affects_view:` front-matter.
- CLAUDE.md Rule 34 (Architecture-Graph Truth) — every proposal that changes the graph must update authoritative inputs, never hand-edit `architecture-graph.yaml`.
- ADR-0068 (Layered 4+1 + Architecture Graph as Twin Sources of Truth).
- Gate Rule 39 (`review_proposal_front_matter`) — validates this front-matter on every CI run.
