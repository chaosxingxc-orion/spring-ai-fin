# ADR-0066 — Independent Module Evolution

- Status: Accepted
- Date: 2026-05-14
- Authority: User directive — "Everything must be code-ified. Architecture must evolve rapidly. Modules must have independent evolution capability, lightweight independent verification, high cohesion / low coupling, and lightweight upgrade in production environments."
- Scope: Mandate per-module metadata (`module-metadata.yaml`) declaring kind, version, and semver compatibility — so each reactor module can build, test, and upgrade independently. Anchors CLAUDE.md Rule 31 and ARCHITECTURE.md §4 #62.
- Cross-link: ADR-0026 (module dep direction / Rule 10), ADR-0055 (platform→runtime dep allowed), ADR-0064 (Layer-0 governing principles).

## Context

The reactor has four modules today (`agent-platform`, `agent-runtime`, `spring-ai-ascend-dependencies`, `spring-ai-ascend-graphmemory-starter`). They build with `mvn -pl <module> -am test` but their versions, kinds, and semver policies are scattered — partly in `pom.xml`, partly in `architecture-status.yaml`, partly in `README.md`. A new contributor cannot answer "what kind of module is this and how stable is its API?" without piecing together multiple files.

Rule 28 demands an executable enforcer for each "must / forbidden / required" sentence. The cleanest enforcer is a yaml file per module with required keys + a gate rule that asserts presence and completeness.

## Decision

### 1. Required file: `<module>/module-metadata.yaml` per reactor module

Schema (required keys):

```yaml
module: <module-dir-name>
kind: platform | domain | starter | bom | sample
version: <semver>
semver_compatibility: <semver-range>
description: <one-line summary>
architecture_doc: <path | null>
dfx_doc: <path | null>
spi_packages: [<package>, ...]    # empty list allowed for non-domain modules
allowed_dependencies: [<module>, ...]
forbidden_dependencies: [<module>, ...]
```

Initial assignments (this PR):

| Module | kind |
|---|---|
| `agent-platform` | platform |
| `agent-runtime` | domain |
| `spring-ai-ascend-dependencies` | bom |
| `spring-ai-ascend-graphmemory-starter` | starter |

### 2. Required architecture surface

Each module of `kind ∈ {platform, domain}` MUST own a `<module>/ARCHITECTURE.md`. `kind ∈ {bom, starter, sample}` modules MAY skip the architecture doc (BoM has no architecture; starter docs roll up to the parent SPI's architecture).

### 3. Build isolation

Every module MUST build and test in isolation via `mvn -pl <module> -am test`. Inter-module dependency direction is governed by Rule 10 / Gate Rule 10 (`module_dep_direction`).

### 4. Enforcement

- Gate Rule 34 `module_metadata_present_and_complete` (enforcer E52) — every `<module>/pom.xml` has `<module>/module-metadata.yaml` with all four required keys (module, kind, version, semver_compatibility).
- Existing Gate Rule 10 `module_dep_direction` (enforcer E1) — agent-runtime pom does not depend on agent-platform.
- Existing E34 ArchUnit `PlatformImportsOnlyRuntimePublicApiTest` — agent-platform may only import runtime.runs.*, runtime.orchestration.spi.*, runtime.posture.* — never internal packages.

### 5. Deferred sub-clauses

- `CLAUDE-deferred.md` 31.b — runtime semver compatibility enforcement (BOM downgrade-rejection check, starter version compatibility table). W2 trigger.
- CI matrix running per-module isolated build — separate PR (CI workflow scope).

## Alternatives considered

**Alt A — Encode the metadata inside `pom.xml`.** Rejected: `pom.xml` is Maven's contract; mixing governance keys with build keys creates schema drift. A sibling yaml keeps concerns separate.

**Alt B — Use a single project-root yaml listing all modules.** Rejected: defeats independent module evolution (one file edited by every PR creates merge conflicts).

**Alt C — Skip `kind:` and infer from packaging.** Rejected: `kind` carries semantic intent (platform vs domain) that packaging (jar) does not capture.

## Consequences

- **Positive**: Every module declares its kind, version, and semver policy in one place; gate rule catches drift; future contributors have a single answer file.
- **Negative**: Four new yaml files to maintain; renaming a module requires editing two files (pom + metadata yaml).
- **Risk surfaced**: Stale metadata yaml could lie about the module's actual state; mitigation — the keys this gate enforces (presence + structure) are stable; semantic fields (description, spi_packages) are checked by adjacent rules (35, 36).

## Enforcers (Rule 28)

- E52 Gate Rule 34 `module_metadata_present_and_complete`.

## §16 Review Checklist

- [x] Yaml schema (4 required keys) is locked.
- [x] `kind` enum is defined (platform | domain | starter | bom | sample).
- [x] Initial kind assignment per module is recorded in this ADR.
- [x] Build-isolation requirement is bound to existing tooling (`mvn -pl <module> -am test`).
- [x] Deferred sub-clauses (runtime semver enforcement, CI matrix) have explicit triggers.
- [x] §4 #62 anchors Rule 31 in the architectural corpus.
