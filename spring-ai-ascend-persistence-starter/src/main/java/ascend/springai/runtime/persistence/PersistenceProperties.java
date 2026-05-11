package ascend.springai.runtime.persistence;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.fin.persistence")
public record PersistenceProperties(
    boolean enabled
) {
    public PersistenceProperties() { this(true); }
}
