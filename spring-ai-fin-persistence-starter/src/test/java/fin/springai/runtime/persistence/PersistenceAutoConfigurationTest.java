package fin.springai.runtime.persistence;

import fin.springai.runtime.spi.persistence.ArtifactRepository;
import fin.springai.runtime.spi.persistence.IdempotencyRepository;
import fin.springai.runtime.spi.persistence.RunRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PersistenceAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(PersistenceAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("fin.springai.runtime.persistence.PersistenceAutoConfiguration");
    }

    @Test
    void contextLoadsAndProvidesDefaultBeans() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).hasSingleBean(RunRepository.class);
            assertThat(ctx).hasSingleBean(IdempotencyRepository.class);
            assertThat(ctx).hasSingleBean(ArtifactRepository.class);
        });
    }

    @Test
    void runRepositorySentinelThrowsWithCounter() {
        runner.run(ctx -> {
            RunRepository repo = ctx.getBean(RunRepository.class);
            MeterRegistry registry = ctx.getBean(MeterRegistry.class);
            assertThatThrownBy(() -> repo.findById("t1", "r1"))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("RunRepository");
            assertThat(registry.counter(
                    "springai_fin_persistence_default_impl_not_configured_total",
                    "spi", "RunRepository", "method", "findById").count())
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
