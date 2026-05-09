# OSS Bill of Materials -- cross-cutting policy

> Owner: architecture | Wave: W0 (introduce); per-wave verification advances | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Pins the **exact version** of every open-source dependency the
architecture depends on, names the **specific APIs** we cite, marks
the **verification level** of each (the U0..U4 ladder below), and
documents the **integration contract** (how our glue talks to the
dep, what fallback exists, what risks remain).

Replaces the previous OSS matrix in `ARCHITECTURE.md` sec-2 which
only listed approximate version ranges (`1.0.x`, `latest`) without
verification. The cycle-11 user prompt correctly identified that
range-pinning without API-doc verification was insufficient; this
document is the response.

## 2. The U0..U4 verification ladder

Verification level is parallel to capability maturity (Rule 12 L0..L4)
but tracks the OSS-integration axis, not the product axis.

| Level | Meaning | Evidence |
|---|---|---|
| **U0** | Design-only | Version range chosen by reasoning + general knowledge; no docs read for this version specifically |
| **U1** | API-doc-verified | Pinned to a specific version; official changelog / Javadoc / release notes read for the APIs we cite; no code written |
| **U2** | Sample-code-verified | A small in-tree probe (compile-only or smoke test) confirms the dep resolves + the cited API exists and compiles |
| **U3** | Integration-verified | An IT test exercises the API end-to-end at the pinned version against a real instance / Testcontainer |
| **U4** | Production-verified | Production traces / metrics show the API behaving as designed across several releases |

**Today every dep starts at U0 or U1.** W0 advances critical-path deps
to U2 (probe code lands). W2/W3/W4 advance to U3 as IT tests land.
U4 is reached only after sustained prod use.

A dep at U0 is allowed in design; the architecture must mark it as
such and accept that the version / API claim may change when probed.
A dep that the architecture relies on for a security-critical control
(JWT validation, RLS enforcement, ActionGuard authorization) may NOT
be at U0 when the corresponding wave starts coding -- it must reach
U1 by then.

## 3. Verified critical-path deps (U1 today)

Three high-risk deps got direct verification on 2026-05-09 via the
upstream release pages.

### 3.1 Spring AI (U1)

| Field | Value |
|---|---|
| GroupId / Artifact | `org.springframework.ai:spring-ai-bom` (BOM) + `spring-ai-starter-*` per provider |
| Version pinned | `1.0.7` (latest 1.0.x patch as of 2026-05-08) |
| Branch | 1.0.x (stable); 1.1.x available; 2.0.x milestones not used |
| Status | GA (Spring AI 1.0.0 released 2025-05-20; 1.0.7 released 2026-05-08) |
| Verification level | U1 -- official Spring blog release notes + Maven Central availability confirmed |
| APIs we cite | `org.springframework.ai.chat.client.ChatClient` (builder + `.prompt().user(...).call()`), `org.springframework.ai.embedding.EmbeddingModel`, `org.springframework.ai.vectorstore.pgvector.PgVectorStore`, `org.springframework.ai.tool.ToolCallback` (function calling) |
| Glue we own | `agent-runtime/llm/ChatClientFactory`, `agent-runtime/llm/LlmRouter`, `agent-runtime/memory/PgVectorAdapter` |
| Integration contract | Provider-specific starters (`spring-ai-starter-model-anthropic`, `spring-ai-starter-model-openai`); each provider gets one bean; `LlmRouter` chooses |
| Fallback if dep absent | `FakeChatClient` for CI; degrades to `LLM_PROVIDER_UNAVAILABLE` 502 |
| Risks | (a) 1.0.x patch version may bump weekly -- treat as patch-compatible only; (b) tool-calling API surface evolved late in 1.0; verify exact signatures at U2 in W2; (c) 1.1.x branches in parallel -- if a 1.1-only API is needed, plan a major-bump wave |
| Upgrade trigger | 1.1 GA stable + ecosystem catches up; not before W4 |

### 3.2 Temporal Java SDK (U1)

| Field | Value |
|---|---|
| GroupId / Artifact | `io.temporal:temporal-sdk` |
| Version pinned | `1.34.0` |
| Status | GA (1.x line stable for years) |
| Verification level | U1 -- Maven Central + official Temporal docs confirm `1.34.0` and the `Workflow.getVersion(...)` API at the documented role |
| APIs we cite | `io.temporal.workflow.Workflow.getVersion(String changeId, int minSupported, int maxSupported)` (workflow versioning markers); `io.temporal.workflow.WorkflowInterface` + `@WorkflowMethod` (workflow contract); `io.temporal.activity.ActivityInterface` + `@ActivityMethod` (activity contract); `io.temporal.client.WorkflowClient.signalWithStart(...)` (signal contract); `io.temporal.workflow.SignalMethod` |
| Glue we own | `agent-runtime/temporal/RunWorkflow` (interface), `RunWorkflowImpl`, `LlmCallActivity`, `ToolCallActivity`, `CancelRunSignal`, `TemporalConfig` |
| Integration contract | Workflow code is deterministic; activities do all I/O; retry policies declared per activity; namespaces per environment / customer |
| Fallback if dep absent | `agent-runtime/run/RunOrchestrator` synchronous mode (W2-W3); workflow durability lost but short runs work |
| Risks | (a) Temporal cluster ops complexity -- managed Temporal Cloud as upgrade path; (b) Workflow lint required to avoid non-determinism; (c) `getVersion` markers must be retired at >= 30 days |
| Upgrade trigger | minor Temporal SDK every 90 days; major every 12 months |

### 3.3 MCP Java SDK (U1, milestone)

| Field | Value |
|---|---|
| GroupId / Artifact | `io.modelcontextprotocol.sdk:mcp` |
| Version pinned | `2.0.0-M2` |
| Status | **MILESTONE (not GA)** -- API may change before 2.0.0 GA |
| Verification level | U1 -- Maven Central artifact existence confirmed; specific API surface still in flux per MCP spec evolution |
| APIs we cite | (target) MCP server stub registration; tool descriptor schema; stdio + HTTP transport. Specific class names not yet pinned -- requires U2 probe in W3. |
| Glue we own | `agent-runtime/tool/McpToolRegistry`, `EchoTool` (stub), `HttpGetAllowlistTool`, `DocParserTool` |
| Integration contract | Tools register at startup as Spring beans implementing the SDK's tool interface; per-tenant allowlist in `tool_registry`; sandbox levels per tenant |
| Fallback if dep absent | In-process Java tool beans only (sandbox level 0 -- dev only) |
| Risks | (a) **MILESTONE STATUS** -- 2.0.0 GA may rename / re-shape APIs; the W3 wave must defend a 2.0.0-GA upgrade path; (b) MCP spec itself evolves on a 2025-11-25 / 2026-XX-XX cadence; (c) the M2 -> GA timeline is not on our roadmap, so we may upgrade to GA mid-W3 |
| Upgrade trigger | 2.0.0 GA at any time; planned for the W3 wave's first sprint |
| Mitigation | The `McpToolRegistry` glue is intentionally thin -- it adapts the SDK's interface to our `Tool` interface so an SDK API change is a single adapter rewrite, not a corpus-wide change |

## 4. Other deps (U0 today; W0+ probe required)

The deps below are at U0 -- versions pinned by reasoning + general
knowledge, not by reading 2026-05-09 release notes. **W0 adds a probe
test per dep that compiles against the listed APIs and advances the
dep to U2.** Until W0 lands, treat the version / API claim as
plausible but unverified.

### 4.1 JVM + build chain

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| OpenJDK | `21.0.x` LTS | virtual threads (`Thread.ofVirtual()`), records, sealed classes | Eclipse Temurin or Liberica binary OK; W0 picks one |
| Maven | `3.9.x` | `mvn -B -ntp --strict-checksums` | parent BOM + module poms |
| Spring Boot | `3.5.x` | `@SpringBootApplication`, actuator, virtual-thread enable | confirms compatibility with Java 21 |

### 4.2 Persistence

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| PostgreSQL | `16.x` | `SET LOCAL`, RLS policies, `FOR UPDATE SKIP LOCKED`, partitioned tables | core DB; on-prem or managed |
| pgvector | `0.7.x` | `vector` column type; `ivfflat` + `hnsw` indexes; `<->` distance ops | extension; verify supported on the chosen Postgres host |
| HikariCP | `5.x` (transitive via Spring Boot) | pool sizing, leak detection | virtual-thread-friendly per Hikari 5.x release notes |
| Flyway | `10.x` | `mvn flyway:migrate`; `V<n>__<name>.sql` | classpath roots per module |
| Spring Data JDBC | (BOM transitive) | `JdbcTemplate`, `@Repository`, optimistic-lock support | not JPA |

### 4.3 Identity + auth + policy

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| Spring Security | `6.x` (BOM transitive) | `SecurityFilterChain`, `oauth2ResourceServer`, JWT decoder | matches Spring Boot 3.5.x |
| Nimbus JOSE+JWT | `9.x` (transitive) | `RSASSAVerifier`, `JWKSet` | algorithm allowlist explicit |
| Keycloak | `25.x` (compose only) | OIDC discovery; realm import | dev IdP; prod customers may bring their own |
| OPA | `0.65.x` | sidecar HTTP API; Rego policy bundle | latency target < 5ms p99 (sidecar) |
| HashiCorp Vault | OSS edition | KV v2 secret backend; `secret/` paths | dev mode in compose; cluster in prod |
| Spring Cloud Vault | `4.x` | `@RefreshScope`, watcher | matches Spring Cloud 2024.x for Boot 3.5 |
| Spring Cloud Config | `4.x` | `@ConfigurationProperties` reload | optional in dev |

### 4.4 Resilience + observability

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| Resilience4j | `2.x` | `@CircuitBreaker`, `@RateLimiter`, `@Retry` annotations | per-bean instance; metrics via Micrometer |
| Caffeine | `3.x` | `Cache.builder().expireAfter(...)` | L0 memory cache + per-tenant config cache |
| Valkey | `7.x` (Redis fork; OSS) | client lib: `lettuce` 6.x | for cross-replica state if needed (W2+) |
| Micrometer | (BOM transitive) | `Counter`, `Timer`, `@Timed` | Prometheus exposition |
| OpenTelemetry Java agent | `2.x` | auto-instrumentation; `@WithSpan` | attached at JVM start |
| Logback + JSON encoder | (BOM) + `net.logstash:logstash-logback-encoder:8.x` | structured logs to Loki | configured in W0 |
| Loki + Grafana + Tempo | latest stable | log + dashboard + trace store | compose + Helm |

### 4.5 Web + tooling

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| Spring Web (MVC) | (BOM) | DispatcherServlet, `@RestController` | virtual threads enabled |
| Spring Cloud Gateway | `4.x` | `RouteLocator`, filter chain | W2 onward |
| Hibernate Validator | (BOM) | `@Valid`, `@NotNull` etc. | Bean Validation 3 |
| Jackson | (BOM) | `ObjectMapper` | YAML adds `jackson-dataformat-yaml` |
| springdoc-openapi | `2.x` | OpenAPI 3 generation | `/v3/api-docs` |
| Apache Tika | `2.x` | `Parser`, `Detector` | document parsing tool default (W3) |

### 4.6 Container + ops

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| Buildpacks (Paketo) | latest | Dockerfile alternative | one of two; pick at W0 |
| Distroless base image | `gcr.io/distroless/java21-debian12@sha256:<digest>` | runtime base | digest pinned |
| Kubernetes | `1.30+` | Deployment, HPA, PDB, NetworkPolicy | required version per Helm chart |
| Helm | `3.x` | umbrella chart | `ops/helm/` |

### 4.7 Testing

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| JUnit 5 | `5.10.x` | `@Test`, `@ParameterizedTest`, lifecycle | core |
| Testcontainers | `1.20.x` | `PostgreSQLContainer`, `GenericContainer`, `KeycloakContainer` | per-IT integration |
| WireMock | `3.x` | provider fake | LLM provider stub in CI |
| RestAssured | `5.x` | E2E HTTP tests | preferred over MockMvc for E2E |
| Karate | `1.x` | `.feature` BDD-style E2E | optional alternative |
| Mockito | (BOM) | unit-test mocks | restricted to Layer 1 (per Rule 4) |

### 4.8 Eval + agentics (W4)

| Dep | Pinned | API surface | Notes |
|---|---|---|---|
| Ragas-Java port OR custom | TBD | RAG eval metrics | W4; choice deferred |
| LangChain4j (alt to Spring AI) | DEFERRED | -- | only if a customer demands |

## 5. Integration contract template

Every dep above has the same shape under "Integration contract":

```
- Where the dep is declared (Maven coordinates, BOM)
- Which Spring bean(s) it produces
- Which glue module owns the wiring
- Which configuration properties it reads
- Which fallback behavior exists if the dep is unavailable
- Which test exercises the integration (per L2 doc)
```

Per-dep entries above use abbreviated forms; the full template lands
when the dep advances to U2 in W0.

## 6. Per-wave verification advancement

| Wave | Promotion target |
|---|---|
| **W0** | Spring Boot, Postgres, Flyway, HikariCP, Java 21, Maven, JUnit, Testcontainers, Logback, Micrometer, Buildpacks -> **U2** (probe in tree) |
| **W1** | Spring Security, Keycloak, Resilience4j, Spring Cloud Vault -> **U2** + **U3** (IT against Testcontainers) |
| **W2** | Spring AI 1.0.7, Spring Cloud Gateway, OTel Java agent, Loki/Grafana, Caffeine -> **U2** + **U3** |
| **W3** | OPA 0.65.x, MCP 2.0.0-Mx, Apache Tika, pgvector 0.7.x, Spring AI VectorStore PgVector -> **U2** + **U3** |
| **W4** | Temporal Java SDK 1.34.0, Helm chart full, distroless image -> **U3** |
| **W4+** | Eval framework, optional Qdrant trigger -> **U2** |

After W4 close, the BoM doc is re-visited every quarter; any dep
that has not been touched (no PRs, no upgrades) for > 90 days is
flagged for review.

## 7. Risk-weighted maintenance

| Tier | Cadence | Examples |
|---|---|---|
| **T1** security-critical | minor monthly; major within 90 days | Spring Security, Spring Boot, Postgres JDBC, Nimbus JOSE+JWT, Vault |
| **T2** runtime-critical | minor quarterly; major within 180 days | Spring AI, Temporal, pgvector, Resilience4j, Caffeine |
| **T3** testing / build | minor on convenience | Testcontainers, JUnit, Maven plugins |

Tier definition matches `ARCHITECTURE.md` sec-2.1 OSS dependency policy.

## 8. Honest gaps

- **No dep is at U2 today.** No Maven artifacts have been pulled; no
  probe code exists. The architecture's API claims are plausible but
  unverified by compile.
- **Spring AI 1.0.7 vs 1.1.x choice is not final.** Pinning to 1.0.x
  trades feature recency for stability; reconsidered each release.
- **MCP Java SDK at milestone.** API may change at 2.0.0 GA. The
  W3 plan must include a 2.0.0-GA upgrade contingency.
- **Temporal 1.34.0 may not be the GA at W4 start.** Pin will refresh
  at the W4 wave plan revision.
- **Pinned exact versions in this doc may drift before W0** as
  upstream releases land. The cadence rule sec-7 catches drift but
  does not prevent it.

## 9. Tests (W0+)

| Test | Layer | Asserts |
|---|---|---|
| `OssBomCompileProbeIT` | CI (W0) | every dep listed at U2 compiles + transitively resolves |
| `OssBomVersionPinIT` | CI (W0) | every BOM-managed dep matches pin in `pom.xml` |
| `OssBomMilestoneNoticeIT` | CI (W3) | milestone deps (e.g., MCP) emit a "milestone-pinned" build warning |

## 10. Cadence

- This doc is updated at every cycle close where an OSS dep was
  pinned, upgraded, swapped, or had its U-level advanced.
- Quarterly: full BoM walk; any U0 entry > 90 days old without
  promotion plan is flagged.
- At every wave close: U-level promotions per sec-6 are recorded as
  status YAML rows.

## 11. References

- `ARCHITECTURE.md` sec-2 (OSS component matrix; this BoM is the
  authoritative version)
- `ARCHITECTURE.md` sec-2.1 (OSS dependency policy: pinning,
  Dependabot, tier cadence)
- `docs/cross-cutting/supply-chain-controls.md` (build provenance,
  SBOM, image digest pinning)
- Spring AI 1.0.7 release notes (2026-05-08) -- upstream confirmation
- Temporal Java SDK docs / Maven Central -- 1.34.0 confirmation
- MCP Java SDK Maven Central -- `io.modelcontextprotocol.sdk:mcp:2.0.0-M2`
