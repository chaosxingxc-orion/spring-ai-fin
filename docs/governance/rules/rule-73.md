---
rule_id: 73
title: "Gate Config Well-Formed"
level: L0
view: scenarios
principle_ref: P-D
authority_refs: [ADR-0077]
enforcer_refs: [E103]
status: active
kernel_cap: 8
kernel: |
  **`gate/config.yaml` MUST validate against `gate/config.schema.yaml`. The gate fails closed on: missing required keys at any level, type mismatch, value outside declared min/max range, unknown keys (typo detection via `additionalProperties: false`), enum violation. Schema follows the wave's structural invariant: yaml → loader-validated env-vars → runtime-checked.**
---

## Motivation

The token-optimization wave Phase 2 introduces `gate/config.yaml` so concurrency / logging / retention / regression-detection knobs are user-editable without code changes. The most common foot-gun in a config-driven system is silent misconfiguration: a typo (`parallelism.cores` instead of `parallelism.jobs`) accepts the default and silently disables what the user thought they configured. Rule 73 makes every misconfiguration fail loudly at gate boot, before any rule runs.

## Details

The validator (`gate_validate_config_against_schema` in `gate/lib/load_config.sh`) performs:

1. **Required-keys check** — every key declared `required` in the schema MUST appear in the config.
2. **Type check** — `integer`, `boolean`, `string`, `array` enforced per leaf.
3. **Range check** — `minimum` / `maximum` for ints and floats.
4. **Enum check** — `batch_strategy ∈ {round_robin, longest_first}`, `stdout_format ∈ {human, quiet, json}`, etc.
5. **Unknown-key check** — `additionalProperties: false` means any key not declared in the schema fails closed (typo detection).

Schema authority: `gate/config.schema.yaml` follows JSON Schema draft-07 conventions but is parsed by a pure-bash validator (no `jsonschema` dependency). Adding a new config knob requires editing both files in the same PR.

## Cross-references

- Enforcer E103 — `gate/check_architecture_sync.sh#gate_config_well_formed`.
- Companion: Rule 48 (Schema-First Domain Contracts) — this rule is the in-gate expression of the schema-first doctrine for the gate's own configuration.
- Companion: Rule 70 (always-loaded byte budget) — both rules together protect the gate from silent regression.
- Authority: token-optimization wave Phase 2 plan + ADR-0077.
