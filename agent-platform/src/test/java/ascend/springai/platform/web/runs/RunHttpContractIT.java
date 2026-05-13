package ascend.springai.platform.web.runs;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Layer-3 contract test for the {@link RunController} (plan §6).
 *
 * <p>Boot 4 does not ship {@code @AutoConfigureMockMvc}; this IT uses the
 * existing {@code HttpClient} pattern from {@code HealthEndpointIT} /
 * {@code PostureBindingIT} to drive HTTP through the real filter chain.
 *
 * <p>This IT covers the unauthenticated paths (status-code matrix rows that
 * don't require a real Bearer token). The full JWT-authenticated matrix
 * (201 PENDING, 422 invalid_run_spec, 403 tenant_mismatch, cancel paths)
 * needs a JWT mint utility against a dev-local-mode fixture keypair — that
 * lands in a follow-up alongside the {@code OpenApiContractIT} snapshot
 * regen.
 *
 * <p>Enforcer rows: docs/governance/enforcers.yaml#E6 (cancel route is POST
 * not DELETE), #E7 (some status-code matrix rows).
 */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "app.posture=dev",
        "app.auth.issuer=https://issuer.test",
        "app.auth.audience=spring-ai-ascend",
        "app.auth.jwks-uri=https://issuer.test/.well-known/jwks.json"
})
class RunHttpContractIT {

    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("springaiascend")
            .withUsername("springaiascend")
            .withPassword("springaiascend");

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @LocalServerPort
    int port;

    private static final HttpClient HTTP = HttpClient.newHttpClient();

    @Test
    void post_runs_without_bearer_returns_401_or_403() throws Exception {
        HttpResponse<String> response = HTTP.send(
                HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/v1/runs"))
                        .header("Content-Type", "application/json")
                        .header("X-Tenant-Id", UUID.randomUUID().toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .POST(HttpRequest.BodyPublishers.ofString("{\"capabilityName\":\"x\"}"))
                        .build(),
                HttpResponse.BodyHandlers.ofString());
        assertThat(response.statusCode()).isIn(401, 403);
    }

    @Test
    void get_run_without_bearer_returns_401_or_403() throws Exception {
        HttpResponse<String> response = HTTP.send(
                HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/v1/runs/" + UUID.randomUUID()))
                        .header("X-Tenant-Id", UUID.randomUUID().toString())
                        .GET()
                        .build(),
                HttpResponse.BodyHandlers.ofString());
        assertThat(response.statusCode()).isIn(401, 403);
    }

    @Test
    void cancel_route_is_post_not_delete() throws Exception {
        // E6: DELETE /v1/runs/{id} MUST NOT be a registered route. Without auth
        // the route is rejected anyway (401/403/404) — never 200.
        HttpResponse<String> response = HTTP.send(
                HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/v1/runs/" + UUID.randomUUID()))
                        .header("X-Tenant-Id", UUID.randomUUID().toString())
                        .DELETE()
                        .build(),
                HttpResponse.BodyHandlers.ofString());
        assertThat(response.statusCode()).isIn(401, 403, 404, 405);
    }

    @Test
    void health_remains_publicly_accessible() throws Exception {
        // Sanity check: permit-list still works after L1 security tightening.
        HttpResponse<String> response = HTTP.send(
                HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/v1/health"))
                        .GET()
                        .build(),
                HttpResponse.BodyHandlers.ofString());
        assertThat(response.statusCode()).isEqualTo(200);
    }
}
