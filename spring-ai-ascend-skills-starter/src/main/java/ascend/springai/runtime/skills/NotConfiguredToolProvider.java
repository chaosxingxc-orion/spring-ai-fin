package ascend.springai.runtime.skills;

import ascend.springai.runtime.spi.skills.ToolProvider;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

/**
 * L0 sentinel: no tool/MCP impl wired at W0.
 * Replaced by MCP McpSyncClient + @Tool bean registry in W2.
 */
class NotConfiguredToolProvider implements ToolProvider {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredToolProvider.class);
    private static final String METRIC = "springai_ascend_skills_default_impl_not_configured_total";
    private static final String MSG =
            "L0: ToolProvider has no default impl yet. " +
            "Provide a @Bean ToolProvider or wait for the W2 MCP + @Tool registry impl.";

    private final MeterRegistry registry;

    NotConfiguredToolProvider(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public List<ToolDescriptor> listTools(String tenantId) {
        registry.counter(METRIC, "spi", "ToolProvider", "method", "listTools").increment();
        LOG.warn("L0: ToolProvider.listTools called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public String invoke(String tenantId, String toolName, String argumentsJson) {
        registry.counter(METRIC, "spi", "ToolProvider", "method", "invoke").increment();
        LOG.warn("L0: ToolProvider.invoke called with no impl; tenantId={} tool={}", tenantId, toolName);
        throw new IllegalStateException(MSG);
    }
}
