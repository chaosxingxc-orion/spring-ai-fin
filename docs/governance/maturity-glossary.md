# Maturity Glossary (Rule 12)

> Per `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` §7 + CLAUDE.md Rule 12.
> Defines the L0–L4 maturity ladder used in `architecture-status.yaml#capabilities[*].maturity`.

| Level | Name | Criterion |
|---|---|---|
| L0 | demo code | happy path only, no stable contract |
| L1 | tested component | unit/integration tests exist; not on the default path |
| L2 | public contract | schema/API/state machine stable; docs + tests full |
| L3 | production default | research/prod default-on; migration + observability |
| L4 | ecosystem ready | third-party can register/extend/upgrade/rollback without source |

## Promotion gates (no L3 without all of these)

A capability cannot move to L3 without:

- Posture-aware default-on (Rule 11)
- Quarantined failure modes (Rule 7)
- Observable fallbacks per Rule 7 four-prong
- Doctor/health-check coverage
- An entry in `architecture-status.yaml` showing `operator_gated` status
- An entry in `decision-sync-matrix.md` showing implementation paths + tests + gate evidence

## Retired labels

The following labels are retired in favour of L0–L4 + the status enum in `closure-taxonomy.md`:

- `experimental` → use `maturity: L0` + `status: proposed` or `design_accepted`
- `implemented_unstable` → use `maturity: L1` + `status: implemented`
- `public_contract` → use `maturity: L2` + `status: test_verified`
- `production_ready` → use `maturity: L3` + `status: operator_gated` or `released`

PRs introducing the retired labels are rejected.
