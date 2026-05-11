package ascend.springai.platform.web;

import ascend.springai.platform.persistence.HealthCheckRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

/**
 * /v1/health -- returns 200 with status + sha + db round-trip evidence.
 *
 * <p>Per W0 acceptance gate: this endpoint must reach Postgres on every call,
 * proving the JDBC + Flyway-applied schema work end-to-end. The body shape is
 * stable for the OpenAPI snapshot test.</p>
 */
@RestController
@RequestMapping("/v1")
public class HealthController {

    private final HealthCheckRepository repo;
    private final String sha;

    public HealthController(HealthCheckRepository repo) {
        this.repo = repo;
        this.sha = System.getenv().getOrDefault("APP_SHA", "dev");
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        long ping = repo.pingDb();
        return Map.of(
                "status", "UP",
                "sha", sha,
                "db_ping_ns", ping,
                "ts", Instant.now().toString()
        );
    }
}
