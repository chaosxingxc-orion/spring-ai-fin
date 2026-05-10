package fin.springai.runtime.memory;

import fin.springai.runtime.spi.memory.LongTermMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Optional;

/**
 * L0 sentinel: increments a counter + logs WARN + throws on every call.
 * Replaced by a real default impl (Spring Data JDBC over Postgres) in W1.
 */
class NotConfiguredLongTermMemoryRepository implements LongTermMemoryRepository {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredLongTermMemoryRepository.class);
    private static final String METRIC = "springai_fin_memory_default_impl_not_configured_total";
    private static final String MSG =
            "L0: LongTermMemoryRepository has no default impl yet. " +
            "Provide a @Bean LongTermMemoryRepository or wait for the W1 JDBC default impl.";

    private final MeterRegistry registry;

    NotConfiguredLongTermMemoryRepository(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public MemoryEntry put(String tenantId, String userId, String content, MemoryMetadata metadata) {
        registry.counter(METRIC, "spi", "LongTermMemoryRepository", "method", "put").increment();
        LOG.warn("L0: LongTermMemoryRepository.put called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public List<MemoryEntry> search(String tenantId, String userId, String query, int topK) {
        registry.counter(METRIC, "spi", "LongTermMemoryRepository", "method", "search").increment();
        LOG.warn("L0: LongTermMemoryRepository.search called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public Optional<MemoryEntry> findById(String tenantId, String entryId) {
        registry.counter(METRIC, "spi", "LongTermMemoryRepository", "method", "findById").increment();
        LOG.warn("L0: LongTermMemoryRepository.findById called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public void delete(String tenantId, String entryId) {
        registry.counter(METRIC, "spi", "LongTermMemoryRepository", "method", "delete").increment();
        LOG.warn("L0: LongTermMemoryRepository.delete called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }
}
