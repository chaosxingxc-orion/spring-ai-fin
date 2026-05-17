---
rule_id: 69
title: "Every Active Rule Has a Card"
level: L0
view: scenarios
principle_ref: P-C
authority_refs: []
enforcer_refs: [E99]
status: active
kernel_cap: 8
kernel: |
  **Every `#### Rule NN` heading in `CLAUDE.md` MUST have a sibling `docs/governance/rules/rule-NN.md` (zero-padded). Every card MUST either appear as a heading in `CLAUDE.md` or as a `Rule NN` reference in `docs/CLAUDE-deferred.md`. Orphan cards that satisfy neither fail the gate.**
---

## Motivation

The kernel-and-card split is a contract: if a rule appears in CLAUDE.md, its expanded body MUST be reachable on disk; if a card exists, it MUST be either active (cited from CLAUDE.md) or deferred (cited from CLAUDE-deferred.md). Rule 69 makes both halves of the contract machine-checked. Without it, kernel shrinks could silently lose detail (rule in CLAUDE.md, no card) or stale cards could accumulate (card on disk, rule deleted).

## Details

The gate computes two sets:

1. **Active rule numbers** — extracted from `^#### Rule NN` headings in CLAUDE.md.
2. **Card numbers** — extracted from filenames `docs/governance/rules/rule-NN.md` (zero-padding stripped).

It fails on:

- **Missing cards**: a rule heading in CLAUDE.md with no matching card file.
- **Orphan cards**: a card file whose rule number is neither in CLAUDE.md nor mentioned as `Rule NN` (or `Rule NN.x` for sub-clauses) in `docs/CLAUDE-deferred.md`.

During the initial PR1 landing the `docs/governance/rules/` directory may not yet exist — the rule is vacuously true in that case so other rules can land first.

## Cross-references

- Enforcer E99 — `gate/check_architecture_sync.sh#every_active_rule_has_card`.
- Companion: Rule 67 (size cap), Rule 68 (byte-identity), Rule 71 (deferred-doc demote).
- Authority: token-optimization wave PR1.
