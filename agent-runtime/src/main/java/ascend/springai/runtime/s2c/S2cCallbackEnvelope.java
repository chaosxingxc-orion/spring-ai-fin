package ascend.springai.runtime.s2c;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * Server-to-Client (S2C) capability invocation request envelope.
 *
 * <p>Schema authority: {@code docs/contracts/s2c-callback.v1.yaml#request}.
 * The Phase 3a cross-rule audit matrix (see
 * {@code docs/reviews/2026-05-16-engine-contract-structural-response.en.md} §5.2)
 * defines six mandatory fields that MUST appear on every S2C envelope at every
 * layer (envelope class, transport SPI, response validator, integration test,
 * audit log). The record below validates the six on construction.
 *
 * <p>Authority: ADR-0074; CLAUDE.md Rule 46 (S2C Callback Envelope + Lifecycle Bound).
 */
public record S2cCallbackEnvelope(
        UUID callbackId,            // primary correlation key
        UUID serverRunId,           // suspending Run id
        String capabilityRef,       // declared client capability id
        Object requestPayload,      // opaque, validated by capability-specific schema (W3)
        String traceId,             // W3C 32-char; MUST equal suspending Run.traceId
        UUID idempotencyKey,        // client may retry; runtime dedupes within window
        Instant deadline,           // absolute deadline; null means "use skill-capacity timeout_ms"
        Map<String, Object> requestAttributes  // optional capability-specific extras
) {
    public S2cCallbackEnvelope {
        Objects.requireNonNull(callbackId, "callbackId is required");
        Objects.requireNonNull(serverRunId, "serverRunId is required");
        Objects.requireNonNull(capabilityRef, "capabilityRef is required");
        if (capabilityRef.isBlank()) {
            throw new IllegalArgumentException("capabilityRef must not be blank");
        }
        Objects.requireNonNull(requestPayload, "requestPayload is required");
        Objects.requireNonNull(traceId, "traceId is required");
        if (traceId.length() != 32) {
            throw new IllegalArgumentException("traceId must be exactly 32 lowercase hex chars (W3C)");
        }
        Objects.requireNonNull(idempotencyKey, "idempotencyKey is required");
        // deadline + requestAttributes are optional
        requestAttributes = requestAttributes == null ? Map.of() : Map.copyOf(requestAttributes);
    }
}
