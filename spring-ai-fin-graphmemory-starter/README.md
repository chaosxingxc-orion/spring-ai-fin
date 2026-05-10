# spring-ai-fin-graphmemory-starter

> Optional sidecar adapter that wires GraphMemoryRepository to the Graphiti (Zep OSS) REST API; replaces the sentinel when enabled=true and SPRINGAI_FIN_GRAPHITI_BASE_URL is set. Maturity: L0.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| GraphMemoryRepository | addFact / query / search | Delegates to Graphiti REST API; all operations tenant-scoped |

This starter provides no new SPI interfaces. It contributes an alternative implementation of `GraphMemoryRepository` (defined in `spring-ai-fin-memory-starter`) that forwards calls to the Graphiti sidecar over HTTP.

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Adapter disabled by default; memory-starter sentinel remains active |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

When `springai.fin.graphmemory.enabled=true` and `SPRINGAI_FIN_GRAPHITI_BASE_URL` is present, the Graphiti adapter bean is registered and overrides the sentinel in all postures.

## Drop-in override (@Bean recipe)

Enable via application property instead of a @Bean override:

```yaml
springai:
  fin:
    graphmemory:
      enabled: true
      base-url: ${SPRINGAI_FIN_GRAPHITI_BASE_URL}
```

Custom override if additional client config is required:

```java
@Bean
GraphMemoryRepository graphitiMemoryRepository(GraphMemoryProperties props, RestClient.Builder builder) {
    return new GraphitiGraphMemoryRepository(props, builder.build());
}
```

## Counters emitted by sentinel

This starter does not emit its own sentinel counters. When disabled, the memory-starter sentinel counters fire:

- `springai_fin_memory_default_impl_not_configured_total` tagged `spi=GraphMemoryRepository, method=*`

## See also

- [spring-ai-fin-memory-starter/README.md](../spring-ai-fin-memory-starter/README.md) for the owning SPI
- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/cross-cutting/middleware-pattern-guide.md](../docs/cross-cutting/middleware-pattern-guide.md) for the sidecar adapter pattern
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
