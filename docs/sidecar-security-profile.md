# Python Sidecar Security Profile

**Status**: v1 — created 2026-05-08 in response to security review §P0-7
**Owner**: Platform team (RO) + Customer infrastructure team
**Companion**: [`security-control-matrix.md`](security-control-matrix.md) §9 · [`agent-runtime/adapters/ARCHITECTURE.md`](../agent-runtime/adapters/ARCHITECTURE.md)

This profile defines the security controls for the out-of-process Python sidecar that hosts mainstream Python agent frameworks (LangGraph, CrewAI, AutoGen, Pydantic-AI, OpenAI Agents SDK). The sidecar is opt-in at customer discretion; this profile is binding when adopted.

---

## 1. Threat model

The sidecar is a high-risk execution environment because it bridges:

- Model output (potentially adversarial)
- Tool invocation (side-effectful)
- Customer data (per-tenant isolation required)
- Network access (egress to LLM providers + tool servers)
- Framework-specific plugins (large dependency tree; heterogeneous trust)

Failure modes:
- **Tenant leak via gRPC metadata loss** (Attack Path B): sidecar drops `tenantId` while streaming events
- **Image supply-chain compromise**: malicious package in framework dependency
- **Egress to attacker infrastructure**: sidecar makes outbound to attacker IP
- **Resource exhaustion**: oversized payload OOMs sidecar; affects JVM via shared resource (e.g., Unix socket buffer)
- **Identity spoofing**: rogue process pretends to be sidecar

---

## 2. Required controls

### 2.1 Transport

- **Local default**: gRPC over Unix Domain Socket (UDS); socket file permission `0600`; owner = service account running both JVM and sidecar
- **Network**: gRPC over TLS 1.3; mTLS REQUIRED (no plain TCP)
- **No transport auto-fallback**: configuration explicitly chooses UDS or mTLS; no plain TCP path

### 2.2 Identity

- **SPIFFE-style workload identity** (preferred):
  - Sidecar carries SVID issued by SPIRE or equivalent
  - JVM verifies SVID at every gRPC connection
  - Identity carries `spiffe://platform/sidecar/<tenant-or-shared>`
- **Static service account fallback**:
  - Sidecar runs as `springaifin-sidecar` user (non-root)
  - JVM verifies process identity via Unix socket peer-cred check
  - Single shared sidecar across tenants requires payload-level tenant validation (§2.4)

### 2.3 Tenant isolation models

| Mode | Description | Use case |
|---|---|---|
| **Per-tenant sidecar** | One sidecar process per tenant; lifecycle managed per tenant | High-isolation BYOC; tenant can supply own Python framework dependencies |
| **Shared sidecar with payload validation** | One sidecar serves multiple tenants; tenantId required in every gRPC payload; round-trip validated | Resource-efficient SaaS multi-tenant |

Both modes MUST validate `tenantId` in payload, not just metadata (Attack Path B fix).

### 2.4 Payload validation

- **Required fields** in every gRPC request:
  - `tenant_id` (mandatory; rejected if missing or doesn't match expected)
  - `run_id` (mandatory)
  - `idempotency_key` (recommended)
- **Required fields** in every gRPC response/stream event:
  - `tenant_id` (mandatory; round-trip validated by JVM)
  - `run_id` (mandatory)
- **Schema validation**: every gRPC message validated against published `.proto` schema; unknown fields rejected (proto3 with `option deprecated_unknown_fields = strict`)

### 2.5 Resource limits

- **Max gRPC message size**: 4MB request, 16MB response (configurable per workload)
- **Deadline**: 60s default, 300s max (configurable)
- **Stream cancellation**: gRPC stream cancel propagates to Python framework cancellation (best-effort + deadline-bound)
- **Concurrent calls**: max 100 concurrent calls per sidecar instance; backpressure on exceedance

### 2.6 Container runtime

- **Image source**: `springaifin/py-sidecar:<version>` from official platform registry; verified at deployment
- **Read-only container filesystem**: writable only `/tmp` (with size limit) and explicit volume mounts
- **No default host filesystem mount**: customer explicitly mounts only what's needed
- **Drop all Linux capabilities**: add only required ones (none for typical workloads)
- **AppArmor profile**: `springaifin-sidecar-restricted` (LSM enforcement); seccomp profile applied
- **User**: non-root (`uid=10001`, `gid=10001`)
- **Network policy**: egress allowlist (default deny; allow only LLM provider domains + tool servers documented in customer's egress-policy.yaml)

### 2.7 Image supply chain

- **SBOM**: CycloneDX SBOM generated at build; published with image
- **Signature**: image signed with cosign; signature verified at deployment via `cosign verify-blob`
- **Pinned base image**: `python:3.12-slim-bookworm@sha256:...` (specific digest, not tag)
- **Vulnerability scan**: Trivy at CI; CVSS ≥ 7.0 blocks release; CVSS ≥ 4.0 + exploit-available blocks release
- **Provenance attestation**: SLSA Level 2 build provenance signed and stored

### 2.8 Sidecar process lifecycle

- **Health check**: `Health` gRPC method returns `SERVING` or `NOT_SERVING`
- **Crash isolation**: sidecar crash does not affect JVM; container restart by orchestrator (Kubernetes / Docker)
- **No partial-result leak**: sidecar crash mid-stream causes `RST_STREAM`; JVM marks run as `FAILED_AWAITING_RECOVERY`; in-flight events for the run discarded; never propagated to other runs
- **Graceful shutdown**: SIGTERM → drain in-flight calls (60s); reject new calls; SIGKILL after timeout

---

## 3. Verification at runtime

JVM `PySidecarAdapter` verifies on every connection:

```java
public AdapterRunHandle start(TaskContract task, RunContext ctx) {
    // 1. Verify sidecar identity
    var spiffeId = sidecarIdentityVerifier.verify(channel);
    if (!allowedSidecarIdentities.contains(spiffeId)) {
        throw new SidecarIdentityException(spiffeId);
    }
    
    // 2. Build request with mandatory tenantId in payload
    var request = StartRunRequest.newBuilder()
        .setTaskJson(task.toJson())
        .setTenantId(ctx.tenantContext().tenantId())   // mandatory
        .setRunId(ctx.runId().toString())              // mandatory
        .build();
    
    // 3. Validate response payloads in stream
    var stream = stub.startRun(request, deadline(60_000));
    return new PySidecarRunHandle(stream, ctx.tenantContext().tenantId());
}

// PySidecarRunHandle.events() validates each event's tenantId == expected
public Flux<StageEvent> events(AdapterRunHandle handle) {
    return ((PySidecarRunHandle) handle).flux()
        .map(event -> {
            if (!event.getTenantId().equals(handle.expectedTenantId())) {
                fallbacks.recordFallback(ctx, "sidecar-tenant-mismatch");
                auditFacade.write(SECURITY_EVENT, "sidecar_tenant_mismatch");
                throw new SidecarTenantMismatchException(event);
            }
            return translateToStageEvent(event);
        });
}
```

---

## 4. Reviewer's acceptance tests (addresses P0-7; status: design_accepted)

| Test | Expected |
|---|---|
| `SidecarSecurityIT.testUnauthenticatedSidecarCannotCallBack` | Rogue process opens UDS but lacks identity → JVM rejects |
| `SidecarSecurityIT.testIdentityVerificationRequired` | JVM cannot dispatch without SPIFFE/peer-cred verification |
| `SidecarSecurityIT.testEgressToInternalNetwork` | Sidecar attempts curl to internal RFC 1918 IP → blocked by netpol |
| `SidecarSecurityIT.testOversizedGrpcPayload` | 100MB request → REJECTED with RESOURCE_EXHAUSTED |
| `SidecarSecurityIT.testMissingTenantIdInPayload` | gRPC request without tenantId → REJECTED |
| `SidecarSecurityIT.testCrashDoesNotLeakBetweenRuns` | Sidecar SIGKILL mid-stream; in-flight events discarded; next run starts clean |

---

## 5. Customer deployment checklist

For BYOC customers adopting Python sidecar:

- [ ] Deploy sidecar container with `springaifin/py-sidecar:<pinned-version>`
- [ ] Configure mTLS or UDS transport (no plain TCP)
- [ ] Configure SPIFFE workload identity OR static service account
- [ ] Apply AppArmor profile `springaifin-sidecar-restricted`
- [ ] Apply Kubernetes NetworkPolicy with egress allowlist
- [ ] Configure read-only filesystem with explicit mounts only
- [ ] Verify image signature with cosign
- [ ] Run vulnerability scan (Trivy) — pass at deploy time
- [ ] Set sidecar's `MAX_TENANT_PER_INSTANCE` (per-tenant=1 OR shared with payload validation)
- [ ] Verify SBOM matches published platform SBOM
- [ ] Configure `/health` endpoint accessible to orchestrator only
- [ ] Set graceful shutdown timeout 60s

---

## 6. Maintenance

This profile is owned by platform team (RO) + customer infrastructure team. Updates:

- New Python framework added to sidecar → image version bump + SBOM update + customer notification
- gRPC schema change → new minor version of sidecar; backward-compatible only
- AppArmor/seccomp profile change → reviewed by security team

`SidecarSecurityProfileLinter` runs in CI to assert:
- All controls in §2 have corresponding test in `SidecarSecurityIT`
- Image build pipeline produces signed SBOM
- Customer attestation schema is valid
