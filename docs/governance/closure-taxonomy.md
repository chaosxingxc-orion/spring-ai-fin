# Closure Taxonomy

> Per `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` sec-4.1 + `docs/systematic-architecture-remediation-plan-2026-05-08.en.md` sec-12.
> Defines the status enum used in `architecture-status.yaml` and forbids `closed` (and equivalent shortcuts) as a status.

## Status enum

| Status | Definition | Required artefacts |
|---|---|---|
| `proposed` | A capability or finding has been recorded in a document. No commitment yet. | A document referencing it. |
| `design_accepted` | The team accepts the design. The L2 document exists and is internally consistent. No implementation. | L2 document; finding recorded; ledger entry. |
| `implemented_unverified` | Code exists for the capability, but the required tests and/or operator-shape gate are still incomplete or red. | Source files exist at the implementation paths recorded in `decision-sync-matrix.md`. Tests may be present but not yet green. |
| `test_verified` | Implementation passes the unit + integration tests recorded in `decision-sync-matrix.md` on the SHA in question. | Green CI run on the recorded tests, on the SHA in question. |
| `operator_gated` | Operator-shape gate (Rule 8) passes for the capability on a long-lived process with real dependencies, on the SHA in question. | `docs/delivery/<date>-<sha>.md` records the gate run; gate output attached. |
| `released` | Capability is released and customer-facing. | Release note; manifest entry; downstream notification. |

`implemented_unverified` exists so that `implemented` cannot be claimed silently before tests pass. A capability that has code but no green test run is `implemented_unverified`, not `implemented` and not `test_verified`.

## Forbidden statuses and shortcuts

The following words and phrases are NOT permitted as a capability status anywhere in the corpus (PR text, ledger, L0/L2 docs, response documents):

- `closed`
- `done`
- `wip`
- `closed by design`
- `fixed in docs`
- `production-ready pending implementation`
- `accepted, therefore closed`
- `operator-gated by intention`
- `verified by review only`
- `closes` / `fixes` when applied to a security finding without the corresponding ledger entry advancing past `test_verified`

These shortcuts collapse *finding-was-found*, *finding-was-accepted*, *finding-was-implemented*, *finding-was-tested*, and *finding-passed-operator-gate* into one indistinct state. Use the precise status above instead.

The CI gate `gate/check_architecture_sync.{ps1,sh}` greps for these shortcuts in `ARCHITECTURE.md`, `docs/security-response-*.md`, and L2 docs and fails the build when a forbidden shortcut is found alongside a `design_accepted` capability.

## Status promotion rules

A status can only move forward (`proposed -> design_accepted -> implemented_unverified -> test_verified -> operator_gated -> released`). Regression (e.g., a test failure on a previously `test_verified` capability) downgrades the status to the highest level that still passes; the W0 gate refuses to release.

A finding from an external review (security, compliance, architecture committee) is not "closed" -- it is `design_accepted` until at least `test_verified` for the capability that addresses it.

## "ACCEPT FULLY" language in security responses

`docs/security-response-2026-05-08.md` uses "ACCEPT FULLY" to mean *the design has been accepted*. That maps to `design_accepted` in this taxonomy. It does NOT mean the finding has been closed; the finding is recorded against the capability in `architecture-status.yaml#findings` and remains open until the capability reaches `test_verified`.

## "closes security review P-N" in section headers

Older edits used `closes security review P0-N` in L0 bullet lists. Per this taxonomy, that wording is forbidden. The current language is:

> addresses P0-N (status: design_accepted; tracked in `docs/governance/architecture-status.yaml`)

`gate/check_architecture_sync.{ps1,sh}` enforces this on every commit.

## Manifest scorecard interaction

Per L0 line 1071 ("Manifest-truth releases"), closure notices derive from the manifest, and `current_verified_readiness` increases only on `operator_gated` or `released`. Capabilities at `proposed`, `design_accepted`, `implemented_unverified`, or `test_verified` do not lift the readiness score.
