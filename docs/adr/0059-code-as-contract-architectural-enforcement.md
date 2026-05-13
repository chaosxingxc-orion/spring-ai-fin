# ADR-0059 — Code-as-Contract Architectural Enforcement (Introduces Rule 28)

- Status: Accepted
- Date: 2026-05-14
- Authority: User-mandated core rule, accepted in L1 plan `l1-modular-russell`.
- Scope: All architectural constraints in the corpus (`CLAUDE.md`, `ARCHITECTURE.md`, every `*/ARCHITECTURE.md`, every ADR, every plan under `docs/plans/`).

## Context

L0 closed with 14 reviewer cycles and 29 gate rules. Every drift incident in those cycles traced to the same pattern: a constraint was written in prose, no executable enforcer existed, the constraint stopped reflecting reality, and a defect shipped because reviewers and tools both read the prose as load-bearing.

Rule 25 ("Architecture-Text Truth", ADR-0025) partially closed this gap by requiring every `shipped: true` row in `architecture-status.yaml` to point at a real test. But Rule 25 only governs **capabilities**. It does not govern:

- numbered constraints in `ARCHITECTURE.md §4` that describe invariants rather than features;
- "must not" / "forbidden" sentences in module ARCHITECTURE.md files;
- ADR decision rules whose enforcement is implicit;
- plan-level commitments that fall through to implementation without a gate.

Rule 25 also tolerates "enforced by X" prose as long as X exists — it does not require X to actually perform the named assertion.

The user-mandated core rule (received 2026-05-13 during L1 planning) is: **all architectural constraints must become code-as-contract architectural constraints.** This ADR operationalises that mandate as Rule 28.

## Decision

Introduce **Rule 28 (Code-as-Contract)** to `CLAUDE.md`:

> Every architectural constraint MUST be enforced by code (test, gate script, schema constraint, or compile-time check). Prose-only constraints are forbidden.

Rule 28 is strictly stronger than Rule 25. The full rule body is in `CLAUDE.md` and is the authoritative text.

This ADR adds the following operational machinery:

### 1. Enforcer index — `docs/governance/enforcers.yaml`

A new tracked artifact. Each row has the shape:

```yaml
- id: <stable-id, e.g. E1>
  constraint_ref: <citation, e.g. "ARCHITECTURE.md §4 #10; ADR-0055">
  kind: gate-script | archunit | integration | schema | compile-time
  artifact: <path to enforcer code, e.g. "gate/check_architecture_sync.sh#rule_10">
  asserts: <one-line summary of what the enforcer asserts>
```

The file is the canonical cross-reference between constraints and their enforcers. The plan-of-record `D:\.claude\plans\l1-modular-russell.md` §11 is the human-readable mirror; the YAML is the machine-readable source.

### 2. Five legal enforcer kinds

A constraint is satisfied if it maps to **at least one** enforcer of kind:

1. **archunit** — ArchUnit test that fails when violated.
2. **gate-script** — rule in `gate/check_architecture_sync.sh` that exits non-zero.
3. **integration** — JUnit integration test asserting observable behaviour.
4. **schema** — database constraint (`NOT NULL`, `UNIQUE`, `CHECK`, `PRIMARY KEY`).
5. **compile-time** — `@ConfigurationProperties` + `@Valid`, sealed-type hierarchies, package-info module enforcement.

Any constraint without an enforcer of one of these kinds is dropped from the architecture corpus. It cannot be "weakened into prose."

### 3. Sub-checks 28a–28i

Nine new gate sub-rules implement Rule 28:

| Sub-rule | Name | Asserts |
|---|---|---|
| 28a | `tenant_column_present` | Every `CREATE TABLE` under `src/main/resources/db/migration/` has a `tenant_id` column. |
| 28b | `high_cardinality_tag_guard` | No source contains `Tag.of("run_id"\|"idempotency_key"\|"jwt_sub"\|"body", …)`. |
| 28c | `no_secret_patterns` | gitleaks-style regex pass over tracked files; pre-existing noise allow-list is inline-annotated. |
| 28d | `out_of_scope_name_guard` | Names of W2+ deferred concepts must not appear in `agent-*/src/main/java`. |
| 28e | `module_count_invariant` | Root `pom.xml` `<module>` count equals exactly 4 (L1 invariant). |
| 28f | `enforcers_yaml_wellformed` | `docs/governance/enforcers.yaml` schema-valid; every row has all five fields. |
| 28g | `no_prose_only_constraint_marker` | No `TODO: enforce`, `FIXME: enforcer`, `deferred: test` markers in architecture corpus. |
| 28h | `l1_review_checklist_present` | Every ADR `0055*–0059*` includes the §16 review-checklist sub-section. |
| 28i | `plan_enforcer_table_in_sync` | The plan's §11 table and `enforcers.yaml` are row-for-row identical. |

Plus the meta-rule:

| Rule | Name | Asserts |
|---|---|---|
| 28 | `constraint_enforcer_coverage` | Every "must"/"must not"/"forbidden"/"required" sentence in the architecture corpus maps to at least one `enforcers.yaml` row. |

### 4. Bootstrapping

L1 ships with `enforcers.yaml` populated for IDs E1–E32 (matching plan §11). Subsequent waves (W2, W3, W4) extend the index in the same PR as their new constraints.

For pre-existing constraints (anything in the corpus before this ADR), L1 backfills the `enforcers.yaml` rows for everything actively enforced. Anything that cannot be mapped is **deleted from prose** by this PR.

### 5. Allow-list discipline

Doc-prose that mentions "must" in a non-architectural sense (quoting a third party, explaining a library convention, etc.) may be allow-listed via an inline HTML comment:

```markdown
<!-- enforcer: NONE_PROSE_ONLY -->
This must not be confused with the Spring "must" pattern.
```

Allow-list comments are PR-reviewed line-by-line. They are not a workaround — they explicitly mark the line as out of architectural scope.

## Consequences

### Positive

- **No more drift.** Every architectural change must land its enforcer in the same PR; future-you cannot find a stale prose claim with no asserter.
- **Mechanical review.** Reviewers (human and agent) can use `gate/check_architecture_sync.sh` Rule 28 output as a coverage report.
- **Cheap to maintain.** The marginal cost per constraint is one YAML row + one test. The compounding cost of *not* having enforcers (cycle 1–14 drift incidents) was higher.

### Negative

- **Surface-area inflation.** The enforcer index becomes a sizeable file (32 rows at L1; will grow with each wave). Mitigated by E29 (`enforcers_yaml_wellformed`) and E32 (`plan_enforcer_table_in_sync`).
- **False-positive risk.** Doc-prose using "must" in non-architectural senses needs the allow-list comment. Reviewed in PR; no regex-tuning to silence.
- **Some legitimate constraints have no automatable enforcer.** Those constraints are *not* allowed to land as prose — they are either dropped or rewritten as something automatable. This is a deliberate cost.

### Neutral

- Rule 25 remains in force. Rule 28 strictly extends it; no override.
- Existing enforcers (Gate Rules 1–27) continue unchanged. Each is registered in `enforcers.yaml`.

## Alternatives Considered

### A. Keep Rule 25, add stronger per-section prose

Rejected: this is exactly the pattern that caused the cycle 1–14 drift. Prose strengthening does not survive contact with refactors.

### B. Require ADRs for every constraint

Rejected: ADRs decay too. ADR-0026 had to be superseded by ADR-0055 within the same review cycle. The decision needs a runtime enforcer, not a paper trail.

### C. Apply Rule 28 only to new constraints from L1 forward

Rejected: leaves the L0 corpus exposed. The bootstrap one-time cost of backfilling 32 rows is bounded; the ongoing benefit of universal coverage compounds.

## §16 Review Checklist (per architect guidance)

- [x] The module owner is clear (corpus-wide; not a single module).
- [x] The out-of-scope list is explicit (E26 enforces).
- [x] No future-wave capability is described as shipped (E28 catches drift).
- [x] Spring bean construction has one owner (Rule 6 unchanged; Rule 28 enforces).
- [x] Configuration properties are validated and consumed (compile-time enforcer kind).
- [x] Tenant identity flow is explicit (E2 enforces).
- [x] Idempotency behavior is tenant-scoped (E13, E15 enforce).
- [x] Persistence survives restart when claimed (E12, E21 enforce).
- [x] Error status codes are stable (E7, E8 enforce).
- [x] Metrics and logs exist for failure paths (E18 enforces).
- [x] Tests cover unit, integration, and public contract layers (Rule 4 unchanged; enforced per row).
- [x] `architecture-status.yaml` truth matches implementation (Rule 25 unchanged).
- [x] The design does not weaken existing Rule 20, Rule 21, or Rule 25 constraints (Rule 28 strictly extends).

## Related

- Rule 25 (`CLAUDE.md`) — Architecture-Text Truth (extended by Rule 28).
- ADR-0025, ADR-0026, ADR-0027 — Rule 25's enforcement triad (Rule 28 inherits and extends).
- ADR-0046 — Release-note shipped-surface truth (a Rule 25 specialisation; Rule 28 generalises).
- Plan-of-record: `D:\.claude\plans\l1-modular-russell.md` §0, §11.
