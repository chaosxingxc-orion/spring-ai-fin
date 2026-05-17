---
rule_id: 38
title: "No Thread.sleep in Business Code"
level: L1
view: process
principle_ref: P-H
authority_refs: [ADR-0069]
enforcer_refs: [E67]
status: active
kernel_cap: 8
kernel: |
  **No production class under `agent-platform/src/main/java/**` or `agent-runtime/src/main/java/**` may invoke `Thread.sleep(...)` or `TimeUnit.<unit>.sleep(...)`. Long-horizon waits MUST be expressed as declarative suspension (`SuspendSignal`) and resumed by the bus-level Tick Engine.**
---

## Motivation

The L0 motivation (LucioIT W1 §6.4): physical sleep holds a thread for the wait duration; with 1000 sleeping agents, the system is paralysed. Chronos Hydration self-destructs the sleeping process and re-hydrates it on the bus wake-pulse.

## Cross-references

- Enforced by Gate Rule 48 (`no_thread_sleep_in_business_code`) — source scan for `Thread.sleep` and `TimeUnit.<x>.sleep`. Test code (`src/test/java`), gate scripts, and Awaitility usage are excluded.
- Architecture reference: ADR-0069 / LucioIT W1 §6.4.
- Cross-cited by Rule 46 ([`rule-46.md`](rule-46.md)) envelope-propagation matrix and asserted independently for the S2C surface by E83 (`S2cCallbackRespectsRule38Test` — no Thread.sleep in s2c..).
- Companion rule: Rule 41 ([`rule-41.md`](rule-41.md)) — Skill Capacity Matrix (over-cap callers are SUSPENDED via the same Chronos Hydration interlock).
