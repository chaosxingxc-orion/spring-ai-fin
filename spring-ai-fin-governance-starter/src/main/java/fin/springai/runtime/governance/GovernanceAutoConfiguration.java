package fin.springai.runtime.governance;

import fin.springai.runtime.spi.governance.PolicyEvaluator;
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
@ConditionalOnClass(PolicyEvaluator.class)
@EnableConfigurationProperties(GovernanceProperties.class)
public class GovernanceAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiFinGovernanceFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(PolicyEvaluator.class)
    @ConditionalOnProperty(prefix = "springai.fin.governance", name = "enabled", havingValue = "true", matchIfMissing = true)
    PolicyEvaluator policyEvaluator(MeterRegistry registry, Environment env) {
        String posture = env.getProperty("app.posture", "dev");
        if (!"dev".equalsIgnoreCase(posture)) {
            throw new BeanCreationException(
                    "L0 sentinel PolicyEvaluator is only allowed in posture=dev. " +
                    "Provide a real @Bean PolicyEvaluator or set app.posture=dev. " +
                    "Current posture: " + posture);
        }
        return new NotConfiguredPolicyEvaluator(registry);
    }
}
