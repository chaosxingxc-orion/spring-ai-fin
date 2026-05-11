package ascend.springai.runtime.persistence;

import ascend.springai.runtime.spi.persistence.ArtifactRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Optional;

/**
 * L0 sentinel: no MinIO/Postgres ArtifactRepository wired at W0.
 * Replaced by Spring Data JDBC + MinIO client impl in W1.
 */
class NotConfiguredArtifactRepository implements ArtifactRepository {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredArtifactRepository.class);
    private static final String METRIC = "springai_ascend_persistence_default_impl_not_configured_total";
    private static final String MSG =
            "L0: ArtifactRepository has no default impl yet. " +
            "Provide a @Bean ArtifactRepository or wait for the W1 JDBC + MinIO impl.";

    private final MeterRegistry registry;

    NotConfiguredArtifactRepository(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public ArtifactRecord store(String tenantId, String runId, String name, String mimeType, byte[] content) {
        registry.counter(METRIC, "spi", "ArtifactRepository", "method", "store").increment();
        LOG.warn("L0: ArtifactRepository.store called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public Optional<ArtifactRecord> findById(String tenantId, String artifactId) {
        registry.counter(METRIC, "spi", "ArtifactRepository", "method", "findById").increment();
        LOG.warn("L0: ArtifactRepository.findById called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }

    @Override
    public List<ArtifactRecord> findByRunId(String tenantId, String runId) {
        registry.counter(METRIC, "spi", "ArtifactRepository", "method", "findByRunId").increment();
        LOG.warn("L0: ArtifactRepository.findByRunId called with no impl; tenantId={}", tenantId);
        throw new IllegalStateException(MSG);
    }
}
