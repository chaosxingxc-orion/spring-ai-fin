package fin.springai.runtime.spi.persistence;

import java.util.Optional;

/**
 * SPI: idempotency key store.
 *
 * Guarantees exactly-once execution for externally-keyed requests.
 * Default impl: Postgres unique constraint on (tenantId, idempotencyKey).
 * Rule 11: tenantId on every record.
 */
public interface IdempotencyRepository {

    /**
     * Attempt to claim the idempotency key.
     * Returns empty if the claim succeeds (first call).
     * Returns the existing record if the key was already claimed.
     */
    Optional<IdempotencyRecord> claimOrFind(String tenantId, String idempotencyKey, String runId);

    record IdempotencyRecord(
            String tenantId,
            String idempotencyKey,
            String runId,
            java.time.Instant claimedAt
    ) {}
}
