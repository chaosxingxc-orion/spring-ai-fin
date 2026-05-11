package ascend.springai.runtime.graphmemory;

import ascend.springai.runtime.memory.spi.GraphMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GraphMemoryAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(GraphMemoryAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("ascend.springai.runtime.graphmemory.GraphMemoryAutoConfiguration");
    }

    @Test
    void disabledByDefaultNoBeansRegistered() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).doesNotHaveBean(GraphMemoryRepository.class);
        });
    }

    @Test
    void devPosture_enabled_contextLoads() {
        runner.withPropertyValues("springai.ascend.graphmemory.enabled=true", "app.posture=dev")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    assertThat(ctx).hasSingleBean(GraphMemoryRepository.class);
                });
    }

    @Test
    void researchPosture_enabled_throwsBeanCreationException() {
        runner.withPropertyValues("springai.ascend.graphmemory.enabled=true", "app.posture=research")
                .run(ctx -> assertThat(ctx).hasFailed());
    }

    @Test
    void prodPosture_enabled_throwsBeanCreationException() {
        runner.withPropertyValues("springai.ascend.graphmemory.enabled=true", "app.posture=prod")
                .run(ctx -> assertThat(ctx).hasFailed());
    }

    @Test
    void whenEnabledSentinelBeanThrowsWithCounter() {
        runner.withPropertyValues("springai.ascend.graphmemory.enabled=true")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    GraphMemoryRepository repo = ctx.getBean(GraphMemoryRepository.class);
                    MeterRegistry registry = ctx.getBean(MeterRegistry.class);
                    assertThatThrownBy(() -> repo.query("t1", "entity", 2))
                            .isInstanceOf(IllegalStateException.class)
                            .hasMessageContaining("Graphiti");
                    assertThat(registry.counter(
                            "springai_ascend_graph_memory_adapter_not_implemented_total",
                            "spi", "GraphMemoryRepository", "method", "query").count())
                            .isEqualTo(1.0);
                });
    }
}
