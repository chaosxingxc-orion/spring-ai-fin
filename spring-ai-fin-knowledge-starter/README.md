# spring-ai-fin-knowledge-starter

> Provides the SPI surface for document layout parsing and multi-source document ingestion, with a registry for fan-out across multiple connectors. Maturity: L1.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| LayoutParser | parse(document, options) | Parses InputStream into ordered ContentBlock list with layout metadata; options control table/image extraction |
| DocumentSourceConnector | connectorId() | Returns human-readable identifier (e.g. "s3", "github") |
| DocumentSourceConnector | fetch(tenantId, config) | Emits all documents from the source for the tenant; caller closes the Iterator |

The knowledge starter also registers a `DocumentSourceConnectorRegistry` bean that holds all `DocumentSourceConnector` instances contributed by the application context and fans out ingestion calls to connectors matching the tenant's configured sources.

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Sentinel impl active; WARN on every call; parse returns empty list |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

## Drop-in override (@Bean recipe)

```java
@Bean
LayoutParser myLayoutParser(Tika tika) {
    return new TikaLayoutParser(tika);
}
```

```java
@Bean
DocumentSourceConnector s3Connector(S3Client s3) {
    return new S3DocumentSourceConnector(s3);
}
```

Multiple `DocumentSourceConnector` beans may be declared; the registry picks them all up automatically via `List<DocumentSourceConnector>` injection.

## Counters emitted by sentinel

- `springai_fin_knowledge_default_impl_not_configured_total` tagged `spi=LayoutParser, method=parse`
- `springai_fin_knowledge_default_impl_not_configured_total` tagged `spi=DocumentSourceConnector, method=fetch`

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
