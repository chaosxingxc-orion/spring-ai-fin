package fin.springai.platform.tenant;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class TenantFilterAutoConfiguration {

    @Bean
    TenantContextFilter tenantContextFilter(MeterRegistry registry,
            @Value("${app.posture:dev}") String posture) {
        return new TenantContextFilter(registry, posture);
    }

    @Bean
    FilterRegistrationBean<TenantContextFilter> tenantContextFilterRegistration(TenantContextFilter filter) {
        FilterRegistrationBean<TenantContextFilter> reg = new FilterRegistrationBean<>(filter);
        reg.setOrder(20);
        return reg;
    }
}
