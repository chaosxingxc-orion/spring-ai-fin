package ascend.springai.runtime.persistence;

import ascend.springai.runtime.spi.persistence.IdempotencyRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Optional;

/**
 * L0 sentinel: no JDBC IdempotencyRepository wired at W0.
 * Replaced by Spring Data JDBC default impl in W1.
 */
class NotConfiguredIdempotencyRepository implements IdempotencyRepository {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredIdempotencyRepository.class);
    private static final String METRIC = "springai_ascend_persistence_default_impl_not_configured_total";
    private static final String MSG =
            "L0: IdempotencyRepository has no default impl yet. " +
            "Provide a @Bean IdempotencyRepository or wait for the W1 Spring Data JDBC impl.";

    private final MeterRegistry registry;

    NotConfiguredIdempotencyRepository(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public Optional<IdempotencyRecord> claimOrFind(String tenantId, String idempotencyKey, String runId) {
        registry.counter(METRIC, "spi", "IdempotencyRepository", "method", "claimOrFind").increment();
        LOG.warn("L0: IdempotencyRepository.claimOrFind called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }
}
