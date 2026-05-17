---
rule_id: 21
title: "Tenant Propagation Purity"
level: L1
view: development
principle_ref: P-A
authority_refs: [ADR-0023, ADR-0055]
enforcer_refs: [E2]
status: active
kernel_cap: 8
kernel: |
  **No production class under `ascend.springai.runtime..` (main sources) may import any class under `ascend.springai.platform..`. The original narrow case — no import of `TenantContextHolder` — remains the specific instance most likely to be violated and is asserted independently as defence-in-depth.**
---

## Motivation

`TenantContextHolder` is a request-scoped HTTP-edge ThreadLocal (valid only for the duration of an HTTP request). Runtime production code MUST source tenant identity from `RunContext.tenantId()` instead. Timer-driven resumes and async orchestration have no HTTP request and would silently receive null from the ThreadLocal. The L1 generalisation (ADR-0055) extends the ban from the single ThreadLocal class to the whole platform package, because every platform-side class encodes request-scoped or HTTP-edge concerns that have no defined meaning in runtime contexts (timer-driven resumes, async orchestration, Temporal activities).

## Details

Enforced by `RuntimeMustNotDependOnPlatformTest` (ArchUnit — broad, L1 contract per ADR-0055) and `TenantPropagationPurityTest` (ArchUnit — narrow, original Rule 21 per ADR-0023). Test classes are intentionally excluded — `TenantContextFilterTest` may read the holder to verify filter behaviour.

## Cross-references

- ADR-0023 — original Rule 21 (narrow `TenantContextHolder` ban).
- ADR-0055 — L1 generalisation to the whole `ascend.springai.platform..` package.
- Architecture reference: §4 #22.
- Rule 6 (Single Construction Path Per Resource Class) — tenant scope as a required constructor argument is the structural enforcement complement.
