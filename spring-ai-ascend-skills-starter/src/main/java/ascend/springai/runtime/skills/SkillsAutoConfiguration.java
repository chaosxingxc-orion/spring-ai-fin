package ascend.springai.runtime.skills;

import ascend.springai.runtime.spi.skills.ToolProvider;
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
@ConditionalOnClass(ToolProvider.class)
@EnableConfigurationProperties(SkillsProperties.class)
public class SkillsAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiAscendSkillsFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(ToolProvider.class)
    @ConditionalOnProperty(prefix = "springai.ascend.skills", name = "enabled", havingValue = "true", matchIfMissing = true)
    ToolProvider toolProvider(MeterRegistry registry, Environment env) {
        String posture = env.getProperty("app.posture", "dev");
        if (!"dev".equalsIgnoreCase(posture)) {
            throw new BeanCreationException(
                    "L0 sentinel ToolProvider is only allowed in posture=dev. " +
                    "Provide a real @Bean ToolProvider or set app.posture=dev. " +
                    "Current posture: " + posture);
        }
        return new NotConfiguredToolProvider(registry);
    }
}
