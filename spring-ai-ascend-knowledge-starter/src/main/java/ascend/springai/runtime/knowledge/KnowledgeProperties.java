package ascend.springai.runtime.knowledge;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.fin.knowledge")
public record KnowledgeProperties(
    boolean enabled
) {
    public KnowledgeProperties() { this(true); }
}
