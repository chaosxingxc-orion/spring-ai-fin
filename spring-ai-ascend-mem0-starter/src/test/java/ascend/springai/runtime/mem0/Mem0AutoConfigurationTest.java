package fin.springai.runtime.mem0;

import fin.springai.runtime.spi.memory.LongTermMemoryRepository;
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
        Class.forName("fin.springai.runtime.mem0.Mem0AutoConfiguration");
    }

    @Test
    void disabledByDefaultNoBeansRegistered() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).doesNotHaveBean(LongTermMemoryRepository.class);
        });
    }

    @Test
    void whenEnabledSentinelBeanThrowsWithCounter() {
        runner.withPropertyValues("springai.fin.mem0.enabled=true")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    LongTermMemoryRepository repo = ctx.getBean(LongTermMemoryRepository.class);
                    MeterRegistry registry = ctx.getBean(MeterRegistry.class);
                    assertThatThrownBy(() -> repo.put("t1", "u1", "content", null))
                            .isInstanceOf(IllegalStateException.class)
                            .hasMessageContaining("mem0");
                    assertThat(registry.counter(
                            "springai_fin_mem0_adapter_not_implemented_total", "method", "put").count())
                            .isEqualTo(1.0);
                });
    }
}
