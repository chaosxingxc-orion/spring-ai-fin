package ascend.springai.runtime.langchain4j;

import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class LangChain4jAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(LangChain4jAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("ascend.springai.runtime.langchain4j.LangChain4jAutoConfiguration");
    }

    @Test
    void contextLoadsMarkerBeanAndIncrementsCounter() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).hasSingleBean(LangChain4jAutoConfiguration.LangChain4jProfileMarker.class);
            MeterRegistry registry = ctx.getBean(MeterRegistry.class);
            assertThat(registry.counter("springai_ascend_langchain4j_profile_loaded_total").count())
                    .isEqualTo(1.0);
        });
    }
}
