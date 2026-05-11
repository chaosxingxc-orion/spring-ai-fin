# spring-ai-ascend-graphmemory-starter

E2 middleware shell for graph-memory integration. This starter contributes an
`@AutoConfiguration` that registers **no beans by default**. It activates only
when `springai.ascend.graphmemory.enabled=true` is set — and even then, it
contributes nothing unless you provide your own `GraphMemoryRepository` bean.

## How to plug in your own implementation

```java
// In your @Configuration class:
@Bean
public GraphMemoryRepository graphMemoryRepository(GraphMemoryProperties props) {
    // Connect to Graphiti (https://github.com/getzep/graphiti):
    return new GraphitiRestGraphMemoryRepository(props.getBaseUrl(), props.getApiKey());

    // Or Cognee, or a custom Postgres-backed implementation.
}
```

Enable the starter:

```yaml
springai:
  ascend:
    graphmemory:
      enabled: true
      base-url: ${SPRINGAI_ASCEND_GRAPHITI_BASE_URL:http://localhost:8001}
```

The SPI contract is at:
`agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java`

Auto-discovery uses Spring Boot 2.7+ `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`.
