package ascend.springai.runtime.docling;

import ascend.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.beans.factory.BeanCreationException;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

@AutoConfiguration
@ConditionalOnClass(LayoutParser.class)
@ConditionalOnProperty(prefix = "springai.ascend.docling", name = "enabled", havingValue = "true", matchIfMissing = false)
@EnableConfigurationProperties(DoclingProperties.class)
public class DoclingAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiAscendDoclingFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(LayoutParser.class)
    LayoutParser doclingLayoutParser(MeterRegistry registry, DoclingProperties properties, Environment env) {
        String posture = env.getProperty("app.posture", "dev");
        if (!"dev".equalsIgnoreCase(posture)) {
            throw new BeanCreationException(
                    "L0 adapter NotImplementedYetDoclingLayoutParser is only allowed in posture=dev. " +
                    "Provide a real @Bean LayoutParser or set app.posture=dev. " +
                    "Current posture: " + posture);
        }
        return new NotImplementedYetDoclingLayoutParser(registry, properties);
    }
}
