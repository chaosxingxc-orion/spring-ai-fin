package ascend.springai.runtime.idempotency;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Contract-spine entity for idempotency. Rule 11: tenant_id is mandatory.
 * W1: backed by a Postgres unique-constraint table via Spring Data JDBC.
 */
public record IdempotencyRecord(
    String idempotencyKey,
    String tenantId,
    UUID runId,
    Instant claimedAt
) {
    public IdempotencyRecord {
        Objects.requireNonNull(idempotencyKey, "idempotencyKey is required");
        Objects.requireNonNull(tenantId, "tenantId is required");
    }
}
