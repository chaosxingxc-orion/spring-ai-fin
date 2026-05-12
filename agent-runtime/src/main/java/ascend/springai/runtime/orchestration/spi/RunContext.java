package ascend.springai.runtime.orchestration.spi;

import ascend.springai.runtime.runs.RunMode;

import java.util.UUID;

/**
 * Execution context threaded through every node and reasoning step.
 * Pure Java — no Spring imports per architecture §4.7.
 *
 * The single nesting entry-point is suspendForChild: it causes the orchestrator
 * to suspend the current run, start a child run under childMode, and return
 * the child's final result when the child completes. From the caller's view
 * it is a synchronous call; internally it throws SuspendSignal.
 */
public interface RunContext {

    UUID runId();

    String tenantId();

    Checkpointer checkpointer();

    /**
     * Request suspension of the current run and delegation to a child executor.
     *
     * @param parentNodeKey identifies which step in the parent is suspending
     * @param childMode     GRAPH or AGENT_LOOP
     * @param childDef      the definition to hand to the child executor
     * @param resumePayload serialisable data the child should start with
     * @return the child's final result once the child completes
     * @throws SuspendSignal always — caught only by the Orchestrator
     */
    Object suspendForChild(String parentNodeKey, RunMode childMode,
                           ExecutorDefinition childDef, Object resumePayload)
            throws SuspendSignal;
}
