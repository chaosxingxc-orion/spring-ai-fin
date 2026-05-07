# spring-ai-fin

> **Capability-layer enterprise agent platform for Southeast Asia financial services (Indonesia OJK / Singapore MAS).** Built on Spring Boot + Spring AI 1.1+. Multi-framework dispatch (Spring AI native, LangChain4j, Python sidecars). Pre-implementation; this repo currently holds the architecture design corpus pending committee review.

**Status**: v6.0 architecture review edition · 2026-05-07 · pre-implementation
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
├── ARCHITECTURE.md                              L0 system boundary (1,648 lines, 17 decisions)
├── CLAUDE.md                                    Behavioural rules (12 universal rules)
├── README.md                                    this file
│
├── agent-platform/                              Tier-A northbound facade (frozen v1)
│   ├── ARCHITECTURE.md                          L1
│   ├── api/ARCHITECTURE.md                      L2 — HTTP transport + filter chain
│   ├── bootstrap/ARCHITECTURE.md                L2 — assembly seam #1
│   ├── cli/ARCHITECTURE.md                      L2 — operator CLI
│   ├── config/ARCHITECTURE.md                   L2 — settings + version pin
│   ├── contracts/ARCHITECTURE.md                L2 — frozen v1 records
│   ├── facade/ARCHITECTURE.md                   L2 — contract↔kernel adapters
│   └── runtime/ARCHITECTURE.md                  L2 — kernel binding seam #2
│
├── agent-runtime/                               Tier-B cognitive runtime
│   ├── ARCHITECTURE.md                          L1
│   ├── adapters/ARCHITECTURE.md                 L2 — multi-framework dispatch ★
│   ├── auth/ARCHITECTURE.md                     L2 — JWT primitives
│   ├── capability/ARCHITECTURE.md               L2 — registry + invoker + breaker
│   ├── evolve/ARCHITECTURE.md                   L2 — experiments + postmortem
│   ├── knowledge/ARCHITECTURE.md                L2 — JSONB glossary + 4-layer retrieval
│   ├── llm/ARCHITECTURE.md                      L2 — Spring AI gateway + tier router
│   ├── memory/ARCHITECTURE.md                   L2 — L0–L3 layered memory
│   ├── observability/ARCHITECTURE.md            L2 — Rule 7 four-prong + spine
│   ├── outbox/ARCHITECTURE.md                   L2 — OUTBOX_ASYNC + SYNC_SAGA + DIRECT_DB ★
│   ├── posture/ARCHITECTURE.md                  L2 — three-posture model
│   ├── runner/ARCHITECTURE.md                   L2 — TRACE 5-stage executor
│   ├── runtime/ARCHITECTURE.md                  L2 — Reactor scheduler + harness
│   ├── server/ARCHITECTURE.md                   L2 — AgentRuntime + RunManager
│   └── skill/ARCHITECTURE.md                    L2 — MCP tools + Spring AI Advisors
│
└── docs/
    ├── architecture-review-2026-05-07.md        Committee-facing review document
    ├── architecture-v5.0.md                     Historical input (preserved)
    └── architecture-v5.0-review-2026-05-07.md   Adversarial review that produced v6.0
```

★ = the two L2 docs implementing v6.0's most distinctive choices.

## Architecture summary

```
┌──────────────────────────────────────────────────────────────────┐
│ Tier-A Northbound Facade — agent-platform/                       │
│ • Frozen v1 HTTP contract (`/v1/*`)                              │
│ • Filter chain: JWTAuth → TenantContext → Idempotency            │
│ • Operator CLI                                                   │
│ • Customer Spring Boot Starters                                  │
└──────────────────────────────────────────────────────────────────┘
                              │ SAS-1 single seam
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ Tier-B Cognitive Runtime — agent-runtime/                        │
│ • TRACE 5-stage durable RunExecutor                              │
│ • LLMGateway over Spring AI ChatClient                           │
│ • FrameworkAdapter dispatch (Spring AI / LangChain4j / Python)   │
│ • Memory + Knowledge + Skill subsystems                          │
│ • Observability spine + Outbox + Sync-Saga + Direct-DB           │
└──────────────────────────────────────────────────────────────────┘
                              │ outbound only
                              ▼
                LLM providers, Postgres, MCP servers, Python sidecars
```

## Predecessor

This architecture inherits 32 release waves of operational learnings from a Python predecessor (`hi-agent`). The 12 universal rules in [`CLAUDE.md`](CLAUDE.md) are translated from that predecessor's hard-won discipline.

## Status

- v5.0 architecture document (9,922 lines, single file) underwent adversarial review
- 6 HIGH + 9 MEDIUM findings identified
- v6.0 (this corpus) corrects all 6 HIGH and 8 of 9 MEDIUM findings
- Pending: architecture committee review and approval per [`docs/architecture-review-2026-05-07.md`](docs/architecture-review-2026-05-07.md) §24
- Implementation has NOT started; W1 plan is conditional on committee approval
