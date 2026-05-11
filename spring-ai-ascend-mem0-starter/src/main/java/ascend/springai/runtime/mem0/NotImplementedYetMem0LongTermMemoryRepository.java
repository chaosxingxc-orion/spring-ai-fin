package ascend.springai.runtime.mem0;

import ascend.springai.runtime.spi.memory.LongTermMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Optional;

/**
 * L0 sentinel for the mem0 adapter. Activated only when springai.ascend.mem0.enabled=true.
 * The REST client wiring (RestClient + Resilience4j) lands in W2.
 */
class NotImplementedYetMem0LongTermMemoryRepository implements LongTermMemoryRepository {

    private static final Logger LOG = LoggerFactory.getLogger(NotImplementedYetMem0LongTermMemoryRepository.class);
    private static final String METRIC = "springai_ascend_mem0_adapter_not_implemented_total";
    private static final String MSG =
            "L0: mem0 adapter enabled but REST client not yet wired. " +
            "W2 will add RestClient + Resilience4j wiring. baseUrl=%s";

    private final MeterRegistry registry;
    private final Mem0Properties properties;

    NotImplementedYetMem0LongTermMemoryRepository(MeterRegistry registry, Mem0Properties properties) {
        this.registry = registry;
        this.properties = properties;
        LOG.info("spring-ai-ascend-mem0-starter activated at L0; REST client pending W2; baseUrl={}", properties.getBaseUrl());
    }

    @Override
    public MemoryEntry put(String tenantId, String userId, String content, MemoryMetadata metadata) {
        registry.counter(METRIC, "method", "put").increment();
        LOG.warn("L0: mem0 adapter PUT called before W2 REST client; tenantId={}", tenantId);
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }

    @Override
    public List<MemoryEntry> search(String tenantId, String userId, String query, int topK) {
        registry.counter(METRIC, "method", "search").increment();
        LOG.warn("L0: mem0 adapter SEARCH called before W2 REST client; tenantId={}", tenantId);
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }

    @Override
    public Optional<MemoryEntry> findById(String tenantId, String entryId) {
        registry.counter(METRIC, "method", "findById").increment();
        LOG.warn("L0: mem0 adapter FIND_BY_ID called before W2 REST client; tenantId={}", tenantId);
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }

    @Override
    public void delete(String tenantId, String entryId) {
        registry.counter(METRIC, "method", "delete").increment();
        LOG.warn("L0: mem0 adapter DELETE called before W2 REST client; tenantId={}", tenantId);
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }
}
