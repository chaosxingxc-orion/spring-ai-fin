# Security Control Matrix

**Status**: v1 — created 2026-05-08 in response to security review §6.2
**Owner**: Platform team (GOV track)
**Companion docs**: [`trust-boundary-diagram.md`](trust-boundary-diagram.md) · [`gateway-conformance-profile.md`](gateway-conformance-profile.md) · [`sidecar-security-profile.md`](sidecar-security-profile.md) · [`security-response-2026-05-08.md`](security-response-2026-05-08.md)

This matrix maps every named security control to: **owner module · enforcement point · posture behaviour · test name · evidence artifact · failure mode**. Reviewers can audit each row independently.

---

## 1. Authentication & Identity

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| JWT signature validation (HS256) | `agent-runtime/auth/JwtValidator` | Filter chain | dev: optional; research/prod: required (BYOC HS256 carve-out) | `JwtSecurityIT.testHs256Validation` | T3 evidence; gate run | invalid sig → 401 |
| JWT signature validation (RS256/ES256/JWKS) | `agent-runtime/auth/JwksValidator` | Filter chain | research/prod default (SaaS multi-tenant + enterprise BYOC) | `JwtSecurityIT.testRs256Validation` | T3 evidence | invalid sig / kid miss → 401 |
| `alg=none` rejection | JwtAuthFilter | Filter chain | all | `JwtSecurityIT.testAlgNoneRejected` | gate | 401 |
| HS/RS algorithm confusion | JwtAuthFilter | Filter chain | all | `JwtSecurityIT.testAlgConfusion` | gate | 401 |
| `iss` validation | JwksValidator | Per-issuer allowlist | research/prod | `JwtSecurityIT.testIssuerValidation` | gate | 401 wrong issuer |
| `aud` validation | JwksValidator | Platform `aud` constant | research/prod | `JwtSecurityIT.testAudienceValidation` | gate | 401 wrong audience |
| `exp/nbf/iat` validation | JwksValidator | Standard claims | all | `JwtSecurityIT.testTimeValidation` | gate | 401 expired/not-yet-valid |
| `kid` rotation cache | JwksValidator | TTL ≤ 1h cache | research/prod | `JwtSecurityIT.testKidRotation` | log | refetch on miss |
| Token replay (`jti` tracking) | JwksValidator | Per-tenant `jti` cache (deferred to v1.1) | n/a v1; prod v1.1 | `JwtReplayIT` (v1.1) | v1.1 deliverable | – |
| Tenant header binding | `JwtAuthFilter` + `TenantContextFilter` | Filter chain | dev: warn; research/prod: 401 mismatch | `TenantBindingIT` | gate | 400 TenantScopeException |

## 2. Authorization (Role + Tenant)

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| Capability RBAC | `agent-runtime/capability/CapabilityPolicy` | ActionGuard stage 3 | all (strict in research/prod) | `ActorAuthorizerIT` | gate | reject + SECURITY_EVENT |
| Tenant entitlement | `agent-runtime/capability/TenantEntitlementStore` | ActionGuard stage 3 | all (strict in research/prod) | `TenantEntitlementIT` | gate | reject + SECURITY_EVENT |
| Default-deny | ActionGuard | All stages | all | `ActionGuardDefaultDenyIT` | gate | reject |
| OPA red-line policy | `agent-runtime/action-guard/OpaPolicyDecider` | ActionGuard stage 7 | all | `OpaPolicyIT` | policy decision id in audit | reject + SECURITY_EVENT |
| HITL gate (irreversible action) | `agent-runtime/action-guard/HitlGate` | ActionGuard stage 8 | research/prod fail-closed | `HitlGateIT` | PauseToken + audit | wait or reject |
| Posture-aware capability | `CapabilityDescriptor.availableInProd/Research/Dev` | ActionGuard stage 4 | per-posture | `MaturityCheckerIT` | gate | reject 400 |

## 3. Tenant Isolation

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| `TenantContextFilter` validates `X-Tenant-Id` matches JWT claim | `agent-platform/api/filter/TenantContextFilter` | Filter chain | dev: warn; research/prod: 401 | `TenantBindingIT` | gate | 401 / 400 |
| Postgres RLS (`current_setting('app.tenant_id')`) | `agent-runtime/server/TenantContextDataSource` | DB session-var per transaction | all postures | `RlsConnectionPoolIT` | DB-level test | query returns 0 rows / fail closed |
| `SET LOCAL app.tenant_id` per transaction | `TenantContextDataSource` | JDBC interceptor | all postures | `RlsConnectionPoolIT.testSetLocal` | test log | fail-closed if missing |
| Connection check-in reset | HikariCP `connectionInitSql` | Pool lifecycle | all | `RlsConnectionPoolIT.testReset` | test | fail closed on next use |
| No DB access outside tenant-scoped txn | AOP `TenantContextAspect` | research/prod | research/prod | `RlsConnectionPoolIT.testFailClosed` | gate | exception |
| Outbox relay tenant scope | `agent-runtime/outbox/OutboxRelayTenantScope` | Per-batch tenant SET | all | `OutboxRelayTenantScopeIT` | metric | rejected event publish |
| SSE tenant filter | `agent-platform/api/RunsExtendedController` | Query at `iterEvents` | all | `SseTenantIsolationIT` | test | 404 cross-tenant |
| Valkey cache key prefix | `agent-runtime/llm/PromptCache` | Key pattern `tenant:{tenantId}:` | all | `CacheTenantIsolationIT` | test | 404 cross-tenant |
| Sidecar gRPC tenant in payload | `agent-runtime/adapters/PySidecarAdapter` | Required field validation | all | `SidecarSecurityIT.testTenantInPayload` | test | reject |

## 4. Action Authorization (the central control)

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| ActionGuard pipeline (10 stages) | `agent-runtime/action-guard/ActionGuard` | Mandatory side-effect boundary | all | `ActionGuardCoverageTest` | CI gate | reject + audit |
| ActionEnvelope spine validation | `ActionEnvelope.@PostConstruct` | Constructor | all | `ActionEnvelopeValidationIT` | test | reject |
| argumentsHash anti-tampering | `SchemaValidator` | Re-hash check | all | `ArgumentsHashIT` | test | reject |
| Source taint propagation | `agent-runtime/llm/PromptComposer` | Prompt section taxonomy | all | `PromptSecurityIT` | gate | reject untrusted instruction |
| Tool call from LLM_OUTPUT taint check | ActionGuard | Stage 7 OPA | all (strict in research/prod) | `PromptSecurityIT.testTaintToToolCall` | gate | reject |

## 5. Data Protection

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| PII detection (Presidio) | `agent-runtime/audit/PiiRedactor` | Ingress + log emit + cache write | all | `PiiDetectionIT` | gate | tokenize/redact |
| Format-preserving tokenization | `agent-runtime/audit/TokenizationService` | At write | all | `TokenizationIT` | test | error |
| PII decode dual-approval | `AuditFacade.requestDecode` + `.approve` | Workflow | research/prod required | `PiiDecodeIT` | audit | reject single-role |
| PII decode 15-min TTL | `agent-runtime/audit/AuditFacade` | Cache eviction | all | `PiiDecodeTtlIT` | test | data evicted |
| Audit-before-PII-reveal | `AuditFacade.writeBeforeRevealOrDeny` | Synchronous | all | `AuditBeforeRevealIT` | test | deny on audit failure |
| Encryption at rest (Postgres pgcrypto) | DB schema | Sensitive columns | research/prod | `EncryptionAtRestIT` | DB-level | error |
| Disk encryption (AES-256) | OS / cloud | Storage layer | research/prod | deployment evidence | infra | n/a |

## 6. Audit & Evidence

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| 5 audit classes | `AuditClass` enum | Required on every `AuditEntry` | all | `AuditClassIT` | test | reject |
| TELEMETRY best-effort | `AuditFacade.writeBestEffort` | Async OK | all | `AuditTelemetryIT` | metric | log + counter |
| SECURITY_EVENT must persist | `AuditFacade.writeOrBlockInProd` | Sync research/prod | research/prod | `AuditSecurityEventIT` | test | block action |
| REGULATORY_AUDIT must WORM-anchor | `WormAnchor` | Daily + sync write | research/prod | `WormSnapshotFreshnessTest` | gate | safe read-only mode |
| PII_ACCESS audit-before-reveal | `AuditFacade.writeBeforeRevealOrDeny` | Sync | all | `AuditBeforeRevealIT` | test | deny |
| FINANCIAL_ACTION in-txn evidence | `AuditFacade.writeInTransactionOrRollback` | Same Postgres txn | all | `AuditInTxnIT` | test | rollback |
| Hash chain integrity | `AuditEntry.hashChainPrev` | Per-row | all | `AuditHashChainIT` | test | tamper-evident |
| WORM daily Merkle root + RFC 3161 | `WormAnchor` | Cron 1AM | research/prod | `WormSnapshotFreshnessTest` | gate | safe read-only |
| Audit DB role append-only | Postgres GRANT | INSERT, SELECT only on `audit_event` | research/prod | `AuditRoleIT` | DB-level | UPDATE/DELETE rejected |
| Inspector access audited recursively | `AuditQueryService` | Self-emit SECURITY_EVENT | all | `InspectorAuditRecursionIT` | audit | log |

## 7. LLM & Prompt Security

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| Prompt section taxonomy | `agent-runtime/llm/PromptComposer` | Composition step | all | `PromptSecurityIT` | gate | reject |
| Untrusted-section markers | PromptComposer | At assembly | all | `PromptSecurityIT.testMarkers` | gate | LLM treats as data |
| Tool-call JSON schema validation | `agent-runtime/llm/OutputValidator` | Post-generation | all | `PromptSecurityIT.testToolCallSchema` | gate | reject malformed |
| Tool name registered check | OutputValidator | Capability registry lookup | all | `PromptSecurityIT.testUnregisteredTool` | gate | reject |
| Hidden-prompt detector | OutputValidator | Heuristic scan | all | `PromptSecurityIT.testHiddenPrompt` | gate | flag + redact |
| Sensitive-output filter | OutputValidator | Pre-return PII regex | all | `PromptSecurityIT.testSensitiveOutput` | gate | redact |
| Prompt cache PII redaction | `PromptCache` | Pre-cache write | all | `PromptCachePiiIT` | gate | strip PII |
| Prompt cache classification | `PromptCache` | Per-section policy | all | `PromptCacheClassificationIT` | gate | non-cacheable for User/Retrieved |
| Prompt cache TTL per data class | `PromptCache` | TTL config | all | `PromptCacheTtlIT` | test | eviction |
| Prompt cache encryption at rest | Postgres pgcrypto | Storage | research/prod | `PromptCacheEncryptionIT` | DB-level | error |

## 8. Skill / MCP / Capability Governance

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| Skill load-time dangerous-capability gate | `agent-runtime/skill/SkillLoader` | Boot-time | research/prod fail-closed | `DangerousCapabilityIT` | boot test | reject |
| Skill runtime authorization (ActionGuard) | ActionGuard | Per-call | all | `SkillRuntimeAuthIT` | gate | reject |
| Skill `allowed_tenants` check | ActionGuard stage 2 | Per-call | all | `SkillRuntimeAuthIT.testTenantAllowed` | test | reject |
| Skill `allowed_roles` check | ActionGuard stage 3 | Per-call | all | `SkillRuntimeAuthIT.testRoleAllowed` | test | reject |
| Skill `egress_domains` allowlist | `agent-runtime/skill/SkillEgressFilter` | Per-call HTTP wrapper | all | `SkillRuntimeAuthIT.testEgress` | test | block |
| Skill `filesystem_scope` | `agent-runtime/skill/SkillSandbox` | Per-call sandbox | all | `SkillRuntimeAuthIT.testFsScope` | test | block |
| Skill `max_runtime_ms` | CapabilityInvoker | Timeout | all | `SkillTimeoutIT` | test | timeout |
| Skill `max_output_bytes` | OutputValidator | Truncation | all | `SkillOutputSizeIT` | test | truncate + flag |
| Skill secret redaction | OutputValidator | Pre-output filter | all | `SkillSecretRedactionIT` | test | redact |
| Skill evidence record | EvidenceWriter | Post-execution | all | `SkillEvidenceIT` | test | written |
| Capability circuit breaker | `CapabilityInvoker.CircuitBreaker` | OPEN/HALF_OPEN/CLOSED | all | `CircuitBreakerStateTest` | test | reject when OPEN |

## 9. Sidecar (Python) Security

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| mTLS (TCP) or Unix socket 0600 (local) | `PySidecarAdapter` | gRPC channel config | all (research/prod required for non-loopback) | `SidecarSecurityIT.testMtls` | gate | reject |
| Workload identity verification | PySidecarAdapter | Per-call | all | `SidecarSecurityIT.testIdentity` | test | reject |
| Per-tenant sidecar OR strict tenant validation | PySidecarAdapter | Per-call payload | all | `SidecarSecurityIT.testTenantPayload` | test | reject |
| Max message size | gRPC config | 4MB req / 16MB resp | all | `SidecarSecurityIT.testMaxSize` | test | reject |
| Deadline (60s default) | PySidecarAdapter | Per-call | all | `SidecarSecurityIT.testDeadline` | test | DEADLINE_EXCEEDED |
| Cancellation contract | gRPC stream cancel | Bidirectional | all | `SidecarSecurityIT.testCancel` | test | propagate |
| Egress allowlist (container netpol) | Container runtime | Network policy | research/prod | `SidecarSecurityIT.testEgress` | infra | block |
| Read-only container fs | Container runtime | RO mount | research/prod | infra | – | enforce |
| AppArmor / seccomp profile | Container runtime | Per-pod | research/prod | infra | – | enforce |
| Image SBOM signed | CI (cosign) | At build | all (verified at runtime in research/prod) | `SidecarImageSignatureIT` | gate | reject deploy |
| Image vulnerability scan | CI (Trivy) | At push | all (CVSS≥7 blocks release) | CI gate | gate | reject release |

## 10. Gateway Conformance

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| OAuth2 / JWT verification | Gateway (Higress / substitute) | At edge | all | `GatewayConformanceIT.testJwt` | gateway log | reject |
| mTLS option | Gateway | Configurable | all | `GatewayConformanceIT.testMtls` | gateway log | reject |
| Tenant header normalization | Gateway | Strip + re-inject | all | `GatewayConformanceIT.testTenantHeader` | test | not spoofable |
| `X-Internal-Trust` HMAC | Gateway → Platform | Validated by platform | all | `GatewayConformanceIT.testInternalTrust` | gate | reject |
| Rate limit by tenant/user/capability | Gateway | At edge | all | `GatewayRateLimitIT` | gateway metric | 429 |
| Body size limits | Gateway | At edge (default 8MB) | all | `GatewayBodySizeIT` | gateway log | 413 |
| SSE concurrency limit | Gateway | Per tenant | all | `GatewaySseLimitIT` | gateway metric | 429 |
| OPA red-line at edge | Gateway | Pre-platform | all | `GatewayOpaIT` | gateway log + audit | reject |
| `/diagnostics` IP allowlist | Gateway | Per env | all | `GatewayDiagnosticsAclIT` | gateway log | 403 |
| Structured access logs | Gateway | Per request | all | `GatewayLogFormatIT` | log shape | reject deploy if missing |
| Platform `/ready` requires conformance | `agent-platform/api/ReadinessController` | At boot | research/prod | `GatewayConformanceIT.testReady` | gate | not-ready |

## 11. Posture Boot Guard

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| Non-loopback bind without `APP_POSTURE` | `agent-runtime/posture/PostureBootGuard` | Boot-time | n/a | `PostureBootGuardIT.testNonLoopback` | boot test | fail boot |
| `dev` posture with real LLM | PostureBootGuard | Boot-time | n/a | `PostureBootGuardIT.testRealLlm` | boot test | fail boot unless override |
| `dev` posture with real DB | PostureBootGuard | Boot-time | n/a | `PostureBootGuardIT.testRealDb` | boot test | fail boot unless override |
| `dev` posture with sidecar | PostureBootGuard | Boot-time | n/a | `PostureBootGuardIT.testSidecar` | boot test | fail boot unless override |
| Posture exposed in `/ready` | ReadinessController | Per request | all | `ReadinessPostureIT` | test | shown |
| Posture exposed in `/v1/manifest` | ManifestController | Per request | all | `ManifestPostureIT` | test | shown |
| Startup banner shows posture | bootstrap | At boot | all | inspection | log | shown |
| `springaifin_app_posture{posture}` metric | observability | Continuous | all | `MetricPostureIT` | metric | n/a |

## 12. Financial Write Discipline

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| `@WriteSite` annotation required | `agent-runtime/runtime/WriteSiteAuditTest` | CI reflective | all | CI gate | gate | reject build |
| `LEDGER_ATOMIC` only on `DIRECT_DB` | WriteSiteAuditTest | CI | all | gate | gate | reject build |
| `SAGA_COMPENSATED` on `SYNC_SAGA` | WriteSiteAuditTest | CI | all | gate | gate | reject build |
| `FINANCIAL_ACTION` audit class | `outbox/SyncSagaOrchestrator` | Per saga step | all | `FinancialWriteIT` | test | rollback if audit fails |
| Saga compensation failure → OperationalGate | SyncSagaOrchestrator | On compensation failure | all | `SagaCompensationFailureIT` | test | escalate |
| LedgerDiscrepancyRecord on compensation failure | SyncSagaOrchestrator | Durable record | all | `SagaCompensationFailureIT.testRecord` | test | recorded |
| Daily 3-way reconciliation | `agent-runtime/audit/Reconciliation` | Cron | research/prod | `ReconciliationIT` | gate | alarm |

## 13. Operator CLI

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| Operator JWT required | `agent-platform/cli/CliApp` | At command | all (loopback can use anonymous in dev) | `OperatorCliAuthIT` | test | reject |
| Loopback default | CliApp | Bind config | all | inspection | – | n/a |
| mTLS for remote | CliApp | TLS config | research/prod | `OperatorCliMtlsIT` | test | reject |
| CLI command audit | AuditFacade | Per command (SECURITY_EVENT) | all | `OperatorCliAuditIT` | audit | log |
| Role separation (no PII decode) | CliApp + CapabilityPolicy | Per command | all | `OperatorCliRoleIT` | test | reject |
| Cross-tenant dual-approval | CliApp | Per command | research/prod | `OperatorCliCrossTenantIT` | audit | reject single-role |
| Output redaction default | CliApp | Output filter | all | `OperatorCliRedactionIT` | test | redacted |

## 14. Observability Privacy

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| Log redaction (Presidio) | `agent-runtime/observability/LogRedactor` | At log emit | all | `LogRedactionIT` | test | redacted |
| Trace attribute allowlist | `agent-runtime/observability/TraceAttributeFilter` | At span | all | `TraceAttributeIT` | test | dropped |
| No raw prompt in metrics/logs | LogRedactor + TraceAttributeFilter | At emit | all | `NoRawPromptIT` | test | redacted |
| Tenant ID hashing for metrics (ops-side) | PromQL recording rules | Storage layer | research/prod | docs/observability/cardinality-policy.md | infra | n/a |
| Secure debug mode | `agent-platform/api/DebugFilter` | Dual-approval token | research/prod | `SecureDebugIT` | audit | requires SECURITY_EVENT + dual-approval |

## 15. Secrets & Supply Chain

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| OpenBao primary | `agent-runtime/auth` integration | Boot + rotation | research/prod | `SecretsLifecycleIT` | infra | error |
| Kubernetes Secrets fallback | infra | Boot | research/prod | infra | infra | n/a |
| HMAC rotation 90-day | `WormAnchor` cron | Per cadence | research/prod | `SecretRotationIT` | gate | alarm if stale |
| DB credential rotation 30-day | infra | Per cadence | research/prod | `SecretRotationIT` | gate | alarm if stale |
| Memory scrubbing for secrets | `char[]` zero-after-use | At handler | all | `SecretMemoryIT` | test | n/a |
| No secret logging | LogRedactor | At log emit | all | `NoSecretLogIT` | test | redacted |
| Break-glass workflow | dual-approval | per incident | research/prod | `BreakGlassIT` | audit | requires SECURITY_EVENT |
| Maven dependency pinning | `pom.xml` | Build | all | `DepPinningIT` | gate | reject build with `LATEST` |
| SBOM generation (CycloneDX) | CI build | At build | all | `SbomGenerationIT` | artifact | gate |
| Vulnerability scanning (OWASP DC) | CI | At build | all | CI gate | gate | reject CVSS≥7 |
| Container vulnerability scan (Trivy) | CI | At push | all | CI gate | gate | reject CVSS≥7 |
| Provenance via SLSA Level 2 | CI | At build | all | `SlsaProvenanceIT` | attestation | gate |

## 16. Idempotency Abuse Controls

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| Per-tenant idempotency rate limit | `IdempotencyStore` | At reserve | all | `IdempotencyRateLimitIT` | metric | 429 |
| Max key length 256 | IdempotencyStore | Validation | all | `IdempotencyKeyLengthIT` | test | reject |
| Replay snapshot size limit 1MB | IdempotencyStore | At store | all | `IdempotencySnapshotSizeIT` | test | reject |
| Encrypted snapshot (sensitive tenants) | Postgres pgcrypto | Storage | configurable | `IdempotencyEncryptionIT` | test | n/a |
| Conflict telemetry | observability | Counter | all | `IdempotencyConflictIT` | metric | alarm at threshold |
| Purge backpressure alarm | LifespanController purge loop | Per loop | all | `IdempotencyBackpressureIT` | metric | alarm if backlog>10K |

## 17. Memory & Knowledge Poisoning

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| `source_provenance` mandatory | `MemoryRecord.@PostConstruct` | Constructor | all | `MemorySpineIT` | test | SpineCompletenessException |
| `trust_level` mandatory | MemoryRecord constructor | Constructor | all | `MemorySpineIT` | test | reject |
| Write authorization | ActionGuard | At write | all | `MemoryWriteAuthIT` | gate | reject |
| Poisoning detection (heuristic) | `agent-runtime/memory/PoisoningDetector` | At write | research opt-in | `PoisoningDetectionIT` | metric | quarantine |
| Quarantine table | MemoryStore | At detection | all | `QuarantineIT` | test | excluded from retrieval |
| "do not use as instruction" marker | PromptComposer integration | At prompt assembly | all | `MemoryNotInstructionIT` | test | wrapped UNTRUSTED |
| Tenant-scoped deletion | MemoryStore | Per request | all | `MemoryTenantDeletionIT` | test | row removal |

## 18. External Agent (A2A) Inbound

| Control | Owner | Enforcement | Posture | Test | Evidence | Failure mode |
|---|---|---|---|---|---|---|
| mTLS identity required | `agent-platform/api/A2aFilter` (v1.1) | At ingress | research/prod required v1.1 | `A2aMtlsIT` (v1.1) | test | reject |
| Static external-agent registry | `agent-platform/contracts/v1/external_agent.yaml` | At registry lookup | all | `A2aRegistryIT` (v1.1) | test | reject unknown |
| Recursion depth limit | RunExecutor | Per run | all | `A2aRecursionIT` | test | reject depth>3 |
| Per-call budget limit | BudgetTracker | Per A2A call | all | `A2aBudgetIT` | test | exception |
| External agent audit (SECURITY_EVENT) | AuditFacade | Per inbound call | all | `A2aAuditIT` | audit | log |

---

## 19. How to use this matrix

### For reviewers

Pick a row. The row tells you:
- **What is enforced** (the control)
- **Where in code** (owner module + enforcement point)
- **Under which conditions** (posture)
- **How to verify** (test name)
- **What evidence is produced** (artifact)
- **What happens on failure** (failure mode)

If the test doesn't exist → P0 not closed.
If the failure mode is unspecified → P0 not closed.
If the posture column is empty → P0 not closed.

### For implementers

Pick a row. The row tells you:
- **What you must implement** (control)
- **Where to implement it** (owner module)
- **What test to write** (test name)
- **What artifact to produce** (evidence)

When the implementation lands, the test must exist; the evidence must be produced; the failure mode must be testable.

### For release captain

The matrix is the source of truth for the W2.5 security gate. Wave 2.5 release notice cites:
- Total controls: ~150
- Implemented: count
- Tested: count (must equal implemented for green)
- In-prod (research/prod fail-closed): count
- WARN-only (dev permissive paths): count

If `implemented < tested` → release blocker.
If any P0-derived row is missing → release blocker.

---

## 20. Maintenance

This matrix is owned by the GOV track. Per-row changes require:

1. PR with row update
2. Linked test file
3. Linked evidence artifact specification
4. Reviewer audit on every PR

`SecurityControlMatrixLinter` runs in CI to assert:
- Every row has all 6 columns populated
- Every test name resolves to a real test class
- Every owner module exists
- Every enforcement point is at a known boundary

This is a binding governance artefact, not documentation.
