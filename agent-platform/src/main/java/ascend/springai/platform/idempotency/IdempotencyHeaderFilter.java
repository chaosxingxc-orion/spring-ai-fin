package ascend.springai.platform.idempotency;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

public class IdempotencyHeaderFilter extends OncePerRequestFilter {

    private static final Logger LOG = LoggerFactory.getLogger(IdempotencyHeaderFilter.class);

    private final String posture;
    private final Counter missingCounter;
    private final Counter invalidCounter;

    public IdempotencyHeaderFilter(MeterRegistry registry, String posture) {
        this.posture = posture;
        this.missingCounter = Counter.builder("springai_ascend_idempotency_header_missing_total")
                .tag("posture", posture).register(registry);
        this.invalidCounter = Counter.builder("springai_ascend_idempotency_header_invalid_total")
                .tag("posture", posture).register(registry);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/actuator") || "/v1/health".equals(path);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {
        String header = request.getHeader(IdempotencyConstants.HEADER_NAME);
        if (header == null || header.isBlank()) {
            missingCounter.increment();
            if ("dev".equalsIgnoreCase(posture)) {
                LOG.warn("Idempotency-Key header missing; continuing in posture=dev");
                chain.doFilter(request, response);
            } else {
                response.sendError(400, "Idempotency-Key header is required");
            }
            return;
        }
        try {
            IdempotencyKey.parse(header);
        } catch (IllegalArgumentException e) {
            invalidCounter.increment();
            LOG.warn("Idempotency-Key header failed UUID validation; request rejected; posture={}", posture);
            response.sendError(400, "Idempotency-Key must be a valid UUID");
            return;
        }
        chain.doFilter(request, response);
    }
}
