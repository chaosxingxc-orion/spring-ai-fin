package ascend.springai.runtime.knowledge;

import ascend.springai.runtime.spi.knowledge.DocumentSourceConnector;
import ascend.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.util.List;
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
@EnableConfigurationProperties(KnowledgeProperties.class)
public class KnowledgeAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiFinKnowledgeFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(LayoutParser.class)
    @ConditionalOnProperty(prefix = "springai.fin.knowledge", name = "enabled", havingValue = "true", matchIfMissing = true)
    LayoutParser layoutParser(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "LayoutParser");
        return new NotConfiguredLayoutParser(registry);
    }

    @Bean
    @ConditionalOnMissingBean(DocumentSourceConnector.class)
    @ConditionalOnProperty(prefix = "springai.fin.knowledge", name = "enabled", havingValue = "true", matchIfMissing = true)
    DocumentSourceConnector documentSourceConnector(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "DocumentSourceConnector");
        return new NotConfiguredDocumentSourceConnector(registry);
    }

    @Bean
    @ConditionalOnProperty(prefix = "springai.fin.knowledge", name = "enabled", havingValue = "true", matchIfMissing = true)
    DocumentSourceConnectorRegistry documentSourceConnectorRegistry(List<DocumentSourceConnector> connectors) {
        return new DocumentSourceConnectorRegistry(connectors);
    }

    private static void rejectIfNonDevPosture(Environment env, String beanName) {
        String posture = env.getProperty("app.posture", "dev");
        if (!"dev".equalsIgnoreCase(posture)) {
            throw new BeanCreationException(
                    "L0 sentinel " + beanName + " is only allowed in posture=dev. " +
                    "Provide a real @Bean " + beanName + " or set app.posture=dev. " +
                    "Current posture: " + posture);
        }
    }
}
