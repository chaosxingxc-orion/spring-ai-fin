package fin.springai.runtime.memory;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.fin.memory")
public record MemoryProperties(
    boolean enabled
) {
    public MemoryProperties() { this(true); }
}
