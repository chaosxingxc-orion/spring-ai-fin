package ascend.springai.runtime.orchestration.inmemory;

import ascend.springai.runtime.orchestration.spi.AgentLoopExecutor;
import ascend.springai.runtime.orchestration.spi.Checkpointer;
import ascend.springai.runtime.orchestration.spi.ExecutorDefinition;
import ascend.springai.runtime.orchestration.spi.GraphExecutor;
import ascend.springai.runtime.orchestration.spi.Orchestrator;
import ascend.springai.runtime.orchestration.spi.RunContext;
import ascend.springai.runtime.orchestration.spi.SuspendSignal;
import ascend.springai.runtime.posture.AppPostureGate;
import ascend.springai.runtime.runs.Run;
import ascend.springai.runtime.runs.RunMode;
import ascend.springai.runtime.runs.RunRepository;
import ascend.springai.runtime.runs.RunStatus;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Reference Orchestrator for in-memory / dev-posture execution.
 *
 * Owns the suspend/checkpoint/resume loop:
 *  1. On SuspendSignal: persist checkpoint, mark parent SUSPENDED, dispatch child.
 *  2. On child completion: load parent checkpoint, transition parent back to RUNNING,
 *     re-invoke parent executor with child result as the resume payload.
 *
 * This implementation is single-threaded (child dispatch is synchronous / recursive).
 * W2 replaces this with a Postgres-backed async orchestrator; the SPI surface is identical.
 */
public final class SyncOrchestrator implements Orchestrator {

    private final RunRepository runs;
    private final Checkpointer checkpointer;
    private final GraphExecutor graphExecutor;
    private final AgentLoopExecutor agentLoopExecutor;

    public SyncOrchestrator(RunRepository runs, Checkpointer checkpointer,
                            GraphExecutor graphExecutor, AgentLoopExecutor agentLoopExecutor) {
        AppPostureGate.requireDevForInMemoryComponent("SyncOrchestrator");
        this.runs = Objects.requireNonNull(runs);
        this.checkpointer = Objects.requireNonNull(checkpointer);
        this.graphExecutor = Objects.requireNonNull(graphExecutor);
        this.agentLoopExecutor = Objects.requireNonNull(agentLoopExecutor);
    }

    @Override
    public Object run(UUID runId, String tenantId, ExecutorDefinition def, Object initialPayload) {
        Run run = runs.findById(runId).orElseGet(() -> createRun(runId, tenantId, def));
        run = runs.save(run.withStatus(RunStatus.RUNNING));
        return executeLoop(run, def, initialPayload);
    }

    /**
     * W0 atomicity invariant (ADR-0024): checkpoint write and RunRepository.save(suspended)
     * are on the same call stack; single-threaded recursion ensures sequential ordering.
     * W2 mandate: both writes MUST move inside a single @Transactional block.
     */
    private Object executeLoop(Run run, ExecutorDefinition def, Object payload) {
        while (true) {
            RunContextImpl ctx = new RunContextImpl(run.tenantId(), run.runId(), checkpointer);
            try {
                Object result = dispatch(ctx, def, payload);
                runs.save(run.withStatus(RunStatus.SUCCEEDED).withFinishedAt(Instant.now()));
                return result;
            } catch (SuspendSignal signal) {
                run = runs.save(run.withSuspension(signal.parentNodeKey(), Instant.now()));

                UUID childRunId = UUID.randomUUID();
                // Pre-create child run with parentRunId so the nesting chain is queryable.
                runs.save(new Run(childRunId, run.tenantId(), "orchestrated",
                        RunStatus.PENDING, modeFor(signal.childDef()), Instant.now(),
                        null, null, run.runId(), null, null, null));
                Object childResult = run(childRunId, run.tenantId(),
                        signal.childDef(), signal.resumePayload());

                run = runs.findById(run.runId()).orElseThrow();
                run = runs.save(run.withStatus(RunStatus.RUNNING).withUpdatedAt(Instant.now()));
                payload = childResult;
            }
        }
    }

    private Object dispatch(RunContext ctx, ExecutorDefinition def, Object payload)
            throws SuspendSignal {
        return switch (def) {
            case ExecutorDefinition.GraphDefinition g -> graphExecutor.execute(ctx, g, payload);
            case ExecutorDefinition.AgentLoopDefinition a -> agentLoopExecutor.execute(ctx, a, payload);
        };
    }

    private Run createRun(UUID runId, String tenantId, ExecutorDefinition def) {
        return new Run(runId, tenantId, "orchestrated",
                RunStatus.PENDING, modeFor(def), Instant.now(),
                null, null, null, null, null, null);
    }

    private static RunMode modeFor(ExecutorDefinition def) {
        return switch (def) {
            case ExecutorDefinition.GraphDefinition g -> RunMode.GRAPH;
            case ExecutorDefinition.AgentLoopDefinition a -> RunMode.AGENT_LOOP;
        };
    }
}
