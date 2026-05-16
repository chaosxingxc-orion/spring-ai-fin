package ascend.springai.platform.engine;

import ascend.springai.runtime.engine.EngineRegistry;
import ascend.springai.runtime.orchestration.inmemory.IterativeAgentLoopExecutor;
import ascend.springai.runtime.orchestration.inmemory.SequentialGraphExecutor;
import ascend.springai.runtime.orchestration.spi.AgentLoopExecutor;
import ascend.springai.runtime.orchestration.spi.ExecutorAdapter;
import ascend.springai.runtime.orchestration.spi.GraphExecutor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

/**
 * Wires the W2.x Phase 5 R2 pilot - runtime self-validation of the engine
 * envelope schema (ADR-0076, extends ADR-0071 and ADR-0072).
 *
 * <p>Boot order is single-pass: every {@link ExecutorAdapter} bean discovered
 * in the Spring context is registered with {@link EngineRegistry}, then
 * {@link EngineRegistry#validateAgainstSchema()} runs once. If the registered
 * set does not match {@code known_engines} in
 * {@code docs/contracts/engine-envelope.v1.yaml}, the bean factory raises
 * {@link IllegalStateException} and the application fails to start. This is
 * the Rule 9 ship-gate posture - misconfiguration cannot reach production.
 *
 * <p>Two reference executors are registered by default: the W0 reference
 * {@link SequentialGraphExecutor} (engineType=graph) and
 * {@link IterativeAgentLoopExecutor} (engineType=agent-loop). Both are
 * conditional on missing beans so an integrator can supply alternative
 * implementations without removing the default wiring.
 *
 * <p>The schema path is configurable via {@code app.engine.envelope-schema-path};
 * the default is correct for unit-test launches from the repo root and for
 * the packaged jar (the YAML is shipped under the same path).
 *
 * <p>Authority: ADR-0076; Layer-0 principle P-M.
 */
@Configuration(proxyBeanMethods = false)
public class EngineAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(GraphExecutor.class)
    public GraphExecutor sequentialGraphExecutor() {
        return new SequentialGraphExecutor();
    }

    @Bean
    @ConditionalOnMissingBean(AgentLoopExecutor.class)
    public AgentLoopExecutor iterativeAgentLoopExecutor() {
        return new IterativeAgentLoopExecutor();
    }

    @Bean
    @ConditionalOnMissingBean
    public EngineRegistry engineRegistry(
            List<ExecutorAdapter> adapters,
            @Value("${app.engine.envelope-schema-path:docs/contracts/engine-envelope.v1.yaml}")
                    String schemaPath) {
        EngineRegistry registry = new EngineRegistry();
        adapters.forEach(registry::register);
        // Phase 5 R2 pilot - fail fast at boot if the registered adapter set
        // does not match docs/contracts/engine-envelope.v1.yaml known_engines.
        registry.validateAgainstSchema(schemaPath);
        return registry;
    }
}
