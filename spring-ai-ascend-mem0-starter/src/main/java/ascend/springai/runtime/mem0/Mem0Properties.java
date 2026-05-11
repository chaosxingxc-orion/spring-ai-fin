package ascend.springai.runtime.mem0;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.ascend.mem0")
public class Mem0Properties {

    private boolean enabled = false;
    private String baseUrl = "http://localhost:8000";
    private String apiKey = "";

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
}
