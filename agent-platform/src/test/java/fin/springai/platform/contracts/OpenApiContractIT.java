package fin.springai.platform.contracts;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.io.InputStream;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * OpenAPI contract snapshot integration test for the W0 public surface.
 *
 * <p>Loads the pinned contract from the test classpath
 * (src/test/resources/contracts/openapi-v1-pinned.yaml) and diffs it against the
 * live springdoc spec at /v3/api-docs. Every path and operation declared in the
 * pinned file must be present in the live spec. Additive changes (new paths or
 * operations in live that are absent from the pinned file) are allowed. Only
 * breaking removals block the build.</p>
 *
 * <p>Starts a full Spring Boot application with real Postgres via Testcontainers,
 * matching the pattern established in HealthEndpointIT.</p>
 */
@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class OpenApiContractIT {

    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("springaifin")
            .withUsername("springaifin")
            .withPassword("springaifin");

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    private static final ObjectMapper YAML_MAPPER = new ObjectMapper(new YAMLFactory());

    @Test
    @SuppressWarnings("unchecked")
    void liveSpecContainsAllPinnedOperations() throws Exception {
        // Load pinned spec from test classpath.
        InputStream pinned = getClass().getResourceAsStream("/contracts/openapi-v1-pinned.yaml");
        assertThat(pinned).as("pinned spec on classpath at /contracts/openapi-v1-pinned.yaml").isNotNull();
        Map<String, Object> pinnedSpec = YAML_MAPPER.readValue(pinned, Map.class);

        // Fetch live spec from running app.
        String url = "http://localhost:" + port + "/v3/api-docs";
        Map<String, Object> liveSpec = restTemplate.getForObject(url, Map.class);
        assertThat(liveSpec).as("live OpenAPI spec from /v3/api-docs").isNotNull();

        // Compare: every operation in pinned must exist in live.
        OpenApiSnapshotComparator.ComparisonResult result =
                OpenApiSnapshotComparator.compare(pinnedSpec, liveSpec);
        assertThat(result.violations())
                .as("Breaking changes detected: pinned operations missing from live spec")
                .isEmpty();
    }

    @Test
    @SuppressWarnings("unchecked")
    void liveSpecInfoIsPresent() {
        String url = "http://localhost:" + port + "/v3/api-docs";
        Map<String, Object> spec = restTemplate.getForObject(url, Map.class);
        assertThat(spec).containsKey("info");
        Map<String, Object> info = (Map<String, Object>) spec.get("info");
        assertThat(info).containsKey("title");
    }
}
