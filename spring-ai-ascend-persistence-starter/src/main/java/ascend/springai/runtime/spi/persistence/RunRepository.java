package ascend.springai.runtime.spi.persistence;

import java.time.Instant;
import java.util.Optional;

/**
 * SPI: durable agent run record store.
 *
 * Default impl: Spring Data JDBC over Postgres.
 * Rule 11: every RunRecord carries tenantId, userId, sessionId.
 * Rule 10: research/prod posture enforces durable Postgres; dev may use in-memory.
 */
public interface RunRepository {

    RunRecord create(RunRecord run);

    Optional<RunRecord> findById(String tenantId, String runId);

    RunRecord updateStage(String tenantId, String runId, RunStage stage);

    RunRecord markTerminal(String tenantId, String runId, RunStage terminalStage, String outcome);

    record RunRecord(
            String runId,
            String tenantId,
            String userId,
            String sessionId,
            String parentRunId,
            RunStage stage,
            Instant startedAt,
            Instant finishedAt,
            String outcome
    ) {}

    enum RunStage {
        CREATED, PLANNING, EXECUTING, AWAITING_TOOL, WITNESSING, SUCCEEDED, FAILED, CANCELLED
    }
}
