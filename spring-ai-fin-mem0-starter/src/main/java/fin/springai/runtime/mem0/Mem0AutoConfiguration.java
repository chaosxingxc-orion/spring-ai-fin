package fin.springai.runtime.mem0;

import fin.springai.runtime.spi.memory.LongTermMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
@ConditionalOnClass(LongTermMemoryRepository.class)
@ConditionalOnProperty(prefix = "springai.fin.mem0", name = "enabled", havingValue = "true", matchIfMissing = false)
@EnableConfigurationProperties(Mem0Properties.class)
public class Mem0AutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiFinMem0FallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(LongTermMemoryRepository.class)
    LongTermMemoryRepository mem0LongTermMemoryRepository(MeterRegistry registry, Mem0Properties properties) {
        return new NotImplementedYetMem0LongTermMemoryRepository(registry, properties);
    }
}
