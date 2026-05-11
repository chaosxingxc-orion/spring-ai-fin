package fin.springai.runtime.docling;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("springai.fin.docling")
public class DoclingProperties {

    private boolean enabled = false;
    private String baseUrl = "http://localhost:5001";

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
}
