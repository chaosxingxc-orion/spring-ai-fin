# spring-ai-ascend-memory-starter

> Provides the SPI surface for durable long-term memory and relationship-aware graph memory, with posture-aware sentinel impls for dev mode. Maturity: L1.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| LongTermMemoryRepository | put(tenantId, userId, content, metadata) | Persists a memory entry; returns assigned id; tenantId required |
| LongTermMemoryRepository | search(tenantId, userId, query, topK) | Returns top-k relevant entries scoped to tenant+user |
| LongTermMemoryRepository | findById(tenantId, entryId) | Returns entry only if tenantId matches; empty otherwise |
| LongTermMemoryRepository | delete(tenantId, entryId) | No-op if not found or wrong tenant; never throws on missing |
| GraphMemoryRepository | addFact(tenantId, subject, relation, object, metadata) | Adds a triple to the tenant-scoped knowledge graph |
| GraphMemoryRepository | query(tenantId, subject, maxDepth) | Traverses graph depth-limited from subject; tenant-scoped |
| GraphMemoryRepository | search(tenantId, queryText, topK) | Full-text + graph search across tenant's graph |

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Sentinel impl active; WARN on every call; no data persisted |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

## Drop-in override (@Bean recipe)

```java
@Bean
LongTermMemoryRepository myLongTermMemoryRepository(DataSource ds) {
    return new MyJdbcLongTermMemoryRepository(ds);
}
```

```java
@Bean
GraphMemoryRepository myGraphMemoryRepository(RestClient graphitiClient) {
    return new GraphitiGraphMemoryRepository(graphitiClient);
}
```

## Counters emitted by sentinel

- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi=LongTermMemoryRepository, method=put`
- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi=LongTermMemoryRepository, method=search`
- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi=LongTermMemoryRepository, method=findById`
- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi=LongTermMemoryRepository, method=delete`
- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi=GraphMemoryRepository, method=addFact`
- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi=GraphMemoryRepository, method=query`
- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi=GraphMemoryRepository, method=search`

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
