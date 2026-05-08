# Decision Sync Matrix (L0 → L1 → L2)

> Per `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` §4.2 and `docs/systematic-architecture-remediation-plan-2026-05-08.en.md` §6.
> A hard L0 decision must be reflected in every affected L1 and L2 document. This file is the index. The cross-check is run by `gate/check_architecture_sync.{ps1,sh}`.

For every hard L0 decision, this matrix records:

- **Decision id**
- **Affected L1 documents**
- **Affected L2 documents**
- **Required implementation file paths** (target locations; no code yet)
- **Required tests**
- **Required gate evidence**
- **Current status** (per `architecture-status.yaml`)

---

## D-block §A3 — Identity Policy (RS256/JWKS for research SaaS + prod; HS256 carve-outs)

| Field | Value |
|---|---|
| Decision id | A3 |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/auth/ARCHITECTURE.md`, `agent-runtime/posture/ARCHITECTURE.md` |
| Implementation paths | `agent-runtime/auth/JwtValidator.java`, `JwksValidator.java`, `HmacValidator.java`, `IssuerRegistry.java`, `JwksCache.java`, `agent-runtime/posture/PostureBootGuard.java` |
| Tests | `JwksValidationLatencyIT`, `AlgConfusionRejectedIT`, `JwksRotationIT`, `IssuerTrustIsolationIT`, `PostureBootGuardIT`, `IdentityPolicyConsistencyIT` |
| Gate evidence | W2 operator-shape gate run under prod posture with JWKS path; recorded in `docs/delivery/<date>-<sha>.md` |
| Status | design_accepted |

## D-block — ActionGuard (P0-1, REM-2026-05-08-2)

| Field | Value |
|---|---|
| Decision id | ActionGuard |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/action-guard/ARCHITECTURE.md`, `agent-runtime/audit/ARCHITECTURE.md`, `agent-runtime/skill/ARCHITECTURE.md`, `agent-runtime/capability/ARCHITECTURE.md`, `agent-runtime/llm/ARCHITECTURE.md`, `agent-runtime/adapters/ARCHITECTURE.md` |
| Implementation paths | `agent-runtime/action-guard/ActionGuard.java`, `ActionEnvelope.java`, 11 stage classes (`SchemaValidator` through `PostActionEvidenceWriter`), `ActionGuardCoverageTest.java` |
| Tests | `ActionGuardLatencyIT`, `CrossTenantActionGuardIT`, `OpaPolicyLatencyIT`, `AuditBeforeActionIT`, `ArgumentsHashTamperingIT`, `EvidenceChainContiguityIT`, `PostEvidenceOnFailureIT` |
| Gate evidence | W2 operator-shape gate; ActionGuardCoverageTest is a release gate |
| Status | design_accepted |

## D-block — Skill / Capability runtime authorization (P0-6, REM-2026-05-08-4)

| Field | Value |
|---|---|
| Decision id | SkillRuntimeAuthz |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/skill/ARCHITECTURE.md`, `agent-runtime/capability/ARCHITECTURE.md`, `agent-runtime/action-guard/ARCHITECTURE.md` |
| Implementation paths | `agent-runtime/skill/SkillLoader.java` (load-time hygiene), `agent-runtime/capability/CapabilityInvoker.java` (delegated to by ActionGuard Stage 10), `agent-runtime/action-guard/ActionGuard.java` (runtime authorization) |
| Tests | `DangerousCapabilityLoadTimeIT`, `RuntimeActionGuardForEverySideEffectIT`, `LoadTimeIsHygieneNotAuthorizationTest` |
| Gate evidence | W2 operator-shape gate; ActionGuardCoverageTest passes against skill bridge + capability invoker |
| Status | design_accepted |

## D-block — Audit class model (P0-8)

| Field | Value |
|---|---|
| Decision id | AuditClassModel |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/audit/ARCHITECTURE.md`, `agent-runtime/observability/ARCHITECTURE.md` (boundary), `agent-runtime/action-guard/ARCHITECTURE.md` (Stage 9, Stage 11) |
| Implementation paths | `agent-runtime/audit/AuditFacade.java`, `AuditEntry.java`, `AuditStore.java`, `WormAnchor.java`, `AuditClass.java` |
| Tests | `AuditWriteLatencyIT`, `AuditBeforeRevealIT`, `AuditInTxnIT`, `WormSnapshotFreshnessTest`, `AuditHashChainIT`, `AuditRoleIT` |
| Gate evidence | W2 operator-shape gate under prod posture; WORM snapshot for current SHA |
| Status | design_accepted |

## D-block — Posture boot guard (P0-4)

| Field | Value |
|---|---|
| Decision id | PostureBootGuard |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/posture/ARCHITECTURE.md`, `agent-runtime/auth/ARCHITECTURE.md` |
| Implementation paths | `agent-runtime/posture/AppPosture.java`, `DeploymentShape.java`, `PostureBootGuard.java`, `BootCheck.java` |
| Tests | `PostureBootGuardIT`, `IdentityPolicyConsistencyIT` |
| Gate evidence | W0 operator-shape gate confirms boot-fails-on-misconfiguration permutations |
| Status | design_accepted |

## D-block — Tenant spine + RLS connection protocol (P0-3, REM-2026-05-08-3)

| Field | Value |
|---|---|
| Decision id | TenantSpineRLS |
| L1 documents | `agent-runtime/ARCHITECTURE.md`, `agent-platform/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/server/ARCHITECTURE.md`, `agent-runtime/outbox/ARCHITECTURE.md`, `agent-platform/api/ARCHITECTURE.md` |
| Implementation paths | `agent-platform/api/filter/TenantContextFilter.java`, `agent-runtime/server/TenantBinder.java`, `RlsConnectionInterceptor.java`, `HikariConnectionResetPolicy.java`, `agent-runtime/server/migrations/V*__rls_policies.sql` |
| Tests | `TenantBindingIT`, `RlsConnectionIsolationIT`, `CrossTenantEventReadReturns404IT`, `PooledConnectionLeakageIT`, `MissingTenantFailsClosedIT`, `RlsPolicyCoverageTest`, `RlsConnectionAuditTest` |
| Gate evidence | W2 operator-shape gate cross-tenant read returns 404 |
| Status | design_accepted |

## D-block — Financial write classes (P0-10)

| Field | Value |
|---|---|
| Decision id | FinancialWriteClass |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/outbox/ARCHITECTURE.md`, `agent-runtime/audit/ARCHITECTURE.md` |
| Implementation paths | `agent-runtime/outbox/FinancialWriteClass.java`, `WriteSite.java`, `WriteSiteAuditTest.java`, `FinancialWriteCompatibilityTest.java`, `agent-runtime/outbox/SyncSagaOrchestrator.java` |
| Tests | `WriteSiteAuditTest`, `FinancialWriteCompatibilityTest`, `SyncSagaCompensationIT`, `ReversalJournalLinkageIT`, `SagaCrashRecoveryIT` |
| Gate evidence | W3 operator-shape gate; saga compensation correctness recorded |
| Status | design_accepted |

## Contract envelope shape (Rule 4.3 / AD-5)

| Field | Value |
|---|---|
| Decision id | ContractErrorThrowableSplit |
| L1 documents | `agent-platform/ARCHITECTURE.md` |
| L2 documents | `agent-platform/contracts/ARCHITECTURE.md` |
| Implementation paths | `agent-platform/contracts/v1/errors/ContractError.java` (record), `agent-platform/contracts/v1/errors/ContractException.java` (RuntimeException), 7 typed `*Exception.java` files |
| Tests | `ContractFreezeTest`, `ContractSpineCompletenessTest`, `ContractPosturePurityTest`, `ContractThrowablePurityTest`, `ControllerAdviceCoverageTest`, `OpenApiGenerationTest` |
| Gate evidence | W1 build verifies the corpus compiles |
| Status | design_accepted |

## Observability ↔ Audit boundary + Privacy + Cardinality (P0-8 follow-on, REM-2026-05-08-7)

| Field | Value |
|---|---|
| Decision id | ObservabilityAuditBoundary |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/observability/ARCHITECTURE.md`, `agent-runtime/audit/ARCHITECTURE.md`, `docs/observability/cardinality-policy.md` |
| Implementation paths | `agent-runtime/observability/Redactor.java`, `ObservabilityPrivacyPolicy.java`, `SpineEmitter.java` (with failure counter), `agent-runtime/audit/AuditFacade.java` |
| Tests | `NoRawPromptInLogsTest`, `NoPiiInMetricLabelsTest`, `NoRawToolArgsInTracesTest`, `PromptCacheClassificationTest`, `SpineEmitterFailureCounterIT`, `CardinalityBudgetIT` |
| Gate evidence | W2 operator-shape gate runs the privacy suite + asserts spine-emit-failure rate is zero on the happy path |
| Status | design_accepted |

## LLM prompt-security control plane (P0-5, REM-2026-05-08-5)

| Field | Value |
|---|---|
| Decision id | LlmPromptSecurity |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/llm/ARCHITECTURE.md`, `agent-runtime/observability/ARCHITECTURE.md`, `agent-runtime/action-guard/ARCHITECTURE.md` |
| Implementation paths | `agent-runtime/llm/PromptSection.java`, `TaintLevel.java`, `PromptComposer.java`, `PromptCache.java`, `agent-runtime/llm/security/PromptTaintPropagator.java` |
| Tests | `NoRawPromptInLogsTest`, `PromptCacheClassificationTest`, `ToolOutputTaintToActionGuardIT`, `RetrievedContextRedactionIT`, `PromptSectionTaxonomyTest` |
| Gate evidence | W2 operator-shape gate runs the prompt-security suite under research posture with real LLM provider |
| Status | design_accepted |

## Python sidecar security binding (P0-7, REM-2026-05-08-6)

| Field | Value |
|---|---|
| Decision id | SidecarRuntimeSecurity |
| L1 documents | `agent-runtime/ARCHITECTURE.md` |
| L2 documents | `agent-runtime/adapters/ARCHITECTURE.md`, `docs/sidecar-security-profile.md` |
| Implementation paths | `agent-runtime/adapters/PySidecarAdapter.java`, `SidecarTransport.java` (UDS default), `SpiffeIdentityVerifier.java`, `SidecarMetadataValidator.java` (tenant metadata is untrusted), `SidecarPayloadGuard.java` (size + timeout + cancellation) |
| Tests | `SidecarTransportUdsDefaultIT`, `SpiffeIdentityRequiredOnNonLoopbackIT`, `SidecarTenantMetadataIsUntrustedIT`, `SidecarPayloadLimitIT`, `SidecarCancellationPropagationIT`, `SidecarImageDigestPinnedTest` |
| Gate evidence | W2/W4 operator-shape gate; sidecar fallback gate-asserted to zero |
| Status | design_accepted |

---

## Procedure when an L0 decision changes

1. Update the L0 prose in `ARCHITECTURE.md`.
2. Update every affected L2 in the same PR.
3. Update this matrix.
4. Update `architecture-status.yaml` if the change affects status or maturity.
5. PR template requires reviewer to confirm all four items.

`gate/check_architecture_sync.{ps1,sh}` reads this matrix and fails the build when:

- A referenced L2 document is missing.
- A status above the evidence level is claimed (e.g., L0 says "closes" while ledger says `design_accepted`).
- A forbidden closure shortcut from `closure-taxonomy.md` is found.
- Gate path or log extension drift is detected across `gate/README.md`, `docs/delivery/README.md`, `decision-sync-matrix.md`.
