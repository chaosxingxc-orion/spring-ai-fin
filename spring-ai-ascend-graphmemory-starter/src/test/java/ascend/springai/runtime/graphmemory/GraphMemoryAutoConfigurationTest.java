package ascend.springai.runtime.graphmemory;

import ascend.springai.runtime.spi.memory.GraphMemoryRepository;
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
    void whenEnabledSentinelBeanThrowsWithCounter() {
        runner.withPropertyValues("springai.fin.graphmemory.enabled=true")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    GraphMemoryRepository repo = ctx.getBean(GraphMemoryRepository.class);
                    MeterRegistry registry = ctx.getBean(MeterRegistry.class);
                    assertThatThrownBy(() -> repo.query("t1", "entity", 2))
                            .isInstanceOf(IllegalStateException.class)
                            .hasMessageContaining("Graphiti");
                    assertThat(registry.counter(
                            "springai_fin_graphmemory_adapter_not_implemented_total",
                            "spi", "GraphMemoryRepository", "method", "query").count())
                            .isEqualTo(1.0);
                });
    }
}
