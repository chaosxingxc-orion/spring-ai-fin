package ascend.springai.runtime.langchain4j;

import ascend.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
@ConditionalOnClass(LayoutParser.class)
public class LangChain4jAutoConfiguration {

    private static final Logger LOG = LoggerFactory.getLogger(LangChain4jAutoConfiguration.class);

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiAscendLangChain4jFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    LangChain4jProfileMarker langChain4jProfileMarker(MeterRegistry registry) {
        return new LangChain4jProfileMarker(registry);
    }

    static class LangChain4jProfileMarker implements InitializingBean {
        private final MeterRegistry registry;
        LangChain4jProfileMarker(MeterRegistry registry) { this.registry = registry; }

        @Override
        public void afterPropertiesSet() {
            registry.counter("springai_ascend_langchain4j_profile_loaded_total").increment();
            LOG.info("spring-ai-ascend-langchain4j-profile activated at L0; " +
                     "alternate ChatClient route wiring pending W2.");
        }
    }
}
