---
rule_id: 67
title: "CLAUDE.md Kernel Size Bounded"
level: L0
view: scenarios
principle_ref: P-C
authority_refs: []
enforcer_refs: [E97]
status: active
kernel_cap: 8
kernel: |
  **Each `#### Rule NN` section in `CLAUDE.md` MUST fit under the `kernel_cap:` declared in the matching `docs/governance/rules/rule-NN.md` card. Daily principles (Rules 1, 2, 3, 4, 9, 10) cap at 12 lines below the heading; architectural and ironclad rules (Rules 5, 6, 20–48 + 67–71) cap at 8.**
---

## Motivation

Without a per-section size cap, CLAUDE.md drifts back to monolithic motivation paragraphs as soon as a reviewer asks for "just a little more context." Rule 67 makes the cap a machine-checked invariant: each rule's body in CLAUDE.md is measured against the cap declared in its card front-matter. Daily principles get more room (12 lines) because they're read on every task; architectural rules get less room (8 lines) because their detail belongs in the on-demand card.

## Details

The gate counts lines from the `#### Rule NN` heading until the next `---` separator (exclusive of the separator). The card's `kernel_cap:` field is read from YAML front-matter. If a card does not exist, Rule 67 is SKIPPED for that section (Rule 69 catches the missing card).

The cap discipline is rule-class-specific because:

- **Daily principles (cap 12)** legitimately need a short bullet list inline (Rule 3's pre-commit dimensions, Rule 4's three layers). Loading the card on every task would be wasteful.
- **Architectural / ironclad (cap 8)** are referenced by file path or feature touch; their detail is on-demand and belongs in the card body, not the kernel.

## Cross-references

- Enforcer E97 — `gate/check_architecture_sync.sh#claude_md_kernel_size_bounded`.
- Companion: Rule 68 (kernel ↔ card byte-identity), Rule 69 (every rule has a card), Rule 70 (always-loaded byte budget).
- Authority: token-optimization wave PR1 — D:/.claude/plans/tokens-token-buzzing-sprout.md.
