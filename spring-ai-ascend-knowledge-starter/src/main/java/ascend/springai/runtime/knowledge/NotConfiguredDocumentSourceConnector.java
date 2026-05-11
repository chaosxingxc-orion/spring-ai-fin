package ascend.springai.runtime.knowledge;

import ascend.springai.runtime.spi.knowledge.DocumentSourceConnector;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Collections;
import java.util.Iterator;

/**
 * L0 sentinel: no document source connectors wired at W0.
 * Real connectors (S3, web, GitHub via langchain4j) land in W2.
 */
class NotConfiguredDocumentSourceConnector implements DocumentSourceConnector {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredDocumentSourceConnector.class);
    private static final String METRIC = "springai_ascend_knowledge_default_impl_not_configured_total";
    private static final String MSG =
            "L0: DocumentSourceConnector has no default impl yet. " +
            "Provide a @Bean DocumentSourceConnector or wait for the W2 connector impls.";

    private final MeterRegistry registry;

    NotConfiguredDocumentSourceConnector(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public String connectorId() {
        return "not-configured";
    }

    @Override
    public Iterator<RawDocument> fetch(String tenantId, SourceConfig config) {
        registry.counter(METRIC, "spi", "DocumentSourceConnector", "method", "fetch").increment();
        LOG.warn("L0: DocumentSourceConnector.fetch called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }
}
