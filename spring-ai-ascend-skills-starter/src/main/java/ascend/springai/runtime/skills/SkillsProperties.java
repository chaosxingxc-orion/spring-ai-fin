package ascend.springai.runtime.skills;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.ascend.skills")
public record SkillsProperties(
    boolean enabled
) {
    public SkillsProperties() { this(true); }
}
