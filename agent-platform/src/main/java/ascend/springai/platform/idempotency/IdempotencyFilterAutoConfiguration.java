package ascend.springai.platform.idempotency;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class IdempotencyFilterAutoConfiguration {

    @Bean
    IdempotencyHeaderFilter idempotencyHeaderFilter(MeterRegistry registry,
            @Value("${app.posture:dev}") String posture) {
        return new IdempotencyHeaderFilter(registry, posture);
    }

    @Bean
    FilterRegistrationBean<IdempotencyHeaderFilter> idempotencyHeaderFilterRegistration(IdempotencyHeaderFilter filter) {
        FilterRegistrationBean<IdempotencyHeaderFilter> reg = new FilterRegistrationBean<>(filter);
        reg.setOrder(30);
        return reg;
    }
}
