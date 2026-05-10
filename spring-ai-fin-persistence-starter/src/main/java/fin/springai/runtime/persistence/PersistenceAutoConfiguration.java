package fin.springai.runtime.persistence;

import fin.springai.runtime.spi.persistence.ArtifactRepository;
import fin.springai.runtime.spi.persistence.IdempotencyRepository;
import fin.springai.runtime.spi.persistence.RunRepository;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.beans.factory.BeanCreationException;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

@AutoConfiguration
@ConditionalOnClass(RunRepository.class)
public class PersistenceAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiFinPersistenceFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(RunRepository.class)
    RunRepository runRepository(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "RunRepository");
        return new NotConfiguredRunRepository(registry);
    }

    @Bean
    @ConditionalOnMissingBean(IdempotencyRepository.class)
    IdempotencyRepository idempotencyRepository(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "IdempotencyRepository");
        return new NotConfiguredIdempotencyRepository(registry);
    }

    @Bean
    @ConditionalOnMissingBean(ArtifactRepository.class)
    ArtifactRepository artifactRepository(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "ArtifactRepository");
        return new NotConfiguredArtifactRepository(registry);
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
