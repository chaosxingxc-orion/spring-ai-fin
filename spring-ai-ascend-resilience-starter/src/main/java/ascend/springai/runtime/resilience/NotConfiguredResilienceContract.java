package ascend.springai.runtime.resilience;

import ascend.springai.runtime.spi.resilience.ResilienceContract;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * L0 sentinel: increments a counter + logs WARN + throws on every call.
 * Replaced by a real default impl wiring @CircuitBreaker annotations in W2.
 */
class NotConfiguredResilienceContract implements ResilienceContract {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredResilienceContract.class);
    private static final String METRIC = "springai_ascend_resilience_default_impl_not_configured_total";
    private static final String MSG =
            "L0: ResilienceContract has no default impl yet. " +
            "Provide a @Bean ResilienceContract or wait for the W2 @CircuitBreaker default impl.";

    private final MeterRegistry registry;

    NotConfiguredResilienceContract(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public ResiliencePolicy resolve(String operationId) {
        registry.counter(METRIC, "spi", "ResilienceContract", "method", "resolve").increment();
        LOG.warn("L0: ResilienceContract.resolve called with no impl; operationId={}", operationId);
        throw new IllegalStateException(MSG);
    }
}
