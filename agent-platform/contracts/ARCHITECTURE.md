# contracts — Frozen v1 Schema (L2)

> **L2 sub-architecture of `agent-platform/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`agent-platform/contracts/` is the **stdlib-only frozen v1 northbound contract surface**.

Three responsibilities:

1. **Single source of public schema truth** (freeze-digested at first stable release SHA).
2. **Spine validator carrier** (every spine-bearing record validates at canonical-constructor time per Rule 11).
3. **Layering boundary** (`java.*` + Jackson + Bean Validation only — NO `agent-runtime.*` imports; NO environment reads).

Out of scope:

- Schema evolution (breaking changes go to `agent-platform/contracts/v2/`).
- Domain-specific record content (loan applications, KYC schemas, transaction shapes — these belong in customer code or `fin-domain-pack/`).
- Protocol negotiation (the contract IS the protocol).
- Data adaptation to/from kernel types (lives in `agent-platform/facade/`).
- **Posture-conditional validation** (records enforce shape only; posture-aware checks live in `agent-platform/facade/PostureAwareValidator`, which receives an injected `AppPosture`).

---

## 2. Layout

```
agent-platform/contracts/
├── v1/                                        # frozen at first stable release SHA
│   ├── run/
│   │   ├── RunRequest.java                   # @Spine(tenant_id, user_id?, project_id?)
│   │   ├── RunResponse.java                  # @Spine(tenant_id, run_id)
│   │   ├── RunStatus.java                    # enum
│   │   └── RunStream.java                    # SSE wrapper
│   ├── tenancy/
│   │   ├── TenantContext.java                # @Spine(tenant_id) — process-internal
│   │   ├── TenantQuota.java                  # @Spine(tenant_id)
│   │   └── CostEnvelope.java                 # @Spine(tenant_id, run_id?)
│   ├── streaming/
│   │   ├── Event.java                        # @Spine(tenant_id, run_id)
│   │   ├── EventCursor.java                  # @Spine(tenant_id, run_id)
│   │   └── EventFilter.java                  # // scope: process-internal
│   ├── gate/
│   │   ├── PauseToken.java                   # @Spine(tenant_id, run_id)
│   │   ├── ResumeRequest.java                # @Spine(tenant_id, run_id)
│   │   ├── GateEvent.java                    # @Spine(tenant_id, run_id, gate_id)
│   │   └── GateDecisionRequest.java          # @Spine(tenant_id, run_id, gate_id, decided_by)
│   ├── memory/
│   │   ├── MemoryTier.java                   # enum L0..L3
│   │   ├── MemoryReadKey.java                # @Spine(tenant_id, project_id?, session_id?)
│   │   └── MemoryWriteRequest.java           # @Spine(tenant_id, project_id, session_id, run_id?)
│   ├── skill/
│   │   ├── SkillRegistration.java            # @Spine(tenant_id, project_id, capability_name)
│   │   ├── SkillVersion.java                 # @Spine(tenant_id, capability_name)
│   │   └── SkillResolution.java              # @Spine(tenant_id)
│   ├── llm_proxy/
│   │   ├── LLMRequest.java                   # @Spine(tenant_id, run_id?)
│   │   └── LLMResponse.java                  # @Spine(tenant_id, run_id?)
│   ├── workspace/
│   │   ├── ContentHash.java                  # // scope: process-internal
│   │   ├── BlobRef.java                      # @Spine(tenant_id, project_id?)
│   │   └── WorkspaceObject.java              # @Spine(tenant_id, project_id)
│   ├── audit/
│   │   ├── AuditEntry.java                   # @Spine(tenant_id, actor_user_id, target_kind, target_id)
│   │   └── RegulatoryEvent.java              # @Spine(tenant_id, regulator, jurisdiction)
│   ├── manifest/
│   │   ├── ManifestSnapshot.java             # @Spine(tenant_id?)
│   │   └── CapabilityDescriptor.java         # // scope: process-internal
│   ├── idempotency/
│   │   ├── IdempotencyResult.java            # @Spine(tenant_id, idempotency_key)
│   │   └── IdempotencyConflict.java          # @Spine(tenant_id, idempotency_key)
│   └── errors/
│       ├── ContractError.java                # wire envelope record (DTO; never thrown)
│       ├── ContractException.java            # base RuntimeException carrying ContractError; thrown
│       ├── AuthException.java                # extends ContractException; mapped to 401
│       ├── TenantScopeException.java         # extends ContractException; mapped to 400
│       ├── SpineCompletenessException.java   # extends ContractException; mapped to 400
│       ├── IdempotencyConflictException.java # extends ContractException; mapped to 409
│       ├── NotFoundException.java            # extends ContractException; mapped to 404
│       ├── QuotaException.java               # extends ContractException; mapped to 429
│       └── RuntimeContractException.java     # extends ContractException; mapped to 500
└── v2/                                        # parallel namespace; empty until v2 released
```

---

## 3. Architecture Decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Freeze + parallel v2 (SAS-3)** | Once v1 RELEASED, all bytes of `v1/` are digest-locked; breaking changes go to `v2/` | Customers in finance plan release cycles 6–12 months ahead; byte-for-byte stability required |
| **AD-2: Stdlib-only purity** | No `agent-runtime.*` imports; no environment reads from inside records | SDKs and OpenAPI generators depend on this surface; must not transitively pull runtime; must not leak boot-time config into wire types |
| **AD-3: Spine validation in canonical constructor** | Java records' canonical constructor is the validation seam (analogous to `__post_init__` in Python) | Construction-time fail-fast; no record without valid spine ever exists |
| **AD-4: Process-internal value objects marked** | `// scope: process-internal` with rationale comment | Some records (`ContentHash`, `EventFilter`, `CapabilityDescriptor`) are transient value objects, not persistent records; exempt from `tenantId` |
| **AD-5: Error envelope is a `record`; thrown type is a class** | `ContractError` is a Java record (the wire envelope, JSON-serializable, never thrown). `ContractException` is a `RuntimeException` subclass that carries a `ContractError` and is the type actually thrown. | Java records may implement interfaces but cannot extend classes — `Throwable` is a class — so a record cannot itself be thrown. The split keeps the wire envelope serialization-friendly while staying valid Java. |
| **AD-6: Contract version pin** | `ContractVersion.V1_FROZEN_HEAD` String constant containing the freeze SHA; cross-checked by `ContractFreezeTest` | Pinning the freeze digest is a single point of truth |
| **AD-7: Records enforce shape only; posture-conditional validation lives outside contracts** | Canonical constructors check non-null, non-blank where required, size limits, type-level constraints. Posture-conditional behaviour (e.g., reject vs warn on blank `tenantId`) lives in `agent-platform/facade/PostureAwareValidator`, which receives an injected `AppPosture`. | Per Rule 6 single-construction-path and Rule 11 boot-time posture read; records must not call `System.getenv` or branch on environment state. |

---

## 4. Spine validation pattern

Records validate **shape** at construction time — non-null, non-blank where required, size limits, typed constraints:

```java
public record RunRequest(
    @NonNull String tenantId,                      // Rule 11: spine
    @Nullable String userId,                       // Rule 11: spine subset
    @Nullable String projectId,                    // Rule 11: spine subset
    @NonNull String goal,
    @Nullable String profileId,
    @Nullable Map<String, Object> metadata,
    @Nullable List<String> frameworkPreference,    // for adapter dispatch
    @Nullable Duration deadline
) {
    public RunRequest {
        Objects.requireNonNull(tenantId, "tenantId");
        Objects.requireNonNull(goal, "goal");
        if (goal.length() > 16384) {
            throw new SpineCompletenessException(
                ContractError.of("validation", "goal exceeds 16384 chars"));
        }
        // Note: blank-tenantId behaviour (reject vs warn) is posture-conditional
        // and is NOT decided here. PostureAwareValidator owns that decision.
    }
}
```

Posture-conditional behaviour is enforced **outside** the record by an injected validator at the facade boundary:

```java
// agent-platform/facade/PostureAwareValidator.java
@Component
public class PostureAwareValidator {
    private final AppPosture posture;             // injected; read once at boot

    public PostureAwareValidator(AppPosture posture) {
        this.posture = posture;
    }

    public void validate(RunRequest req) {
        if (req.tenantId().isBlank()) {
            if (posture.requiresStrict()) {
                throw new SpineCompletenessException(
                    ContractError.of("spineCompleteness", "tenantId is blank"));
            }
            log.warn("tenantId blank in dev posture; accepting");
        }
        // future cross-field, cross-record posture-conditional checks live here.
    }
}
```

This is the SAS-1-compliant pattern: contracts stay stdlib-only and environment-free; posture is read **once** at boot via `AppPosture.fromEnv()` (per `agent-runtime/posture/`) and injected into validators that wrap record acceptance at the facade boundary.

---

## 5. ContractError envelope and ContractException

The wire envelope is a record (DTO); the thrown type is a class:

```java
// Wire envelope: serialization-safe DTO. Never thrown.
public record ContractError(
    @NonNull String code,                          // "auth" | "tenantScope" | "validation" | ...
    @NonNull String message,                       // human-readable
    @Nullable Object detail,                       // structured cause (JSON-serializable)
    @Nullable String traceId,                      // OTel trace id for correlation
    @Nullable Instant occurredAt
) {
    public ContractError {
        Objects.requireNonNull(code);
        Objects.requireNonNull(message);
        if (occurredAt == null) occurredAt = Instant.now();
    }

    public static ContractError of(String code, String message) {
        return new ContractError(code, message, null, null, Instant.now());
    }
}

// Thrown type: conventional class. Carries a ContractError envelope.
public class ContractException extends RuntimeException {
    private final ContractError error;

    public ContractException(ContractError error) {
        super(error.message());
        this.error = Objects.requireNonNull(error);
    }

    public ContractException(ContractError error, Throwable cause) {
        super(error.message(), cause);
        this.error = Objects.requireNonNull(error);
    }

    public ContractError error() { return error; }
}
```

All exception subclasses (`AuthException`, `TenantScopeException`, `SpineCompletenessException`, `IdempotencyConflictException`, `NotFoundException`, `QuotaException`, `RuntimeContractException`) extend `ContractException` and supply a `ContractError` with the appropriate `code`. Each is mapped to an HTTP status by `GlobalExceptionHandler`:

```java
@ControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(SpineCompletenessException.class)
    ResponseEntity<ContractError> spine(SpineCompletenessException ex) {
        return ResponseEntity.badRequest().body(ex.error());
    }

    @ExceptionHandler(TenantScopeException.class)
    ResponseEntity<ContractError> tenantScope(TenantScopeException ex) {
        return ResponseEntity.badRequest().body(ex.error());
    }

    @ExceptionHandler(IdempotencyConflictException.class)
    ResponseEntity<ContractError> idemConflict(IdempotencyConflictException ex) {
        return ResponseEntity.status(409).body(ex.error());
    }

    @ExceptionHandler(NotFoundException.class)
    ResponseEntity<ContractError> notFound(NotFoundException ex) {
        return ResponseEntity.status(404).body(ex.error());
    }

    @ExceptionHandler(QuotaException.class)
    ResponseEntity<ContractError> quota(QuotaException ex) {
        return ResponseEntity.status(429).body(ex.error());
    }

    @ExceptionHandler(AuthException.class)
    ResponseEntity<ContractError> auth(AuthException ex) {
        return ResponseEntity.status(401).body(ex.error());
    }

    @ExceptionHandler(ContractException.class)
    ResponseEntity<ContractError> contract(ContractException ex) {
        return ResponseEntity.internalServerError().body(ex.error());
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ContractError> internal(Exception ex) {
        log.error("internal", ex);
        return ResponseEntity.internalServerError()
            .body(ContractError.of("internal", "see traceId"));
    }
}
```

---

## 6. Cross-cutting hooks

| Concern | Implementation |
|---|---|
| **SAS-3 freeze** | `ContractFreezeTest` walks `v1/` and computes per-file SHA-256; compares to `docs/governance/contract_v1_freeze.json`; fails on drift |
| **Spine completeness (Rule 11)** | `ContractSpineCompletenessTest` walks `v1/` and asserts every public record has a canonical-constructor validation OR `// scope: process-internal` comment |
| **Posture (Rule 11)** | Records do **not** read posture; posture-conditional decisions live in `agent-platform/facade/PostureAwareValidator` with injected `AppPosture`. `ContractPosturePurityTest` greps `v1/` for `System.getenv`, `Environment.getProperty`, and `AppPosture.fromEnv` and fails the build if found in `contracts/v1/` |
| **Throwable purity (AD-5)** | `ContractThrowablePurityTest` reflectively walks `errors/` and asserts every type either is a `record` (envelope, not thrown) or extends `ContractException` (thrown). Records implementing `Throwable` fail the build. |
| **Allowlist (Rule 17)** | If a v1 contract MUST allow a temporary additive change post-freeze (e.g., adding a new optional field with default value), record in `docs/governance/allowlists.yaml` with expiry_wave |

---

## 7. Quality Attributes

| Attribute | Target | Verification |
|---|---|---|
| **Freeze integrity** | Zero byte drift in `v1/` post-release | `ContractFreezeTest` |
| **Spine coverage** | 100% of records validated or marked process-internal | `ContractSpineCompletenessTest` |
| **No `agent-runtime` imports** | Zero | `ArchitectureRulesTest::contractsStdLibOnly` |
| **No environment reads from contracts** | Zero | `ContractPosturePurityTest` |
| **No record implementing `Throwable`** | Zero | `ContractThrowablePurityTest` |
| **OpenAPI generator-friendly** | All records map cleanly to Jackson + Bean Validation | `OpenApiGenerationTest` |
| **Error envelope completeness** | Every `ContractException` subclass maps to a `ContractError` code | `ControllerAdviceCoverageTest` |

---

## 8. Risks & Technical Debt

| Risk | Plan |
|---|---|
| v1 freeze too rigid | If a customer-blocking bug requires v1 shape change → escalate to GOV; emergency patch is a v1.0.1 with same SHA digest if shape unchanged, OR v2 if shape changes |
| Spine over-validation slowness | Profiled at construction; <1µs per validation; should not be hot-path concern |
| Process-internal records misclassified | Reviewer audit; PR comment "why is this `// scope: process-internal`?" |
| Java records vs Jackson | Jackson 2.12+ supports records natively; ensure Spring Boot 3.x version |

---

## 9. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Spine validation in `agent-runtime/runner/SpineValidator.java`
- Posture: [`../../agent-runtime/posture/ARCHITECTURE.md`](../../agent-runtime/posture/ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/agent_server/contracts/ARCHITECTURE.md` — same pattern, Python `__post_init__` instead of Java canonical constructor
- Java records: https://docs.oracle.com/en/java/javase/21/language/records.html
- Jackson record support: https://github.com/FasterXML/jackson-modules-java8
- Systematic-architecture-improvement-plan: [`../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md`](../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md) §4.3
