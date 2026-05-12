package ascend.springai.runtime.runs;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Contract-spine entity for the run lifecycle. Rule 11: tenant_id is mandatory.
 * W1-W2: backed by a Postgres table via RunRepository (Spring Data JDBC CrudRepository).
 */
public record Run(
    UUID runId,
    String tenantId,
    String capabilityName,
    RunStatus status,
    Instant createdAt,
    Instant updatedAt,
    Instant finishedAt,
    UUID parentRunId,
    Integer attemptId
) {
    public Run {
        Objects.requireNonNull(runId, "runId is required");
        Objects.requireNonNull(tenantId, "tenantId is required");
        Objects.requireNonNull(capabilityName, "capabilityName is required");
        Objects.requireNonNull(status, "status is required");
        Objects.requireNonNull(createdAt, "createdAt is required");
    }
}
