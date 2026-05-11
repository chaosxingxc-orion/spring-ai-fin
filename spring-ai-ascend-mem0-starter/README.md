# spring-ai-fin-mem0-starter

> Optional sidecar adapter that wires LongTermMemoryRepository to the Mem0 REST API; replaces the sentinel when enabled=true and SPRINGAI_FIN_MEM0_BASE_URL is set. Maturity: L0.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| LongTermMemoryRepository | put / search / findById / delete | Delegates to Mem0 REST API; all operations tenant-scoped |

This starter provides no new SPI interfaces. It contributes an alternative implementation of `LongTermMemoryRepository` (defined in `spring-ai-fin-memory-starter`) that forwards calls to the Mem0 sidecar over HTTP.

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Adapter disabled by default; memory-starter sentinel remains active |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

When `springai.fin.mem0.enabled=true` and `SPRINGAI_FIN_MEM0_BASE_URL` is present, the Mem0 adapter bean is registered and overrides the sentinel in all postures.

## Drop-in override (@Bean recipe)

Enable via application property instead of a @Bean override:

```yaml
springai:
  fin:
    mem0:
      enabled: true
      base-url: ${SPRINGAI_FIN_MEM0_BASE_URL}
```

Custom override if additional client config is required:

```java
@Bean
LongTermMemoryRepository mem0MemoryRepository(Mem0Properties props, RestClient.Builder builder) {
    return new Mem0LongTermMemoryRepository(props, builder.build());
}
```

## Counters emitted by sentinel

This starter does not emit its own sentinel counters. When disabled, the memory-starter sentinel counters fire:

- `springai_fin_memory_default_impl_not_configured_total` tagged `spi=LongTermMemoryRepository, method=*`

## See also

- [spring-ai-fin-memory-starter/README.md](../spring-ai-fin-memory-starter/README.md) for the owning SPI
- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/cross-cutting/middleware-pattern-guide.md](../docs/cross-cutting/middleware-pattern-guide.md) for the sidecar adapter pattern
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
