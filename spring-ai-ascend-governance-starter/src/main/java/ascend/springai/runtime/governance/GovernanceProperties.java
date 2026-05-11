package ascend.springai.runtime.governance;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.ascend.governance")
public record GovernanceProperties(
    boolean enabled
) {
    public GovernanceProperties() { this(true); }
}
