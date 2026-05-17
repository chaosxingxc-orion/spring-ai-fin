---
principle_id: P-D
title: "SPI-Aligned, DFX-Explicit, Spec-Driven, TCK-Tested"
level: L0
view: development
authority: "Layer 0 governing principle (CLAUDE.md)"
enforced_by_rules: [32]
kernel: |
  P-D — SPI-Aligned, DFX-Explicit, Spec-Driven, TCK-Tested.
  Every domain module ships an SPI;
  every platform/domain module declares its Design-for-X posture
  (releasability, resilience, availability, vulnerability, observability);
  contracts precede implementation;
  alternative implementations must pass a TCK to be conformant.
  Enforced by Rule 32 (TCK content deferred per `CLAUDE-deferred.md` 32.b/32.c).
---

## Motivation

This principle exists because a platform without a published **SPI** ends up with implicit contracts that drift in every refactor, a platform without explicit **Design-for-X posture** ships with unknown failure modes, and a platform without a **TCK** cannot make compatibility claims about third-party adapters. The four sub-disciplines compose: SPI declares the surface, DFX yaml declares the operational posture across five dimensions (releasability, resilience, availability, vulnerability, observability), spec-driven design forces the contract to land before code, and the TCK turns "X is a valid implementation of Y" from social claim into executable assertion.

## Operationalising rules

- Rule 32 — SPI + DFX + TCK Co-Design ([`docs/governance/rules/rule-32.md`](../rules/rule-32.md))

## Cross-references

- ADR-0067 (origin of Rule 32 and the per-module DFX yaml schema)
- Deferred sub-clauses 32.b (TCK module scaffolding), 32.c (TCK conformance content), 32.d (vulnerability-scanner integration) — see [`docs/CLAUDE-deferred.md`](../../CLAUDE-deferred.md)
- Related: P-C (Independent Modules) — SPI surface is what makes independent evolution safe
- Related: Rule 48 (Schema-First Domain Contracts) — extends spec-driven discipline to every fixed-vocabulary taxonomy
