package ascend.springai.runtime.orchestration.spi;

/**
 * Result of a {@link RuntimeMiddleware} hook invocation. The dispatcher
 * aggregates outcomes across registered middlewares and decides the next
 * step.
 *
 * <p>Pure Java — no Spring imports per architecture §4.7
 * (orchestration.spi imports only java.*).
 *
 * <p>Authority: ADR-0073.
 */
public sealed interface HookOutcome
        permits HookOutcome.Proceed, HookOutcome.ShortCircuit, HookOutcome.Fail {

    /** The middleware permits dispatch to continue unchanged. */
    record Proceed() implements HookOutcome {
        private static final Proceed INSTANCE = new Proceed();
        public static Proceed instance() { return INSTANCE; }
    }

    /**
     * The middleware satisfies the request without running the engine — used by
     * cache layers, dry-run middlewares, or replay middlewares. The dispatcher
     * returns {@code result} as the run output.
     */
    record ShortCircuit(Object result) implements HookOutcome {}

    /**
     * The middleware rejects dispatch. The Run transitions to FAILED with
     * {@code reason} as the rejection cause.
     */
    record Fail(String reason) implements HookOutcome {}

    static HookOutcome proceed() {
        return Proceed.instance();
    }
}
