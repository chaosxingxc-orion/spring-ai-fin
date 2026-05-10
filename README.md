# spring-ai-fin

> **Capability-layer enterprise agent platform for Southeast Asia financial services (Indonesia OJK / Singapore MAS).** Built on Spring Boot 3.5 + Spring AI 2.0.0-M5. Multi-framework dispatch (Spring AI native, LangChain4j profile, Python sidecars). W0 scaffold landed; 14 Maven modules, SPI surface frozen at 7 interfaces.

**Status**: v6.0 architecture · W0 scaffold landed 2026-05-10 · 14 Maven modules · SPI surface frozen
**License preference**: Apache 2.0 / MIT only on the runtime path (see [`ARCHITECTURE.md`](ARCHITECTURE.md) D-15)

---

## Reading order

| Audience | Start at | Time |
|---|---|---|
| Architecture review committee | [`docs/architecture-review-2026-05-07.md`](docs/architecture-review-2026-05-07.md) (1,286 lines, 4 appendices) | 90–180 min |
| Senior architect | [`ARCHITECTURE.md`](ARCHITECTURE.md) §6 (17 decision chains) | 90 min |
| Engineer onboarding | [`CLAUDE.md`](CLAUDE.md) (12 universal rules) → L1 docs | 60 min |
| Skeptical reviewer | [`docs/architecture-v5.0-review-2026-05-07.md`](docs/architecture-v5.0-review-2026-05-07.md) → [`ARCHITECTURE.md`](ARCHITECTURE.md) §15 deltas | 60 min |

## Document hierarchy

```
spring-ai-fin/
├── ARCHITECTURE.md                              L0 system boundary (17 decisions)
├── CLAUDE.md                                    Behavioural rules (12 universal rules)
├── README.md                                    this file
│
├── agent-platform/                              Tier-A northbound facade (L1 — HealthEndpointIT GREEN)
│   └── ARCHITECTURE.md                          L1
│
├── agent-runtime/                               Tier-B cognitive runtime (L0 — OssApiProbe shell)
│   └── ARCHITECTURE.md                          L1
│
├── spring-ai-fin-dependencies/                  BoM — pins 9 starter coordinates + 13 OSS deps (L1)
│   └── pom.xml
│
├── spring-ai-fin-memory-starter/                SPI: LongTermMemoryRepository, GraphMemoryRepository (L0)
├── spring-ai-fin-skills-starter/                SPI: ToolProvider (L0)
├── spring-ai-fin-knowledge-starter/             SPI: LayoutParser, DocumentSourceConnector (L0)
├── spring-ai-fin-governance-starter/            SPI: PolicyEvaluator (L0)
├── spring-ai-fin-persistence-starter/           SPI: RunRepository, IdempotencyRepository, ArtifactRepository (L0)
│
├── spring-ai-fin-mem0-starter/                  Sidecar adapter — Mem0 REST (enabled=false by default, L0)
├── spring-ai-fin-graphmemory-starter/           Sidecar adapter — Graphiti REST (enabled=false by default, L0)
├── spring-ai-fin-docling-starter/               Sidecar adapter — Docling REST (enabled=false by default, L0)
├── spring-ai-fin-langchain4j-profile/           Alternate framework profile — LangChain4j (enabled=false, L0)
│
├── third_party/                                 Third-party notices and OSS attribution
│
└── docs/
    ├── architecture-review-2026-05-07.md        Committee-facing review document
    ├── governance/                              architecture-status.yaml, evidence-manifest.yaml
    ├── delivery/                                Gate-run evidence files (per-SHA)
    └── cross-cutting/                           OSS BoM policy, security, posture
```

SPI interfaces are frozen by `ApiCompatibilityTest` (ArchUnit 4 rules GREEN at commit 97b0827).
L-levels per Rule 12: L0 = sentinel impl only; L1 = tested component.

## Architecture summary

```
┌──────────────────────────────────────────────────────────────────┐
│ Tier-A Northbound Facade — agent-platform/                       │
│ • Frozen v1 HTTP contract (`/v1/*`)                              │
│ • Filter chain: JWTAuth → TenantContext → Idempotency            │
│ • /v1/health (HealthEndpointIT GREEN)                            │
└──────────────────────────────────────────────────────────────────┘
                              │ SAS-1 single seam
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ SPI / Starter Layer — spring-ai-fin-*-starter (W0 scaffold)      │
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

## Predecessor

This architecture inherits 32 release waves of operational learnings from a Python predecessor (`hi-agent`). The 12 universal rules in [`CLAUDE.md`](CLAUDE.md) are translated from that predecessor's hard-won discipline.

## Status

- v6.0 architecture review committee approval pending per [`docs/architecture-review-2026-05-07.md`](docs/architecture-review-2026-05-07.md) §24
- W0 scaffold landed at commit `97b0827` (see `docs/delivery/` for gate-run evidence)
- 14 Maven modules built; 7 SPI interfaces frozen; `ApiCompatibilityTest` (ArchUnit) GREEN
- Next milestone: W1 default impls (Spring Data JDBC `RunRepository`, JDBC `LongTermMemoryRepository`, Tika `LayoutParser`)
