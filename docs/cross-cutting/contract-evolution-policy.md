> Owner: agent-platform | Maturity: L2 | Posture: all | Last refreshed: 2026-05-10

# Contract Evolution Policy

This document defines versioning rules per contract type, the breaking-change checklist, and the maturity-aware compatibility matrix for the spring-ai-fin platform.

---

## Versioning rules per contract type

### SPI interfaces (semver)

SPI interfaces follow semantic versioning tied to the Maven artifact version.

| Change type | Version bump | Process |
|---|---|---|
| Add optional default method | Minor (backward compatible) | No consumer changes required |
| Add method to interface | Major (breaking) | New major Maven artifact version; migration plan required |
| Change method signature | Major (breaking) | New major Maven artifact version; migration plan required |
| Remove method | Major (breaking) | Deprecate in N release; remove in N+2; migration plan required |

The current SPI surface is frozen at 9 interfaces (plus ResilienceContract = 10) as of commit `97b0827`. ArchUnit `ApiCompatibilityTest` enforces no-import-of-platform-internals from SPI packages. Breaking changes require a new wave plan in `docs/plans/engineering-plan-W0-W4.md`.

### HTTP API contracts (/v1 to /v2)

The HTTP API follows URL versioning (`/v1/*`, `/v2/*`).

| Change type | Version bump | Process |
|---|---|---|
| Add optional request field | None (backward compatible) | Field must have a safe default |
| Add optional response field | None (backward compatible) | Clients ignore unknown fields |
| Remove request field | /v2 | /v1 remains active for N+2 releases; migration guide published |
| Change status code semantics | /v2 | /v1 remains active for N+2 releases |
| Remove an endpoint | /v2 | /v1 endpoint returns 410 Gone after deprecation window |

The `OpenApiContractIT` test pins the expected OpenAPI snapshot and fails on any change to /v1 response schema. New endpoints start on /v2 when breaking.

### Configuration contracts (deprecation N+2 releases)

Configuration properties under `springai.fin.*` follow a deprecation cycle.

| Change type | Process |
|---|---|
| Add new property | Non-breaking; document default value and posture impact |
| Rename existing property | Deprecate old name in release N; emit WARN when old name is used; remove in N+2 |
| Remove property | Deprecate in N; remove in N+2; application fails to start in N+1 if old name used with strict mode |
| Change default value | Count as a breaking change; version bump required; release notes required |

Properties are documented in [docs/contracts/configuration-contracts.md](../contracts/configuration-contracts.md).

---

## Breaking-change checklist

Before merging any change that modifies a contract surface:

- [ ] Root-cause block written per CLAUDE.md Rule 1 (four-line block)
- [ ] Change classified by type and version bump requirement (table above)
- [ ] Old contract path kept active for the full deprecation window
- [ ] ArchUnit test updated if SPI package visibility rules change
- [ ] OpenAPI snapshot updated and pinned if HTTP response schema changes
- [ ] `docs/contracts/contract-catalog.md` updated with new version pin
- [ ] `docs/contracts/configuration-contracts.md` updated if property table changes
- [ ] Migration guide written and linked from release notes
- [ ] Downstream teams notified (per `docs/governance/architecture-status.yaml` consumer list)
- [ ] Wave plan updated if change spans a wave boundary

---

## Maturity-aware compatibility matrix

| Maturity level | Stability tier | Breaking change policy |
|---|---|---|
| L0 (demo code) | Experimental; may break at any time | No compatibility guarantee; consumers accept churn |
| L1 (tested component) | Unstable; breaking changes announced 1 release ahead | No semver; changelog entry required for any break |
| L2 (public contract) | Stable; semver enforced | Breaking changes require major version bump and N+2 deprecation window |
| L3 (production default) | Semver enforced; migration path mandatory | Major bumps require migration tooling + N+3 deprecation window; rollback recipe in wave plan |
| L4 (ecosystem ready) | Backward-compatible extension points only | Removal requires ecosystem-wide migration; 6-month notice minimum |

Current platform maturity:

- SPI interfaces: L1 (tested; no semver yet; frozen by ArchUnit)
- HTTP /v1 API: L2 (stable; OpenApiContractIT pins snapshot)
- Configuration: L1 (property table documented; no deprecation tooling yet)
- Telemetry: L1 (namespace defined; cardinality budget documented)

---

## Related documents

- [docs/contracts/contract-catalog.md](../contracts/contract-catalog.md) for the full contract inventory
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
- [ARCHITECTURE.md](../../ARCHITECTURE.md) section 3.2 for SPI extension surface
