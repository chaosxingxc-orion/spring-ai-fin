package ascend.springai.runtime.memory;

import ascend.springai.runtime.spi.memory.GraphMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

/**
 * L0 sentinel: no graph memory impl at W0 (sidecar-only SPI).
 * Replaced by spring-ai-ascend-graphmemory-starter (Graphiti) in W2.
 */
class NotConfiguredGraphMemoryRepository implements GraphMemoryRepository {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredGraphMemoryRepository.class);
    private static final String METRIC = "springai_ascend_graph_memory_default_impl_not_configured_total";
    private static final String MSG =
            "L0: GraphMemoryRepository has no in-process default impl. " +
            "Add spring-ai-ascend-graphmemory-starter and set springai.ascend.graphmemory.enabled=true.";

    private final MeterRegistry registry;

    NotConfiguredGraphMemoryRepository(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public void addFact(String tenantId, String subject, String relation, String object, GraphMetadata metadata) {
        registry.counter(METRIC, "spi", "GraphMemoryRepository", "method", "addFact").increment();
        LOG.warn("L0: GraphMemoryRepository.addFact called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public List<GraphEdge> query(String tenantId, String subject, int maxDepth) {
        registry.counter(METRIC, "spi", "GraphMemoryRepository", "method", "query").increment();
        LOG.warn("L0: GraphMemoryRepository.query called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public List<GraphEdge> search(String tenantId, String queryText, int topK) {
        registry.counter(METRIC, "spi", "GraphMemoryRepository", "method", "search").increment();
        LOG.warn("L0: GraphMemoryRepository.search called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }
}
