package fin.springai.platform.idempotency;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static io.restassured.RestAssured.given;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class IdempotencyHeaderFilterIT {

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

    @Test
    void healthEndpoint_exemptFromIdempotencyFilter_withoutHeader() {
        given()
                .port(port)
            .when()
                .get("/v1/health")
            .then()
                .statusCode(200);
    }

    @Test
    void healthEndpoint_exemptFromIdempotencyFilter_withHeader() {
        given()
                .port(port)
                .header(IdempotencyConstants.HEADER_NAME, "123e4567-e89b-12d3-a456-426614174000")
            .when()
                .get("/v1/health")
            .then()
                .statusCode(200);
    }
}
