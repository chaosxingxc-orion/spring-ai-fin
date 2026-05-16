package ascend.springai.runtime.orchestration.inmemory;

import ascend.springai.runtime.engine.EngineRegistry;
import ascend.springai.runtime.engine.HookDispatcher;
import ascend.springai.runtime.orchestration.spi.Checkpointer;
import ascend.springai.runtime.orchestration.spi.ExecutorDefinition;
import ascend.springai.runtime.orchestration.spi.HookContext;
import ascend.springai.runtime.orchestration.spi.HookPoint;
import ascend.springai.runtime.orchestration.spi.Orchestrator;
import ascend.springai.runtime.orchestration.spi.RunContext;
import ascend.springai.runtime.orchestration.spi.SuspendSignal;
import ascend.springai.runtime.posture.AppPostureGate;
import ascend.springai.runtime.resilience.SuspendReason;
import ascend.springai.runtime.runs.Run;
import ascend.springai.runtime.runs.RunMode;
import ascend.springai.runtime.runs.RunRepository;
import ascend.springai.runtime.runs.RunStatus;
import ascend.springai.runtime.s2c.S2cCallbackEnvelope;
import ascend.springai.runtime.s2c.S2cCallbackResponse;
import ascend.springai.runtime.s2c.spi.S2cCallbackSignal;
import ascend.springai.runtime.s2c.spi.S2cCallbackTransport;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.CompletionException;

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
    private final EngineRegistry engineRegistry;
    private final HookDispatcher hookDispatcher;

    /**
     * W2.x Phase 1 (ADR-0072): dispatch goes through {@link EngineRegistry}
     * exclusively. Pattern-matching on {@link ExecutorDefinition} subtypes
     * outside the registry is forbidden by Rule 43.
     *
     * <p>W2.x Phase 2 (ADR-0073): the orchestrator fires three structural
     * hooks ({@link HookPoint#ON_ERROR}, {@link HookPoint#BEFORE_SUSPENSION},
     * {@link HookPoint#BEFORE_RESUME}) via {@link EngineRegistry#hookDispatcher()}.
     * Phase 2 logs outcomes only; outcome handling (Fail aborts, ShortCircuit
     * returns) lands in W2 Telemetry Vertical.
     */
    public SyncOrchestrator(RunRepository runs, Checkpointer checkpointer, EngineRegistry engineRegistry) {
        AppPostureGate.requireDevForInMemoryComponent("SyncOrchestrator");
        this.runs = Objects.requireNonNull(runs);
        this.checkpointer = Objects.requireNonNull(checkpointer);
        this.engineRegistry = Objects.requireNonNull(engineRegistry, "engineRegistry is required");
        this.hookDispatcher = engineRegistry.hookDispatcher();
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
                hookDispatcher.fire(new HookContext(
                        HookPoint.BEFORE_SUSPENSION,
                        run.runId(),
                        run.tenantId(),
                        Map.of("parentNodeKey", signal.parentNodeKey())));
                run = runs.save(run.withSuspension(signal.parentNodeKey(), Instant.now()));

                UUID childRunId = UUID.randomUUID();
                // Pre-create child run with parentRunId so the nesting chain is queryable.
                runs.save(new Run(childRunId, run.tenantId(), "orchestrated",
                        RunStatus.PENDING, modeFor(signal.childDef()), Instant.now(),
                        null, null, run.runId(), null, null, null));
                Object childResult = run(childRunId, run.tenantId(),
                        signal.childDef(), signal.resumePayload());

                hookDispatcher.fire(new HookContext(
                        HookPoint.BEFORE_RESUME,
                        run.runId(),
                        run.tenantId(),
                        Map.of("childRunId", childRunId)));
                run = runs.findById(run.runId()).orElseThrow();
                run = runs.save(run.withStatus(RunStatus.RUNNING).withUpdatedAt(Instant.now()));
                payload = childResult;
            } catch (S2cCallbackSignal s2cSignal) {
                // W2.x Phase 3 (ADR-0074): persist checkpoint, dispatch via transport,
                // validate response, resume parent with response payload. Caught BEFORE
                // the generic RuntimeException branch so S2C is never confused with on_error.
                hookDispatcher.fire(new HookContext(
                        HookPoint.BEFORE_SUSPENSION,
                        run.runId(),
                        run.tenantId(),
                        Map.of("parentNodeKey", s2cSignal.parentNodeKey(),
                                "callbackId", s2cSignal.envelope().callbackId())));
                run = runs.save(run.withSuspension(s2cSignal.parentNodeKey(), Instant.now()));
                Object newPayload = handleClientCallback(run, s2cSignal.envelope());
                hookDispatcher.fire(new HookContext(
                        HookPoint.BEFORE_RESUME,
                        run.runId(),
                        run.tenantId(),
                        Map.of("callbackId", s2cSignal.envelope().callbackId())));
                run = runs.findById(run.runId()).orElseThrow();
                run = runs.save(run.withStatus(RunStatus.RUNNING).withUpdatedAt(Instant.now()));
                payload = newPayload;
            } catch (RuntimeException e) {
                hookDispatcher.fire(new HookContext(
                        HookPoint.ON_ERROR,
                        run.runId(),
                        run.tenantId(),
                        Map.of("exception", e.getClass().getName(),
                                "message", String.valueOf(e.getMessage()))));
                throw e;
            }
        }
    }

    private Object dispatch(RunContext ctx, ExecutorDefinition def, Object payload)
            throws SuspendSignal {
        // Rule 43: never pattern-match on ExecutorDefinition subtypes here —
        // EngineRegistry encapsulates the class-to-engineType mapping.
        return engineRegistry.resolveByPayload(def).execute(ctx, def, payload);
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

    /**
     * W2.x Phase 3 (ADR-0074): dispatch an S2C callback via the registered
     * {@link S2cCallbackTransport}, await the response, validate, and return
     * the validated payload to be used as the parent's resume payload.
     *
     * <p>Validation invariants (per s2c-callback.v1.yaml + Phase 3a audit matrix):
     * <ul>
     *   <li>Response {@code callbackId} MUST match request {@code callbackId}.</li>
     *   <li>Outcome {@code ERROR}  -- Run transitions to FAILED with
     *       {@link SuspendReason.AwaitClientCallback#S2C_CLIENT_ERROR}.</li>
     *   <li>Outcome {@code TIMEOUT} -- Run transitions to FAILED with
     *       {@link SuspendReason.AwaitClientCallback#S2C_TIMEOUT}.</li>
     *   <li>Validation failure -- Run transitions to FAILED with
     *       {@link SuspendReason.AwaitClientCallback#S2C_RESPONSE_INVALID}.</li>
     *   <li>Transport unavailable -- Run transitions to FAILED with
     *       {@code s2c_transport_unavailable}.</li>
     * </ul>
     *
     * <p>The {@link CompletionStage} returned by the transport is awaited via
     * {@code toCompletableFuture().join()} -- this is intentional at W2.x:
     * SyncOrchestrator is single-threaded recursive; W2's async orchestrator
     * will use non-blocking composition (no Thread.sleep involved, so Rule 38
     * holds).
     */
    private Object handleClientCallback(Run run, S2cCallbackEnvelope envelope) {
        S2cCallbackTransport transport = engineRegistry.s2cCallbackTransport();
        if (transport == null) {
            throw new IllegalStateException("s2c_transport_unavailable: SyncOrchestrator received "
                    + "an S2C SuspendSignal but no S2cCallbackTransport is registered "
                    + "(register via EngineRegistry.registerS2cCallbackTransport).");
        }
        S2cCallbackResponse response;
        try {
            response = transport.dispatch(envelope).toCompletableFuture().join();
        } catch (CompletionException ce) {
            throw new IllegalStateException("s2c_transport_failure: " + ce.getCause(), ce.getCause());
        }
        if (response == null) {
            throw new IllegalStateException(SuspendReason.AwaitClientCallback.S2C_RESPONSE_INVALID
                    + ": transport returned null response");
        }
        if (!Objects.equals(response.callbackId(), envelope.callbackId())) {
            throw new IllegalStateException(SuspendReason.AwaitClientCallback.S2C_RESPONSE_INVALID
                    + ": response.callbackId=" + response.callbackId()
                    + " does not match request.callbackId=" + envelope.callbackId());
        }
        return switch (response.outcome()) {
            case OK -> response.responsePayload();
            case ERROR -> throw new IllegalStateException(
                    SuspendReason.AwaitClientCallback.S2C_CLIENT_ERROR
                            + ": " + response.errorCode() + " -- " + response.errorMessage());
            case TIMEOUT -> throw new IllegalStateException(
                    SuspendReason.AwaitClientCallback.S2C_TIMEOUT
                            + ": client did not respond within deadline=" + envelope.deadline());
        };
    }
}
