package ascend.springai.platform.web.runs;

import ascend.springai.runtime.runs.Run;
import ascend.springai.runtime.runs.RunMode;
import ascend.springai.runtime.runs.RunRepository;
import ascend.springai.runtime.runs.RunStatus;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.util.UUID;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Layer-3 contract test for the {@link RunController} (plan §6).
 * Drives every key row of the status-code matrix through the full filter chain
 * (Spring Security + JwtTenantClaimCrossCheck + TenantContextFilter +
 * IdempotencyHeaderFilter + RunController).
 *
 * <p>JWTs are injected via Spring Security Test's {@code jwt()} processor so no
 * real key material is required. {@code app.auth.dev-local-mode=true} +
 * {@code app.posture=dev} keeps PostureBootGuard silent and lets WebSecurityConfig
 * see a JwtDecoder.
 *
 * <p>Enforcer rows: E5, E6, E7, E10, E24.
 */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(properties = {
        "app.posture=dev",
        "app.auth.dev-local-mode=true",
        "app.auth.issuer=https://issuer.test",
        "app.auth.audience=spring-ai-ascend",
        "app.idempotency.allow-in-memory=false"
})
@AutoConfigureMockMvc
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

    private static final UUID TENANT = UUID.fromString("00000000-0000-0000-0000-00000000000a");
    private static final UUID OTHER_TENANT = UUID.fromString("00000000-0000-0000-0000-00000000000b");

    @Autowired
    MockMvc mvc;

    @Autowired
    RunRepository runs;

    @Autowired
    ObjectMapper mapper;

    @BeforeEach
    void clearState() {
        // InMemoryRunRegistry has no explicit clear; tests rely on fresh UUIDs.
    }

    @Test
    void create_returns_201_with_status_pending() throws Exception {
        String body = mapper.writeValueAsString(new CreateRunRequest("hello"));
        mvc.perform(post("/v1/runs")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.capabilityName").value("hello"));
    }

    @Test
    void create_with_empty_capability_returns_422_invalid_run_spec() throws Exception {
        String body = mapper.writeValueAsString(new CreateRunRequest(""));
        mvc.perform(post("/v1/runs")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("invalid_run_spec"));
    }

    @Test
    void create_with_malformed_body_returns_400_invalid_request() throws Exception {
        mvc.perform(post("/v1/runs")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{not-json"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("invalid_request"));
    }

    @Test
    void create_without_jwt_returns_401() throws Exception {
        String body = mapper.writeValueAsString(new CreateRunRequest("x"));
        mvc.perform(post("/v1/runs")
                        .header("X-Tenant-Id", TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void tenant_mismatch_between_jwt_and_header_returns_403() throws Exception {
        String body = mapper.writeValueAsString(new CreateRunRequest("x"));
        mvc.perform(post("/v1/runs")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", OTHER_TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("tenant_mismatch"));
    }

    @Test
    void get_unknown_run_returns_404_not_found() throws Exception {
        mvc.perform(get("/v1/runs/" + UUID.randomUUID())
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("not_found"));
    }

    @Test
    void get_cross_tenant_run_returns_404() throws Exception {
        Run otherTenantRun = seedRun(OTHER_TENANT, RunStatus.PENDING);
        mvc.perform(get("/v1/runs/" + otherTenantRun.runId())
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString()))
                .andExpect(status().isNotFound());
    }

    @Test
    void get_invalid_runId_returns_400() throws Exception {
        mvc.perform(get("/v1/runs/not-a-uuid")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("invalid_request"));
    }

    @Test
    void cancel_pending_run_transitions_to_cancelled() throws Exception {
        Run run = seedRun(TENANT, RunStatus.PENDING);
        mvc.perform(post("/v1/runs/" + run.runId() + "/cancel")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void cancel_already_cancelled_run_is_idempotent_200() throws Exception {
        Run run = seedRun(TENANT, RunStatus.CANCELLED);
        mvc.perform(post("/v1/runs/" + run.runId() + "/cancel")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void cancel_terminal_run_returns_409_illegal_state_transition() throws Exception {
        Run run = seedRun(TENANT, RunStatus.SUCCEEDED);
        mvc.perform(post("/v1/runs/" + run.runId() + "/cancel")
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("illegal_state_transition"));
    }

    @Test
    void delete_v1_runs_id_is_not_a_route() throws Exception {
        // Cancel MUST be POST /v1/runs/{id}/cancel, never DELETE /v1/runs/{id}.
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .delete("/v1/runs/" + UUID.randomUUID())
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString()))
                .andExpect(status().is(org.hamcrest.Matchers.anyOf(
                        org.hamcrest.Matchers.is(404),
                        org.hamcrest.Matchers.is(405))));
    }

    @Test
    void response_envelope_is_pure_error_no_top_level_drift() throws Exception {
        mvc.perform(get("/v1/runs/" + UUID.randomUUID())
                        .with(jwt().jwt(j -> j.claim("tenant_id", TENANT.toString())))
                        .header("X-Tenant-Id", TENANT.toString()))
                .andExpect(status().isNotFound())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.error").exists())
                .andExpect(jsonPath("$.error.code").exists())
                .andExpect(jsonPath("$.error.message").exists())
                .andExpect(jsonPath("$.error.details").isArray());
    }

    private Run seedRun(UUID tenantId, RunStatus status) {
        Instant now = Instant.now();
        Run run = new Run(
                UUID.randomUUID(),
                tenantId.toString(),
                "seed-capability",
                status,
                RunMode.GRAPH,
                now, now, null, null, null, null, null);
        return runs.save(run);
    }
}
