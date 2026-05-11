package ascend.springai.platform;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * spring-ai-ascend platform entry point.
 *
 * <p>W0 minimal: brings up Spring Boot, exposes /v1/health, runs Flyway against
 * Postgres. No auth, no LLM, no tenancy yet -- those are W1/W2.</p>
 */
@SpringBootApplication
public class PlatformApplication {

    public static void main(String[] args) {
        SpringApplication.run(PlatformApplication.class, args);
    }
}
