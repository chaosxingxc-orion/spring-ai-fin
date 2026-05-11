package ascend.springai.runtime.graphmemory;

import ascend.springai.runtime.spi.memory.GraphMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

/**
 * L0 sentinel for the Graphiti adapter. Activated only when springai.ascend.graphmemory.enabled=true.
 * REST client wiring lands in W2. Cycle-15 confirmed Graphiti over Cognee.
 */
class NotImplementedYetGraphMemoryRepository implements GraphMemoryRepository {

    private static final Logger LOG = LoggerFactory.getLogger(NotImplementedYetGraphMemoryRepository.class);
    private static final String METRIC = "springai_ascend_graph_memory_adapter_not_implemented_total";
    private static final String MSG =
            "L0: Graphiti adapter enabled but REST client not yet wired. " +
            "W2 will add RestClient wiring. baseUrl=%s";

    private final MeterRegistry registry;
    private final GraphMemoryProperties properties;

    NotImplementedYetGraphMemoryRepository(MeterRegistry registry, GraphMemoryProperties properties) {
        this.registry = registry;
        this.properties = properties;
        LOG.info("spring-ai-ascend-graphmemory-starter activated at L0; REST client pending W2; baseUrl={}", properties.getBaseUrl());
    }

    @Override
    public void addFact(String tenantId, String subject, String relation, String object, GraphMetadata metadata) {
        registry.counter(METRIC, "spi", "GraphMemoryRepository", "method", "addFact").increment();
        LOG.warn("L0: Graphiti addFact called before W2 REST client; tenantId={}", tenantId);
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }

    @Override
    public List<GraphEdge> query(String tenantId, String subject, int maxDepth) {
        registry.counter(METRIC, "spi", "GraphMemoryRepository", "method", "query").increment();
        LOG.warn("L0: Graphiti query called before W2 REST client; tenantId={}", tenantId);
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }

    @Override
    public List<GraphEdge> search(String tenantId, String queryText, int topK) {
        registry.counter(METRIC, "spi", "GraphMemoryRepository", "method", "search").increment();
        LOG.warn("L0: Graphiti search called before W2 REST client; tenantId={}", tenantId);
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }
}
