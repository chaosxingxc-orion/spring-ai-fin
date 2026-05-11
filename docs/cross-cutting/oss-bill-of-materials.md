# OSS Bill of Materials -- cross-cutting policy

> Owner: architecture | Wave: W0 (introduce); per-wave verification advances | Maturity: L2
> Last refreshed: 2026-05-10 (W0 U2 promotion complete)

## 1. Purpose

Pins the **exact version** of every open-source dependency the
architecture depends on, names the **specific APIs** we cite, marks
the **verification level** of each (the U0..U4 ladder below), and
documents the **integration contract** (how our glue talks to the
dep, what fallback exists, what risks remain).

## 2. The U0..U4 verification ladder

| Level | Meaning | Evidence |
|---|---|---|
| **U0** | Design-only | Version range chosen by reasoning; no docs read for this version specifically |
| **U1** | API-doc-verified | Pinned to a specific version; official changelog / Javadoc read for the APIs we cite |
| **U2** | Sample-code-verified | In-tree probe compiles against the dep at the pinned version; `mvn compile` green |
| **U3** | Integration-verified | IT test exercises the API end-to-end at the pinned version against a real instance |
| **U4** | Production-verified | Production traces / metrics show the API behaving as designed across several releases |

## 3. Critical-path deps (U2 as of W0, sha cd13612)

All five W0 critical-path deps are at U2 as of commit cd13612
(`probe: refresh OssApiProbe for AI 2.0 + MCP 1.0.0 GA`).
Evidence: `docs/delivery/2026-05-10-ca9bbba-mvn-resolve.log`.

### 3.1 Spring AI 2.0.0-M5 (U2)

| Field | Value |
|---|---|
| GroupId / Artifact | `org.springframework.ai:spring-ai-bom` (BOM) + `spring-ai-starter-*` per provider |
| Version pinned | `2.0.0-M5` |
| Status | **MILESTONE** -- 2.0 GA expected mid-2026. Required for Spring Boot 4.0 compatibility (1.x incompatible with Boot 4). |
| Verification level | **U2** at sha cd13612 |
| Verified-at-sha | cd13612 |
| APIs cited | `ChatClient`, `ChatModel`, `EmbeddingModel`, `VectorStore` (package `org.springframework.ai.*`) |
| Probe | `agent-runtime/.../probe/OssApiProbe.java` |
| Glue we own | `agent-runtime/llm/ChatClientFactory`, `agent-runtime/llm/LlmRouter`, `agent-runtime/memory/PgVectorAdapter` |
| Risks | (a) Milestone API may shift between M5 and GA; gate/check_spring_ai_milestone.sh fails CI past 2026-08-01 if still on M-version, forcing re-eval. (b) 2.0 GA expected ~mid-2026 -- plan W2 upgrade. |
| Upgrade trigger | 2.0 GA; or gate fires |

### 3.2 Temporal Java SDK 1.35.0 (U2)

| Field | Value |
|---|---|
| GroupId / Artifact | `io.temporal:temporal-sdk` |
| Version pinned | `1.35.0` |
| Status | GA (1.x line stable) |
| Verification level | **U2** at sha cd13612 |
| Verified-at-sha | cd13612 |
| APIs cited | `Workflow`, `WorkflowInterface`, `WorkflowMethod`, `ActivityInterface`, `ActivityMethod`, `WorkflowClient` (package `io.temporal.*`) |
| Probe | `agent-runtime/.../probe/OssApiProbe.java#temporalGetVersionShape()` |
| Glue we own | `agent-runtime/temporal/RunWorkflow`, `RunWorkflowImpl`, `LlmCallActivity`, `ToolCallActivity` |
| Risks | Workflow determinism lint required; `getVersion` markers must be retired >= 30 days after rollout |
| Upgrade trigger | Minor every 90 days; major every 12 months |

### 3.3 MCP Java SDK 1.0.0 GA (U2)

| Field | Value |
|---|---|
| GroupId / Artifact | `io.modelcontextprotocol.sdk:mcp` |
| Version pinned | `1.0.0` (GA -- downgraded from milestone 2.0.0-M2 to stable release) |
| Status | GA |
| Verification level | **U2** at sha cd13612 |
| Verified-at-sha | cd13612 |
| APIs cited | `McpClient`, `McpSyncClient`, `McpAsyncClient` (package `io.modelcontextprotocol.client`); `McpSchema` (package `io.modelcontextprotocol.spec`) |
| Probe | `agent-runtime/.../probe/OssApiProbe.java` |
| Glue we own | `agent-runtime/tool/McpToolRegistry` |
| Risks | MCP spec continues evolving; 1.0.0 is first stable release; server transports (SSE, streamable-HTTP) are part of the API |
| Upgrade trigger | Patch as available; minor when a needed MCP server feature requires it |

### 3.4 Apache Tika 3.3.0 (U2)

| Field | Value |
|---|---|
| GroupId / Artifact | `org.apache.tika:tika-core` + `tika-parsers-standard-package` |
| Version pinned | `3.3.0` |
| Status | GA (3.x series replaces 2.x which reached EOL April 2025) |
| Verification level | **U2** at sha cd13612 |
| Verified-at-sha | cd13612 |
| APIs cited | `AutoDetectParser`, `Metadata` (package `org.apache.tika.*`) |
| Breaking change vs 2.x | Metadata key prefixes changed: `html:`, `mapi:`, `X-TIKA:resourceName`. No production code reads Tika metadata yet (pipeline lands W2). |
| Probe | `agent-runtime/.../probe/OssApiProbe.java` |
| Upgrade trigger | Patch as available |

### 3.5 Spring Boot 4.0.5 + platform stack (U2)

All Spring Boot 4.x transitive deps (Web, Security, Data JDBC, Actuator, Validation, Cache) resolved and compiled at sha cd13612.

| Component | Version |
|---|---|
| Spring Boot parent | `4.0.5` |
| Spring Cloud BOM | `2025.1.1` ("Oakwood" -- only train compatible with Boot 4.0.x) |
| Spring Security | `6.x` (BOM transitive) |
| Spring Data JDBC | BOM transitive |
| Flyway | `11.19.1` |
| Resilience4j | `2.4.0` |
| Caffeine | `3.2.4` |
| springdoc-openapi | `3.0.3` (Boot 4 official support) |
| logstash-logback-encoder | `8.0` |
| Micrometer | BOM transitive |
| Testcontainers | `1.21.4` |
| WireMock | `3.9.1` (4.x is beta) |
| RestAssured | `5.5.0` (6.0.0 is major) |
| ArchUnit | `1.4.2` |

## 4. Other deps (U0-U1; wave schedule below)

### 4.1 JVM + build chain (U2 at W0)

| Dep | Pinned | Status |
|---|---|---|
| OpenJDK 21 | Temurin `21.0.11+10` | U2 -- installed and compile-verified |
| Maven | `3.9.15` (via wrapper) | U2 -- mvnw bootstrapped at sha ca9bbba |

### 4.2 Persistence (U0/U1; U2 target W1-W2)

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| PostgreSQL | `16.x` | `SET LOCAL`, RLS, `FOR UPDATE SKIP LOCKED`, partitioned tables | External; Testcontainer for IT |
| pgvector | `0.7.x` | `vector` column, `ivfflat`/`hnsw` indexes, `<->` ops | Extension; needs host support |
| HikariCP | `5.x` (BOM transitive) | pool sizing, leak detection | Virtual-thread-friendly per 5.x release notes |
| Spring Data JDBC | BOM transitive | `JdbcTemplate`, `@Repository` | Not JPA |

### 4.3 Identity + auth + policy (U0/U1; U2 target W1)

| Dep | Pinned | Notes |
|---|---|---|
| Spring Security | `6.x` (BOM) | `SecurityFilterChain`, `oauth2ResourceServer`, JWT decoder |
| Nimbus JOSE+JWT | `9.x` (transitive) | Algorithm allowlist explicit |
| Keycloak | `25.x` (compose only) | OIDC discovery; realm import; dev IdP |
| OPA | `0.65.x` | sidecar HTTP API; Rego policy bundle; latency < 5ms p99 |
| HashiCorp Vault | OSS | KV v2; dev mode in compose; cluster in prod |
| Spring Cloud Vault | `2025.1.1` BOM | `@RefreshScope`, watcher |

### 4.4 Resilience + observability (U2 compile-verified, U3 target W1)

| Dep | Pinned | Notes |
|---|---|---|
| Resilience4j | `2.4.0` | `@CircuitBreaker`, `@RateLimiter`, `@Retry`; metrics via Micrometer |
| Caffeine | `3.2.4` | L0 memory cache + per-tenant config cache |
| OpenTelemetry Java agent | `2.10.0` | auto-instrumentation; `@WithSpan` |
| logstash-logback-encoder | `8.0` | structured logs to Loki |

### 4.5 Document parsing + knowledge (U2 Tika core; sidecars U0)

| Dep | Pinned | Channel | Notes |
|---|---|---|---|
| Apache Tika | `3.3.0` | Maven | Core + parsers-standard; U2 at W0 |
| Docling-serve | pinned in third_party/MANIFEST.md | Tier C (REST sidecar) | Layout-aware PDF; optional via docling-starter SPI |

### 4.6 langchain4j (alternate RAG profile; U0 at W0)

| Field | Value |
|---|---|
| BOM | `dev.langchain4j:langchain4j-bom:1.14.1` |
| Status | GA (1.14.1 released 2026-05-07) |
| Usage | Alternate RAG profile starter (`spring-ai-ascend-langchain4j-profile`); not in default path |
| Verification level | U0 -- BOM declared; no module depends on it yet |
| Target | U2 when spring-ai-ascend-langchain4j-profile scaffolded (Step 11) |

## 5. Per-wave verification advancement (revised W0 complete)

| Wave | Status | Promotion target |
|---|---|---|
| **W0** | **COMPLETE** at sha cd13612 | Java 21, Maven 3.9.15, Spring Boot 4.0.5, Spring AI 2.0.0-M5, MCP 1.0.0 GA, Temporal 1.35.0, Tika 3.3.0, Flyway 11.19.1, Resilience4j 2.4.0, Caffeine 3.2.4, Testcontainers 1.21.4, ArchUnit 1.4.2 -> **U2** |
| **W1** | Pending | Spring Security, Keycloak, Spring Cloud Vault, OPA -> **U2** + **U3** (IT against Testcontainers) |
| **W2** | Pending | Spring AI VectorStore PgVector, OTel Java agent, Loki/Grafana, Kafka/Redpanda, Caffeine IT -> **U3** |
| **W3** | Pending | OPA runtime policy, pgvector, Temporal full IT, WireMock LLM stubs -> **U3** |
| **W4** | Pending | Helm chart full, distroless image -> **U3** |
| **W4+** | Future | Eval framework -> **U2** |

## 6. Integration model (W0 decision, reference-project verified)

**Decision: Hybrid library-first SDK with optional Python-community REST sidecars.**

The SDK ships as Spring Boot Starters published to Maven Central. The default
integration mode for every capability is in-JVM Java code; nothing in the default
path requires an extra service beyond the data plane (Postgres+pgvector, Temporal
server, OPA daemon, observability stack, LLM provider APIs, MCP tool servers).

For capabilities where the most-active OSS community lives in Python, the SDK
exposes a stable Java SPI; an optional adapter starter implements that SPI as a
thin REST client, and a docker-compose overlay in `ops/compose/` provisions the
Python sidecar. Consumers opt in per deployment.

This model is validated by three reference projects (langchain4j, spring-ai-alibaba,
agentscope-java), all of which ship as Maven Central libraries with zero mandatory
microservices. See `docs/architecture-v6.X.md` integration-model section for the
full analysis.

### Per-capability OSS adoption matrix

| Capability | Default (Maven Central, embedded) | Optional sidecar (REST via SPI) |
|---|---|---|
| Skills / Tools | MCP Java SDK 1.0.0 GA + external MCP servers | n/a (MCP is protocol-based) |
| Short-term memory | Spring AI `ChatMemory` (in-process) | n/a |
| Long-term hierarchical memory | Spring AI `ChatMemoryRepository` over Postgres | **mem0** (55.2k stars) via `LongTermMemoryRepository` SPI |
| Knowledge-graph memory | none in default path | **Graphiti** (25.8k stars) via `GraphMemoryRepository` SPI |
| Document parsing (general) | Apache Tika 3.3.0 (in-process) | n/a |
| Document parsing (layout-aware) | Tika fallback | **Docling-serve** (IBM/LF AI&Data) via `LayoutParser` SPI |
| RAG pipeline (default) | Spring AI 2.0-M5 ETL (`DocumentReader` -> `DocumentTransformer` -> `VectorStore`) | n/a |
| RAG pipeline (alternate) | langchain4j 1.14.1 modules (opt-in profile) | n/a |
| Vector store | Spring AI `VectorStore` client + pgvector | Spring AI Pinecone/Qdrant/Weaviate adapters |
| Embedding model | Spring AI client -> OpenAI/Anthropic/Bedrock/Ollama | n/a |
| Governance build-time | ArchUnit + active-corpus.yaml | n/a |
| Governance runtime | OPA Java client (in-process) | OPA daemon (external REST) |
| Database / persistence | Spring Data JDBC + Flyway 11.19.1 + Postgres | n/a |
| Workflow orchestration | Temporal Java SDK 1.35.0 + Temporal server (external) | n/a |

### SPI surface (frozen by ArchUnit at Step 10)

- `ascend.springai.runtime.spi.memory.LongTermMemoryRepository` -- default: Spring AI JDBC repo. Sidecar: mem0.
- `ascend.springai.runtime.spi.memory.GraphMemoryRepository` -- sidecar only: Graphiti (cycle-15 confirms vs Cognee).
- `ascend.springai.runtime.spi.knowledge.LayoutParser` -- default: Tika. Sidecar: Docling.
- `ascend.springai.runtime.spi.knowledge.DocumentSourceConnector` -- N implementations, opt-in per source.
- `ascend.springai.runtime.spi.skills.ToolProvider` -- wraps MCP `McpClient` + local `@Tool` registry.
- `ascend.springai.runtime.spi.governance.PolicyEvaluator` -- default: in-process JSR-303 + ArchUnit. External: OPA client.
- `ascend.springai.runtime.spi.persistence.RunRepository`, `IdempotencyRepository`, `ArtifactRepository` -- Spring Data JDBC default impls.

## 7. Tier C: local source clones + Python OSS sidecars

Tracked in `third_party/MANIFEST.md`. All entries gitignored; SHAs captured in the manifest.

### Infrastructure servers (11)

| Name | Purpose |
|---|---|
| Postgres + pgvector | Primary data store + vector extension |
| Keycloak | OIDC IdP (dev) |
| Temporal server | Workflow orchestration |
| Redpanda | Kafka-compatible event bus |
| MinIO | Object storage |
| Loki | Log aggregation |
| Grafana | Dashboards |
| Prometheus | Metrics |
| Tempo | Distributed tracing |
| OPA | Policy engine daemon |
| OpenSearch | Full-text search (optional) |

### Python community OSS sidecars (5)

| Name | Stars | Purpose | SPI |
|---|---|---|---|
| **mem0** (`mem0ai/mem0`) | 55.2k | Long-term hierarchical memory | `LongTermMemoryRepository` via `spring-ai-ascend-mem0-starter` |
| **Graphiti** (`getzep/graphiti`) | 25.8k | Knowledge-graph memory | `GraphMemoryRepository` via `spring-ai-ascend-graphmemory-starter` |
| **Cognee** (`topoteretes/cognee`) | 17.1k | Graph memory alternative to Graphiti | Evaluation alternative; cycle-15 picks one |
| **Docling-serve** (`docling-project/docling-serve`) | IBM/LF AI&Data | Layout-aware PDF parsing | `LayoutParser` via `spring-ai-ascend-docling-starter` |
| **RAGFlow** (`infiniflow/ragflow`) | 80.1k | Alternate full-stack RAG platform | No SDK adapter; consumer integrates via RAGFlow API |

## 8. Excluded dependencies (competitor code -- never import)

These projects' implementations are **NOT imported as Maven dependencies,
NOT cloned to `third_party/`, and NOT auto-configured anywhere in the SDK**.
Their architectures may be cited as design evidence in plans/ADRs, but their
code does not enter our build.

| Project | Group ID | Reason | Permitted use |
|---|---|---|---|
| **spring-ai-alibaba** | `com.alibaba.cloud.ai:*` | Direct competitor in the agent runtime / SDK space | Architectural reference in ADRs/docs only |

**ArchUnit enforcement (Step 10):**
```java
noClasses().that().resideInAPackage("ascend.springai..")
           .should().dependOnClassesThat()
           .resideInAPackage("com.alibaba.cloud.ai..");
```

Future cycles MUST check this section before proposing any `com.alibaba.cloud.ai:*` artifact.

The remaining reference projects (langchain4j, agentscope-java) are NOT on this list:
- **langchain4j** (`dev.langchain4j:*`) -- generic open-source agent toolkit; imported as alternate RAG profile + document-loader catalog.
- **agentscope-java** (`io.agentscope:*`) -- research-oriented agent framework; not currently imported; available as architectural reference only.

## 9. Backward-compatibility strategy (SDK publishing)

1. **Strict version pinning.** Every dep pinned to exact patch in `pom.xml` `<properties>`. No ranges, no `LATEST`.
2. **BoM module.** `spring-ai-ascend-dependencies` (packaging=pom) is the SDK's published version contract.
3. **SPI freeze via ArchUnit.** `ApiCompatibilityTest` enforces public-package boundary on `ascend.springai.runtime.spi.**`. Any change requires editing the test.
4. **Spring AI milestone gate.** `gate/check_spring_ai_milestone.sh` fails CI past 2026-08-01 if `spring-ai.version` still contains `-M`.
5. **Sidecar adapter independence.** Sidecar adapter starters live in their own modules; the Python service can break compatibility without affecting the SDK's SPI surface.
6. **Deprecation policy**: SemVer; minor for additive; major for breaking; downstream gets one minor of deprecation overlap. Documented in `docs/cross-cutting/sdk-versioning.md`.

## 10. Risk-weighted maintenance

| Tier | Cadence | Examples |
|---|---|---|
| **T1** security-critical | minor monthly; major within 90 days | Spring Security, Spring Boot, Postgres JDBC, Nimbus JOSE+JWT, Vault |
| **T2** runtime-critical | minor quarterly; major within 180 days | Spring AI, Temporal, pgvector, Resilience4j, Caffeine |
| **T3** testing / build | minor on convenience | Testcontainers, JUnit, Maven plugins |

## 11. Honest gaps

- **Spring AI 2.0.0-M5 milestone risk.** API may shift between M5 and GA. `gate/check_spring_ai_milestone.sh` enforces re-evaluation by 2026-08-01. W2 plan includes upgrade-to-GA contingency.
- **WireMock stuck at 3.9.1.** WireMock 4.x is in beta (4.0.0-beta.34 as of 2026-05-10); keeping 3.x until 4.x reaches GA.
- **RestAssured stuck at 5.5.0.** 6.0.0 is a major version jump; upgrade deferred to W1 wave evaluation.
- **logstash-logback-encoder stuck at 8.0.** 9.0 is a major version jump; upgrade deferred to W1 evaluation.
- **Graphiti vs Cognee not yet picked.** Both cloned into `third_party/`; `spring-ai-ascend-graphmemory-starter` initially wires Graphiti (higher activity). Cycle-15 confirms or swaps.
- **langchain4j at U0.** BOM declared; no module depends on it yet. Advances to U2 when `spring-ai-ascend-langchain4j-profile` scaffolded at Step 11.
- **Python sidecar version drift.** mem0 / Graphiti / Docling release independently. Mitigated by SPI layer + `third_party/MANIFEST.md` SHA pinning.
- **springdoc 3.0.3 Boot 4 runtime behavior.** Compile-verified at W0; runtime auto-configuration verified in W1 IT tests.

## 12. References

- `ARCHITECTURE.md` sec-2 (OSS component matrix)
- `docs/architecture-v6.X.md` integration-model section
- `docs/plans/engineering-plan-W0-W4.md`
- `third_party/MANIFEST.md` (Tier C SHA manifest)
- `docs/cross-cutting/sdk-versioning.md` (deprecation policy)
- `docs/cross-cutting/dev-environment.md` (toolchain install guide)
- Spring AI 2.0.0-M5 release notes (milestone)
- Temporal Java SDK 1.35.0 -- Maven Central confirmation
- MCP Java SDK 1.0.0 GA -- Maven Central `io.modelcontextprotocol.sdk:mcp:1.0.0`
- langchain4j 1.14.1 GA (2026-05-07) -- `dev.langchain4j:langchain4j-bom:1.14.1`
