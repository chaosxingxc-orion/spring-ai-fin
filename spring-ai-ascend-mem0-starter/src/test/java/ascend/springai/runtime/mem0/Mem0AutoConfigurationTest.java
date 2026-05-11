package ascend.springai.runtime.mem0;

import ascend.springai.runtime.spi.memory.LongTermMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class Mem0AutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(Mem0AutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("ascend.springai.runtime.mem0.Mem0AutoConfiguration");
    }

    @Test
    void disabledByDefaultNoBeansRegistered() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).doesNotHaveBean(LongTermMemoryRepository.class);
        });
    }

    @Test
    void devPosture_enabled_contextLoads() {
        runner.withPropertyValues("springai.ascend.mem0.enabled=true", "app.posture=dev")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    assertThat(ctx).hasSingleBean(LongTermMemoryRepository.class);
                });
    }

    @Test
    void researchPosture_enabled_throwsBeanCreationException() {
        runner.withPropertyValues("springai.ascend.mem0.enabled=true", "app.posture=research")
                .run(ctx -> assertThat(ctx).hasFailed());
    }

    @Test
    void prodPosture_enabled_throwsBeanCreationException() {
        runner.withPropertyValues("springai.ascend.mem0.enabled=true", "app.posture=prod")
                .run(ctx -> assertThat(ctx).hasFailed());
    }

    @Test
    void whenEnabledSentinelBeanThrowsWithCounter() {
        runner.withPropertyValues("springai.ascend.mem0.enabled=true")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    LongTermMemoryRepository repo = ctx.getBean(LongTermMemoryRepository.class);
                    MeterRegistry registry = ctx.getBean(MeterRegistry.class);
                    assertThatThrownBy(() -> repo.put("t1", "u1", "content", null))
                            .isInstanceOf(IllegalStateException.class)
                            .hasMessageContaining("mem0");
                    assertThat(registry.counter(
                            "springai_ascend_mem0_adapter_not_implemented_total", "method", "put").count())
                            .isEqualTo(1.0);
                });
    }
}
