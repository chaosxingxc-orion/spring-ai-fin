# spring-ai-ascend

Enterprise agent platform scaffold for financial services teams building on Spring AI 2.0.0-M5 + Spring Boot 4.0.5.

**Status**: W0 scaffold; 5 modules; GET /v1/health shipped; 9 tests GREEN

---

## Modules

| Module | Role |
|--------|------|
| `agent-platform` | Northbound HTTP facade — filter chain, health endpoint, idempotency |
| `agent-runtime` | Cognitive runtime — SPI contracts, OSS API probe |
| `spring-ai-ascend-dependencies` | BoM — pins all SDK and OSS dependency versions |
| `spring-ai-ascend-graphmemory-starter` | Sidecar adapter — Graphiti REST (opt-in, `enabled=false` by default) |

---

## Integration paths

| Path | When to use | Entry point |
|------|-------------|-------------|
| Drop-in `@Bean` override | Provide your own `GraphMemoryRepository` impl; starter auto-config wires it | `spring-ai-ascend-graphmemory-starter` |
| Direct Spring AI / Spring Data | Use `ChatMemory`, `VectorStore`, `CrudRepository` directly without starters | No starter needed |
| BoM import only | Pin all SDK versions; manage wiring yourself | `spring-ai-ascend-dependencies` BoM |

---

## Quick start

```bash
./mvnw clean test
```

Posture is set via `APP_POSTURE` env var (`dev` / `research` / `prod`).
Research and prod reject sentinel stubs at startup; provide real `@Bean` overrides before deploying.

---

## Reading order

1. `README.md` — this file, current status
2. `docs/STATE.md` — per-capability shipped/deferred table
3. `ARCHITECTURE.md` — system boundary, decision chains, SPI contracts
