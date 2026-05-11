package ascend.springai.platform.tenant;

import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

public class TenantContextFilter extends OncePerRequestFilter {

    private static final Logger LOG = LoggerFactory.getLogger(TenantContextFilter.class);

    private final MeterRegistry registry;
    private final String posture;

    public TenantContextFilter(MeterRegistry registry, String posture) {
        this.registry = registry;
        this.posture = posture;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/actuator") || "/v1/health".equals(path);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {
        String header = request.getHeader(TenantConstants.HEADER_NAME);
        if (header == null || header.isBlank()) {
            registry.counter("springai_fin_tenant_header_missing_total", "posture", posture).increment();
            if ("dev".equalsIgnoreCase(posture)) {
                LOG.warn("X-Tenant-Id header missing; using dev default tenant in posture=dev");
                TenantContextHolder.set(
                        new TenantContext(UUID.fromString(TenantConstants.DEV_DEFAULT_TENANT_ID)));
                try {
                    chain.doFilter(request, response);
                } finally {
                    TenantContextHolder.clear();
                }
            } else {
                response.sendError(400, "X-Tenant-Id header is required");
            }
            return;
        }
        UUID uuid;
        try {
            uuid = UUID.fromString(header.strip());
        } catch (IllegalArgumentException e) {
            registry.counter("springai_fin_tenant_header_invalid_total", "posture", posture).increment();
            response.sendError(400, "X-Tenant-Id must be a valid UUID");
            return;
        }
        TenantContextHolder.set(new TenantContext(uuid));
        try {
            chain.doFilter(request, response);
        } finally {
            TenantContextHolder.clear();
        }
    }
}
