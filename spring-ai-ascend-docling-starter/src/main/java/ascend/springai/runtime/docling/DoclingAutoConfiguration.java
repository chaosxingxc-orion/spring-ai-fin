package ascend.springai.runtime.docling;

import ascend.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
@ConditionalOnClass(LayoutParser.class)
@ConditionalOnProperty(prefix = "springai.fin.docling", name = "enabled", havingValue = "true", matchIfMissing = false)
@EnableConfigurationProperties(DoclingProperties.class)
public class DoclingAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiFinDoclingFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(LayoutParser.class)
    LayoutParser doclingLayoutParser(MeterRegistry registry, DoclingProperties properties) {
        return new NotImplementedYetDoclingLayoutParser(registry, properties);
    }
}
