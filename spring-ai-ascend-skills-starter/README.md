# spring-ai-ascend-skills-starter

> Provides the SPI surface for the agent's tool registry; bridges MCP server tool lists and local Spring bean tools to the runtime. Maturity: L1.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| ToolProvider | listTools(tenantId) | Returns all tools available for the tenant; filtered by tenant allowlist |
| ToolProvider | invoke(tenantId, toolName, argumentsJson) | Invokes named tool with JSON args; returns JSON result; throws on error |

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Sentinel impl active; WARN on every call; listTools returns empty list |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

## Drop-in override (@Bean recipe)

```java
@Bean
ToolProvider myToolProvider(McpSyncClient mcpClient) {
    return new McpToolProvider(mcpClient);
}
```

## Counters emitted by sentinel

- `SPRINGAI_ASCEND_skills_default_impl_not_configured_total` tagged `spi=ToolProvider, method=listTools`
- `SPRINGAI_ASCEND_skills_default_impl_not_configured_total` tagged `spi=ToolProvider, method=invoke`

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
