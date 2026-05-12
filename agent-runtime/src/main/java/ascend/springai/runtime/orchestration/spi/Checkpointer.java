package ascend.springai.runtime.orchestration.spi;

import java.util.Optional;
import java.util.UUID;

/**
 * SPI for suspend-point persistence. Pure Java — no Spring imports.
 *
 * dev posture: in-memory ConcurrentHashMap (InMemoryCheckpointer).
 * W2 posture: Postgres jsonb column on the runs table (PostgresCheckpointer).
 * W4 posture: not needed — Temporal owns state durability.
 */
public interface Checkpointer {

    /**
     * Persist a serialised checkpoint for the given run and node.
     * Overwrites any previously stored value for the same (runId, nodeKey) pair.
     */
    void save(UUID runId, String nodeKey, byte[] payload);

    /**
     * Load the most recent checkpoint for the given run and node.
     * Returns empty if no checkpoint has been saved for this pair.
     */
    Optional<byte[]> load(UUID runId, String nodeKey);
}
