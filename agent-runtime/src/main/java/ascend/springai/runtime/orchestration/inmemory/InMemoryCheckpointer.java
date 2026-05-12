package ascend.springai.runtime.orchestration.inmemory;

import ascend.springai.runtime.orchestration.spi.Checkpointer;

import java.util.Arrays;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Dev-posture Checkpointer backed by a ConcurrentHashMap.
 * Not durable across JVM restarts. W2 replaces with a Postgres-backed impl.
 */
public final class InMemoryCheckpointer implements Checkpointer {

    private final Map<String, byte[]> store = new ConcurrentHashMap<>();

    @Override
    public void save(UUID runId, String nodeKey, byte[] payload) {
        store.put(key(runId, nodeKey), Arrays.copyOf(payload, payload.length));
    }

    @Override
    public Optional<byte[]> load(UUID runId, String nodeKey) {
        byte[] value = store.get(key(runId, nodeKey));
        return value == null ? Optional.empty()
                             : Optional.of(Arrays.copyOf(value, value.length));
    }

    private static String key(UUID runId, String nodeKey) {
        return runId + ":" + nodeKey;
    }
}
