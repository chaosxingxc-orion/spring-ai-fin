# R4 Scope Guardian Audit of L0 v2 Release Note
Date: 2026-05-13
Reviewer: scope-guardian-reviewer (compound-engineering)
Input: docs/releases/2026-05-13-L0-architecture-release-v2.en.md

## Verdict
PASS-WITH-OBSERVATIONS

All `shipped: true` YAML rows that correspond to "Capabilities Shipped at W0" entries are confirmed backed by code and tests. The structural separation between "Capabilities Shipped at W0" and "Architectural Commitments (L0 contract level)" is present and mostly clear. Two observations follow — neither is a P0/P1 ship-blocker, but both are correctable before multi-agent audit convergence.

---

## Findings

### Finding 1 — `CapabilityRegistry` described with implementation-tone language inside a design-only commitment block, no per-sentence wave qualifier

- Severity: P2
- Defect category: commitment-vs-impl-confusion
- 4-shape label: PERIPHERAL-DRIFT (commitment body carries implementation-style assertions without a wave-qualifier, while the section header carries the deferred framing)
- Observed: v2 line 118 under "Skill Topology Scheduler and Capability Bidding (§4 #50, ADR-0052)": "`CapabilityRegistry` (extended) — capability tags bound to domain permission identifiers; tenant-scoped pre-authorization; rejects with `Rejected(INSUFFICIENT_PERMISSION)` if the requesting tenant lacks the required identifier."
- Reality: YAML row `capability_registry_spi` is `shipped: false`, `status: design_accepted`, `implementation: null`, `tests: []`, `allowed_claim: "Design only — CapabilityRegistry SPI for enumerating available skills/executors by name... Implementation deferred to W2."` The `skill_topology_scheduler_and_capability_bidding` row is `shipped: true` only for the ADR/ARCHITECTURE.md document artifacts, not for any Java implementation. No `CapabilityRegistry` Java class exists in the codebase.
- Root cause: The Architectural Commitments section correctly frames the overall block as "L0 contract level," but each sub-bullet for `CapabilityRegistry` behavior reads prescriptively ("rejects with `Rejected(INSUFFICIENT_PERMISSION)`") without an inline wave qualifier, creating an implied claim that the rejection behavior is operative.
- Fix proposal: Append "(W2+ Java types and runtime deferred)" to the `CapabilityRegistry` bullet, matching the explicit deferred-qualifier pattern used for C/S Hydration on line 95 ("Java types and wire bindings deferred to W2+").

---

### Finding 2 — `PlaceholderPreservationPolicy` labeled "ship-blocking" in the commitment body but silently deferred to W3

- Severity: P2
- Defect category: w-boundary-blur
- 4-shape label: GATE-SCOPE-GAP (the "ship-blocking" label is a signal strong enough to imply current enforcement, but enforcement is in the W3 deferred table with no cross-reference in the commitment text)
- Observed: v2 line 111 under "Memory and Knowledge Ownership Boundary (§4 #49, ADR-0051)": "`PlaceholderPreservationPolicy` (first-class, **ship-blocking**): when C-Side passes placeholders (e.g. `[USER_ID_102]`), S-Side MUST preserve them verbatim..." — no wave qualifier in this bullet. v2 line 185 in the W3 deferred table: "`PlaceholderPreservationPolicy` enforcement | ADR-0051 / §4 #49."
- Reality: YAML `memory_knowledge_ownership_boundary` is `shipped: true` (for the ADR and ARCHITECTURE.md document artifacts only). The YAML `allowed_claim` states "PlaceholderPreservationPolicy (first-class, ship-blocking): placeholders preserved verbatim... Java types and DelegationGrant template deferred W2+." The W3 deferred table in v2 confirms enforcement is deferred to W3. No Java type for `PlaceholderPreservationPolicy` or `SymbolicReturnEnvelope` exists in the codebase.
- Root cause: The label "ship-blocking" was added to the commitment body to signal the policy's architectural priority, but without an accompanying wave qualifier it reads as blocking W0 ship rather than being a requirement that blocks a future wave's ship gate. A reader scanning the "Capabilities Shipped at W0" and "Architectural Commitments" sections in sequence may infer the policy is currently enforced.
- Fix proposal: Rephrase to "(first-class, W3 ship-blocking: enforcement deferred to W3 per ADR-0051)" to make the wave explicit at the point of declaration, eliminating the ambiguity between "this requirement must be enforced before W3 ships" and "this is currently enforced."

---

### Finding 3 — `ChronosHydration` prose in Workflow Intermediary commitment body lacks inline wave qualifier (minor)

- Severity: P3
- Defect category: w-boundary-blur
- 4-shape label: PERIPHERAL-DRIFT
- Observed: v2 lines 103-104 under "Workflow Intermediary + Three-Track Cross-Service Bus (§4 #48, ADR-0050)": "`ChronosHydration` end-to-end flow (whitepaper §5.4): sleep declaration → snapshot durable → compute self-destruct → `TickEngine` evaluates condition → `WakeupPulse` on Rhythm track → local intermediary rehydrates." No inline wave qualifier.
- Reality: v2's own W4 deferred table at line 194 lists "`ChronosHydration` runtime (sleep→self-destruct→wakeup→rehydrate) | ADR-0050" as W4. No Java implementation exists. The deferred table does catch this, but the commitment body prose reads as a description of operative behavior.
- Root cause: The commitment section was written to name the whitepaper concept comprehensively; the inline wave-qualifier discipline applied to C/S Hydration (line 95) was not applied here.
- Fix proposal: Append "(W4 runtime — design-only at W0)" to the `ChronosHydration` sentence.

---

## Verification of "No Regression" Claim (Migration from v1)

Five capabilities from v1's shipped list cross-checked against v2 and YAML:

| v1 Capability | v2 Shipped | YAML shipped: true | YAML tests: non-empty |
|--------------|-----------|-------------------|----------------------|
| `GET /v1/health` | Yes (line 50) | `agent_platform_facade` | Yes (`HealthEndpointIT`) |
| `TenantContextFilter` | Yes (line 51) | `tenant_context_filter` | Yes (`TenantContextFilterTest`, `TenantContextFilterIT`) |
| `RunStateMachine` (Run entity + DFA) | Yes (line 59) | `run_status_transition_validator` | Yes (`RunStateMachineTest`) |
| `ResilienceContract` + `YamlResilienceContract` | Yes (line 64) | `resilience_contract` | Yes (`ResilienceContractTest`, `ResilienceContractIT`) |
| `InMemoryCheckpointer` (dev-posture executors) | Yes (line 62) | `orchestration_spi` + `inmemory_orchestrator` | Yes (`InMemoryCheckpointerTest`, `RunStatusTransitionIT`) |

All five confirmed. Migration claim ("No regression vector. Every v1 capability that was shipped is still shipped") holds.

---

## Service-Layer Microservice Commitment — Framing Verification

YAML `service_layer_microservice_commitment`: `shipped: true`, `status: design_accepted`. Implementation paths list only `ARCHITECTURE.md`, `docs/adr/0048-...`, and the archived serverless doc — no runtime Java. The `allowed_claim` confirms the commitment is at deployment-topology level.

v2's treatment is honest: it places this under "Architectural Commitments (L0 contract level)" (not under "Capabilities Shipped at W0"), and the Known Limitations section notes "Ops runbooks and Helm chart are skeletons: not deployment-tested." The YAML `shipped: true` is consistent with the note's framing because `shipped` for this row means the decision/document is committed, not that deployment infrastructure is running.

One minor gap: v2 does not explicitly state in the Architectural Commitments prose that "no Agent Bus broker or cross-docker deployment exists at W0." The Known Limitations section covers the Helm/runbook skeleton but not the Agent Bus substrate. This is at most P3; the executive summary (line 24) states "Nothing that is not shipped at W0 is described as shipped" and the §4 #46 constraint text in ARCHITECTURE.md plus the YAML allowed_claim carry the full nuance.

---

## Deferred Capabilities Cross-Check (sample)

Items listed as deferred in v2 cross-checked against YAML:

| v2 Deferred Entry | YAML shipped: true? |
|------------------|---------------------|
| `IdempotencyStore` dedup (W1) | `idempotency_store`: shipped: false. Correct. |
| JWT cross-check (W1) | `w1_http_contract_reconciliation`: shipped: false. Correct. |
| `PostgresCheckpointer` (W2) | `multi_backend_checkpointer`: shipped: false. Correct. |
| C/S protocol Java types (W2) | `c_s_dynamic_hydration_protocol`: shipped: true — but only for ADR doc artifacts; `allowed_claim` explicitly states "Java types and wire bindings deferred W2+." v2 deferred entry is consistent. |
| `SandboxExecutor` SPI (W3) | `sandbox_executor_spi`: shipped: false. Correct. |
| `PlaceholderPreservationPolicy` enforcement (W3) | `memory_knowledge_ownership_boundary`: shipped: true only for ADR/doc artifacts. Enforcement deferred per YAML. Consistent with deferred table. |

No YAML `shipped: true` (with Java implementation) row found in the v2 deferred table. No underclaim detected for items with code shipped.

---

## Categorized Summary

| Finding | Severity | Category | Shape |
|---------|----------|----------|-------|
| F1 — `CapabilityRegistry` lacks per-sentence wave qualifier in commitment block | P2 | commitment-vs-impl-confusion | PERIPHERAL-DRIFT |
| F2 — `PlaceholderPreservationPolicy` "ship-blocking" label ambiguous without inline wave | P2 | w-boundary-blur | GATE-SCOPE-GAP |
| F3 — `ChronosHydration` prose no inline wave qualifier (deferred table present) | P3 | w-boundary-blur | PERIPHERAL-DRIFT |

Zero P0 findings. Zero P1 findings. Zero overclaims for actually-shipped-in-code capabilities. Zero underclaims for deferred-but-YAML-shipped items. The shipped/deferred boundary is structurally sound; the three findings are precision improvements to prose within the Architectural Commitments section.
