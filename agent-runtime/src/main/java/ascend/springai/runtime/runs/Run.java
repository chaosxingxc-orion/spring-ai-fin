package ascend.springai.runtime.runs;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Contract-spine entity for the run lifecycle. Rule 11: tenant_id is mandatory.
 * W2: backed by a Postgres table via RunRepository (Spring Data JDBC CrudRepository). W0 dev: held
 * in-memory by InMemoryRunRegistry. See ADR-0021.
 * mode discriminates whether this run is executing a deterministic graph or a ReAct agent loop.
 * parentNodeKey and suspendedAt are populated only when status = SUSPENDED.
 */
public record Run(
    UUID runId,
    String tenantId,
    String capabilityName,
    RunStatus status,
    RunMode mode,
    Instant createdAt,
    Instant updatedAt,
    Instant finishedAt,
    UUID parentRunId,
    Integer attemptId,
    String parentNodeKey,
    Instant suspendedAt
) {
    public Run {
        Objects.requireNonNull(runId, "runId is required");
        Objects.requireNonNull(tenantId, "tenantId is required");
        Objects.requireNonNull(capabilityName, "capabilityName is required");
        Objects.requireNonNull(status, "status is required");
        Objects.requireNonNull(mode, "mode is required");
        Objects.requireNonNull(createdAt, "createdAt is required");
    }

    public Run withStatus(RunStatus newStatus) {
        RunStateMachine.validate(this.status, newStatus);
        return new Run(runId, tenantId, capabilityName, newStatus, mode,
                createdAt, Instant.now(), finishedAt, parentRunId, attemptId,
                parentNodeKey, suspendedAt);
    }

    public Run withFinishedAt(Instant newFinishedAt) {
        return new Run(runId, tenantId, capabilityName, status, mode,
                createdAt, Instant.now(), newFinishedAt, parentRunId, attemptId,
                parentNodeKey, suspendedAt);
    }

    public Run withUpdatedAt(Instant newUpdatedAt) {
        return new Run(runId, tenantId, capabilityName, status, mode,
                createdAt, newUpdatedAt, finishedAt, parentRunId, attemptId,
                parentNodeKey, suspendedAt);
    }

    public Run withSuspension(String newParentNodeKey, Instant newSuspendedAt) {
        RunStateMachine.validate(this.status, RunStatus.SUSPENDED);
        return new Run(runId, tenantId, capabilityName, RunStatus.SUSPENDED, mode,
                createdAt, Instant.now(), finishedAt, parentRunId, attemptId,
                newParentNodeKey, newSuspendedAt);
    }
}
