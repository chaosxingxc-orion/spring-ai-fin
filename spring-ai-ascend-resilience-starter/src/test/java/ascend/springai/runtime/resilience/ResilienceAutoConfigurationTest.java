package ascend.springai.runtime.resilience;

import ascend.springai.runtime.spi.resilience.ResilienceContract;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ResilienceAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(ResilienceAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("ascend.springai.runtime.resilience.ResilienceAutoConfiguration");
    }

    @Test
    void contextLoadsAndProvidesDefaultBean() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).hasSingleBean(ResilienceContract.class);
        });
    }

    @Test
    void defaultSentinelThrowsWithCounter() {
        runner.run(ctx -> {
            ResilienceContract contract = ctx.getBean(ResilienceContract.class);
            MeterRegistry registry = ctx.getBean(MeterRegistry.class);
            assertThatThrownBy(() -> contract.resolve("test-op"))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("ResilienceContract");
            assertThat(registry.counter(
                    "springai_fin_resilience_default_impl_not_configured_total",
                    "spi", "ResilienceContract", "method", "resolve").count())
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
}
