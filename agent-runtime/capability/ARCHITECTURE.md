# capability — Tenant-Agnostic Registry of Named Tools (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`capability/` owns the **platform-level capability registry** — named, callable, schema-described tools available to all tenants equally. Capabilities are tenant-agnostic metadata; per-tenant policy is decided at runtime by `../action-guard/`.

This is the one place in the platform where records do **not** carry `tenantId`. They are explicitly `// scope: process-internal` per Rule 11. The reasoning: a capability descriptor describes a callable; the callable's invocation is per-tenant (handled by `ActionGuard` and `CapabilityInvoker`).

> **Important security boundary** (per `../action-guard/` AD-1 and security review §P0-1, §P0-6):
> `CapabilityInvoker` is **not** a public entry point. It is the inner delegate that `ActionGuard` Stage 10 (Executor) calls **after** the 9-stage authorization pipeline approves the action. Code that calls `CapabilityInvoker.invoke` directly without going through `ActionGuard.authorize(envelope)` is a CI violation, caught by `ActionGuardCoverageTest` (in `../action-guard/`).

Owns:

- `CapabilityRegistry` — name → `CapabilitySpec` map
- `CapabilitySpec` — handler reference + metadata
- `CapabilityDescriptor` — frozen metadata: `riskClass`, `effectClass`, `dataAccessClass`, `requiresAuth`, `availableInDev/Research/Prod`, `maturityLevel L0..L4`, `sandboxLevel`, `requiresHumanGate`
- `CapabilityInvoker` — policy + breaker + timeout + retry wrapper. **Called only from `ActionGuard` Stage 10 Executor; not a public entry point.**
- `CapabilityPolicy` — RBAC resolver (role → capability set); consulted by `ActionGuard` Stage 3 ActorAuthorizer
- `TenantEntitlementStore` — per-tenant grant of capability access; consulted by `ActionGuard` Stage 3
- `CircuitBreaker` — per-capability OPEN/HALF_OPEN/CLOSED state
- `CapabilityBundle` — registration grouping (e.g., "kyc-bundle" registers 5 KYC-related capabilities)

Does NOT own:

- Action orchestration (delegated to `../action-guard/ActionGuard`)
- MCP dispatch (delegated to `../skill/McpToolBridge`)
- Skill resolution (delegated to `../skill/`)
- LLM gating (delegated to `../llm/`)
- Runtime authorization (delegated to `../action-guard/`)

---

## 2. Why platform-level (NOT per-tenant)

A "capability" is a primitive — `transfer.execute`, `kyc.lookup`, `skill.invoke` etc. The capability metadata (risk class, effect class, data-access class, required auth, posture availability) is the same across tenants. What differs per-tenant is:

- Whether the tenant has been granted access (`TenantEntitlementStore`; consumed by `ActionGuard` Stage 3)
- The tenant's specific skill versions or tool variants (in `../skill/`)
- The per-call policy decision (computed by `ActionGuard`'s 9 pre-execution stages)

Adding `tenantId` to `CapabilitySpec` would force a per-tenant copy of every capability descriptor — wasteful and easy to drift. The current decision: capabilities are platform metadata; tenant filtering happens at runtime by `ActionGuard`.

This is documented in code:

```java
public record CapabilityDescriptor(
    @NonNull String name,
    @NonNull String version,
    @NonNull RiskClass riskClass,             // LOW / MEDIUM / HIGH
    @NonNull EffectClass effectClass,         // READ_ONLY / IDEMPOTENT_WRITE / NON_IDEMPOTENT
    @NonNull DataAccessClass dataAccessClass, // PUBLIC / TENANT_INTERNAL / PII / FINANCIAL_LEDGER
    @NonNull boolean requiresAuth,
    boolean availableInDev,
    boolean availableInResearch,
    boolean availableInProd,
    @NonNull MaturityLevel maturityLevel,     // L0 .. L4
    @NonNull SandboxLevel sandboxLevel,       // OPEN / RESTRICTED / SANDBOXED
    boolean requiresHumanGate
) {
    // scope: process-internal — capability descriptors are platform-level metadata, not per-tenant records
    // No tenantId field by design.
}
```

The descriptor is consumed by:

- `ActionGuard` Stage 3 (`ActorAuthorizer`) — RBAC + entitlement
- `ActionGuard` Stage 4 (`MaturityChecker`) — `maturityLevel × posture`
- `ActionGuard` Stage 5 (`EffectClassifier`) — descriptor is authoritative; envelope is anti-tampering checked
- `ActionGuard` Stage 6 (`DataAccessClassifier`) — `dataAccessClass` drives audit class selection
- `ActionGuard` Stage 8 (`HitlGate`) — `requiresHumanGate` bit

---

## 3. Capability invocation flow (runtime)

```mermaid
sequenceDiagram
    participant CALLER as Caller (e.g., McpToolBridge from LLM tool call)
    participant AG as ActionGuard
    participant DESC as CapabilityDescriptor
    participant POLICY as CapabilityPolicy + TenantEntitlement
    participant CB as CircuitBreaker
    participant CI as CapabilityInvoker
    participant H as Handler

    CALLER->>AG: authorize(ActionEnvelope)
    AG->>POLICY: Stage 3 RBAC + entitlement
    AG->>DESC: Stage 4-6 maturity / effect / data-access
    AG->>AG: Stage 7 OPA red-line; Stage 8 HitlGate
    AG->>AG: Stage 9 PreActionEvidenceWriter (audit-before-action)
    AG->>CB: Stage 10 Executor: CB.state == OPEN?
    alt breaker open
        CB-->>AG: CircuitOpenException
        AG-->>CALLER: deny + structured error
    else breaker closed
        AG->>CI: Stage 10 Executor: invoke(envelope)
        CI->>H: timeout-bounded handler call
        alt success
            H-->>CI: result
            CI->>CB: recordSuccess
            CI-->>AG: result
            AG->>AG: Stage 11 PostActionEvidenceWriter (terminal evidence)
            AG-->>CALLER: result
        else failure
            H-->>CI: exception
            CI->>CB: recordFailure (may transition to OPEN)
            CI-->>AG: exception
            AG->>AG: Stage 11 PostActionEvidenceWriter (terminal failure evidence)
            AG-->>CALLER: exception
        end
    end
```

`CapabilityInvoker.invoke` is reached only via `ActionGuard` Stage 10. The CI gate `ActionGuardCoverageTest` (in `../action-guard/`) reflectively checks every entry path:

- callers under `agent-runtime/runtime/HarnessExecutor` route through `ActionGuard.authorize`
- callers under `agent-runtime/skill/McpToolBridge` route through `ActionGuard.authorize`
- callers under `agent-runtime/adapters/SpringAiAdapter` (via Spring AI Advisors) route through `ActionGuard.authorize`
- direct calls to `CapabilityInvoker.invoke` from outside `ActionGuard` fail the build

---

## 4. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Platform-level (not per-tenant) registry** | `// scope: process-internal` Rule 11 exemption | Capabilities are tenant-agnostic metadata; per-tenant filtering at runtime by ActionGuard |
| **AD-2: `CapabilityDescriptor` is canonical metadata** | Single frozen record carries all metadata | Avoids separate metadata sources drifting; consumed by ActionGuard Stages 3-8 |
| **AD-3: Posture gate is hard fail** | `MaturityChecker` (ActionGuard Stage 4) raises `CapabilityNotAvailableException` (400 envelope) | Strongest interpretation of Rule 1 — gate, not notification |
| **AD-4: CircuitBreaker per capability** | OPEN / HALF_OPEN / CLOSED state | Standard resilience pattern; protects downstream from cascading failures |
| **AD-5: CapabilityBundle for registration** | Bundle groups (e.g., "kyc-bundle") for batch register | Customer Starters can register a bundle; cleaner than 5 separate registrations |
| **AD-6: Heuristic fallback under non-prod** | If LLM gateway missing under dev, capability falls through to heuristic stub | Faster dev iteration; prod fail-closed |
| **AD-7: MaturityLevel L0..L4 per capability** | Mirror Rule 12 ladder per capability | Manifest exposes per-capability maturity |
| **AD-8: CapabilityInvoker is internal to ActionGuard** | Not a public entry point; called only from Stage 10 Executor | addresses P0-1 + P0-6 (status: design_accepted); bypass paths fail CI |
| **AD-9: TenantEntitlementStore is consulted at runtime, not at registration** | A capability's entitlement can be granted/revoked per-tenant without re-registering the capability | addresses P1-7 (status: design_accepted); per-tenant entitlement is independent of platform-wide capability availability |

---

## 5. Cross-cutting hooks

- **Rule 6**: `CapabilityRegistry` is `@Bean` singleton
- **Rule 7**: capability invocation failures emit `springaifin_capability_failures_total{capability, reason}` + breaker state changes
- **Rule 11**: `CapabilityDescriptor` is process-internal; documented exception to spine completeness
- **Rule 12**: every capability declares `MaturityLevel`; manifest reflects
- **Posture-aware**: hard-fail under prod when capability not `availableInProd`; heuristic fallback under dev
- **ActionGuard integration**: ActionGuard is the only public entry point to a capability invocation

---

## 6. Quality

| Attribute | Target | Verification |
|---|---|---|
| Capability registration latency | ≤ 100ms for 100-capability bundle | `tests/integration/CapabilityBundleIT` |
| Posture gate enforcement | hard-fail under prod when descriptor flag false | `tests/integration/CapabilityPostureIT` |
| Circuit breaker correctness | OPEN after threshold; HALF_OPEN probing; CLOSED on success | `tests/unit/CircuitBreakerStateTest` |
| Maturity level reporting in manifest | every capability rendered with its level | `tests/integration/ManifestCapabilityIT` |
| ActionGuard coverage | 100% of capability invocations come from ActionGuard Stage 10 | `ActionGuardCoverageTest` (in `../action-guard/`) |
| Per-tenant entitlement | grant/revoke without re-registering capability | `tests/integration/TenantEntitlementIT` |

## 7. Risks

- **Per-tenant override demand**: customer asks for tenant-specific capability variant — handled by `../skill/` versioning, not capability registry
- **Bundle versioning**: customer Starter bundle version drift — tracked at Starter version (`fin-starter-kyc:1.0.2`)
- **Heuristic fallback under prod misconfig**: explicit boot assertion that prod has LLM gateway
- **CapabilityInvoker bypass**: `ActionGuardCoverageTest` enforces at CI; reviewer audit on every PR that adds an entry point

## 8. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Action-guard (runtime authorization; calls CapabilityInvoker at Stage 10): [`../action-guard/ARCHITECTURE.md`](../action-guard/ARCHITECTURE.md)
- Skill consumer: [`../skill/ARCHITECTURE.md`](../skill/ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/hi_agent/capability/ARCHITECTURE.md`
- Systematic-architecture-remediation-plan: [`../../docs/systematic-architecture-remediation-plan-2026-05-08.en.md`](../../docs/systematic-architecture-remediation-plan-2026-05-08.en.md) §7.2
