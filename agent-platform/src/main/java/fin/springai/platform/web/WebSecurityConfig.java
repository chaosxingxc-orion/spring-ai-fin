package fin.springai.platform.web;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * W0 SecurityFilterChain: permit /v1/health and actuator endpoints only.
 * Everything else is denied (W0 has no auth -- intentional; W1 adds it).
 *
 * <p>OpenAPI / Swagger-UI are NOT exposed in W0 across any posture (cycle-14 C2).
 * W1 adds posture-aware exposure: dev-public, research/prod localhost-only.</p>
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
                        .requestMatchers("/v1/health", "/actuator/**").permitAll()
                        .anyRequest().denyAll()
                )
                .build();
    }
}
