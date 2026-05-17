---
principle_id: P-H
title: "Chronos Hydration"
level: L0
view: process
authority: "Layer 0 governing principle (CLAUDE.md); LucioIT W1 L0 §6-§7"
enforced_by_rules: [38]
kernel: |
  P-H — Chronos Hydration.
  Long-horizon waits in business code MUST be declarative suspension
  (`SuspendSignal`), not physical thread sleep.
  The sleeping process self-destructs and re-hydrates on the bus wake-pulse.
  Enforced by Rule 38.
---

## Motivation

This principle exists because **physical sleep holds a thread for the entire wait duration** — with 1000 sleeping agents across long-horizon orchestrations, the system is paralysed even though zero CPU work is happening. Chronos Hydration replaces the sleeping thread with a `SuspendSignal` checkpoint: the process record persists, the OS thread returns to the pool, and the bus wake-pulse re-hydrates the process when the wait condition resolves. This is the runtime counterpart to P-G's non-blocking I/O — together they guarantee no agent ever holds an OS thread while waiting on time, an external API, or a downstream callback.

## Operationalising rules

- Rule 38 — No Thread.sleep in Business Code ([`docs/governance/rules/rule-38.md`](../rules/rule-38.md))

## Cross-references

- ADR-0069 (origin of Rules 35–42 and the LucioIT W1 §6.4 Chronos Hydration doctrine)
- ADR-0019 (origin of `SuspendSignal` as compile-time-visible suspension)
- Related: P-G (Non-Blocking I/O) — Chronos Hydration is the wait-side companion to non-blocking call-side
- Related: Rule 46 (S2C Callback Envelope) — S2C suspend reuses the SuspendSignal mechanism (sealed checked-suspension variant)
- Test code, gate scripts, and Awaitility usage are explicitly excluded from Rule 38 scans
