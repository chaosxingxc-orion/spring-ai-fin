# 0052. Skill Topology Scheduler and Capability Bidding

**Status:** accepted
**Deciders:** architecture, chaos.xing.xc@gmail.com
**Date:** 2026-05-13
**Technical story:** Reviewer finding P1-1 (`docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md`): the whitepaper §4.1 requires a global Skill Topology Scheduler with prediction and saturation queuing; §5.3 requires pre-authorized capability access, bidding, and explicit permission issuance to delegates. The current Skill SPI design (ADR-0030 lifecycle, ADR-0038 resource-tier classification) is a Java SPI shape, **NOT** a distributed scheduling and bidding contract. This ADR adds the missing topology scheduler + bidding + permission issuance vocabulary at L0 contract level. Java types deferred to W2+.

## Context

Whitepaper §4.1:

> "Skill-Dimensional Resource Pooling: The S-side must establish a global 'Skill Topology Scheduler'. Every heavyweight tool (e.g., commercial registry lookup API, memory-intensive internal video analysis algorithm) is abstracted as an independent resource pool."
>
> "Prediction and Queuing: When the C-side initiates a 100-step long-horizon `Run` request, the S-side should predict the request's dependency weight on specific underlying Skills prior to scheduling. If the concurrency quota for the 'Enterprise Registry Lookup Skill' is currently full, the scheduler should only suspend and queue the specific agent instance dependent on that Skill, rather than blindly occupying LLM inference threads, and certainly not starving other lightweight agents under the same tenant."
>
> "Deepening Multi-Tenant Isolation: Resource arbitration must be two-dimensional — the horizontal axis is the 'Tenant Quota', and the vertical axis is the 'Global Skill Capacity'."

Whitepaper §5.3:

> "Capability Intent Registration and Pre-Authorized Isolation: Agents register their tags with the bus's capability center (Registry) upon startup. However, to prevent untrusted nodes from stealing task contexts, the registry implements a 'Pre-Authorized Access System'. Capability tags must be bound to domain permission identifiers granted by the underlying S-side."
>
> "Delegate Bidding System: When the S-side master agent throws an `IntentEvent(capability='code_audit')` onto the bus, not all nodes can grab the order. Only 'Swarm Delegates' holding the pre-authorized identifier for that domain are qualified to participate in the bidding response."
>
> "Cascading Issuance of Collaborative Permissions: After bidding concludes, the S-side not only hands over the task cursor but also rigidly issues the 'specific work permissions (Action/Tool Permission)' required for the task to the winning delegate."

The reviewer observed that current ADR-0030 (Skill SPI lifecycle: init/execute/suspend/teardown + `SkillResourceMatrix` + `SkillTrustTier`) is a useful Java SPI shape but does NOT express the distributed scheduling, bidding, or permission-issuance contracts the whitepaper requires. ADR-0038 (resource-tier classification) refined the matrix but is still Java-SPI-shaped.

This ADR is the missing distributed contract layer above the Java SPI.

## Decision Drivers

- Reviewer P1-1: the architecture must distinguish "a Java SPI for skills" from "a distributed skill resource scheduler"; both must exist.
- Tenant quota and global skill capacity must both be represented (two-axis arbitration).
- Permission issuance to delegates must be explicit and traceable (auditable security boundary).
- Skill saturation must yield only the dependent agent step, not consume LLM inference threads.

## Considered Options

1. **Add ADR-0052 introducing topology scheduler + bidding + permission issuance; cross-reference from ADR-0030 / ADR-0038** (this decision).
2. **Update ADR-0030/0038 in place** — rejected: the distributed scheduling contract is a distinct decision layer; a dedicated ADR is cleaner for review and reference.
3. **Defer to W2 implementation** — rejected: leaves L0 silent on the central whitepaper scheduling concept; permits drift.

## Decision Outcome

**Chosen option:** Option 1.

### Topology scheduler contracts

The platform recognizes **two arbitration axes** (whitepaper §4.1 deepening multi-tenant isolation):

- **Horizontal axis: Tenant Quota** — per-tenant caps on total Run concurrency, total tokens/wall-clock/$ per hour, per-skill quotas.
- **Vertical axis: Global Skill Capacity** — global caps on each Skill's concurrent invocations (e.g. only 4 simultaneous calls to the Enterprise Registry Lookup API across all tenants).

A Run that hits the vertical-axis cap MUST suspend only the **dependent agent step**, not the whole Run and not the LLM inference thread pool.

#### `SkillResourceMatrix` (extends ADR-0030 / ADR-0038)

The matrix is the platform's view of one Skill at one moment:

- `skillName` (canonical capability tag)
- `tenantQuotaBySkill` — `Map<tenantId, currentUsage, hardCap>`
- `globalSkillCapacity` — `(currentConcurrent, hardCap)`
- `currentUtilization` — derived percentage (per tenant and global)
- `reservedCapacity` — concurrent slots held by in-flight `BidResponse.Accepted` that haven't started executing yet
- `saturationReason` — when saturated: `TENANT_QUOTA_EXCEEDED | GLOBAL_CAPACITY_REACHED | SKILL_DRAINING | SKILL_DEGRADED`

This matrix is consulted at three points:
1. **Pre-bid**: the scheduler decides whether to admit the `IntentEvent` to the bidding round.
2. **Bid-evaluation**: when scoring `BidResponse` candidates, the matrix tells the scheduler which bidders have spare capacity.
3. **Saturation check**: at any point a Run can be moved to `SUSPENDED + RateLimited(resourceKey, retryAfter)` if the matrix flips.

#### `CapabilityRegistry` (with tenant scope and pre-authorization)

The `CapabilityRegistry` is the platform's directory of available capabilities. It:

- **Registers capability tags** — `{capabilityName, owningTenant?, trustTier (VETTED|UNTRUSTED), kind (JAVA_NATIVE|MCP_TOOL|SANDBOXED_CODE_INTERPRETER), sandboxRequirement, domainPermissions[]}`.
- **Binds capability tags to domain permission identifiers** — e.g. `code_audit` requires the `domain:engineering.code_access` permission identifier. Agents lacking the identifier cannot bid on this capability.
- **Pre-authorizes access per tenant** — `resolve(name, runContext)` rejects with `Rejected(reason=INSUFFICIENT_PERMISSION)` if the requesting tenant lacks the required domain permission.
- **Composes with `SkillTrustTier`** (ADR-0030) — `UNTRUSTED` skills MUST be wrapped in a `SandboxExecutor` (ADR-0018) in `research`/`prod` posture; the Registry enforces this.

#### Pre-Authorized Access (whitepaper §5.3)

Untrusted nodes cannot bid on capabilities they don't have the domain identifier for. The platform issues `DomainPermissionGrant`s out-of-band (admin console, signed bootstrap config). A bid from a non-pre-authorized bidder is **silently dropped** at the Registry level — the bidder doesn't even see the intent.

### Bidding contracts

#### `BidRequest`

When the S-side decides to dispatch an `IntentEvent` (ADR-0050) that requires capability bidding (as opposed to direct-dispatch to a known capability), the scheduler issues:

- `bidId` (unique)
- `capabilityName`
- `tenantId`
- `intent` (free-form structured description of what the work entails)
- `budget` — `{tokens?, walltimeSec?, dollarCap?}`
- `requiredPermissions[]` (domain permission identifiers; bidders without these are filtered at Registry level before they see the request)
- `expectedDuration`
- `dataPointerRefs[]` (no inline heavy data; see ADR-0050)
- `biddingDeadline`

#### `BidResponse`

Each eligible (pre-authorized) candidate responds:

- `bidId` (echo)
- `bidderId` (Agent Service instance ID + capability variant ID)
- `capacityAvailable` (boolean)
- `expectedStartTime`
- `requiredSubstitutions[]` — bidder may propose substitutions (e.g. "I can do `code_audit` but only with model `gpt-4o-mini` instead of `gpt-4o`")
- `confidence` — bidder's self-reported confidence (0.0–1.0)
- `costEstimate` — `{tokens, walltimeSec, dollarCost}`

#### Bid-scoring rule

The scheduler scores bidders by:
1. **Capacity available** — gate (rejected bids excluded).
2. **Confidence × (budget − costEstimate)** — higher score wins.
3. **Tie-break by earliest `expectedStartTime`**.
4. **Final tie-break by round-robin across bidder pool** (avoid starvation).

#### `PermissionEnvelope` (cascading issuance)

When a bid wins, the S-side issues a **per-task permission envelope** to the winning delegate:

- `envelopeId`
- `runId` / `bidId` (links)
- `tenantId`
- `actionPermissions[]` — specific tool/Action permissions the delegate may exercise (e.g. `tool:registry_lookup`, `tool:postgres_read:account_balance`)
- `subsumptionBoundary` — the set of sub-agents the winning delegate may delegate to (per whitepaper §5.3 Skill Subsumption Principle); permissions propagate within this boundary only.
- `expiry` (envelope is short-lived; cannot outlive the bid expiry)
- `revokeOnYield` (boolean; if true, yielding the work revokes the envelope)
- `signature` (cryptographic — prevents privilege forgery; out-of-band issuance from S-side root)

Envelopes are **NOT** transitive beyond the declared subsumption boundary. A delegate cannot grant permissions it doesn't hold; cannot grant permissions beyond its own envelope.

### `SkillSaturationYield`

When a Run's planned skill step hits saturation:

- The dependent agent step yields via `SuspendSignal` with `SuspendReason.RateLimited(resourceKey, retryAfter)` (per §4 #19).
- The Run transitions to `SUSPENDED`.
- **Only the dependent step yields** — the parent Run's other branches continue if independent.
- The LLM inference thread is **released** (not blocked waiting on the saturated skill).
- The scheduler schedules retry at `retryAfter` or earlier if the skill's `globalSkillCapacity` frees up.
- The C-Side is **not notified** of skill saturation unless retry exhaustion converts to `BusinessDegradationRequest` per ADR-0049.

### Reconciliation with ADR-0030, ADR-0038, ADR-0050

- **ADR-0030 (Skill SPI lifecycle)** — preserved; the Java SPI (`init/execute/suspend/teardown`) is the **inside** of one capability. The Skill SPI describes how a single skill behaves at the JVM level.
- **ADR-0038 (resource-tier classification)** — preserved; the four enforceability tiers (hard-enforceable, sandbox-enforceable, advisory/receipt, hints) classify which `SkillResourceMatrix` fields can be enforced at runtime.
- This ADR (ADR-0052) is the **outside** layer: distributed scheduling, bidding, permission issuance, tenant×global arbitration. Together with ADR-0030 + ADR-0038 the picture is complete.
- **ADR-0050 (Workflow Intermediary)** — the `IntentEvent` carried on the bus references `PermissionEnvelope` via `permissionEnvelopeRef`. The `WorkflowIntermediary` consumes the envelope when admitting work; `SkillSaturationYield` emits `BackpressureSignal.SKILL_SATURATION`.

### Wave staging

- **L0 (this PR)**: contracts named (`SkillResourceMatrix`, `CapabilityRegistry`, `BidRequest`, `BidResponse`, `PermissionEnvelope`, `SkillSaturationYield`); cross-refs added to ADR-0030 and ADR-0038.
- **W2**: Java types for these contracts (separate ADR/PR); composes with ADR-0030 lifecycle and ADR-0050 bus.
- **W3**: full bidding implementation; sandboxed enforcement of `UNTRUSTED` capabilities.
- **W4**: integration with Temporal for durable bidding rounds.

### Out of scope

- Java types (deferred W2+).
- Cryptographic specification of `PermissionEnvelope.signature` (deferred W3; signing root + key rotation policy).
- Specific bidding-protocol wire format (composes with ADR-0050 substrate choice).
- Multi-region bidding (post-W4).

### Consequences

**Positive:**
- Reviewer P1-1 closed: the architecture distinguishes "Java SPI for skills" (ADR-0030/0038) from "distributed skill resource scheduler" (this ADR).
- Two-axis arbitration is explicit: tenant quota × global skill capacity.
- Permission issuance to delegates is explicit, traceable, and short-lived (revokes on yield).
- `SkillSaturationYield` ensures saturated skills don't starve LLM inference threads.

**Negative:**
- Adds six new named contracts at L0 contract level without Java code (per reviewer non-goal "broad Java runtime implementation"). Reviewers reading the codebase see prose-level types only.
- `CapabilityRegistry` + `PermissionEnvelope` are a non-trivial security surface to implement and operate. Mitigated by deferring impl to W2-W3.
- The bid-scoring rule is a starting point and will likely need tuning as production data arrives.

### Acceptance criteria (reviewer P1-1)

- Architecture text distinguishes "a Java SPI for skills" from "a distributed skill resource scheduler" — Yes; ADR-0030/0038 = Java SPI; this ADR = distributed scheduler.
- Tenant quota and global skill capacity are both represented — Yes; two-axis matrix is explicit.
- Permission issuance to delegates is explicit and traceable — Yes; `PermissionEnvelope` with `envelopeId`, `signature`, `expiry`, `revokeOnYield`.

## References

- Reviewer source: `docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md` (finding P1-1)
- Whitepaper: `docs/spring-ai-ascend-architecture-whitepaper-en.md` §4.1, §5.3
- ARCHITECTURE.md §4 #50 (this ADR's anchoring constraint)
- ADR-0030: Skill SPI lifecycle + `SkillResourceMatrix` + `SkillTrustTier` (Java SPI level — preserved, cross-ref forward note)
- ADR-0038: Skill SPI resource-tier classification (preserved, cross-ref forward note)
- ADR-0018: SandboxExecutor SPI (`UNTRUSTED` skill enforcement at W3)
- ADR-0050: Workflow Intermediary, Mailbox, Rhythm Track (`IntentEvent` references `PermissionEnvelope`; `WorkflowIntermediary` emits `BackpressureSignal.SKILL_SATURATION`)
- ADR-0049: C/S Dynamic Hydration Protocol (`SkillPoolLimit` from C-Side feeds `BidRequest`)
- Whitepaper alignment matrix: `docs/governance/whitepaper-alignment-matrix.md` — rows for Skill Topology Scheduler, Capability bidding, Permission issuance
- `architecture-status.yaml` row: `skill_topology_scheduler_and_capability_bidding`
