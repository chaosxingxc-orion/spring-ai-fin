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
    void devPosture_enabled_contextLoads() {
        runner.withPropertyValues("springai.ascend.docling.enabled=true", "app.posture=dev")
                .run(ctx -> {
                    assertThat(ctx).hasNotFailed();
                    assertThat(ctx).hasSingleBean(LayoutParser.class);
                });
    }

    @Test
    void researchPosture_enabled_throwsBeanCreationException() {
        runner.withPropertyValues("springai.ascend.docling.enabled=true", "app.posture=research")
                .run(ctx -> assertThat(ctx).hasFailed());
    }

    @Test
    void prodPosture_enabled_throwsBeanCreationException() {
        runner.withPropertyValues("springai.ascend.docling.enabled=true", "app.posture=prod")
                .run(ctx -> assertThat(ctx).hasFailed());
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
