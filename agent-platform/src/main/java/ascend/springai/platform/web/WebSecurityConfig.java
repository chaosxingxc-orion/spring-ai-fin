package ascend.springai.platform.web;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * W0 SecurityFilterChain: permit /v1/health, actuator endpoints, and the
 * springdoc OpenAPI spec path only. Everything else is denied (W0 has no
 * auth -- intentional; W1 adds it).
 *
 * <p>/v3/api-docs and /v3/api-docs/** are permitted so that the OpenAPI
 * contract snapshot integration test (OpenApiContractIT) can fetch the live
 * spec without a security denial. The Swagger UI HTML (/swagger-ui/**) is
 * NOT permitted in W0 -- operator probe and contract tests only need the
 * JSON spec. W1 adds posture-aware UI exposure: dev-public,
 * research/prod localhost-only.</p>
 *
 * <p>W1 replaces this with the real oauth2-resource-server filter per
 * agent-platform/auth/ARCHITECTURE.md.</p>
 */
@Configuration
public class WebSecurityConfig {

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(
                                "/v1/health",
                                "/actuator/**",
                                "/v3/api-docs",
                                "/v3/api-docs/**"
                        ).permitAll()
                        .anyRequest().denyAll()
                )
                .build();
    }
}
