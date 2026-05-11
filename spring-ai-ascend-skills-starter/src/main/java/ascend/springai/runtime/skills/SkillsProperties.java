package fin.springai.runtime.skills;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.fin.skills")
public record SkillsProperties(
    boolean enabled
) {
    public SkillsProperties() { this(true); }
}
