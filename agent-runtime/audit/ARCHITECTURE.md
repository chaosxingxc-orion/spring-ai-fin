# audit — Audit Class Model + WORM Anchoring (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)
>
> **Origin**: created 2026-05-08 in response to security review finding **P0-8**. Audit is broken out of `observability/` into its own L2 because the security boundary between optional telemetry and mandatory regulatory evidence must be sharp.

---

## 1. Purpose & Boundary

`audit/` owns the **classified audit-event model** with class-specific failure semantics. The pre-v6.0-review architecture allowed spine emitters to never raise — appropriate for telemetry, but unsafe for regulatory evidence. The 5-class model (verbatim from the security reviewer) draws the security/telemetry boundary clearly.

Owns:

- `AuditClass` enum: `TELEMETRY / SECURITY_EVENT / REGULATORY_AUDIT / PII_ACCESS / FINANCIAL_ACTION`
- `AuditEntry` — typed audit record with class + spine + payload
- `AuditStore` — Postgres append-only `audit_event` table; class-aware durability
- `AuditFacade` (consumed by `agent-platform/facade/`) — the API surface for audit writes
- `WormAnchor` — daily Merkle root + RFC 3161 timestamp anchoring
- `AuditQueryService` — read-only read path (used by inspector role; integrates with PII dual-approval)

Does NOT own:

- Telemetry log/metric emit (delegated to `../observability/`)
- PII detection itself (delegated to `Presidio` integration in `../audit/PiiRedactor.java`)
- Tokenization service (delegated to `../audit/TokenizationService.java` — also hosted here)

---

## 2. Audit class model

The 5 classes draw the line between best-effort telemetry and mandatory evidence:

| Class | When used | Persistence requirement | Failure behaviour |
|---|---|---|---|
| **TELEMETRY** | Run lifecycle counters, performance metrics, run-event log entries that are also already in `EventStore` | Best-effort | Failure: log-only; emit `springaifin_audit_telemetry_lost_total`; action proceeds |
| **SECURITY_EVENT** | Auth events, ActionGuard rejections, posture override, cross-tenant attempt, idempotency conflict | MUST persist OR block in research/prod | Failure: emit alarm; in prod, action that triggered the event also blocks |
| **REGULATORY_AUDIT** | Bias audit findings, MAS FEAT report data, OJK regulator notification, recurrence-ledger entry | MUST persist AND WORM-anchor in prod | Failure: enter safe read-only mode (block all platform writes); compliance alarm |
| **PII_ACCESS** | PII decode approve, decode execute, decode reveal, decode evict | MUST persist BEFORE reveal | Failure: do NOT reveal plaintext; return error; session ended |
| **FINANCIAL_ACTION** | Fund transfer step, position post, settlement, ledger entry | MUST persist BEFORE commit OR same-txn evidence | Failure: rollback; do not commit |

### Class-aware durability semantics

```java
public class AuditFacade {
    
    public void write(AuditEntry entry) {
        switch (entry.auditClass()) {
            case TELEMETRY -> writeBestEffort(entry);
            case SECURITY_EVENT -> writeOrBlockInProd(entry);
            case REGULATORY_AUDIT -> writeOrSafeReadOnly(entry);
            case PII_ACCESS -> writeBeforeRevealOrDeny(entry);
            case FINANCIAL_ACTION -> writeInTransactionOrRollback(entry);
        }
    }
    
    /** PII_ACCESS: synchronous; blocks PII reveal if write fails. */
    private void writeBeforeRevealOrDeny(AuditEntry entry) {
        try {
            auditStore.appendSync(entry);
        } catch (Exception e) {
            fallbacks.recordFallback(ctx, "audit-pii-access-failed", e);
            throw new AuditWriteFailedException(
                "PII access audit write failed; reveal denied", e);
        }
    }
    
    /** FINANCIAL_ACTION: same-transaction OR fail. */
    @WriteSite(consistency = SYNC_SAGA, financialClass = FINANCIAL_ACTION_DEPENDENT,
               reason = "audit row in same saga step as financial mutation")
    private void writeInTransactionOrRollback(AuditEntry entry) {
        // Caller is in a saga step; this is part of the same DB transaction
        auditStore.appendInTransaction(entry);
    }
}
```

---

## 3. Audit entry shape

```java
public record AuditEntry(
    @NonNull String tenantId,                // spine
    @NonNull String actorUserId,             // spine: who triggered this
    @NonNull String runId,                   // spine
    @Nullable String parentRunId,
    @Nullable String attemptId,
    @NonNull AuditClass auditClass,
    @NonNull String eventType,               // e.g., "pii_decode_approved"
    @NonNull String targetKind,              // e.g., "kyc_record"
    @NonNull String targetId,
    @Nullable String reason,                 // user-provided rationale (PII decode, override etc.)
    @NonNull String evidenceJson,            // structured evidence payload
    @Nullable String policyDecisionId,       // OPA decision id (from ActionGuard stage 7)
    @Nullable String approvalId,             // dual-approval id if PII or FINANCIAL
    @NonNull Instant occurredAt,
    @NonNull String hashChainPrev            // chain anchor for tamper-evidence
) {
    public AuditEntry { /* spine validation */ }
}
```

### hashChainPrev — tamper-evidence

Every audit row carries `hashChainPrev = SHA-256(prev_row_canonical_json)`. This:

1. Detects insertion attacks (modified row breaks hash chain)
2. Provides per-tenant Merkle tree leaves for daily WORM anchor
3. Verifiable by inspector queries

---

## 4. WORM anchor

```java
@Component
public class WormAnchor {
    
    /** Runs daily; anchors per-tenant per-day Merkle root. */
    @Scheduled(cron = "0 0 1 * * *")  // 1 AM daily
    public void anchorDaily() {
        for (var tenantId : tenantRegistry.activeTenants()) {
            try {
                var entries = auditStore.entriesForDay(tenantId, yesterday());
                var merkleRoot = computeMerkleRoot(entries);
                
                // 1. Write to WORM storage (S3 Object Lock or SeaweedFS WORM)
                wormStorage.put(
                    "audit/" + tenantId + "/" + yesterday() + "/merkle-root",
                    merkleRoot,
                    WormPolicy.GOVERNANCE_RETENTION_7Y
                );
                
                // 2. Anchor to RFC 3161 timestamp service (public)
                var timestamp = rfc3161Client.timestamp(merkleRoot);
                wormStorage.put(
                    "audit/" + tenantId + "/" + yesterday() + "/timestamp",
                    timestamp,
                    WormPolicy.GOVERNANCE_RETENTION_7Y
                );
            } catch (Exception e) {
                fallbacks.recordFallback(ctx, "worm-anchor-failed",
                    AuditClass.REGULATORY_AUDIT, e);
                // REGULATORY_AUDIT failure: enter safe read-only mode
                safeModeController.enterSafeReadOnly("worm-anchor-failed", tenantId);
                complianceAlarm.fire("WORM anchor failed for tenant " + tenantId);
            }
        }
    }
}
```

The CI gate `WormSnapshotFreshnessTest` runs at every release HEAD and asserts:

- WORM snapshot exists for yesterday (or last business day)
- Snapshot's RFC 3161 timestamp is valid
- Hash chain integrity verified for a sample of rows

Failure to anchor blocks release.

---

## 5. Inspector access

Regulatory inspector role uses read-only routes:

- `GET /v1/audit/{recordId}` — fetch single audit entry (with cross-tenant authorization)
- `GET /v1/audit/range?from=...&to=...&class=...` — range query
- `POST /v1/audit/decode` — request PII decode (dual-approval workflow)
- `POST /v1/audit/decode/{requestId}/approve` — second approver

Inspector queries themselves emit `AuditClass.SECURITY_EVENT` records (recursive auditing — inspector access is itself audited).

---

## 6. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: 5 audit classes** | TELEMETRY / SECURITY_EVENT / REGULATORY_AUDIT / PII_ACCESS / FINANCIAL_ACTION | Reviewer-recommended; sharply distinguishes telemetry from evidence |
| **AD-2: Class-aware failure semantics** | Each class has explicit failure behaviour | P0-8 closure; "PII decode cannot return plaintext if audit write fails" |
| **AD-3: Audit-before-action for PII/financial** | Synchronous write before reveal/commit | Prevents unprovable actions |
| **AD-4: Hash chain per row** | hashChainPrev links rows in chain | Tamper-evidence at row level |
| **AD-5: Daily Merkle root + RFC 3161 anchor** | Per-tenant per-day Merkle root → public timestamp | Compliance-defensible immutability |
| **AD-6: Safe read-only mode on REGULATORY_AUDIT failure** | Platform enters degraded state | Failure to record evidence = cannot continue regulated operation |
| **AD-7: Postgres append-only role** | `runtime_role` has only INSERT, SELECT on `audit_event` | UPDATE/DELETE forbidden by DB role |
| **AD-8: Inspector access is itself audited** | Recursive SECURITY_EVENT | Closes "who watches the watchers" |
| **AD-9: Audit broken out of observability/** | Separate L2 | Sharp boundary between telemetry and evidence; observability spine emitters can never raise but audit MUST raise on failure |

---

## 7. Cross-cutting hooks

- **Rule 7**: telemetry-class fallbacks emit standard four-prong; SECURITY/REGULATORY/PII/FINANCIAL classes fail-closed
- **Rule 8**: WormSnapshotFreshnessTest is part of operator-shape gate
- **Rule 11**: every audit entry carries spine
- **Rule 14**: WORM anchor IS the manifest-truth foundation for compliance
- **ActionGuard integration**: ActionGuard stage 9 (EvidenceWriter) calls AuditFacade.write with appropriate class

---

## 8. Quality

| Attribute | Target | Verification |
|---|---|---|
| Audit write latency p95 | ≤ 5ms (TELEMETRY); ≤ 20ms (SECURITY/REGULATORY); ≤ 50ms (PII_ACCESS sync); within saga (FINANCIAL) | `tests/integration/AuditWriteLatencyIT` |
| PII reveal blocked on audit failure | yes | `tests/integration/AuditBeforeRevealIT` |
| Financial commit blocked on audit failure | yes | `tests/integration/AuditInTxnIT` |
| WORM anchor daily | yes; alarm if missing | `WormSnapshotFreshnessTest` |
| Hash chain integrity | sample-verified | `tests/integration/AuditHashChainIT` |
| Audit modification by non-maintenance role | rejected at DB role | `tests/integration/AuditRoleIT` |

### Reviewer's acceptance tests (all adopted)

- "PII decode cannot return plaintext if audit write fails" → `AuditBeforeRevealIT`
- "Non-idempotent financial action cannot proceed without evidence record" → `AuditInTxnIT`
- "WORM snapshot failure creates explicit compliance alarm and blocks release gate" → `WormSnapshotFreshnessTest`
- "Audit rows cannot be updated/deleted by runtime role" → `AuditRoleIT`

---

## 9. Risks & Technical Debt

- **WORM storage cost**: 7-year retention for compliance categories; tracked in capacity planning
- **RFC 3161 dependency**: external timestamp service; if unavailable, anchor falls to internal append + alarm
- **Hash chain rebuild**: if a row is corrupted, recovery requires partial chain rebuild + WORM cross-check
- **PII decode TTL**: 15-min plaintext window; after eviction, only audit trail remains; eviction is itself audited
- **Inspector cross-tenant access**: requires regulator authorization JWT claim + audit; reviewer audit at PR

---

## 10. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- ActionGuard (consumer): [`../action-guard/ARCHITECTURE.md`](../action-guard/ARCHITECTURE.md)
- Outbox financial write classes: [`../outbox/ARCHITECTURE.md`](../outbox/ARCHITECTURE.md)
- Security review: [`../../docs/deep-architecture-security-assessment-2026-05-07.en.md`](../../docs/deep-architecture-security-assessment-2026-05-07.en.md) §P0-8
- Response: [`../../docs/security-response-2026-05-08.md`](../../docs/security-response-2026-05-08.md) §P0-8
- RFC 3161: https://datatracker.ietf.org/doc/html/rfc3161
