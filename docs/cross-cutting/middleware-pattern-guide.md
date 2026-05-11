> Owner: agent-platform | Maturity: L2 | Posture: all | Last refreshed: 2026-05-10

# Middleware Pattern Guide: Sidecar Adapter Pattern

This guide walks through the sidecar adapter pattern end-to-end using `spring-ai-ascend-mem0-starter` (Mem0 REST adapter) as a concrete example. The same four-step pattern applies to any sidecar adapter (Graphiti, Docling, LangChain4j, or custom).

---

## Why the sidecar adapter pattern

Spring-ai-fin SPI interfaces are defined in pure Java with no framework dependencies. This makes them implementable by any class, including one that delegates over HTTP to an external process (the sidecar). The pattern:

1. Isolates the external dependency behind the SPI contract.
2. Enables opt-in via a single property without code changes.
3. Keeps the core starter free of HTTP client or external-service dependencies.
4. Allows the sidecar to be written in any language (Python, Go, etc.) as long as it exposes the expected REST API.

---

## Step 1: Implement the SPI interface

Create a class that implements the target SPI interface. All external calls go through a `RestClient` injected at construction time. The implementation must be thread-safe (called from virtual threads concurrently).

```java
package ascend.springai.runtime.mem0;

import ascend.springai.runtime.spi.memory.LongTermMemoryRepository;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Optional;

public class Mem0LongTermMemoryRepository implements LongTermMemoryRepository {

    private final RestClient restClient;
    private final Mem0Properties properties;

    public Mem0LongTermMemoryRepository(Mem0Properties properties, RestClient restClient) {
        this.properties = properties;
        this.restClient = restClient;
    }

    @Override
    public MemoryEntry put(String tenantId, String userId, String content, MemoryMetadata metadata) {
        // POST to Mem0 REST API; map response to MemoryEntry
        var response = restClient.post()
            .uri("/memories")
            .body(new Mem0PutRequest(tenantId, userId, content))
            .retrieve()
            .body(Mem0PutResponse.class);
        return toMemoryEntry(response);
    }

    @Override
    public List<MemoryEntry> search(String tenantId, String userId, String query, int topK) {
        // GET from Mem0 REST API; map response list
        // ...
        return List.of();
    }

    @Override
    public Optional<MemoryEntry> findById(String tenantId, String entryId) {
        // GET single entry; return empty if 404
        return Optional.empty();
    }

    @Override
    public void delete(String tenantId, String entryId) {
        // DELETE from Mem0 REST API; no-op on 404
    }

    private MemoryEntry toMemoryEntry(Mem0PutResponse response) {
        // map Mem0 response fields to SPI record
        return new MemoryEntry(response.id(), response.tenantId(),
            response.userId(), response.content(), null);
    }
}
```

---

## Step 2: Create the AutoConfiguration with @ConditionalOnProperty

The AutoConfiguration is the wiring class. It is active only when the adapter is explicitly enabled.

```java
package ascend.springai.runtime.mem0;

import ascend.springai.runtime.spi.memory.LongTermMemoryRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
@EnableConfigurationProperties(Mem0Properties.class)
@ConditionalOnProperty(name = "springai.ascend.mem0.enabled", havingValue = "true")
public class Mem0AutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    LongTermMemoryRepository mem0LongTermMemoryRepository(
            Mem0Properties props,
            RestClient.Builder builder) {
        RestClient client = builder.baseUrl(props.baseUrl()).build();
        return new Mem0LongTermMemoryRepository(props, client);
    }
}
```

The `@ConditionalOnMissingBean` ensures that if the application declares its own `LongTermMemoryRepository` @Bean, the adapter does not conflict.

---

## Step 3: Register in META-INF/spring/

Register the AutoConfiguration so Spring Boot discovers it automatically:

File: `src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`

```
ascend.springai.runtime.mem0.Mem0AutoConfiguration
```

This is the Spring Boot 4.x way to register auto-configurations (replaces `spring.factories`).

---

## Step 4: Enable with springai.ascend.mem0.enabled=true

End-users enable the adapter by setting the property in their `application.yml`:

```yaml
springai:
  fin:
    mem0:
      enabled: true
      base-url: ${SPRINGAI_ASCEND_MEM0_BASE_URL}
```

Or as environment variables:

```
SPRINGAI_ASCEND_MEM0_ENABLED=true
SPRINGAI_ASCEND_MEM0_BASE_URL=http://mem0-sidecar:8001
```

The memory-starter's sentinel `NotConfiguredLongTermMemoryRepository` has `@ConditionalOnMissingBean`; it steps aside automatically when the Mem0 bean is present.

---

## Wire your X: template

To adapt a new external service `X` to SPI interface `MySpi`:

1. Create `spring-ai-ascend-<x>-starter/` module.
2. Implement `MySpiXAdapter implements MySpi` with a `RestClient` constructor arg.
3. Create `XAutoConfiguration` with `@ConditionalOnProperty(name = "springai.ascend.<x>.enabled", havingValue = "true")` and `@ConditionalOnMissingBean` on the @Bean method.
4. Register `XAutoConfiguration` in `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`.
5. Create `XProperties` record with `@ConfigurationProperties(prefix = "springai.ascend.<x>")` carrying at minimum `enabled` (boolean) and `baseUrl` (String).
6. Write a unit test for `XAutoConfiguration` verifying: (a) adapter registered when property is true, (b) sentinel remains when property is false or missing.
7. Document the property prefix in [docs/contracts/configuration-contracts.md](../contracts/configuration-contracts.md).

---

## Related documents

- [docs/cross-cutting/integration-guide.md](integration-guide.md) for the three integration paths
- [docs/contracts/spi-contracts.md](../contracts/spi-contracts.md) for SPI semantic contracts
- [ARCHITECTURE.md](../../ARCHITECTURE.md) section 2 (OSS matrix) for the registered sidecar adapters
