package ascend.springai.runtime.s2c.spi;

import ascend.springai.runtime.s2c.S2cCallbackEnvelope;

import java.util.Objects;

/**
 * Unchecked signal an executor throws to request a Server-to-Client (S2C)
 * capability callback. The orchestrator catches it, persists checkpoint,
 * dispatches via {@link S2cCallbackTransport}, validates the response, and
 * resumes the parent with the response payload.
 *
 * <p>This is a separate hierarchy from
 * {@link ascend.springai.runtime.orchestration.spi.SuspendSignal} because the
 * latter must stay in {@code orchestration.spi} and import only {@code java.*}
 * (SPI purity rule E3); the S2C envelope lives in {@code runtime.s2c}. As a
 * {@link RuntimeException} this signal does not pollute existing
 * {@code throws SuspendSignal} signatures on {@code NodeFunction} /
 * {@code Reasoner} -- lambdas may throw it freely.
 *
 * <p>The orchestrator catches {@code S2cCallbackSignal} BEFORE its
 * {@code catch (RuntimeException)} on_error handler so an S2C suspension is
 * never mistaken for a generic error.
 *
 * <p>Authority: ADR-0074; CLAUDE.md Rule 46 (S2C Callback Envelope + Lifecycle Bound).
 */
public final class S2cCallbackSignal extends RuntimeException {

    private static final long serialVersionUID = 1L;

    private final String parentNodeKey;
    private final S2cCallbackEnvelope envelope;

    public S2cCallbackSignal(String parentNodeKey, S2cCallbackEnvelope envelope) {
        super("S2C client callback at node: " + parentNodeKey);
        this.parentNodeKey = Objects.requireNonNull(parentNodeKey, "parentNodeKey is required");
        this.envelope = Objects.requireNonNull(envelope, "envelope is required");
    }

    public String parentNodeKey() {
        return parentNodeKey;
    }

    public S2cCallbackEnvelope envelope() {
        return envelope;
    }
}
