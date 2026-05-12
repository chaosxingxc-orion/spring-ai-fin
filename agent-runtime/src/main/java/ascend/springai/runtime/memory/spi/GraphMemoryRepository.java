package ascend.springai.runtime.memory.spi;

import java.util.List;

/**
 * SPI: knowledge-graph memory store for relationship-aware retrieval.
 *
 * No default in-JVM impl (graph structure requires an external store).
 * Primary sidecar impl: spring-ai-ascend-graphmemory-starter (Graphiti REST).
 * ADR-0034: Graphiti selected as W1 reference sidecar; Cognee not selected.
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

    record GraphMetadata(String tenantId, String sessionId, String runId, java.time.Instant createdAt) {}
}
