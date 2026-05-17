---
rule_id: 3
title: "Pre-Commit Checklist"
level: L1
view: process
principle_ref: P-A
authority_refs: []
enforcer_refs: []
status: active
kernel_cap: 12
kernel: |
  Before every commit, audit every touched file. Fix defects before committing — "I'll fix it later" is forbidden. **Smoke + lint** required before commits touching server entry points, runtime adapters, or dependency-wiring modules.
---

## Motivation

"I'll fix it later" is the most reliable predictor of a defect that ships. Every touched file gets a five-dimension audit before the commit lands — contract truth, orphan config, error visibility, lint, and test honesty. Commits touching high-blast-radius surfaces (server entry points, runtime adapters, dependency-wiring modules) additionally require a smoke run plus full lint before the commit closes.

## Details

| Dimension | Check |
|-----------|-------|
| **Contract truth** | No empty stubs, `TODO`-bodied methods, or `UnsupportedOperationException` placeholders shipped on the default path. |
| **Orphan config** | Every parameter / config field / env var is consumed downstream. |
| **Error visibility** | No silent swallow. Every catch re-raises, logs at `WARNING+`, or converts to typed failure. |
| **Lint green** | Project linter exits 0. No suppression added in the same commit as the offending line. |
| **Test honesty** | No mocks on the unit under test in integration tests. No assertion that accepts failure as success. |

**Smoke + lint** required before commits touching server entry points, runtime adapters, or dependency-wiring modules.

## Cross-references

- Rule 4 (Three-Layer Testing, With Honest Assertions) — the "Test honesty" dimension is operationalised in detail there.
- Rule 9 (Self-Audit is a Ship Gate, Not a Disclosure) — checklist findings that touch ship-blocking categories block the PR.
- Rule 2 (Simplicity & Surgical Changes) — the "orphan config" check enforces the no-speculative-features clause at commit time.
