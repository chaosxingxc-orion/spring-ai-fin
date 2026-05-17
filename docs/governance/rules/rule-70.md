---
rule_id: 70
title: "Always-Loaded Byte Budget"
level: L0
view: scenarios
principle_ref: P-B
authority_refs: []
enforcer_refs: [E100]
status: active
kernel_cap: 8
kernel: |
  **Every file listed in `gate/always-loaded-budget.txt` MUST be at or below its declared byte ceiling. `gate/measure_always_loaded_tokens.sh` walks the budget file and exits non-zero on any overage. A ceiling of `0` means the file is kept on disk but excluded from the always-loaded budget (used after a file has been demoted to on-demand).**
---

## Motivation

Token cost compounds across every conversation. Without a per-file budget gate, the governance corpus drifts back to multi-megabyte size as soon as a contributor "just adds one more paragraph." Rule 70 makes the per-session token cost a first-class, machine-checked constraint: the budget file declares the ceilings, the measure script reports current bytes/lines/tokens, and any regression fails the gate.

## Details

The budget format is `<relpath>=<max_bytes>`, one per line. Comments start with `#`. The token estimate uses `bytes / 4` as a conservative heuristic (English+code prose averages ~3.8–4.2 chars/token in production tokenisers).

After the token-optimization wave lands:

- `CLAUDE.md` ceiling = 8000 bytes (post-shrink target ~6 KB)
- `ARCHITECTURE.md` ceiling tightened to 8000 bytes after PR4 (4+1 view sharding)
- `architecture-graph.yaml` / `architecture-status.yaml` ceilings drop to 0 after PR2/PR3 (sharded; manifests live in `docs/governance/graph/` and `docs/governance/status/`)
- `CLAUDE-deferred.md` ceiling = 0 after PR1 (demoted to on-demand)

The budget file is the single source of truth for "what is always loaded" and is the seat of any future tightening.

## Cross-references

- Enforcer E100 — `gate/check_architecture_sync.sh#always_loaded_budget_enforced`.
- Script: `gate/measure_always_loaded_tokens.sh`.
- Budget file: `gate/always-loaded-budget.txt`.
- Companion: Rule 71 (deferred-doc demote).
- Authority: token-optimization wave PR1.
