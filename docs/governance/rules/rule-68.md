---
rule_id: 68
title: "CLAUDE.md Kernel Matches Card"
level: L0
view: scenarios
principle_ref: P-C
authority_refs: []
enforcer_refs: [E98]
status: active
kernel_cap: 8
kernel: |
  **For every `docs/governance/rules/rule-NN.md` card, the `kernel:` scalar in YAML front-matter MUST byte-match (after whitespace normalisation) the body paragraph under `#### Rule NN` in `CLAUDE.md`. Drift in either direction fails the gate.**
---

## Motivation

When source-of-truth splits across two files, drift is inevitable without a mechanical check. Rule 68 makes the kernel in CLAUDE.md (what the agent reads at session start) and the card body (where motivation, tables, and sub-clauses live) provably consistent: the binding paragraph in the card front-matter is byte-identical (after whitespace normalisation) with the paragraph in CLAUDE.md.

## Details

Normalisation steps applied to both sides before comparison:

1. Strip CR characters (`tr -d '\r'`)
2. Collapse runs of spaces and tabs to a single space (`tr -s ' \t' ' '`)
3. Join lines (`tr '\n' ' '`)
4. Collapse multi-space runs again (`tr -s ' '`)
5. Strip leading/trailing whitespace

The card's `kernel:` field supports both YAML literal block style (`|`) and single-line scalar. Either works; the awk extractor handles both.

For Rule 28 and Rule 46 (the longest rules), the kernel preserves the bolded imperative plus any embedded numbered list (Rule 28's five enforcement surfaces). The card body holds the Constraint State Taxonomy table (Rule 28) and the envelope-propagation matrix reference (Rule 46) — these do NOT participate in the kernel byte-comparison.

## Cross-references

- Enforcer E98 — `gate/check_architecture_sync.sh#claude_md_kernel_matches_card`.
- Companion: Rule 67 (size cap), Rule 69 (every rule has a card).
- Authority: token-optimization wave PR1.
