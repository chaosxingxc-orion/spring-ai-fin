package ascend.springai.platform.web.runs;

import ascend.springai.platform.tenant.TenantContext;
import ascend.springai.platform.tenant.TenantContextHolder;
import ascend.springai.platform.web.ErrorEnvelope;
import ascend.springai.runtime.runs.Run;
import ascend.springai.runtime.runs.RunMode;
import ascend.springai.runtime.runs.RunRepository;
import ascend.springai.runtime.runs.RunStatus;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * W1 HTTP run API (plan §6).
 *
 * <ul>
 *   <li>{@code POST /v1/runs} — create a run; initial status {@code PENDING}.</li>
 *   <li>{@code GET /v1/runs/{runId}} — fetch run state within tenant scope; cross-tenant
 *       reads return 404 (architect guidance §9.4).</li>
 *   <li>{@code POST /v1/runs/{runId}/cancel} — idempotent cancellation. Cancelling an
 *       already-{@code CANCELLED} run returns 200 with current state; cancelling a
 *       {@code SUCCEEDED}/{@code FAILED}/{@code EXPIRED} run returns 409
 *       {@code illegal_state_transition}.</li>
 * </ul>
 *
 * <p>Auth, tenant cross-check, and idempotency dedup happen in upstream filters
 * (Spring Security + {@code JwtTenantClaimCrossCheck} + {@code TenantContextFilter}
 * + {@code IdempotencyHeaderFilter}). The controller reads
 * {@link TenantContextHolder} to scope persistence.
 *
 * <p>Enforcer rows: docs/governance/enforcers.yaml#E5, #E6, #E7, #E24.
 */
@RestController
@RequestMapping("/v1/runs")
public class RunController {

    private static final Logger LOG = LoggerFactory.getLogger(RunController.class);

    private final RunRepository repository;

    public RunController(RunRepository repository) {
        this.repository = repository;
    }

    @PostMapping(produces = "application/json", consumes = "application/json")
    public ResponseEntity<?> create(@Valid @RequestBody CreateRunRequest request) {
        TenantContext tenant = TenantContextHolder.get();
        if (tenant == null) {
            return error(HttpStatus.BAD_REQUEST, "tenant_context_missing",
                    "Tenant context not resolved.");
        }
        Instant now = Instant.now();
        Run run = new Run(
                UUID.randomUUID(),
                tenant.tenantId().toString(),
                request.capabilityName(),
                RunStatus.PENDING,
                RunMode.GRAPH,
                now,
                now,
                null,
                null,
                null,
                null,
                null);
        Run saved = repository.save(run);
        LOG.info("Run created: runId={} tenant={} capability={}",
                saved.runId(), saved.tenantId(), saved.capabilityName());
        return ResponseEntity.status(HttpStatus.CREATED).body(RunResponse.from(saved));
    }

    @GetMapping(value = "/{runId}", produces = "application/json")
    public ResponseEntity<?> get(@PathVariable String runId) {
        UUID id = parseUuidOr400(runId);
        if (id == null) {
            return error(HttpStatus.BAD_REQUEST, "invalid_request",
                    "Path parameter runId must be a UUID.");
        }
        TenantContext tenant = TenantContextHolder.get();
        Optional<Run> found = repository.findById(id);
        if (found.isEmpty() || tenant == null
                || !found.get().tenantId().equals(tenant.tenantId().toString())) {
            return error(HttpStatus.NOT_FOUND, "not_found",
                    "Run not found within tenant scope.");
        }
        return ResponseEntity.ok(RunResponse.from(found.get()));
    }

    @PostMapping(value = "/{runId}/cancel", produces = "application/json")
    public ResponseEntity<?> cancel(@PathVariable String runId) {
        UUID id = parseUuidOr400(runId);
        if (id == null) {
            return error(HttpStatus.BAD_REQUEST, "invalid_request",
                    "Path parameter runId must be a UUID.");
        }
        TenantContext tenant = TenantContextHolder.get();
        Optional<Run> found = repository.findById(id);
        if (found.isEmpty() || tenant == null
                || !found.get().tenantId().equals(tenant.tenantId().toString())) {
            return error(HttpStatus.NOT_FOUND, "not_found",
                    "Run not found within tenant scope.");
        }

        Run current = found.get();
        if (current.status() == RunStatus.CANCELLED) {
            // Idempotent: already cancelled; return current state with 200.
            return ResponseEntity.ok(RunResponse.from(current));
        }

        try {
            Run cancelled = current.withStatus(RunStatus.CANCELLED);
            Run saved = repository.save(cancelled);
            return ResponseEntity.ok(RunResponse.from(saved));
        } catch (IllegalStateException ise) {
            // Terminal -> CANCELLED transition rejected by RunStateMachine.
            return error(HttpStatus.CONFLICT, "illegal_state_transition",
                    "Run is in a terminal state and cannot be cancelled: " + current.status());
        }
    }

    private static UUID parseUuidOr400(String raw) {
        try {
            return UUID.fromString(raw);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static ResponseEntity<?> error(HttpStatus status, String code, String message) {
        return ResponseEntity.status(status).body(ErrorEnvelope.of(code, message));
    }
}
