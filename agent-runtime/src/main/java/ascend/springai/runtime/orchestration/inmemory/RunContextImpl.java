package ascend.springai.runtime.orchestration.inmemory;

import ascend.springai.runtime.orchestration.spi.Checkpointer;
import ascend.springai.runtime.orchestration.spi.ExecutorDefinition;
import ascend.springai.runtime.orchestration.spi.RunContext;
import ascend.springai.runtime.orchestration.spi.SuspendSignal;
import ascend.springai.runtime.runs.RunMode;

import java.util.Objects;
import java.util.UUID;

/**
 * RunContext implementation for the in-memory reference executor.
 * suspendForChild always throws SuspendSignal — the Orchestrator catches it.
 */
final class RunContextImpl implements RunContext {

    private final String tenantId;
    private final UUID runId;
    private final Checkpointer checkpointer;

    RunContextImpl(String tenantId, UUID runId, Checkpointer checkpointer) {
        this.tenantId = Objects.requireNonNull(tenantId);
        this.runId = Objects.requireNonNull(runId);
        this.checkpointer = Objects.requireNonNull(checkpointer);
    }

    @Override public UUID runId() { return runId; }
    @Override public String tenantId() { return tenantId; }
    @Override public Checkpointer checkpointer() { return checkpointer; }

    @Override
    public Object suspendForChild(String parentNodeKey, RunMode childMode,
                                  ExecutorDefinition childDef, Object resumePayload)
            throws SuspendSignal {
        throw new SuspendSignal(parentNodeKey, resumePayload, childMode, childDef);
    }
}
