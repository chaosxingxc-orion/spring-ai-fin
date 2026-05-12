package ascend.springai.runtime.orchestration.spi;

/**
 * SPI for ReAct-style iterative agent-loop execution. Pure Java — no Spring imports.
 * Implementations drive a Reasoner through up to maxIterations reasoning steps.
 * A reasoning step may call RunContext.suspendForChild to nest a child run (graph or loop).
 *
 * resumePayload is null on first call; on resume it carries the child run's final result.
 * The saved iteration index (via RunContext.checkpointer()) is replayed with resumePayload.
 */
public interface AgentLoopExecutor {

    /**
     * Execute or resume the agent loop defined by {@code def} within the given {@code ctx}.
     *
     * @param resumePayload null on first call; child run result on resume
     * @return the final payload produced by the terminal reasoning step
     * @throws SuspendSignal if a reasoning step requests suspension for a child run
     */
    Object execute(RunContext ctx, ExecutorDefinition.AgentLoopDefinition def, Object resumePayload)
            throws SuspendSignal;
}
