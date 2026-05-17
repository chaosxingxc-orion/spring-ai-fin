---
rule_id: 29
title: "Business/Platform Decoupling Enforcement"
level: L0
view: development
principle_ref: P-A
authority_refs: [ADR-0064]
enforcer_refs: [E48, E49]
status: active
kernel_cap: 8
kernel: |
  **Platform code MUST NOT contain business-specific customizations. Business and example code MUST extend the platform via SPI + `@ConfigurationProperties` only — never by patching `*.impl.*` or `ascend.springai.platform..`. The platform MUST ship a runnable quickstart (`docs/quickstart.md`) referenced from `README.md` so a developer reaches first-agent execution without platform-team intervention.**
---

## Motivation

Rule 29 is the in-repo enforceable expression of governing principle P-A (Business / Platform Decoupling + Developer Self-Service). Once any business-specific customization lands in platform code, every downstream tenant becomes a constraint on platform evolution; once any extension requires platform-team intervention, the platform stops being self-service. The two structural conditions — SPI-only extension and a runnable quickstart referenced from README — make decoupling and self-service simultaneously testable.

## Details

Enforced by E48 (`SpiPurityGeneralizedArchTest`) and Gate Rule 31 (`quickstart_present`).

## Cross-references

- ADR-0064 — origin decision record.
- P-A — governing principle Rule 29 operationalises.
- Architecture reference: §4 #60.
- Deferred sub-clause 29.c — quickstart smoke-run in CI (W1 trigger).
- Rule 32 (SPI + DFX + TCK Co-Design) — co-enforced by E48 on the SPI purity side.
