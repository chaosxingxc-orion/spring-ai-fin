package ascend.springai.runtime.memory.spi;

import java.util.List;

/**
 * SPI: knowledge-graph memory store for relationship-aware retrieval.
 *
 * No default in-JVM impl (graph structure requires an external store).
 * W1 reference sidecar (per ADR-0034): spring-ai-ascend-graphmemory-starter wires a Graphiti REST
 * client at W1; no adapter implementation ships at W0.
 *
 * Rule 11: every operation carries tenantId.
 */
public interface GraphMemoryRepository {

    /** Add a fact triple (subject, relation, object) to the tenant's graph. */
    void addFact(String tenantId, String subject, String relation, String object, GraphMetadata metadata);

    /** Traverse the graph starting from subject, depth-limited. */
    List<GraphEdge> query(String tenantId, String subject, int maxDepth);

    /** Full-text + graph search over the tenant's knowledge graph. */
    List<GraphEdge> search(String tenantId, String queryText, int topK);

    record GraphEdge(String tenantId, String subject, String relation, String object) {}

    /**
     * Pre-W2 minimal graph-edge metadata subset. Full {@code MemoryMetadata} (including
     * {@code embeddingModelVersion}) lands with the W2 memory implementation per ADR-0034.
     */
    record GraphMetadata(String tenantId, String sessionId, String runId, java.time.Instant createdAt) {}
}
