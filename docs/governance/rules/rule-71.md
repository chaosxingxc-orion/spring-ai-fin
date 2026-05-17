---
rule_id: 71
title: "Deferred Doc Not in Always-Loaded Set"
level: L0
view: scenarios
principle_ref: P-B
authority_refs: []
enforcer_refs: [E101]
status: active
kernel_cap: 8
kernel: |
  **`docs/CLAUDE-deferred.md` MUST NOT be auto-injected into the session context: no `@docs/CLAUDE-deferred.md` include directive in `CLAUDE.md`, and no `ALWAYS` / `ALWAYS-LOAD` marker on its row in `docs/governance/SESSION-START-CONTEXT.md`. Plain prose pointers ("see `docs/CLAUDE-deferred.md`") are fine — only the auto-load mechanisms are forbidden.**
---

## Motivation

CLAUDE-deferred.md (~9.3K tokens) is consulted only when a re-introduction trigger fires for a deferred rule — a rare per-session event. Auto-injecting it as part of the always-loaded set wastes those tokens on every conversation. Rule 71 keeps the demote durable: after PR1 lands, no future edit can silently re-add it to the always-loaded path.

## Details

The gate scans two surfaces:

1. **CLAUDE.md** — lines matching `^@docs/CLAUDE-deferred\.md` (the Claude Code auto-load include syntax). Plain Markdown references to `docs/CLAUDE-deferred.md` (without the `@` auto-load prefix) are allowed and unaffected.
2. **SESSION-START-CONTEXT.md** — lines mentioning `CLAUDE-deferred.md` are filtered for `ALWAYS` or `ALWAYS-LOAD` markers in the Load column. The intended row uses `(ON-DEMAND)` to mark the file as load-on-trigger.

Either signal fails the gate.

## Cross-references

- Enforcer E101 — `gate/check_architecture_sync.sh#deferred_doc_not_in_always_loaded`.
- Companion: Rule 70 (byte budget) — `docs/CLAUDE-deferred.md` is given ceiling `0` in the budget file after demote.
- Authority: token-optimization wave PR1.
