package fin.springai.runtime.memory;

import fin.springai.runtime.spi.memory.GraphMemoryRepository;
import fin.springai.runtime.spi.memory.LongTermMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.beans.factory.BeanCreationException;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

@AutoConfiguration
@ConditionalOnClass(LongTermMemoryRepository.class)
public class MemoryAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiFinMemoryFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(LongTermMemoryRepository.class)
    LongTermMemoryRepository longTermMemoryRepository(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "LongTermMemoryRepository");
        return new NotConfiguredLongTermMemoryRepository(registry);
    }

    @Bean
    @ConditionalOnMissingBean(GraphMemoryRepository.class)
    GraphMemoryRepository graphMemoryRepository(MeterRegistry registry, Environment env) {
        rejectIfNonDevPosture(env, "GraphMemoryRepository");
        return new NotConfiguredGraphMemoryRepository(registry);
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
