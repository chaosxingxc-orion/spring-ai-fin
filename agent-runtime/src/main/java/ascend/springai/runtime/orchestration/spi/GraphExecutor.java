package ascend.springai.runtime.orchestration.spi;

/**
 * SPI for deterministic graph execution. Pure Java — no Spring imports.
 * Implementations traverse GraphDefinition nodes in edge order, passing payload
 * from node to node. A node may call RunContext.suspendForChild to nest a child run.
 *
 * resumePayload is null on first call; on resume it carries the child run's final result.
 * Implementations use RunContext.checkpointer() to save and load the resume position.
 */
public interface GraphExecutor {

    /**
     * Execute or resume the graph defined by {@code def} within the given {@code ctx}.
     *
     * @param resumePayload null on first call; child run result on resume
     * @return the final payload produced by the terminal node
     * @throws SuspendSignal if a node requests suspension for a child run
     */
    Object execute(RunContext ctx, ExecutorDefinition.GraphDefinition def, Object resumePayload)
            throws SuspendSignal;
}
