package ascend.springai.platform.idempotency;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Optional;

/**
 * W0 dev-posture stub. Emits a startup WARNING for non-dev postures.
 * claimOrFind() throws IllegalStateException on research/prod until W1 wires a
 * Postgres-backed implementation via Spring Data JDBC.
 *
 * W1: replace with a real implementation backed by a Postgres unique-constraint table.
 */
@Component
public class IdempotencyStore {

    private static final Logger LOG = LoggerFactory.getLogger(IdempotencyStore.class);

    private final String posture;

    public IdempotencyStore(Environment env) {
        this.posture = env.getProperty("app.posture", "dev");
    }

    @PostConstruct
    public void init() {
        if (!"dev".equalsIgnoreCase(posture)) {
            LOG.warn("IdempotencyStore[W0 stub] is active in posture={}. " +
                "Configure a Postgres-backed IdempotencyStore bean (W1). " +
                "Calls to claimOrFind will throw IllegalStateException.", posture);
        }
    }

    /**
     * Attempt to claim the idempotency key for the given tenant and run.
     * Returns empty on first claim (proceed). Returns the existing record on duplicate.
     * Dev posture: always returns empty (no-op). Research/prod: throws until W1.
     */
    public Optional<IdempotencyRecord> claimOrFind(String tenantId, String idempotencyKey, String runId) {
        if ("dev".equalsIgnoreCase(posture)) {
            LOG.warn("IdempotencyStore: no-op in dev posture; tenantId={} key={}", tenantId, idempotencyKey);
            return Optional.empty();
        }
        throw new IllegalStateException(
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
