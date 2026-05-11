package ascend.springai.runtime.graphmemory;

import ascend.springai.runtime.spi.memory.GraphMemoryRepository;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
@ConditionalOnClass(GraphMemoryRepository.class)
@ConditionalOnProperty(prefix = "springai.ascend.graphmemory", name = "enabled", havingValue = "true", matchIfMissing = false)
@EnableConfigurationProperties(GraphMemoryProperties.class)
public class GraphMemoryAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(MeterRegistry.class)
    SimpleMeterRegistry springAiAscendGraphMemoryFallbackMeterRegistry() {
        return new SimpleMeterRegistry();
    }

    @Bean
    @ConditionalOnMissingBean(GraphMemoryRepository.class)
    GraphMemoryRepository graphitiGraphMemoryRepository(MeterRegistry registry, GraphMemoryProperties properties) {
        return new NotImplementedYetGraphMemoryRepository(registry, properties);
    }
}
