# Supply Chain Controls -- cross-cutting policy

> Owner: security + ops | Wave: W0 (CI) + W2 (image pin) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Documents how dependencies enter the build, how images are pinned, and
what evidence is produced for each release. Replaces the pre-refresh
`docs/supply-chain-controls.md`.

## 2. Java dependencies

- Single parent `pom.xml` with managed versions via Maven BOM.
- No floating ranges in module POMs (e.g., no `[1.0,2.0)`); only
  exact versions resolved by the BOM.
- `mvn -B -ntp --strict-checksums` in CI; checksum-locked resolver.
- Dependabot enabled at the repo root: weekly PRs for Tier-1 deps,
  monthly for Tier-2, quarterly for Tier-3. (Tiering defined in
  `ARCHITECTURE.md` sec-2.1.)
- Snyk weekly scan; CVE >= 7.0 patched within 14 days; CVE >= 9.0
  within 72 hours.

## 3. Container images

- One `Dockerfile` (Buildpacks-based) at repo root.
- Base image is a distroless Java 21 image, version-pinned by digest:
  `gcr.io/distroless/java21-debian12@sha256:<digest>`.
- All third-party images in `ops/compose.yml` and `ops/helm/` are
  pinned by digest (Postgres, Valkey, Temporal, Keycloak, OPA, Loki,
  Grafana).
- Image-pin lint: CI step refuses any `image:` line without a `@sha256:` suffix.

## 4. SBOM

- `mvn cyclonedx:makeAggregateBom` produces an SBOM at every build.
- SBOM committed to the release branch under `releases/<version>/sbom.json`.
- `prod` posture rejects starts when the running image's SBOM digest
  does not match the committed SBOM (W4 enforcement; W2 produces the
  SBOM, W4 enforces).

## 5. Build provenance

- CI builds emit SLSA Level-2 provenance via GitHub Actions
  `actions/attest-build-provenance`.
- Provenance is attached to the image as an OCI artifact and verified
  at deploy time (W4).

## 6. Per-tier rotation

| Tier | Examples | Cadence | Auto-merge? |
|---|---|---|---|
| 1 (security-critical) | Spring Security, Spring Boot, Postgres JDBC, Nimbus, Vault | minor weekly; major within 90 days | yes if CI green |
| 2 (runtime-critical) | Spring AI, Temporal, pgvector, Resilience4j, Caffeine | minor monthly; major within 180 days | manual review |
| 3 (build / test) | Testcontainers, JUnit, Maven plugins | minor on convenience; major opportunistic | manual |

A Tier-1 or Tier-2 major upgrade requires its own wave-style plan in
`docs/plans/engineering-plan-W0-W4.md` with rollback recipe.

## 7. Tests / CI

| Check | CI step | Asserts |
|---|---|---|
| `mvn -B -ntp --strict-checksums verify` | every PR | clean build with checksums |
| `image-pin-lint` | every PR | every `image:` line has `@sha256:` |
| `cyclonedx:makeAggregateBom` | every build | SBOM produced |
| `dependabot-snapshot` | nightly | no CVE >= 7.0 unpatched > 14 days |
| `slsa-attest` | every release | provenance attested |

## 8. Open issues / deferred

- Reproducible-build verification (bit-for-bit): W4+.
- Tag-and-pin for Helm subcharts: W4+ post.
- Sigstore / cosign verification at deploy time: W4+ optional.
