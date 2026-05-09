package fin.springai.platform.web;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * W0 SecurityFilterChain: permit /v1/health and actuator endpoints; everything
 * else requires authentication (which W0 doesn't yet provide -- intentional).
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
                        .requestMatchers("/v1/health", "/actuator/**", "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                        .anyRequest().denyAll()
                )
                .build();
    }
}
