package ascend.springai.runtime.memory;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.ascend.memory")
public record MemoryProperties(
    boolean enabled
) {
    public MemoryProperties() { this(true); }
}
