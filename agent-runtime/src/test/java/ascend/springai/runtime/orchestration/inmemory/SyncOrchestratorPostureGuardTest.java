package ascend.springai.runtime.orchestration.inmemory;

import ascend.springai.runtime.orchestration.spi.ExecutorDefinition;
import ascend.springai.runtime.orchestration.spi.RunContext;
import ascend.springai.runtime.orchestration.spi.SuspendSignal;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

/**
 * Verifies that SyncOrchestrator delegates to AppPostureGate on construction (ADR-0035, §4 #32).
 *
 * <p>The research/prod throw is validated in AppPostureGateTest which exercises the gate directly
 * (env-var manipulation is not possible within the JVM). Gate Rule 12 asserts the
 * AppPostureGate.requireDevForInMemoryComponent literal is present in SyncOrchestrator.java,
 * ensuring delegation is wired.
 */
class SyncOrchestratorPostureGuardTest {

    @Test
    void dev_posture_allows_construction() {
        // APP_POSTURE not set in test env → dev posture → AppPostureGate warns, does not throw.
        var registry = new InMemoryRunRegistry();
        var checkpointer = new InMemoryCheckpointer();

        assertThatCode(() -> new SyncOrchestrator(
                registry,
                checkpointer,
                (ctx, def, payload) -> payload,       // stub GraphExecutor
                (ctx, def, payload) -> payload         // stub AgentLoopExecutor
        )).doesNotThrowAnyException();
    }

    @Test
    void construction_wires_all_required_dependencies() {
        var registry = new InMemoryRunRegistry();
        var checkpointer = new InMemoryCheckpointer();
        var orchestrator = new SyncOrchestrator(
                registry,
                checkpointer,
                (ctx, def, payload) -> payload,
                (ctx, def, payload) -> payload
        );
        assertThat(orchestrator).isNotNull();
    }
}
