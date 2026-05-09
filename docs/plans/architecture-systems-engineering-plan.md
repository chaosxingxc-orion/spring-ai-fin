# Architecture Systems-Engineering Plan -- L0 / L1 / L2 Drill-Down

> Companion to `ARCHITECTURE.md` and
> `docs/plans/engineering-plan-W0-W4.md`. This plan handles the
> documentation drill-down only: which L1/L2 files exist, what each one
> covers, what is removed, and the order of rewriting. **This is not a
> design plan -- design is in ARCHITECTURE.md; this is the document-level execution
> plan that makes the refresh actually visible at every subdirectory.**
>
> **Last refreshed:** 2026-05-08
> **Cadence rule:** the refresh document set is rewritten in one coordinated
> pass (this plan), not cycle-by-cycle. After this pass, doc changes
> ride on the wave that introduces real artifact change.

## 0. The drill-down hierarchy

```
L0 (system boundary)        ARCHITECTURE.md            [done]
|
+-- L1 agent-platform       agent-platform/ARCHITECTURE.md       [rewrite]
|   |
|   +-- L2 web              agent-platform/web/ARCHITECTURE.md           [new]
|   +-- L2 auth             agent-platform/auth/ARCHITECTURE.md          [new]
|   +-- L2 tenant           agent-platform/tenant/ARCHITECTURE.md        [new]
|   +-- L2 idempotency      agent-platform/idempotency/ARCHITECTURE.md   [new]
|   +-- L2 bootstrap        agent-platform/bootstrap/ARCHITECTURE.md     [rewrite, slim]
|   +-- L2 config           agent-platform/config/ARCHITECTURE.md        [rewrite, slim]
|   +-- L2 contracts        agent-platform/contracts/ARCHITECTURE.md     [rewrite, slim -> OpenAPI]
|
+-- L1 agent-runtime        agent-runtime/ARCHITECTURE.md        [rewrite]
|   |
|   +-- L2 run              agent-runtime/run/ARCHITECTURE.md            [new; supersedes server/, runner/, runtime/]
|   +-- L2 llm              agent-runtime/llm/ARCHITECTURE.md            [rewrite]
|   +-- L2 tool             agent-runtime/tool/ARCHITECTURE.md           [new; supersedes skill/, capability/]
|   +-- L2 action           agent-runtime/action/ARCHITECTURE.md         [new; replaces action-guard/ 11-stage with 5-stage]
|   +-- L2 memory           agent-runtime/memory/ARCHITECTURE.md         [rewrite]
|   +-- L2 outbox           agent-runtime/outbox/ARCHITECTURE.md         [rewrite]
|   +-- L2 temporal         agent-runtime/temporal/ARCHITECTURE.md       [new]
|   +-- L2 observability    agent-runtime/observability/ARCHITECTURE.md  [rewrite, slim]
|
+-- agent-eval              agent-eval/ARCHITECTURE.md           [new; W4]

Cross-cutting docs (no L2 home; live under docs/):
+-- docs/cross-cutting/security-control-matrix.md         [rewrite, slim]
+-- docs/cross-cutting/observability-policy.md            [new; supersedes cardinality-policy.md]
+-- docs/cross-cutting/posture-model.md                   [new; supersedes posture/ARCHITECTURE.md]
+-- docs/cross-cutting/sidecar-security-profile.md        [DEFERRED -> docs/v6-rationale/]
+-- docs/cross-cutting/gateway-conformance-profile.md     [DEFERRED -> docs/v6-rationale/]
+-- docs/cross-cutting/secrets-lifecycle.md               [rewrite, slim]
+-- docs/cross-cutting/supply-chain-controls.md           [rewrite, slim]
+-- docs/cross-cutting/trust-boundary-diagram.md          [rewrite, slim]
```

## 1. Disposition table (one row per existing v6 doc)

`Disposition` codes:

- `KEEP` -- this file remains in place; content rewritten to the refresh form.
- `MERGE -> X` -- content folds into another file; this file moves to v6-rationale.
- `RENAME -> X` -- this file's path changes; content rewritten.
- `DEFER -> v6-rationale` -- removed from current-refresh active corpus; archived.
- `NEW` -- file does not exist yet; will be created in this pass.

| v6 path                                          | refresh disposition                                | refresh path                                         | Wave     |
|---|---|---|---|
| `ARCHITECTURE.md`                                | DEFER -> v6-rationale (banner only kept)      | (archived after W0)                             | W0       |
| `agent-platform/ARCHITECTURE.md`                 | KEEP (rewrite)                                | same                                            | this pass |
| `agent-platform/contracts/ARCHITECTURE.md`       | KEEP (rewrite, slim, lead with OpenAPI)       | same                                            | this pass |
| `agent-platform/api/ARCHITECTURE.md`             | MERGE -> `agent-platform/web/`                | (moved into web)                                | this pass |
| `agent-platform/runtime/ARCHITECTURE.md`         | DEFER -> v6-rationale                         | (archived; Spring Boot main covers this)        | W0       |
| `agent-platform/facade/ARCHITECTURE.md`          | DEFER -> v6-rationale                         | (archived; merged into agent-platform L1)       | W0       |
| `agent-platform/bootstrap/ARCHITECTURE.md`       | KEEP (rewrite, slim, PostureBootGuard only)   | same                                            | this pass |
| `agent-platform/cli/ARCHITECTURE.md`             | DEFER -> v6-rationale                         | (CLI is not in W0-W4)                           | W0       |
| `agent-platform/config/ARCHITECTURE.md`          | KEEP (rewrite, slim, Spring Cloud Config)     | same                                            | this pass |
| `agent-runtime/ARCHITECTURE.md`                  | KEEP (rewrite)                                | same                                            | this pass |
| `agent-runtime/server/ARCHITECTURE.md`           | RENAME -> `agent-runtime/run/`                | `agent-runtime/run/ARCHITECTURE.md`             | this pass |
| `agent-runtime/runner/ARCHITECTURE.md`           | MERGE -> `agent-runtime/run/`                 | (merged)                                        | this pass |
| `agent-runtime/runtime/ARCHITECTURE.md`          | MERGE -> `agent-runtime/temporal/` + `run/`   | (merged)                                        | this pass |
| `agent-runtime/llm/ARCHITECTURE.md`              | KEEP (rewrite)                                | same                                            | this pass |
| `agent-runtime/skill/ARCHITECTURE.md`            | MERGE -> `agent-runtime/tool/`                | (merged)                                        | this pass |
| `agent-runtime/capability/ARCHITECTURE.md`       | MERGE -> `agent-runtime/tool/` + `action/`    | (merged)                                        | this pass |
| `agent-runtime/memory/ARCHITECTURE.md`           | KEEP (rewrite)                                | same                                            | this pass |
| `agent-runtime/knowledge/ARCHITECTURE.md`        | DEFER -> v6-rationale                         | (knowledge graph deferred indefinitely)         | W0       |
| `agent-runtime/adapters/ARCHITECTURE.md`         | DEFER -> v6-rationale                         | (multi-framework dispatch deferred)             | W0       |
| `agent-runtime/observability/ARCHITECTURE.md`    | KEEP (rewrite, slim)                          | same                                            | this pass |
| `agent-runtime/outbox/ARCHITECTURE.md`           | KEEP (rewrite)                                | same                                            | this pass |
| `agent-runtime/posture/ARCHITECTURE.md`          | RENAME -> `docs/cross-cutting/posture-model.md` | new path                                      | this pass |
| `agent-runtime/auth/ARCHITECTURE.md`             | RENAME -> `agent-platform/auth/ARCHITECTURE.md` | new path                                      | this pass |
| `agent-runtime/action-guard/ARCHITECTURE.md`     | RENAME -> `agent-runtime/action/ARCHITECTURE.md` (5-stage) | new path                            | this pass |
| `agent-runtime/audit/ARCHITECTURE.md`            | DEFER -> v6-rationale (replaced by OTel + audit_log table) | (no L2 doc)                          | W0       |
| `agent-runtime/evolve/ARCHITECTURE.md`           | DEFER -> v6-rationale (replaced by eval + skill) | (no L2 doc)                                  | W0       |
| New: `agent-platform/web/ARCHITECTURE.md`        | NEW                                           | same                                            | this pass |
| New: `agent-platform/tenant/ARCHITECTURE.md`     | NEW                                           | same                                            | this pass |
| New: `agent-platform/idempotency/ARCHITECTURE.md` | NEW                                          | same                                            | this pass |
| New: `agent-runtime/run/ARCHITECTURE.md`         | NEW                                           | same                                            | this pass |
| New: `agent-runtime/tool/ARCHITECTURE.md`        | NEW                                           | same                                            | this pass |
| New: `agent-runtime/action/ARCHITECTURE.md`      | NEW                                           | same                                            | this pass |
| New: `agent-runtime/temporal/ARCHITECTURE.md`    | NEW                                           | same                                            | this pass |
| New: `agent-eval/ARCHITECTURE.md`                | NEW (W4 module)                               | same                                            | this pass |
| `docs/security-control-matrix.md`                | KEEP (rewrite, slim)                          | `docs/cross-cutting/security-control-matrix.md` (move) | this pass |
| `docs/trust-boundary-diagram.md`                 | KEEP (rewrite, slim)                          | `docs/cross-cutting/trust-boundary-diagram.md` (move)  | this pass |
| `docs/sidecar-security-profile.md`               | DEFER -> v6-rationale                         | (no Python sidecar in W0-W4)                    | W0       |
| `docs/gateway-conformance-profile.md`            | DEFER -> v6-rationale                         | (re-emerges only when Spring Cloud Gateway gets advanced features)  | W0       |
| `docs/secrets-lifecycle.md`                      | KEEP (rewrite, slim, Vault-anchored)          | `docs/cross-cutting/secrets-lifecycle.md` (move) | this pass |
| `docs/supply-chain-controls.md`                  | KEEP (rewrite, slim)                          | `docs/cross-cutting/supply-chain-controls.md` (move)  | this pass |
| `docs/observability/cardinality-policy.md`       | RENAME -> `docs/cross-cutting/observability-policy.md` | new path                              | this pass |

**Net counts:**

- v6 active files: ~35.
- refresh-surviving (after this pass): L0(1) + L1(2) + L2(11) + agent-eval(1) + cross-cutting(6) = **21 files**.
- DEFERRED to `docs/v6-rationale/`: ~14 files.
- current-refresh active corpus shrinks by ~40%.

## 2. refresh-surviving doc set (canonical list)

After this pass, the active refreshed architecture corpus is exactly:

**L0:**
- `ARCHITECTURE.md`

**L1 (2):**
- `agent-platform/ARCHITECTURE.md`
- `agent-runtime/ARCHITECTURE.md`

**L2 agent-platform (6):**
- `agent-platform/web/ARCHITECTURE.md`
- `agent-platform/auth/ARCHITECTURE.md`
- `agent-platform/tenant/ARCHITECTURE.md`
- `agent-platform/idempotency/ARCHITECTURE.md`
- `agent-platform/bootstrap/ARCHITECTURE.md`
- `agent-platform/config/ARCHITECTURE.md`
- `agent-platform/contracts/ARCHITECTURE.md`

**L2 agent-runtime (8):**
- `agent-runtime/run/ARCHITECTURE.md`
- `agent-runtime/llm/ARCHITECTURE.md`
- `agent-runtime/tool/ARCHITECTURE.md`
- `agent-runtime/action/ARCHITECTURE.md`
- `agent-runtime/memory/ARCHITECTURE.md`
- `agent-runtime/outbox/ARCHITECTURE.md`
- `agent-runtime/temporal/ARCHITECTURE.md`
- `agent-runtime/observability/ARCHITECTURE.md`

**Module-level (1):**
- `agent-eval/ARCHITECTURE.md` (W4)

**Cross-cutting (6, under `docs/cross-cutting/`):**
- `security-control-matrix.md`
- `trust-boundary-diagram.md`
- `posture-model.md`
- `secrets-lifecycle.md`
- `supply-chain-controls.md`
- `observability-policy.md`

**Plans + governance:**
- `docs/plans/engineering-plan-W0-W4.md`
- `docs/plans/architecture-systems-engineering-plan.md` (this file)
- governance corpus (`docs/governance/*`) -- unchanged structure, content updated to reference the refresh

## 3. Per-doc skeleton (every L2 follows this)

Every refreshed L2 document is short (target 120-200 lines) and has the same
sections so a reader can compare modules quickly:

```
# <Module name> -- L2 architecture (2026-05-08 refresh)

> Owner | Wave | Status (maturity L0..L4) | Reads | Writes
> Last refreshed: 2026-05-08

## 1. Purpose
One paragraph. What this module does. What it is not.

## 2. OSS dependencies
Table: dependency | version | role.

## 3. Glue we own
Table: file path | purpose | LOC estimate.

## 4. Public contract
Either an interface signature, OpenAPI excerpt, or DB schema reference.

## 5. Posture-aware defaults
What changes between dev / research / prod.

## 6. Tests (the only proof of correctness)
Table: test name | layer | asserts.

## 7. Out of scope (explicit)
Two-line list of what this module does NOT cover.

## 8. Wave landing
Which W0-W4 wave brings this online; reference to the engineering plan.

## 9. Risks
Two to four lines.
```

This skeleton is enforced by a (W1) gate rule `l2_refresh_skeleton_present`.

## 4. Order of writes (this pass)

Tier 1 (must land in this commit chain):

1. L1 `agent-platform/ARCHITECTURE.md` (rewrite)
2. L1 `agent-runtime/ARCHITECTURE.md` (rewrite)
3. L2 the 8 surviving v6 files we are rewriting (smaller scope first):
   - `agent-platform/contracts/`, `bootstrap/`, `config/`
   - `agent-runtime/llm/`, `memory/`, `outbox/`, `observability/`

Tier 2 (this commit chain, larger):

4. L2 the 7 NEW files:
   - `agent-platform/web/`, `auth/`, `tenant/`, `idempotency/`
   - `agent-runtime/run/`, `tool/`, `action/`, `temporal/`

Tier 3 (cross-cutting moves; can be batched):

5. Move + rewrite cross-cutting docs under `docs/cross-cutting/`.
6. Move + rewrite `agent-runtime/posture/` -> `docs/cross-cutting/posture-model.md`.
7. Move + rewrite `agent-runtime/auth/` -> `agent-platform/auth/`.
8. Move + rename `agent-runtime/server/` -> `agent-runtime/run/`.
9. Move + rename `agent-runtime/action-guard/` -> `agent-runtime/action/`.

Tier 4 (deferred files; banner-only this pass; archive in W0):

10. Add a "DEFERRED in v7; archived to `docs/v6-rationale/` in W0" banner
    to the v6-only files (cli, knowledge, adapters, evolve, audit,
    runner, runtime, server, skill, capability, facade, runtime,
    sidecar-security-profile, gateway-conformance-profile,
    architecture-v5.0, etc.).

## 5. Governance changes during this pass

- `docs/governance/active-corpus.yaml`:
  - Add the refresh-surviving 21 files to `active_documents`.
  - Move v6-only DEFER files to `historical_documents` with reason
    `deferred_in_v7; w0_archive_pending`.
- `docs/governance/architecture-status.yaml`:
  - Add refresh capability rows matching the current module set, each with
    `maturity: L0`, `evidence_state: design_accepted`,
    `target_wave: W0..W4` per the engineering plan.
  - Mark v6 capabilities as `v6_disposition: <code>` where code is
    one of `kept_rewritten | merged_into:<X> | renamed_to:<X> |
    deferred_in_v7`.
- `docs/governance/current-architecture-index.md`: regenerated from the refresh
  surviving doc set; v6 list moves to a separate "Historical (v6)"
  appendix.

## 6. Acceptance for this pass

The systems-engineering pass is done when:

1. All 21 refresh-surviving files exist with the per-doc skeleton.
2. All 14 v6-only deferred files carry a "DEFERRED" banner.
3. `docs/governance/active-corpus.yaml` reflects the v7 split.
4. `docs/governance/architecture-status.yaml` lists every current module as a
   capability and tags every v6-only entry with a disposition.
5. `current-architecture-index.md` leads with v7.
6. Architecture-sync gate passes (cycle-9 evidence chain).
7. `engineering-plan-W0-W4.md` references each surviving current module by
   path.

## 7. What this pass does NOT do

- It does not write Java code. That is W0+.
- It does not delete v6 files (only banners + active-corpus moves). The
  W0 deprecation step archives them to `docs/v6-rationale/`.
- It does not promote any capability above maturity L0. Promotion
  requires code + tests + an operator-shape gate run.
- It does not introduce new gate rules; the `l2_refresh_skeleton_present`
  rule is W1.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Doc rewriting reignites the cycle 1-8 reviewer loop | Each L2 must be <= 200 lines and follow the skeleton; reviewer findings batched, not fixed inline |
| Accidentally promote a deferred capability | All v7 L2 docs lead with maturity L0 + the wave they land in |
| OSS dependency list grows during the pass | Adding an OSS dep requires a row in `architecture-v7.0.md` sec-2 first |
| Stale references in v6-rationale | Banner is enough; cross-references are not chased |
