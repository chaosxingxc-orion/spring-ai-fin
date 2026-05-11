package ascend.springai.runtime.resilience;

import ascend.springai.runtime.spi.resilience.ResilienceContract;
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
@ConditionalOnClass(ResilienceContract.class)
@EnableConfigurationProperties(ResilienceProperties.class)
public class ResilienceAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiAscendResilienceFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(ResilienceContract.class)
    @ConditionalOnProperty(prefix = "springai.ascend.resilience", name = "enabled", havingValue = "true", matchIfMissing = true)
    ResilienceContract resilienceContract(MeterRegistry registry, Environment env) {
        String posture = env.getProperty("app.posture", "dev");
        if (!"dev".equalsIgnoreCase(posture)) {
            throw new BeanCreationException(
                    "L0 sentinel ResilienceContract is only allowed in posture=dev. " +
                    "Provide a real @Bean ResilienceContract or set app.posture=dev. " +
                    "Current posture: " + posture);
        }
        return new NotConfiguredResilienceContract(registry);
    }
}
