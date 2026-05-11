package ascend.springai.runtime.memory;

import ascend.springai.runtime.spi.memory.GraphMemoryRepository;
import ascend.springai.runtime.spi.memory.LongTermMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MemoryAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(MemoryAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("ascend.springai.runtime.memory.MemoryAutoConfiguration");
    }

    @Test
    void contextLoadsAndProvidesDefaultBeans() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).hasSingleBean(LongTermMemoryRepository.class);
            assertThat(ctx).hasSingleBean(GraphMemoryRepository.class);
            assertThat(ctx).hasSingleBean(MeterRegistry.class);
        });
    }

    @Test
    void longTermMemoryDefaultSentinelThrowsWithCounter() {
        runner.run(ctx -> {
            LongTermMemoryRepository repo = ctx.getBean(LongTermMemoryRepository.class);
            MeterRegistry registry = ctx.getBean(MeterRegistry.class);
            assertThatThrownBy(() -> repo.put("t1", "u1", "content", null))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("LongTermMemoryRepository");
            assertThat(registry.counter(
                    "springai_ascend_memory_default_impl_not_configured_total",
                    "spi", "LongTermMemoryRepository", "method", "put").count())
                    .isEqualTo(1.0);
        });
    }

    @Test
    void sentinelRejectedInResearchPosture() {
        runner.withPropertyValues("app.posture=research")
                .run(ctx -> assertThat(ctx).hasFailed());
    }

    @Test
    void sentinelRejectedInProdPosture() {
        runner.withPropertyValues("app.posture=prod")
                .run(ctx -> assertThat(ctx).hasFailed());
    }

    @Test
    void propertiesBindWithDefaults() {
        runner.run(ctx -> {
            assertThat(ctx).hasSingleBean(MemoryProperties.class);
            MemoryProperties props = ctx.getBean(MemoryProperties.class);
            assertThat(props.enabled()).isTrue();
        });
    }

    @Test
    void starterBeansAbsentWhenDisabled() {
        runner.withPropertyValues("springai.ascend.memory.enabled=false")
            .run(ctx -> {
                assertThat(ctx).doesNotHaveBean(LongTermMemoryRepository.class);
                assertThat(ctx).doesNotHaveBean(GraphMemoryRepository.class);
            });
    }
}
