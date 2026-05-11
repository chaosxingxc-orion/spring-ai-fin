package ascend.springai.runtime.spi.resilience;

/**
 * SPI: maps an operation identifier to a named resilience policy.
 *
 * The returned policy carries names only; the caller registers the
 * corresponding @CircuitBreaker/@Retry annotations in W2 caller code.
 * Rule 11: operationId is process-internal (not stored).
 */
public interface ResilienceContract {

    /**
     * Resolve policy names for the given operation.
     * Returns a policy with non-null names; never null.
     */
    ResiliencePolicy resolve(String operationId);

    /** scope: process-internal -- config DTO, not persisted or transmitted. */
    record ResiliencePolicy(String circuitBreakerName, String retryName, String timeLimiterName) {}
}
