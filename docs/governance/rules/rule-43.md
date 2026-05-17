---
rule_id: 43
title: "Engine Envelope Single Authority"
level: L1
view: development
principle_ref: P-M
authority_refs: [ADR-0072]
enforcer_refs: [E74, E76]
status: active
kernel_cap: 8
kernel: |
  **Every Run dispatch MUST go through `EngineRegistry.resolve(envelope)` (or the convenience `resolveByPayload(def)`). Pattern-matching on `ExecutorDefinition` subtypes outside `ascend.springai.runtime.engine.EngineRegistry` is forbidden. The envelope schema `docs/contracts/engine-envelope.v1.yaml` is the single source of truth for engine metadata; the `EngineEnvelope` Java record mirrors the schema and validates required fields (nullability, blanks) on construction. `known_engines` membership is enforced by `EngineRegistry.resolve(...)` and registry boot validation (Phase 5 R2 pilot — enforcer E84); constructor-level membership validation is deferred to Rule 48.c.**
---

## Motivation

Authority: ADR-0072 / P-M. Part of the W2.x Engine Contract Structural Wave that absorbs the 2026-05-15 L0 proposal "Runtime-Engine Contract for Heterogeneous Agent Execution". Follows the wave's structural invariant: every new domain contract ships as `yaml schema → Java type that validates REQUIRED FIELDS on construction → runtime self-validates membership and other invariants at registry boot / dispatch`.

## Cross-references

- Enforced by Gate Rule 55 (`engine_envelope_yaml_present_and_wellformed`, enforcer E76) and ArchUnit E74 (`EnginePayloadDispatchOnlyViaRegistryTest` — every concrete Orchestrator implementation depends on EngineRegistry).
- Strict construction-time membership validation for `EngineEnvelope` deferred to Rule 48.c (re-introduction trigger: first envelope built outside the Spring-boot test harness).
- Schema source: `docs/contracts/engine-envelope.v1.yaml`.
- Companion rule: Rule 44 ([`rule-44.md`](rule-44.md)) — Strict Engine Matching.
- Companion rule: Rule 48 ([`rule-48.md`](rule-48.md)) — Schema-First Domain Contracts (the cross-cutting invariant Rule 43 instantiates).
