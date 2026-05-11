package fin.springai.runtime.spi.skills;

import java.util.List;

/**
 * SPI: registry of callable tools available to the agent runtime.
 *
 * Default impl: composite of MCP McpSyncClient tool list + Spring AI
 * @Tool-annotated bean registry.
 *
 * Implementations are expected to filter the tool list by the tenant's
 * allowlist (Rule 11: tenantId scoping enforced by the caller).
 */
public interface ToolProvider {

    /**
     * Returns all tools available for the given tenant.
     * The runtime invokes tools through {@link #invoke}.
     */
    List<ToolDescriptor> listTools(String tenantId);

    /**
     * Invoke a named tool with JSON-encoded arguments.
     * Returns the JSON-encoded result or throws on error.
     */
    String invoke(String tenantId, String toolName, String argumentsJson);

    record ToolDescriptor(
            String tenantId,
            String name,
            String description,
            String inputSchemaJson,
            ToolSource source
    ) {}

    enum ToolSource {
        MCP_SERVER,
        LOCAL_BEAN,
        COMPOSITE
    }
}
