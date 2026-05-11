package fin.springai.runtime.spi.persistence;

import java.util.List;
import java.util.Optional;

/**
 * SPI: store and retrieve run output artifacts (files, reports, data).
 *
 * Default impl: Postgres-backed metadata + MinIO object storage (via Spring AI
 * document storage or direct MinIO client).
 * Rule 11: tenantId on every ArtifactRecord.
 */
public interface ArtifactRepository {

    ArtifactRecord store(String tenantId, String runId, String name,
                         String mimeType, byte[] content);

    Optional<ArtifactRecord> findById(String tenantId, String artifactId);

    List<ArtifactRecord> findByRunId(String tenantId, String runId);

    record ArtifactRecord(
            String artifactId,
            String tenantId,
            String runId,
            String name,
            String mimeType,
            long sizeBytes,
            String storageUri,
            java.time.Instant createdAt
    ) {}
}
