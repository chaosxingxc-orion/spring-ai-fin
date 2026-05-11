# spring-ai-ascend-persistence-starter

> Provides the SPI surface for durable run records, idempotency key deduplication, and artifact storage; all records carry full contract-spine fields. Maturity: L1.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| RunRepository | create(run) | Creates a new run record; returns the stored record with server-assigned fields |
| RunRepository | findById(tenantId, runId) | Returns run only if tenantId matches; empty otherwise |
| RunRepository | updateStage(tenantId, runId, stage) | Transitions run stage; returns updated record |
| RunRepository | markTerminal(tenantId, runId, terminalStage, outcome) | Marks run as SUCCEEDED, FAILED, or CANCELLED with outcome; idempotent |
| IdempotencyRepository | claimOrFind(tenantId, idempotencyKey, runId) | Claims key if first call (returns empty); returns existing record on replay |
| ArtifactRepository | store(tenantId, runId, name, mimeType, content) | Stores artifact bytes; returns record with storageUri |
| ArtifactRepository | findById(tenantId, artifactId) | Returns artifact only if tenantId matches |
| ArtifactRepository | findByRunId(tenantId, runId) | Lists all artifacts for a run; tenant-scoped |

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Sentinel impl active; WARN on every call; no data persisted |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

## Drop-in override (@Bean recipe)

```java
@Bean
RunRepository myRunRepository(JdbcTemplate jdbc) {
    return new JdbcRunRepository(jdbc);
}
```

```java
@Bean
IdempotencyRepository myIdempotencyRepository(JdbcTemplate jdbc) {
    return new JdbcIdempotencyRepository(jdbc);
}
```

```java
@Bean
ArtifactRepository myArtifactRepository(JdbcTemplate jdbc, MinioClient minio) {
    return new MinioArtifactRepository(jdbc, minio);
}
```

## Counters emitted by sentinel

- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=RunRepository, method=create`
- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=RunRepository, method=findById`
- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=RunRepository, method=updateStage`
- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=RunRepository, method=markTerminal`
- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=IdempotencyRepository, method=claimOrFind`
- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=ArtifactRepository, method=store`
- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=ArtifactRepository, method=findById`
- `SPRINGAI_ASCEND_persistence_default_impl_not_configured_total` tagged `spi=ArtifactRepository, method=findByRunId`

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
