package ascend.springai.platform.posture;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;

/**
 * Proves the APP_POSTURE -> app.posture bridge defined in application.yml:66.
 * The bridge: app.posture: ${APP_POSTURE:dev}
 * Sets APP_POSTURE=research as a Spring property (simulating the OS env var)
 * and asserts that app.posture resolves to research in both the raw Environment
 * and in posture-sensitive filter behavior.
 */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"APP_POSTURE=research"})
class PostureBindingIT {

    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("springAiAscend")
            .withUsername("springAiAscend")
            .withPassword("springAiAscend");

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private Environment env;

    @org.springframework.boot.test.web.server.LocalServerPort
    private int port;

    @Test
    void appPosture_resolves_from_APP_POSTURE_via_yaml_placeholder() {
        // The application.yml bridge: app.posture: ${APP_POSTURE:dev}
        // With APP_POSTURE=research in test properties, app.posture must be research.
        assertThat(env.getProperty("app.posture")).isEqualTo("research");
    }

    @Test
    void researchPosture_tenantFilter_rejects_missing_header() {
        // Behavioral proof: posture-sensitive filter received research from the bridge.
        given()
                .port(port)
            .when()
                .get("/v1/runs")
            .then()
                .statusCode(400);
    }
}
