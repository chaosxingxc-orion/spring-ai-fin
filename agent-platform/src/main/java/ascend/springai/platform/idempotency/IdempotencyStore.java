package ascend.springai.platform.idempotency;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.env.Environment;

import java.time.Instant;
import java.util.Optional;

/**
 * W0 dev-posture stub. Not registered as a Spring @Component at W0 — not injected anywhere.
 * W1 will wire this into IdempotencyHeaderFilter with (tenant_id, key) claim/replay semantics
 * backed by a Postgres unique-constraint table. See ADR-0027.
 */
// @Component -- wired in W1 (ADR-0027); intentionally unregistered at W0
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
