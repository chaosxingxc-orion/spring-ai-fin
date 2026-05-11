# spring-ai-ascend-langchain4j-profile

> Alternate framework profile that replaces Spring AI ChatClient dispatching with LangChain4j; disabled by default; the Spring AI native path is the W0 production default. Maturity: L0.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| (no new SPI) | -- | This profile contributes LangChain4j-backed bean implementations for SPI interfaces already defined in core starters |

This module does not define new SPI interfaces. When activated, it registers LangChain4j-based implementations that override the Spring AI native beans for the LLM dispatch path inside `agent-runtime`. All SPI contracts (LongTermMemoryRepository, ToolProvider, etc.) remain unchanged.

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Profile disabled by default; Spring AI native path is active |
| research | Profile disabled by default; must be explicitly enabled |
| prod | Profile disabled by default; must be explicitly enabled |

Enable by setting `spring.profiles.active=langchain4j` (or adding `langchain4j` to an active profile list). The profile is mutually exclusive with the default Spring AI path; running both simultaneously is an unsupported configuration.

## Drop-in override (@Bean recipe)

Enable via Spring profile activation:

```yaml
spring:
  profiles:
    active: langchain4j
```

Or at startup:

```
java -jar agent-platform.jar --spring.profiles.active=langchain4j
```

No @Bean override is needed at the application level; activating the profile registers all LangChain4j beans automatically via conditional auto-configuration.

## Counters emitted by sentinel

This profile does not contribute sentinel counters. When the profile is inactive, the core starter sentinels remain in effect.

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design, section 2 (OSS matrix) for the multi-framework dispatch entry
- [docs/cross-cutting/middleware-pattern-guide.md](../docs/cross-cutting/middleware-pattern-guide.md) for the sidecar adapter pattern
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
