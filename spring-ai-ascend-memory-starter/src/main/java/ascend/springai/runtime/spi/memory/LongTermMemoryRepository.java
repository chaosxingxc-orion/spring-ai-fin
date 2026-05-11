package ascend.springai.runtime.spi.memory;

import java.util.List;
import java.util.Optional;

/**
 * SPI: durable long-term memory store, scoped to a tenant + user session.
 *
 * Default impl: Spring Data JDBC repository over Postgres.
 * Optional sidecar impl: spring-ai-ascend-mem0-starter (mem0 REST API).
 *
 * All implementations are required to scope every operation to the
 * provided tenantId (Rule 11 contract-spine requirement).
 */
public interface LongTermMemoryRepository {

    /**
     * Persist a memory entry for the given tenant + user.
     * The store assigns an opaque id returned in the response.
     */
    MemoryEntry put(String tenantId, String userId, String content, MemoryMetadata metadata);

    /**
     * Retrieve the top-k most relevant entries for the given query.
     */
    List<MemoryEntry> search(String tenantId, String userId, String query, int topK);

    /**
     * Fetch a single entry by id; empty if not found or wrong tenant.
     */
    Optional<MemoryEntry> findById(String tenantId, String entryId);

    /**
     * Delete an entry. No-op if the entry does not exist or belongs to a
     * different tenant.
     */
    void delete(String tenantId, String entryId);

    record MemoryEntry(
            String id,
            String tenantId,
            String userId,
            String content,
            MemoryMetadata metadata
    ) {}

    record MemoryMetadata(
            String tenantId,
            String sessionId,
            String runId,
            java.time.Instant createdAt
    ) {}
}
