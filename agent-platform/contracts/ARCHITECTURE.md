# contracts — Frozen v1 Schema (L2)

> **L2 sub-architecture of `agent-platform/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`agent-platform/contracts/` is the **stdlib-only frozen v1 northbound contract surface**.

Three responsibilities:

1. **Single source of public schema truth** (freeze-digested at first stable release SHA).
2. **Spine validator carrier** (every spine-bearing record validates at canonical-constructor time per Rule 11).
3. **Layering boundary** (`java.*` + Jackson + Bean Validation only — NO `agent-runtime.*` imports).

Out of scope:

- Schema evolution (breaking changes go to `agent-platform/contracts/v2/`).
- Domain-specific record content (loan applications, KYC schemas, transaction shapes — these belong in customer code or `fin-domain-pack/`).
- Protocol negotiation (the contract IS the protocol).
- Data adaptation to/from kernel types (lives in `agent-platform/facade/`).

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
│       ├── ContractError.java                # base
│       ├── AuthException.java                # 401
│       ├── TenantScopeException.java         # 400
│       ├── SpineCompletenessException.java   # 400
│       ├── IdempotencyConflictException.java # 409
│       ├── NotFoundException.java            # 404
│       ├── QuotaException.java               # 429
│       └── RuntimeContractException.java     # 500
└── v2/                                        # parallel namespace; empty until v2 released
```

---

## 3. Architecture Decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Freeze + parallel v2 (SAS-3)** | Once v1 RELEASED, all bytes of `v1/` are digest-locked; breaking changes go to `v2/` | Customers in finance plan release cycles 6–12 months ahead; byte-for-byte stability required |
| **AD-2: Stdlib-only purity** | No `agent-runtime.*` imports; posture read via `Environment.getProperty("APP_POSTURE")` directly | SDKs and OpenAPI generators depend on this surface; must not transitively pull runtime |
| **AD-3: Spine validation in canonical constructor** | Java records' canonical constructor is the validation seam (analogous to `__post_init__` in Python) | Construction-time fail-fast; no record without valid spine ever exists |
| **AD-4: Process-internal value objects marked** | `// scope: process-internal` with rationale comment | Some records (`ContentHash`, `EventFilter`, `CapabilityDescriptor`) are transient value objects, not persistent records; exempt from `tenantId` |
| **AD-5: Errors are records too** | All `Exception` subclasses are `record`s implementing `Throwable` | Allows error envelope serialization to be lossless; reviewers can grep error categories |
| **AD-6: Contract version pin** | `ContractVersion.V1_FROZEN_HEAD` String constant containing the freeze SHA; cross-checked by `ContractFreezeTest` | Pinning the freeze digest is a single point of truth |

---

## 4. Spine validation pattern

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
        if (tenantId.isBlank()) {
            throw strictPosture()
                ? new SpineCompletenessException("tenantId is blank")
                : log("WARNING: tenantId blank in dev posture");
        }
        if (goal.length() > 16384) {
            throw new ContractError("goal exceeds 16384 chars");
        }
    }
    
    private static boolean strictPosture() {
        String p = System.getenv("APP_POSTURE");
        return "research".equals(p) || "prod".equals(p);
    }
}
```

The `strictPosture()` helper mirrors `agent-runtime.posture.AppPosture.isStrict()` semantics without importing it. This is the SAS-1 compliance trick: contracts read posture from environment directly.

---

## 5. ContractError envelope

All `/v1/*` responses with non-2xx status use the `ContractError` envelope:

```java
public record ContractError(
    @NonNull String code,                          // "auth" | "tenantScope" | "validation" | ...
    @NonNull String message,                       // human-readable
    @Nullable String detail,                       // structured cause (JSON-serializable)
    @Nullable String traceId,                      // OTel trace id for correlation
    @Nullable Instant occurredAt
) implements Throwable {
    public ContractError {
        Objects.requireNonNull(code);
        Objects.requireNonNull(message);
        if (occurredAt == null) occurredAt = Instant.now();
    }
}
```

Spring `@ControllerAdvice` maps every uncaught exception to `ContractError`:

```java
@ControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(SpineCompletenessException.class)
    ResponseEntity<ContractError> spine(...) { return badRequest("spineCompleteness", ex); }
    
    @ExceptionHandler(TenantScopeException.class)
    ResponseEntity<ContractError> tenantScope(...) { return badRequest("tenantScope", ex); }
    
    @ExceptionHandler(IdempotencyConflictException.class)
    ResponseEntity<ContractError> idemConflict(...) { return conflict("idempotencyConflict", ex); }
    
    @ExceptionHandler(Exception.class)
    ResponseEntity<ContractError> internal(...) { 
        log.error("internal", ex);
        return internalServerError("internal", "see traceId");
    }
}
```

---

## 6. Cross-cutting hooks

| Concern | Implementation |
|---|---|
| **SAS-3 freeze** | `ContractFreezeTest` walks `v1/` and computes per-file SHA-256; compares to `docs/governance/contract_v1_freeze.json`; fails on drift |
| **Spine completeness (Rule 11)** | `ContractSpineCompletenessTest` walks `v1/` and asserts every public record has a `@PostConstruct`-equivalent constructor validation OR `// scope: process-internal` comment |
| **Posture (Rule 11)** | Strict-posture decision in records; mirror via `Environment.getProperty` to avoid SAS-1 violation |
| **Allowlist (Rule 17)** | If a v1 contract MUST allow a temporary additive change post-freeze (e.g., adding a new optional field with default value), record in `docs/governance/allowlists.yaml` with expiry_wave |

---

## 7. Quality Attributes

| Attribute | Target | Verification |
|---|---|---|
| **Freeze integrity** | Zero byte drift in `v1/` post-release | `ContractFreezeTest` |
| **Spine coverage** | 100% of records validated or marked process-internal | `ContractSpineCompletenessTest` |
| **No `agent-runtime` imports** | Zero | `ArchitectureRulesTest::contractsStdLibOnly` |
| **OpenAPI generator-friendly** | All records map cleanly to Jackson + Bean Validation | `OpenApiGenerationTest` |
| **Error envelope completeness** | Every exception type maps to a `ContractError` code | `ControllerAdviceCoverageTest` |

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
- Hi-agent prior art: `D:/chao_workspace/hi-agent/agent_server/contracts/ARCHITECTURE.md` — same pattern, Python `__post_init__` instead of Java canonical constructor
- Java records: https://docs.oracle.com/en/java/javase/21/language/records.html
- Jackson record support: https://github.com/FasterXML/jackson-modules-java8
