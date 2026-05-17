---
rule_id: 20
title: "Run State Transition Validity"
level: L1
view: logical
principle_ref: P-A
authority_refs: [ADR-0020]
enforcer_refs: []
status: active
kernel_cap: 8
kernel: |
  **Every `Run.withStatus(newStatus)` mutation MUST call `RunStateMachine.validate(this.status, newStatus)` before constructing the updated record. Illegal transitions MUST throw `IllegalStateException`.**
---

## Motivation

A Run is the durable identity that crosses tiers (in-memory, Postgres, Temporal) and stages (cancellation, suspend, resume, expire). Without a single validating gate on every status mutation, terminal states leak into RUNNING transitions, suspended Runs resume into FAILED, and the suspend/resume loop accumulates ghost states. Centralising the DFA in `RunStateMachine.validate` makes every illegal mutation a compile-time-visible call site that throws — debuggers, traces, and unit tests all converge on the same predicate.

## Details

Legal DFA: `PENDING → RUNNING | CANCELLED`; `RUNNING → SUSPENDED | SUCCEEDED | FAILED | CANCELLED`; `SUSPENDED → RUNNING | EXPIRED | FAILED | CANCELLED`; `FAILED → RUNNING`; `SUCCEEDED`, `CANCELLED`, `EXPIRED` are terminal.

Enforced by `RunStateMachine.validate(from, to)` (wired into `Run.withStatus` + `Run.withSuspension`) and unit-tested in `RunStateMachineTest`.

## Cross-references

- ADR-0020 — original decision record.
- Architecture reference: §4 #20.
- Rule 46 (S2C Callback Envelope + Lifecycle Bound) — S2C invalid-response path transitions Run to FAILED with reason `s2c_response_invalid` via this state machine.
