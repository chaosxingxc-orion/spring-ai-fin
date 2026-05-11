package ascend.springai.runtime.docling;

import ascend.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DoclingAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(DoclingAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("ascend.springai.runtime.docling.DoclingAutoConfiguration");
    }

    @Test
    void disabledByDefaultNoBeansRegistered() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).doesNotHaveBean(LayoutParser.class);
        });
    }

    @Test
    void whenEnabledSentinelBeanThrowsWithCounter() {
        runner.withPropertyValues("springai.ascend.docling.enabled=true")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    LayoutParser parser = ctx.getBean(LayoutParser.class);
                    MeterRegistry registry = ctx.getBean(MeterRegistry.class);
                    assertThatThrownBy(() -> parser.parse(null, LayoutParser.ParseOptions.defaults()))
                            .isInstanceOf(IllegalStateException.class)
                            .hasMessageContaining("Docling");
                    assertThat(registry.counter(
                            "springai_ascend_docling_adapter_not_implemented_total",
                            "spi", "LayoutParser", "method", "parse").count())
                            .isEqualTo(1.0);
                });
    }
}
