package ascend.springai.runtime.resilience;

/**
 * Fin-services routing layer: maps an operation identifier to a named resilience policy triple.
 * Call sites apply Resilience4j annotations (@CircuitBreaker, @Retry, @TimeLimiter) using
 * the resolved policy names. Spring @ConfigurationProperties wiring is deferred to W2.
 */
public interface ResilienceContract {

    ResiliencePolicy DEFAULT_POLICY = new ResiliencePolicy("default-cb", "default-retry", "default-tl");

    /**
     * Resolve the resilience policy for the given operation.
     * Dev posture: returns DEFAULT_POLICY for unknown operations.
     * Research/prod posture: throws IllegalArgumentException for unknown operations.
     */
    ResiliencePolicy resolve(String operationId);
}
