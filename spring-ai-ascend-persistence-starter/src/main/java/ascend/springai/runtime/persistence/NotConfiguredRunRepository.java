package ascend.springai.runtime.persistence;

import ascend.springai.runtime.spi.persistence.RunRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Optional;

/**
 * L0 sentinel: no JDBC RunRepository wired at W0.
 * Replaced by Spring Data JDBC default impl in W1.
 */
class NotConfiguredRunRepository implements RunRepository {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredRunRepository.class);
    private static final String METRIC = "springai_ascend_persistence_default_impl_not_configured_total";
    private static final String MSG =
            "L0: RunRepository has no default impl yet. " +
            "Provide a @Bean RunRepository or wait for the W1 Spring Data JDBC impl.";

    private final MeterRegistry registry;

    NotConfiguredRunRepository(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public RunRecord create(RunRecord run) {
        registry.counter(METRIC, "spi", "RunRepository", "method", "create").increment();
        LOG.warn("L0: RunRepository.create called with no impl");
        throw new IllegalStateException(MSG);
    }

    @Override
    public Optional<RunRecord> findById(String tenantId, String runId) {
        registry.counter(METRIC, "spi", "RunRepository", "method", "findById").increment();
        LOG.warn("L0: RunRepository.findById called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public RunRecord updateStage(String tenantId, String runId, RunStage stage) {
        registry.counter(METRIC, "spi", "RunRepository", "method", "updateStage").increment();
        LOG.warn("L0: RunRepository.updateStage called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public RunRecord markTerminal(String tenantId, String runId, RunStage terminalStage, String outcome) {
        registry.counter(METRIC, "spi", "RunRepository", "method", "markTerminal").increment();
        LOG.warn("L0: RunRepository.markTerminal called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }
}
