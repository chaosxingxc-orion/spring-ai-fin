package ascend.springai.runtime.resilience;

import ascend.springai.runtime.spi.resilience.ResilienceContract;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.beans.factory.BeanCreationException;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

@AutoConfiguration
@ConditionalOnClass(ResilienceContract.class)
public class ResilienceAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiFinResilienceFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(ResilienceContract.class)
    ResilienceContract resilienceContract(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "ResilienceContract");
        return new NotConfiguredResilienceContract(registry);
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
