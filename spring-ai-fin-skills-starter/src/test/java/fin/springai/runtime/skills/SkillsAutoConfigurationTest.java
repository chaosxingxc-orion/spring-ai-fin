package fin.springai.runtime.skills;

import fin.springai.runtime.spi.skills.ToolProvider;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SkillsAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(SkillsAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("fin.springai.runtime.skills.SkillsAutoConfiguration");
    }

    @Test
    void contextLoadsAndProvidesDefaultBean() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).hasSingleBean(ToolProvider.class);
        });
    }

    @Test
    void defaultSentinelThrowsWithCounter() {
        runner.run(ctx -> {
            ToolProvider provider = ctx.getBean(ToolProvider.class);
            MeterRegistry registry = ctx.getBean(MeterRegistry.class);
            assertThatThrownBy(() -> provider.listTools("t1"))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("ToolProvider");
            assertThat(registry.counter(
                    "springai_fin_skills_default_impl_not_configured_total",
                    "spi", "ToolProvider", "method", "listTools").count())
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
            assertThat(ctx).hasSingleBean(SkillsProperties.class);
            SkillsProperties props = ctx.getBean(SkillsProperties.class);
            assertThat(props.enabled()).isTrue();
        });
    }

    @Test
    void starterBeansAbsentWhenDisabled() {
        runner.withPropertyValues("springai.fin.skills.enabled=false")
            .run(ctx -> {
                assertThat(ctx).doesNotHaveBean(ToolProvider.class);
            });
    }
}
