# Contract Catalog

> Single source of truth for all public contracts in the spring-ai-ascend platform.
> Version: 0.1.0-SNAPSHOT | Last refreshed: 2026-05-13 (sixth + seventh reviewer response)

---

## 1. HTTP API contracts

Stable W0 routes: `GET /v1/health`, `GET /actuator/health`, `GET /actuator/prometheus` (no auth headers). Planned W1 routes: `POST /v1/runs`, `GET /v1/runs/{id}`, `POST /v1/runs/{id}/cancel` — all require `X-Tenant-Id`; POST routes also require `Idempotency-Key`; W1 adds JWT `tenant_id` claim cross-check against `X-Tenant-Id` (ADR-0040). Full per-route spec: [http-api-contracts.md](http-api-contracts.md) + `docs/contracts/openapi-v1.yaml`.

**API conventions** (absorbed from `api-conventions.md`): URL major-versioned (`/v1/`); plural nouns; RFC 7807 `application/problem+json` errors with stable `code`; cursor pagination (`?limit=20&cursor=`); `GET`=200, POST-create=201, async=202, DELETE=204; `Idempotency-Key` required on POST/PUT/PATCH in research/prod; `OpenApiContractIT` snapshot-tests spec; SSE streaming reserved W3+.

---

## 2. SPI contracts

**Inclusion rule for SPI sub-table:** Java `interface` types that represent named public extension points in `agent-platform` or `agent-runtime`; not probes, not data carriers (records/sealed classes), not implementations.

All SPI impls: thread-safe, no null returns, tenant-scoped. SPI packages import only `java.*` (ArchUnit `ApiCompatibilityTest`). japicmp binary-compat from W1.

**Active SPI interfaces (W0, shipped) — 7 interfaces:**

| Interface | Module | Status |
|---|---|---|
| `RunRepository` | `agent-runtime` | shipped — W0 in-memory impl (`InMemoryRunRegistry`) |
| `Checkpointer` | `agent-runtime` | shipped — W0 in-memory impl (`InMemoryCheckpointer`) |
| `GraphMemoryRepository` | `agent-runtime` (SPI interface); `spring-ai-ascend-graphmemory-starter` (adapter shell) | shipped — interface only; no production impl at W0; Graphiti is W1 reference (ADR-0034) |
| `ResilienceContract` | `agent-runtime` | shipped — W0 Resilience4j impl |
| `Orchestrator` | `agent-runtime` | shipped — W0 reference impl (`SyncOrchestrator`) |
| `GraphExecutor` | `agent-runtime` | shipped — W0 reference impl (`SequentialGraphExecutor`) |
| `AgentLoopExecutor` | `agent-runtime` | shipped — W0 reference impl (`IterativeAgentLoopExecutor`) |

**Data carriers (not SPIs; structural contracts):**

| Type | Module | Notes |
|---|---|---|
| `RunContext` | `agent-runtime` | Per-run context record passed to SPIs |
| `ExecutorDefinition` | `agent-runtime` | Sealed: `GraphDefinition` \| `AgentLoopDefinition` |
| `SuspendSignal` | `agent-runtime` | Checked-exception interrupt primitive |

**Probes (not SPIs; classpath shape checks):**

| Type | Module | Notes |
|---|---|---|
| `OssApiProbe` | `agent-runtime` | W0 classpath shape probe; verifies Spring AI + Temporal + MCP + Tika on classpath |

**Design-named SPIs (deferred W2+):**

| Interface | Planned Wave | ADR |
|---|---|---|
| `Skill` + `SkillContext` + `SkillResourceMatrix` | W2 | ADR-0030 |
| `RunDispatcher` | W2 | ADR-0031 |
| `CapabilityRegistry` | W2 | ADR-0021 |
| `AgentRegistry` + `RemoteAgentClient` | post-W4 | ADR-0016 |

Seven previously listed SDK SPI interfaces were deleted in the 2026-05-12 Occam pass (see `architecture-status.yaml` row `sdk_spi_starters`). They are no longer part of the contract surface.

---

## 3. Configuration contracts

**Absorbed from `configuration-contracts.md`**: All properties under `springai.ascend.*`; `app.posture={dev,research,prod}` read once at boot (dev=permissive, research/prod=fail-closed). Each starter exposes `springai.ascend.<domain>.enabled`. Sidecar adapters (`graphmemory`) default `enabled=false`; require `base-url` when enabled.

**Absorbed from `contract-evolution-policy.md`**: Config deprecation = N+2 release cycle. HTTP /v1 stays active after /v2 (research: 90 days, prod: 180 days). Breaking-change checklist required before any contract-surface PR merges.

---

## 4. Telemetry contract (absorbed from `telemetry-contracts.md`)

Counter: `SPRINGAI_ASCEND_<domain>_<subject>_total`. Timer: `SPRINGAI_ASCEND_<domain>_<operation>_seconds`. High-cardinality labels (`tenant_id`, `run_id`, `user_id`) forbidden on Prometheus; use structured JSON logs. Cardinality cap: 1 000 (research) / 10 000 (prod). Key counters: `*_default_impl_not_configured_total{spi, method}`, `filter_errors_total{filter, reason}`, `idempotency_{claimed,replayed,conflict,error}_total`.

---

## 5. SDK versioning (absorbed from `sdk-versioning.md`)

SemVer from 1.0.0: PATCH=fix, MINOR=additive, MAJOR=breaking. Stable surface: starter artifacts, SPI interfaces, Spring Boot property keys. Deprecate with `@Deprecated` in current MINOR; remove in next MAJOR. All deps pinned to exact patch in `spring-ai-ascend-dependencies` BoM. Spring AI 2.0.0-M5; CI forces upgrade after 2026-08-01. Current maturity: SPI=L1, HTTP /v1=L2, Config=L1, Telemetry=L1.

---

## 6. Maven BoM

`ascend.springai:spring-ai-ascend-dependencies:0.1.0-SNAPSHOT` — active modules:

| Artifact | Status |
|---|---|
| `spring-ai-ascend-parent` | Parent POM |
| `agent-platform` | Platform SPI + web + security + idempotency |
| `agent-runtime` | Run lifecycle + orchestration + posture |
| `spring-ai-ascend-graphmemory-starter` | Graph memory sidecar adapter skeleton |
| `spring-ai-ascend-dependencies` | BoM (dependency management) |

The following starters were deleted in the 2026-05-12 Occam pass and are no longer in `pom.xml`:
`-memory`, `-skills`, `-knowledge`, `-governance`, `-persistence`, `-resilience`, `-mem0`, `-docling`, `-langchain4j-profile`.

---

*See also*: `docs/cross-cutting/observability-policy.md` · `docs/cross-cutting/posture-model.md` · `docs/cross-cutting/data-model-conventions.md`
