---
rule_id: 41
title: "Skill Capacity Matrix"
level: L1
view: physical
principle_ref: P-K
authority_refs: [ADR-0069, ADR-0070]
enforcer_refs: [E70, E73]
status: active
kernel_cap: 8
kernel: |
  **`docs/governance/skill-capacity.yaml` MUST exist and declare, per skill, both `capacity_per_tenant` and `global_capacity` fields plus a `queue_strategy` (`suspend` or `fail`). The runtime `ResilienceContract.resolve(tenant, skill)` MUST consult this matrix; over-cap callers are SUSPENDED, not rejected (Chronos Hydration interlock with Rule 38).**
---

## Motivation

The L0 motivation (LucioIT W1 §7.3): a single high-frequency skill (slow external API) can exhaust the cluster's connection pool and CPU. The 2D defence net (Tenant Quota × Global Skill Capacity) lets the scheduler suspend only the Agent processes blocked on that specific skill, leaving lightweight reasoning tasks free to proceed on freed OS threads.

## Cross-references

- Enforced by Gate Rule 51 (`skill_capacity_yaml_present_and_wellformed`) — schema check.
- Architecture reference: ADR-0069 / LucioIT W1 §7.3.
- Runtime enforcement activated in W1.x Phase 9 (`SkillCapacityResolutionIT.suspendsSecondCallerWhenCapacityIsOne`, enforcer E73, gate Rule 54 per ADR-0070); the original 41.b deferral closed.
- Cross-cited by Rule 46 ([`rule-46.md`](rule-46.md)) envelope-propagation matrix — S2C callbacks consume the `s2c.client.callback` skill capacity.
- Companion rule: Rule 38 ([`rule-38.md`](rule-38.md)) — No Thread.sleep in Business Code (Chronos Hydration interlock).
