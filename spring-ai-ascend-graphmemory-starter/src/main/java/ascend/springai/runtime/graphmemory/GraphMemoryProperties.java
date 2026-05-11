package ascend.springai.runtime.graphmemory;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.ascend.graphmemory")
public class GraphMemoryProperties {

    private boolean enabled = false;
    private String baseUrl = "http://localhost:8001";
    private String apiKey = "";

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
}
