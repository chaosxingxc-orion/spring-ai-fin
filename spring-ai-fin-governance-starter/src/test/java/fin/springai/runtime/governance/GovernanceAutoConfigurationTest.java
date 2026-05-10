package fin.springai.runtime.governance;

import fin.springai.runtime.spi.governance.PolicyEvaluator;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GovernanceAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(GovernanceAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("fin.springai.runtime.governance.GovernanceAutoConfiguration");
    }

    @Test
    void contextLoadsAndProvidesDefaultBean() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).hasSingleBean(PolicyEvaluator.class);
        });
    }

    @Test
    void defaultSentinelThrowsWithCounter() {
        runner.run(ctx -> {
            PolicyEvaluator evaluator = ctx.getBean(PolicyEvaluator.class);
            MeterRegistry registry = ctx.getBean(MeterRegistry.class);
            assertThatThrownBy(() -> evaluator.evaluate("t1", "policy-A", Map.of()))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("PolicyEvaluator");
            assertThat(registry.counter(
                    "springai_fin_governance_default_impl_not_configured_total",
                    "spi", "PolicyEvaluator", "method", "evaluate").count())
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
            assertThat(ctx).hasSingleBean(GovernanceProperties.class);
            GovernanceProperties props = ctx.getBean(GovernanceProperties.class);
            assertThat(props.enabled()).isTrue();
        });
    }

    @Test
    void starterBeansAbsentWhenDisabled() {
        runner.withPropertyValues("springai.fin.governance.enabled=false")
            .run(ctx -> {
                assertThat(ctx).doesNotHaveBean(PolicyEvaluator.class);
            });
    }
}
