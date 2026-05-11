package ascend.springai.runtime.resilience;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.ascend.resilience")
public record ResilienceProperties(
    boolean enabled
) {
    public ResilienceProperties() { this(true); }
}
