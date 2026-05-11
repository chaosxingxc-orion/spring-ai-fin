package ascend.springai.runtime.mem0;

import ascend.springai.runtime.spi.memory.LongTermMemoryRepository;
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
@ConditionalOnClass(LongTermMemoryRepository.class)
@ConditionalOnProperty(prefix = "springai.ascend.mem0", name = "enabled", havingValue = "true", matchIfMissing = false)
@EnableConfigurationProperties(Mem0Properties.class)
public class Mem0AutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiAscendMem0FallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(LongTermMemoryRepository.class)
    LongTermMemoryRepository mem0LongTermMemoryRepository(MeterRegistry registry, Mem0Properties properties, Environment env) {
        String posture = env.getProperty("app.posture", "dev");
        if (!"dev".equalsIgnoreCase(posture)) {
            throw new BeanCreationException(
                    "L0 adapter NotImplementedYetMem0LongTermMemoryRepository is only allowed in posture=dev. " +
                    "Provide a real @Bean LongTermMemoryRepository or set app.posture=dev. " +
                    "Current posture: " + posture);
        }
        return new NotImplementedYetMem0LongTermMemoryRepository(registry, properties);
    }
}