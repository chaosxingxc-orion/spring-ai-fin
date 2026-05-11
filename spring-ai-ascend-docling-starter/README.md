# spring-ai-ascend-docling-starter

> Optional sidecar adapter that wires LayoutParser to the Docling REST API (IBM Docling-serve); replaces the sentinel when enabled=true and SPRINGAI_ASCEND_DOCLING_BASE_URL is set. Maturity: L0.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| LayoutParser | parse(document, options) | Delegates to Docling REST API; returns layout-aware ContentBlock list including table extraction |

This starter provides no new SPI interfaces. It contributes an alternative implementation of `LayoutParser` (defined in `spring-ai-ascend-knowledge-starter`) that forwards document bytes to the Docling sidecar over HTTP and deserializes the structured response into `ContentBlock` objects.

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Adapter disabled by default; knowledge-starter sentinel remains active |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

When `springai.ascend.docling.enabled=true` and `SPRINGAI_ASCEND_DOCLING_BASE_URL` is present, the Docling adapter bean is registered and overrides the sentinel in all postures.

## Drop-in override (@Bean recipe)

Enable via application property instead of a @Bean override:

```yaml
springai:
  fin:
    docling:
      enabled: true
      base-url: ${SPRINGAI_ASCEND_DOCLING_BASE_URL}
```

Custom override if additional client config is required:

```java
@Bean
LayoutParser doclingLayoutParser(DoclingProperties props, RestClient.Builder builder) {
    return new DoclingLayoutParser(props, builder.build());
}
```

## Counters emitted by sentinel

This starter does not emit its own sentinel counters. When disabled, the knowledge-starter sentinel counters fire:

- `SPRINGAI_ASCEND_knowledge_default_impl_not_configured_total` tagged `spi=LayoutParser, method=parse`

## See also

- [spring-ai-ascend-knowledge-starter/README.md](../spring-ai-ascend-knowledge-starter/README.md) for the owning SPI
- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/cross-cutting/middleware-pattern-guide.md](../docs/cross-cutting/middleware-pattern-guide.md) for the sidecar adapter pattern
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
