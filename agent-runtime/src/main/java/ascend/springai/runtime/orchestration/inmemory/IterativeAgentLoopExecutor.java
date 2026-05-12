package ascend.springai.runtime.orchestration.inmemory;

import ascend.springai.runtime.orchestration.spi.AgentLoopExecutor;
import ascend.springai.runtime.orchestration.spi.ExecutorDefinition;
import ascend.springai.runtime.orchestration.spi.RunContext;
import ascend.springai.runtime.orchestration.spi.SuspendSignal;

import java.nio.charset.StandardCharsets;

/**
 * Reference AgentLoopExecutor: drives the Reasoner through iterations until terminal.
 *
 * Resume protocol:
 *  - On SuspendSignal: saves the CURRENT iteration index to checkpointer under "_loop_resume_iter".
 *  - On resume (resumePayload != null): loads "_loop_resume_iter", replays that iteration
 *    with resumePayload (child result) as the payload — the reasoner must NOT call
 *    suspendForChild again on a resume iteration.
 */
public final class IterativeAgentLoopExecutor implements AgentLoopExecutor {

    private static final String RESUME_ITER_KEY = "_loop_resume_iter";
    // Accumulated payload at the suspension point — combined with child result on resume.
    static final String RESUME_STATE_KEY = "_loop_resume_state";

    @Override
    public Object execute(RunContext ctx, ExecutorDefinition.AgentLoopDefinition def,
                          Object resumePayload) throws SuspendSignal {
        int startIteration;
        Object payload;

        if (resumePayload != null) {
            startIteration = ctx.checkpointer().load(ctx.runId(), RESUME_ITER_KEY)
                    .map(b -> Integer.parseInt(new String(b, StandardCharsets.UTF_8)))
                    .orElse(0);
            // Reconstruct payload: combine pre-suspension accumulated state with child result.
            String savedState = ctx.checkpointer().load(ctx.runId(), RESUME_STATE_KEY)
                    .map(b -> new String(b, StandardCharsets.UTF_8))
                    .orElse(null);
            payload = savedState != null ? savedState + resumePayload : resumePayload;
        } else {
            startIteration = 0;
            payload = def.initialContext();
        }

        for (int i = startIteration; i < def.maxIterations(); i++) {
            try {
                ExecutorDefinition.ReasoningResult result = def.reasoner().reason(ctx, payload, i);
                if (result.terminal()) {
                    return result.payload();
                }
                payload = result.payload();
            } catch (SuspendSignal signal) {
                ctx.checkpointer().save(ctx.runId(), RESUME_ITER_KEY,
                        String.valueOf(i).getBytes(StandardCharsets.UTF_8));
                // Only save accumulated state if prior iterations produced output (i > 0).
                // At i == 0 the payload is the initial context, not accumulated work.
                if (i > 0 && payload != null) {
                    ctx.checkpointer().save(ctx.runId(), RESUME_STATE_KEY,
                            payload.toString().getBytes(StandardCharsets.UTF_8));
                }
                throw signal;
            }
        }
        throw new IllegalStateException("Agent loop exceeded maxIterations=" + def.maxIterations()
                + " without reaching a terminal step");
    }
}
