package ascend.springai.platform.idempotency;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Optional;

/**
 * W0 idempotency store placeholder. Posture-aware fail-fast until W1 wires a real
 * Postgres-backed implementation. No state is kept in-process.
 *
 * W1: replace the method body with a Postgres unique-constraint claim via Spring Data JDBC.
 */
@Component
public class IdempotencyStore {

    private static final Logger LOG = LoggerFactory.getLogger(IdempotencyStore.class);

    private final String posture;

    public IdempotencyStore(Environment env) {
        this.posture = env.getProperty("app.posture", "dev");
    }

    /**
     * Attempt to claim the idempotency key for the given tenant and run.
     * Returns empty on first claim (proceed). Returns the existing record on duplicate.
     */
    public Optional<IdempotencyRecord> claimOrFind(String tenantId, String idempotencyKey, String runId) {
        if ("dev".equalsIgnoreCase(posture)) {
            LOG.warn("IdempotencyStore: no-op in dev posture; tenantId={} key={}", tenantId, idempotencyKey);
            return Optional.empty();
        }
        throw new UnsupportedOperationException(
                "IdempotencyStore is not implemented for posture=" + posture +
                ". W1 will add a Postgres-backed claim. Tenant: " + tenantId);
    }

    public record IdempotencyRecord(
            String tenantId,
            String idempotencyKey,
            String runId,
            Instant claimedAt
    ) {}
}
