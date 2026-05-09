# SDK Versioning and Deprecation Policy

spring-ai-fin SDK versioning (W0 baseline; 2026-05-10).

## Version scheme

SemVer (`MAJOR.MINOR.PATCH`):

| Increment | Trigger |
|---|---|
| `PATCH` | Bug fixes, dependency patch bumps, non-breaking internal changes |
| `MINOR` | Additive public API or SPI additions; no breaking changes |
| `MAJOR` | Breaking changes to any public API or SPI surface |

Current version: `0.1.0-SNAPSHOT` (pre-release; no stability guarantees until `1.0.0`).

## Stability contract (effective from 1.0.0)

The SDK's stable contract surface is:

1. **SDK module artifacts** (`spring-ai-fin-*-starter`, `spring-ai-fin-dependencies`) — published to Maven Central.
2. **SPI interfaces** in `fin.springai.runtime.spi.**` — frozen by `ApiCompatibilityTest` via ArchUnit. Any signature change requires editing the test, making the break explicit.
3. **Spring Boot auto-configuration property keys** in `fin.springai.*` namespace — changes to required properties are MAJOR.

The following are NOT stability-contracted:
- Internal implementation classes (packages without `api` or `spi` in the path)
- Test utilities and fixtures
- Sidecar adapter internals (REST client implementations)
- Compose overlay container image tags (tracked in `third_party/MANIFEST.md`)

## Deprecation process

1. Mark the target API/SPI element `@Deprecated` with Javadoc `@since` and `@deprecated` reasons.
2. Provide the replacement in the same MINOR release.
3. Deprecated elements survive at least one MINOR release before removal.
4. Removal is a MAJOR increment.

## Dependency version policy

- All deps pinned to exact patch in `pom.xml` `<properties>`. No ranges, no `LATEST`, no `RELEASE`.
- The `spring-ai-fin-dependencies` BoM is the externally-consumable version contract.
- Dependency upgrades within a MAJOR line (e.g. `resilience4j 2.4.0 → 2.5.0`) are PATCH/MINOR in the SDK.
- Dependency MAJOR upgrades (e.g. `tika 3.x → 4.x`) require a deprecation cycle and SDK MAJOR bump unless the new API is backward-compatible.

## Spring AI milestone watch

Spring AI 2.0.0-M5 is used at W0. `gate/check_spring_ai_milestone.sh` fails CI after 2026-08-01 if `spring-ai.version` still contains `-M`, forcing upgrade to the GA release. When Spring AI 2.0 GA ships, the upgrade is a PATCH-level SDK change (no API break expected between M5 and GA given the stable 2.0 contract).

## Sidecar adapter versioning

Sidecar adapter starters (`spring-ai-fin-mem0-starter`, `-graphmemory-starter`, `-docling-starter`) follow the SDK version. The Python services (mem0, Graphiti, Docling-serve) release independently. The SPI layer isolates the SDK contract: only the adapter starter changes when the Python service breaks compatibility — the SDK SPI surface is stable.
