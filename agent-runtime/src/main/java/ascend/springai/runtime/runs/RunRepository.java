package ascend.springai.runtime.runs;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * SPI for run persistence. W1-W2: implemented via Spring Data JDBC CrudRepository
 * backed by Postgres. Pure-Java types only (no Spring imports) per architecture constraint 7.
 */
public interface RunRepository {
    Optional<Run> findById(UUID runId);
    Run save(Run run);
    List<Run> findByTenant(String tenantId);
    List<Run> findByParentRunId(UUID parentRunId);
    List<Run> findByTenantAndStatus(String tenantId, RunStatus status);
}
