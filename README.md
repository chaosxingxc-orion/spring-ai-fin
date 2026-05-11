# spring-ai-ascend

> **Capability-layer enterprise agent platform for Southeast Asia financial services (Indonesia OJK / Singapore MAS).** Built on Spring Boot 4.0.5 + Spring AI 2.0.0-M5. Multi-framework dispatch (Spring AI native, LangChain4j profile, Python sidecars). W0 scaffold: Maven compile+unit-test PASS at a7756cd; ITs pending Docker in CI. 14 Maven modules, SPI surface frozen at 7 interfaces.

**Status**: v6.1 architecture · W0 scaffold: Maven compile+unit-test PASS at a7756cd; ITs pending Docker in CI · 14 Maven modules · SPI surface frozen
**License preference**: Apache 2.0 / MIT only on the runtime path (see [`ARCHITECTURE.md`](ARCHITECTURE.md) D-15)

---

## Reading order

| Audience | Start at | Time |
|---|---|---|
| Architecture review committee | [`docs/architecture-review-2026-05-07.md`](docs/architecture-review-2026-05-07.md) (1,286 lines, 4 appendices) | 90-180 min |
| Senior architect | [`ARCHITECTURE.md`](ARCHITECTURE.md) v6.1 (17 decision chains) | 90 min |
| Engineer onboarding | [`CLAUDE.md`](CLAUDE.md) (12 universal rules) then L1 docs | 60 min |
| Skeptical reviewer | [`docs/architecture-v5.0-review-2026-05-07.md`](docs/architecture-v5.0-review-2026-05-07.md) then [`ARCHITECTURE.md`](ARCHITECTURE.md) deltas | 60 min |

## Document hierarchy

```
spring-ai-ascend/
├── ARCHITECTURE.md                              L0 system boundary (v6.1, 17 decisions)
├── CLAUDE.md                                    Behavioural rules (12 universal rules)
├── README.md                                    this file
│
├── agent-platform/                              Tier-A northbound facade (L1 — HealthEndpointIT; CI pass expected)
│   └── ARCHITECTURE.md                          L1
│
├── agent-runtime/                               Tier-B cognitive runtime (L1 — OssApiProbeTest compile-verified at a7756cd)
│   └── ARCHITECTURE.md                          L1
│
├── spring-ai-ascend-dependencies/                  BoM — pins 7 starter coordinates + 13 OSS deps (L1 — SPI interface compiled)
│   └── pom.xml
│
├── spring-ai-ascend-memory-starter/                SPI: LongTermMemoryRepository, GraphMemoryRepository (L1 — SPI interface compiled)
├── spring-ai-ascend-skills-starter/                SPI: ToolProvider (L1 — SPI interface compiled)
├── spring-ai-ascend-knowledge-starter/             SPI: LayoutParser, DocumentSourceConnector (L1 — SPI interface compiled)
├── spring-ai-ascend-governance-starter/            SPI: PolicyEvaluator (L1 — SPI interface compiled)
├── spring-ai-ascend-persistence-starter/           SPI: RunRepository, IdempotencyRepository, ArtifactRepository (L1 — SPI interface compiled)
├── spring-ai-ascend-resilience-starter/            SPI: ResilienceContract (L1 — SPI interface compiled; W2 callers)
│
├── spring-ai-ascend-mem0-starter/                  Sidecar adapter — Mem0 REST (enabled=false by default, L0)
├── spring-ai-ascend-graphmemory-starter/           Sidecar adapter — Graphiti REST (enabled=false by default, L0)
├── spring-ai-ascend-docling-starter/               Sidecar adapter — Docling REST (enabled=false by default, L0)
├── spring-ai-ascend-langchain4j-profile/           Alternate framework profile — LangChain4j (enabled=false, L0)
│
├── ops/
│   ├── runbooks/                                5 operational runbooks (L0 skeleton, Maturity: L0)
│   └── helm/spring-ai-ascend/                      Helm chart skeleton (L0, not deployment-tested)
├── perf/                                        Performance evidence path (JMH skeleton, W4 numbers)
├── gate/                                        Architecture gate + doctor scripts
├── third_party/                                 Third-party notices and OSS attribution
│
└── docs/
    ├── adr/                                     15 per-file MADR 4.0 ADRs (0001..0015) + README index
    ├── security/rls-policy.sql                  PostgreSQL RLS DDL (app.tenant_id GUC enforcement)
    ├── contracts/                               HTTP API, SPI, config, telemetry, BoM contracts
    ├── architecture-review-2026-05-07.md        Committee-facing review document
    ├── governance/                              architecture-status.yaml, evidence-manifest.yaml
    ├── delivery/                                Gate-run evidence files (per-SHA)
    └── cross-cutting/                           OSS BoM policy, security, posture
```

SPI interfaces are frozen by `ApiCompatibilityTest` (ArchUnit 4 rules compile-verified at a7756cd; japicmp configured).
L-levels per Rule 12: L0 = sentinel impl only; L1 = tested component; L2 = public contract.

## Architecture-review readiness

A 15-dimension architecture-review-readiness audit was run on 2026-05-10 against the W0 scaffold.
Result: 5 PASS / 6 PARTIAL / 4 GAP. An improvement pass (T-AR-0 through T-AR-13) closed or
scaffolded every gap. Final score after the pass: 9 PASS / 6 PARTIAL / 0 GAP.

**Gaps closed (Tier 1):**

| Tranche | What changed |
|---------|-------------|
| T-AR-0 | `mvnw` executable bit set for Linux CI runners |
| T-AR-1 | japicmp baseline configured; ApiCompatibilityTest rules 3+4 non-vacuous |
| T-AR-2 | `@ConditionalOnProperty` wired in all 5 starters; enabled=false disables beans |
| T-AR-3 | OpenApiContractIT replaced vacuous check with actual snapshot diff |
| T-AR-4 | RLS policy SQL in-tree; 3 tenant isolation IT skeletons added |
| T-AR-5 | 5 operational runbooks + Helm chart skeleton + doctor scripts |

**Hygiene (Tier 2):**

| Tranche | What changed |
|---------|-------------|
| T-AR-6 | 15 monolithic ADRs split into per-file MADR 4.0 under `docs/adr/`; versions updated |
| T-AR-7 | Stale doc trees removed (`docs/security-control-matrix.md`, `docs/architecture-v5.0.md`) |
| T-AR-8 | TODO/TBD sweep; `docs/governance/open-items.md` created as canonical deferral register |
| T-AR-9 | `OssApiProbeTest` added to agent-runtime (closes 0-test callout) |
| T-AR-10 | Performance evidence path: JMH skeleton + baseline doc (W4 numbers) |

**Accepted Tier 3 deferrals (honest gaps):**

- `@CircuitBreaker` call-site wiring (W2 — no host code in W0)
- Sidecar adapter impls: mem0, graphmemory, docling (W2+)
- Real-LLM N>=3 sequential runs per Rule 8 (W4)
- BudgetMetric SPI (W2)
- RLS ITs un-disabled and passing (W2)
- JMH benchmark with captured numbers (W4)
- japicmp first real version diff (post-W0; baseline established)

See [`docs/governance/open-items.md`](docs/governance/open-items.md) for the tracked deferral register.
See [`docs/adr/`](docs/adr/) for architectural decision records.
See [`ops/runbooks/`](ops/runbooks/) for operational runbooks.

## Architecture summary

```
┌──────────────────────────────────────────────────────────────────┐
│ Tier-A Northbound Facade — agent-platform/                       │
│ • Frozen v1 HTTP contract (`/v1/*`)                              │
│ • Filter chain: JWTAuth → TenantContext → Idempotency            │
│ • /v1/health (HealthEndpointIT; CI pass expected)                │
└──────────────────────────────────────────────────────────────────┘
                              │ SAS-1 single seam
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ SPI / Starter Layer — spring-ai-ascend-*-starter (W0 scaffold)      │
│ • LongTermMemoryRepository · GraphMemoryRepository               │
│ • ToolProvider                                                   │
│ • LayoutParser · DocumentSourceConnector                         │
│ • PolicyEvaluator                                                │
│ • RunRepository · IdempotencyRepository · ArtifactRepository     │
│ L0 sentinel impls in dev; posture fail-fast in research/prod     │
└──────────────────────────────────────────────────────────────────┘
           │ SPI consumed                  │ sidecar adapters
           ▼                               ▼
┌──────────────────────────────┐  ┌────────────────────────────┐
│ Tier-B Cognitive Runtime     │  │ Sidecar adapters (opt-in)  │
│ agent-runtime/               │  │ Mem0 · Graphiti · Docling  │
│ • LLMGateway (Spring AI)     │  │ LangChain4j profile        │
│ • Memory + Knowledge + Skill │  │ enabled=false by default   │
│ • Observability spine        │  └────────────────────────────┘
└──────────────────────────────┘
                              │ outbound only
                              ▼
                LLM providers, Postgres, MCP servers
```

## 5-minute quickstart

### 1. Import the BoM

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>ascend.springai</groupId>
      <artifactId>spring-ai-ascend-dependencies</artifactId>
      <version>0.1.0-SNAPSHOT</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

### 2. Add a starter

```xml
<dependency>
  <groupId>ascend.springai</groupId>
  <artifactId>spring-ai-ascend-memory-starter</artifactId>
</dependency>
```

### 3. Drop in a @Bean override (posture=dev uses sentinel if omitted)

```java
@Bean
LongTermMemoryRepository myMemoryRepo(DataSource ds) {
    return new MyJdbcLongTermMemoryRepository(ds);
}
```

```java
@Bean
PolicyEvaluator myPolicyEvaluator() {
    return new MyAllowAllPolicyEvaluator();
}
```

```java
@Bean
DocumentSourceConnector s3Connector(S3Client s3) {
    return new S3DocumentSourceConnector(s3);
}
```

Posture is set via `APP_POSTURE` env var (dev/research/prod). Research and prod reject
sentinel stubs at startup; provide real @Bean overrides before deploying.

See [docs/cross-cutting/integration-guide.md](docs/cross-cutting/integration-guide.md) for
the full integration guide.

## Predecessor

This architecture inherits 32 release waves of operational learnings from a Python predecessor (`hi-agent`). The 12 universal rules in [`CLAUDE.md`](CLAUDE.md) are translated from that predecessor's hard-won discipline.

## Status

- v6.1 architecture; review committee approval pending per [`docs/architecture-review-2026-05-07.md`](docs/architecture-review-2026-05-07.md) §24
- Phase 0 milestone: Maven compile+unit-test PASS at a7756cd (2026-05-10); ITs pending Docker in CI (see `docs/delivery/` for gate-run evidence)
- 14 Maven modules (reactor); 7 SPI starters; 4 sidecar/profile modules; SPI surface frozen. `ApiCompatibilityTest` compile-verified at a7756cd; HealthEndpointIT CI-expected.
- `@ConditionalOnProperty` wired in all 5 starters; `OpenApiContractIT` runs actual snapshot diff
- Next milestone: W1 default impls (Spring Data JDBC `RunRepository`, JDBC `LongTermMemoryRepository`, Tika `LayoutParser`)
