# spring-ai-fin Systematic Architecture Remediation Plan - Cycle 3

**Date**: 2026-05-08  
**Scope**: `D:/chao_workspace/spring-ai-fin` after remediation cycle 2 and the latest architecture review  
**Audience**: Architecture committee, platform engineers, security reviewers, release captains  
**Current classification**: Documentation-first architecture corpus with a partially implemented architecture-sync gate. Not implementation-verified. Not operator-gated.  
**Relation to prior plans**: This document extends `docs/systematic-architecture-remediation-plan-2026-05-08.en.md` and `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-2.en.md`. It captures the five cycle-3 findings found after the team expanded the sync gate and committed cycle-2 evidence.

---

## 1. Executive Judgment

Cycle 2 fixed several high-value design drifts: L0 now says ActionGuard has 11 stages, platform L1 now aligns better with the environment-free contract model and JWKS identity posture, server L2 now correctly describes transaction-scoped `SET LOCAL` as the RLS safety property, and the sync gate was expanded to scan L1/L2 docs.

The latest review found the next layer of defects:

- the PowerShell architecture-sync gate is broken on Windows;
- the current HEAD has no matching valid gate evidence file;
- `docs/security-control-matrix.md` still carries the obsolete RLS reset control;
- closure wording is still present in L1/L2 docs despite the taxonomy;
- `gate/README.md` still describes the directory as if Rule 8 operator-shape scripts exist, while only architecture-sync scripts exist.

This is a governance-stage failure, not a runtime-stage failure. The project still has no Maven build, no Java source, no tests, and no `gate/run_operator_shape_smoke.*`. The priority is therefore:

1. make the architecture-sync gate reliable on both Windows and POSIX;
2. bind every evidence file to the exact SHA it claims;
3. remove remaining control-plane drift from the security matrix;
4. make closure language enforcement broad and case-insensitive;
5. stop describing the `gate/` directory as Rule 8-ready until the operator-shape smoke exists.

The strongest valid reading is:

> `spring-ai-fin` has a stronger architecture corpus than before, but the evidence system is not yet trustworthy enough to authorize the next implementation wave. W0 must first produce a reliable gate baseline and then a runnable skeleton.

---

## 2. Root-Cause Block

**Observed failure**: Running `gate/check_architecture_sync.ps1` on the current clean tree throws before emitting structured gate results. Separately, the latest delivery evidence files are for older SHAs, while the current HEAD is different.

**Execution path**: The reviewer runs the Windows sync gate because W0 explicitly requires Windows and POSIX gate scripts. The script builds `$L0`, `$L1L2`, `$DocsAllowed`, and `$AllScanFiles`, then iterates `$AllScanFiles` and calls `Get-Content -LiteralPath $f`. The path list contains a malformed concatenation of a relative path and an absolute path, producing an error like `Cannot find drive. A drive with the name 'ARCHITECTURE.mdD' does not exist.`

**Root cause statement**: The cycle-2 sync gate expanded its scan surface without normalizing all paths into one canonical representation, so the Windows gate can fail before it reaches semantic checks or evidence emission.

**Evidence**:

- `gate/check_architecture_sync.ps1:59-82` builds mixed scan lists.
- `gate/check_architecture_sync.ps1:100-102` reads those paths and fails.
- `docs/delivery/2026-05-08-7025ac9.md:51-67` records evidence for SHA `7025ac9`, not the current HEAD reviewed later.
- `docs/security-control-matrix.md:42-44` still lists HikariCP `connectionInitSql` as the connection reset control.
- `docs/governance/closure-taxonomy.md:21-36` forbids closure shortcuts, but multiple L1/L2 docs still contain P0 closure wording.
- `gate/README.md:1-21` describes Rule 8 operator-shape scripts even though `run_operator_shape_smoke.*` is absent.

---

## 3. Finding-to-Remediation Matrix

| Finding | Severity | Category | Primary files | Required remediation | Target wave |
|---|---:|---|---|---|---|
| PowerShell architecture-sync gate is broken | P0 | Gate reliability | `gate/check_architecture_sync.ps1` | Normalize scan paths; make Windows gate emit structured PASS/FAIL; add self-test for mixed relative/absolute path inputs | W0 immediate |
| Current HEAD has no matching valid evidence file | P0 | Evidence reproducibility | `docs/delivery/*.md`, `gate/log/*.json` | Generate fresh gate log and delivery file for the exact HEAD after the gate is fixed; reject stale evidence for current reviews | W0 immediate |
| Security matrix still specifies obsolete RLS reset control | P0 | Security control-plane consistency | `docs/security-control-matrix.md`, `agent-runtime/server/ARCHITECTURE.md` | Replace `connectionInitSql` reset control with transaction-scoped `SET LOCAL` + leakage test evidence | W0 document sync; W2 test |
| Closure taxonomy is not enforced broadly enough | P1 | Governance language enforcement | `docs/governance/closure-taxonomy.md`, `gate/check_architecture_sync.*`, L1/L2 docs | Scan all L0/L1/L2/docs with case-insensitive closure patterns; allow closure language only in taxonomy/remediation docs | W0 |
| Gate README overstates current shape | P1 | Gate documentation truth | `gate/README.md` | Split architecture-sync gate from future Rule 8 operator-shape gate; remove claim that all gate scripts exist today | W0 |

---

## 4. Workstream A: Fix the PowerShell Architecture-Sync Gate

### Problem

The Windows gate is a W0 deliverable, but it currently fails before it can report semantic findings. This makes it unusable as evidence on Windows and undermines the cross-platform gate requirement.

### Required correction

Normalize every scan path to an absolute path before adding it to `$AllScanFiles`.

Recommended pattern:

```powershell
function Add-ScanFile([System.Collections.ArrayList]$list, [string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return }
  $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
  [void]$list.Add($resolved.Path)
}

$AllScanFiles = New-Object System.Collections.ArrayList
Add-ScanFile $AllScanFiles 'ARCHITECTURE.md'
Get-ChildItem -Path 'agent-platform','agent-runtime' -Filter 'ARCHITECTURE.md' -Recurse -File |
  ForEach-Object { Add-ScanFile $AllScanFiles $_.FullName }
```

Avoid array expressions that combine scalar strings and arrays without normalizing first:

```powershell
$AllScanFiles = @($L0 + $L1L2 + $DocsAllowed)
```

### Required gate behavior

The gate must:

- never throw on valid repository paths;
- emit JSON whether the result is PASS or FAIL;
- report path and line for every semantic failure;
- fail on dirty tree by default;
- support `-LocalOnly` only for non-delivery evidence;
- return equivalent semantic results to the POSIX script.

### Exit criteria

- `gate/check_architecture_sync.ps1` runs successfully on a clean tree.
- A deliberate bad path produces a structured failure, not a PowerShell exception.
- A mixed relative/absolute path list is covered by a gate self-test or script-level test fixture.
- The generated log has `working_tree_clean`, `semantic_pass`, and `evidence_valid_for_delivery`.

---

## 5. Workstream B: Bind Evidence to the Exact HEAD

### Problem

Architecture evidence must be SHA-specific. A delivery file for `7025ac9` cannot validate a later HEAD such as `802e25d` or any subsequent commit. This is especially important because architecture-only commits can change the gate itself, the security matrix, or the status ledger.

### Required correction

After the PowerShell gate is fixed:

1. run both sync gates on the current clean HEAD;
2. write `gate/log/<current-sha>.json`;
3. write `docs/delivery/<date>-<current-sha>.md`;
4. explicitly mark it as **architecture-sync evidence only**, not Rule 8 operator-shape evidence;
5. record the current HEAD, gate script version, scan count, clean-tree state, semantic pass, and delivery validity.

### Delivery rule

Every review or release decision must answer:

```text
Which SHA is being reviewed?
Which gate log was generated from that exact SHA?
Was the working tree clean?
Was evidence_valid_for_delivery true?
Is this architecture-sync evidence or Rule 8 operator-shape evidence?
```

### Exit criteria

- Current HEAD has a matching log and delivery file.
- Older delivery files are labelled historical and cannot be used for the current HEAD.
- `docs/delivery/README.md` explicitly rejects delivery evidence for any SHA other than the current reviewed SHA.

---

## 6. Workstream C: Correct the RLS Security-Control Matrix

### Problem

Server L2 now correctly states that `SET LOCAL app.tenant_id` is transaction-scoped and automatically discarded on commit or rollback. It also correctly says HikariCP `connectionInitSql` is not a per-checkout reset hook.

But `docs/security-control-matrix.md` still lists:

```text
Connection check-in reset | HikariCP connectionInitSql | Pool lifecycle
```

That makes the security matrix contradict the authoritative RLS design.

### Required correction

Replace the obsolete matrix row with controls that match the server L2 design:

```text
Tenant transaction binding | TenantBinder SET LOCAL app.tenant_id | Transaction start | all postures | TenantBindingIT | fail closed if missing
Pooled connection leakage | Transaction-scoped GUC auto-discard + validation at transaction start | Pool reuse | all postures | PooledConnectionLeakageIT | fail closed on stale GUC
RLS policy coverage | Postgres ENABLE ROW LEVEL SECURITY + tenant_isolation policy | Migration | all postures | RlsPolicyCoverageTest | reject migration
```

### Gate rule

`gate/check_architecture_sync.*` must fail when `docs/security-control-matrix.md` says:

- `connectionInitSql` is the tenant reset control;
- `connectionInitSql` is a check-in, checkout, or per-lease reset hook;
- RLS control rows omit `TenantBinder`, `SET LOCAL`, or `PooledConnectionLeakageIT`.

### Exit criteria

- Security matrix matches server L2.
- Decision-sync matrix still references `PooledConnectionLeakageIT`.
- W2 acceptance tests can be generated directly from the matrix without inheriting the old HikariCP hook error.

---

## 7. Workstream D: Enforce Closure Language Broadly

### Problem

The taxonomy is correct: a finding is not closed until at least `test_verified`. However, the corpus still contains wording such as `P0-1 closure`, `closes P0-2`, and `Closes security review`. These phrases remain in L1/L2 docs because the gate patterns are too narrow.

### Required correction

Expand closure enforcement to be case-insensitive and broader than the exact old phrase.

Suggested forbidden patterns outside taxonomy/remediation/history docs:

```regex
(?i)\bcloses?\s+(security\s+review\s+)?(§)?P[0-9]+-[0-9]+\b
(?i)\bP[0-9]+-[0-9]+\s+closure\b
(?i)\bclosure\s+rests\s+on\b
(?i)\bclosed\s+by\s+design\b
(?i)\bfixed\s+in\s+docs\b
(?i)\baccepted,\s*therefore\s*closed\b
```

Allowed replacement language:

```text
addresses P0-N; status is tracked in docs/governance/architecture-status.yaml
accepted design for P0-N; not closed until test_verified
```

### Scope

Scan:

- root `ARCHITECTURE.md`;
- `agent-platform/**/ARCHITECTURE.md`;
- `agent-runtime/**/ARCHITECTURE.md`;
- `docs/**/*.md`;
- security response docs unless explicitly classified as historical and excluded by path.

### Exit criteria

- The gate fails on all closure phrases still present in L1/L2 docs.
- Every replacement phrase points to the ledger.
- `architecture-status.yaml` remains the only source of finding state.

---

## 8. Workstream E: Make `gate/README.md` State the Truth

### Problem

`gate/README.md` says the directory holds executable gate scripts that run a long-lived process with real dependencies and verify Rule 8. That is not true yet. The directory currently contains architecture-sync scripts, not `run_operator_shape_smoke.*`.

### Required correction

Split the README into two sections:

```text
## Implemented now
- check_architecture_sync.ps1
- check_architecture_sync.sh

These are architecture-sync gates. They do not start the app and do not satisfy Rule 8.

## W0 deliverables
- run_operator_shape_smoke.ps1
- run_operator_shape_smoke.sh

These will be the first Rule 8 operator-shape gates.
```

### Required wording

The README must explicitly say:

- architecture-sync PASS is not release evidence;
- Rule 8 evidence requires a runnable artifact;
- Rule 8 evidence requires real dependencies;
- Rule 8 evidence requires three sequential public-entry runs;
- Rule 8 evidence requires cancellation and fallback-zero checks;
- `run_operator_shape_smoke.*` is absent until W0.

### Exit criteria

- No reader can mistake the current `gate/` directory for a working Rule 8 gate.
- `docs/delivery/*.md` uses the same distinction.
- `architecture-status.yaml` uses separate entries or notes for architecture-sync and operator-shape smoke.

---

## 9. Status Ledger Updates

Add these cycle-3 findings to `docs/governance/architecture-status.yaml#findings`.

| Finding id | Capability | Status | Target wave | Notes |
|---|---|---|---|---|
| `REM-2026-05-08-C3-1` | `operator_shape_gate` | `design_accepted` until PowerShell gate runs cleanly | W0 immediate | Windows architecture-sync gate broken |
| `REM-2026-05-08-C3-2` | `operator_shape_gate` | `design_accepted` until current HEAD evidence exists | W0 immediate | SHA-bound evidence missing |
| `REM-2026-05-08-C3-3` | `server_rls_protocol` | `design_accepted` | W0/W2 | Security matrix still has obsolete HikariCP control |
| `REM-2026-05-08-C3-4` | `operator_shape_gate` | `implemented_unverified` only after broad closure enforcement passes | W0 | Gate pattern set too narrow |
| `REM-2026-05-08-C3-5` | `operator_shape_gate` | `design_accepted` until README is corrected | W0 | Gate README overstates current shape |

Important:

- The architecture-sync gate cannot remain `implemented_unverified` if one supported platform script fails to run.
- The Rule 8 operator-shape gate remains `design_accepted` until `gate/run_operator_shape_smoke.*` exists and passes.
- No P0 security finding advances past `design_accepted` from this cycle alone.

---

## 10. Immediate Next Pull Request

The next PR should be narrow and evidence-first.

Recommended scope:

1. Fix `gate/check_architecture_sync.ps1` path normalization.
2. Add a minimal script self-test or documented verification command for the PowerShell scan-list behavior.
3. Run PowerShell and POSIX sync gates on a clean tree.
4. Generate `gate/log/<current-sha>.json`.
5. Add `docs/delivery/<date>-<current-sha>.md` for architecture-sync evidence only.
6. Update `docs/security-control-matrix.md` RLS rows.
7. Expand closure-language gate patterns.
8. Correct `gate/README.md` to distinguish implemented architecture-sync gates from future Rule 8 smoke gates.
9. Update `architecture-status.yaml` with the five cycle-3 findings.

Expected result after that PR:

```text
PowerShell sync gate passes on Windows.
POSIX sync gate passes on POSIX.
Both logs are tied to the exact clean HEAD.
Security matrix matches server RLS L2.
Closure language cannot re-enter L0/L1/L2 unnoticed.
The repository still honestly states that Rule 8 operator-shape smoke is pending W0.
```

---

## 11. Definition of Done for Cycle 3

Cycle 3 is complete only when:

1. `gate/check_architecture_sync.ps1` runs successfully on Windows.
2. `gate/check_architecture_sync.sh` runs successfully in the documented POSIX environment.
3. Both scripts emit equivalent semantic results.
4. Current HEAD has a matching `gate/log/<sha>.json`.
5. Current HEAD has a matching `docs/delivery/<date>-<sha>.md`.
6. The delivery file explicitly says it is architecture-sync evidence, not Rule 8 evidence.
7. `docs/security-control-matrix.md` no longer lists HikariCP `connectionInitSql` as an RLS reset control.
8. Closure-language enforcement catches broad P0/P1 closure phrases across L0/L1/L2/docs.
9. `gate/README.md` no longer overstates the current gate implementation.
10. `architecture-status.yaml` records all five cycle-3 findings.
11. No capability is promoted because of this cycle except the narrow architecture-sync capability, and only after both platform scripts pass.
12. `gate/run_operator_shape_smoke.*` remains explicitly pending until W0 implements the runnable skeleton.

