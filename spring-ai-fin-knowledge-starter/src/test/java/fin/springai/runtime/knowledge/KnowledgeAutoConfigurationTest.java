package fin.springai.runtime.knowledge;

import fin.springai.runtime.spi.knowledge.DocumentSourceConnector;
import fin.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class KnowledgeAutoConfigurationTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(KnowledgeAutoConfiguration.class));

    @Test
    void autoConfigurationClassIsLoadable() throws Exception {
        Class.forName("fin.springai.runtime.knowledge.KnowledgeAutoConfiguration");
    }

    @Test
    void contextLoadsAndProvidesDefaultBeans() {
        runner.run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).hasSingleBean(LayoutParser.class);
            assertThat(ctx).hasSingleBean(DocumentSourceConnector.class);
        });
    }

    @Test
    void layoutParserSentinelThrowsWithCounter() {
        runner.run(ctx -> {
            LayoutParser parser = ctx.getBean(LayoutParser.class);
            MeterRegistry registry = ctx.getBean(MeterRegistry.class);
            assertThatThrownBy(() -> parser.parse(null, LayoutParser.ParseOptions.defaults()))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("LayoutParser");
            assertThat(registry.counter(
                    "springai_fin_knowledge_layout_parser_not_configured_total",
                    "spi", "LayoutParser", "method", "parse").count())
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
