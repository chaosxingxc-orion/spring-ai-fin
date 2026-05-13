# R6 Feasibility & Forward Compatibility Audit of L0 v2 Release Note
Date: 2026-05-13
Reviewer: feasibility-reviewer (compound-engineering)
Input: docs/releases/2026-05-13-L0-architecture-release-v2.en.md

## Verdict
PASS-WITH-OBSERVATIONS

The v2 note is internally consistent and the deferral discipline is unusually rigorous (each W2/W3/W4 row has an ADR, a `architecture-status.yaml` row, and an explicit wave qualifier). The SPI primitives I examined are credibly serverless-compatible. However, six commitments in the note will require real engineering judgement before they survive W2 implementation — they are not currently wrong, but the v2 wording understates their downstream cost. Findings below are forward-looking risks, not blockers for L0.

## Findings

### Finding 1 — `Checkpointer.save(byte[])` admits stateless deployment but punts the serialisation problem
- Severity: P2
- Defect category: feasibility-risk
- 4-shape label: N/A
- The L0 commitment: "SPI primitives stay serverless-friendly so W4+ migration remains open" (v2 §Service-Layer Microservice Commitment; ADR-0048 line 59).
- Feasibility concern: `Checkpointer.save(UUID, String, byte[])` (agent-runtime/.../spi/Checkpointer.java:28) and `SuspendSignal` carrying `Object resumePayload` (SuspendSignal.java:22) are serverless-compatible **only** if a `PayloadCodec` exists. Rule 22 (PayloadCodec discipline) is deferred to W2, and `RunContext.suspendForChild` (RunContext.java:34) currently accepts `Object resumePayload` with no codec lookup. A stateless function deployment cannot reload a captured Java `Object` graph across JVM boundaries; the SPI is "serverless-friendly" only in the trivial sense that the byte array is opaque.
- Risk severity: Moderate. The SPI shape is preserved, but every concrete executor written at W2 against the current `Object`-typed suspend payload will need to be rewritten when codecs land. The v2 note implies "no migration cost"; reality is "codec retrofit cost spread across every executor".
- Mitigation already in place: Rule 22 deferred row with W2 trigger; ADR-0022 + ADR-0028 named; §4 #21/#25 deferred.
- Residual risk: The forward-compat claim in v2 is true at the *signature* level but false at the *implementation* level. A reader will read "serverless-friendly" and infer "no migration code"; the truth is "codec layer must be inserted before any function-deployment trial".
- Fix proposal: Soften the v2 wording from "SPI primitives stay serverless-friendly so W4+ migration remains open" to "SPI signatures stay serverless-compatible; codec/serialisation retrofit (Rule 22) is required before any serverless deployment trial". One-line change.

### Finding 2 — Rhythm-track physical isolation narrows substrate choice more than v2 admits
- Severity: P2
- Defect category: sequencing-risk
- 4-shape label: N/A
- The L0 commitment: "Track 3 Rhythm (independently protected — heartbeats, `SleepDeclaration`, `WakeupPulse`, `TickEngine` ticks, lease renewal, `ChronosHydration` triggers)" (v2 §Workflow Intermediary + Three-Track Cross-Service Bus); ADR-0050 line 110-112: "congestion in Track 1 (control) MUST NOT delay Track 3 (rhythm). If they share substrate, the substrate MUST provide physical isolation".
- Feasibility concern: ADR-0050 line 156 lists substrate candidates as "dedicated NATS subject, separate Kafka topic on isolated partition, lightweight gossip (Serf / memberlist), or custom UDP heartbeat". A *separate Kafka topic on the same broker* does NOT provide physical isolation against a broker-side congestion event (a saturated request handler queue affects all topics on that broker). The Rhythm-independence requirement effectively forces either (a) a second broker cluster, (b) a fundamentally different transport for Rhythm (gossip/UDP), or (c) Temporal-as-TickEngine. Substrate choice is not freely deferable; the Rhythm constraint pre-selects.
- Risk severity: Moderate. Operationally this means the deployment will likely need two transports + Temporal, not one event bus. ADR-0050's "Negative" note ("Three substrates to operate") admits this; v2 does not call it out for the reader who only reads the release note.
- Mitigation already in place: ADR-0050 §"Substrate choices (deferred)" lists the constraint; ADR-0050 Negative consequence #1 names the three-substrate cost.
- Residual risk: A W2 implementer reading only v2 will believe the substrate is freely choosable. It is not — Rhythm-independence + Track 2 P2P + durable TickEngine narrows the space significantly.
- Fix proposal: Accept as residual risk; ADR-0050 already documents it correctly. Optionally add a one-line v2 forward note: "substrate choice deferred to W2 within the Rhythm-isolation envelope per ADR-0050".

### Finding 3 — `PlaceholderPreservationPolicy` is named "ship-blocking" at L0 but W3 enforcement may be infeasible
- Severity: P1
- Defect category: over-commitment
- 4-shape label: N/A
- The L0 commitment: "`PlaceholderPreservationPolicy` (first-class, ship-blocking): when C-Side passes placeholders (e.g. `[USER_ID_102]`), S-Side MUST preserve them verbatim through every LLM prompt, tool call, intermediate result, and final return." (v2 §Memory Ownership Boundary); ADR-0051 line 107: "Violation of this rule is a **ship-blocking defect** on any tool, LLM call, or memory operation."
- Feasibility concern: The W3 row in v2 lists "`PlaceholderPreservationPolicy` enforcement" with no scope qualifier. Genuine enforcement requires: (a) placeholder detection regex/grammar in every prompt template, (b) round-trip verification on every LLM response (LLMs routinely paraphrase opaque tokens — `[USER_ID_102]` becomes `User 102` or `the user with ID 102`), (c) wire-boundary inspection on every tool call, (d) sandboxed enforcement for `UNTRUSTED` skills. Items (b) and (c) are open research problems — modern LLMs do not respect "treat this token as algebra"; they pattern-match. ADR-0051 line 107 names `SandboxExecutor` (ADR-0018, also W3) as the enforcement venue for `UNTRUSTED` skills, but `VETTED` skills are listed only as "MUST be audited" — i.e. manual audit, not runtime enforcement.
- Risk severity: High. "Ship-blocking" is a strong word. If W3 lands the SandboxExecutor but cannot demonstrate LLM-side placeholder preservation (which is the dominant violation path), the entire `PlaceholderPreservationPolicy` becomes effectively unenforced, and v2's "first-class, ship-blocking" claim becomes hollow. This is the kind of commitment that, when reality catches up, gets quietly downgraded and damages the trust calculus around other L0 commitments.
- Mitigation already in place: ADR-0051 §"Wave staging" puts enforcement at W3 with sandbox; `VETTED` is audit-only.
- Residual risk: The "ship-blocking" framing in ADR-0051 line 107 is unscoped. It can be read as (a) ship-blocking once W3 lands enforcement, or (b) ship-blocking right now for any tool that violates. Reading (b) is unattainable without runtime enforcement.
- Fix proposal: Either (1) add a wave qualifier in ADR-0051 line 107: "Violation of this rule is a ship-blocking defect **once W3 enforcement lands**; pre-W3 violations are tracked as known-debt rows"; or (2) reduce scope to "tool-boundary and wire-boundary preservation is ship-blocking from L0; LLM-side preservation is enforced at W3 via prompt-template scaffolding + response verification". Option 2 is more honest about what is actually achievable.

### Finding 4 — Bid-scoring rule is named but not stable; deferring wire format risks W2 redesign
- Severity: P2
- Defect category: feasibility-risk
- 4-shape label: N/A
- The L0 commitment: "Bidders respond with `BidResponse(capacityAvailable, expectedStartTime, requiredSubstitutions[], confidence, costEstimate)`" (v2 §Skill Topology Scheduler); ADR-0052 §"Bid-scoring rule": "Confidence × (budget − costEstimate) — higher score wins" (line 117).
- Feasibility concern: The scoring formula `confidence × (budget − costEstimate)` has a known pathology: when `costEstimate > budget`, the score goes negative; when `confidence` is bidder-self-reported with no calibration, bidders are incentivised to over-report. ADR-0052 line 179 acknowledges: "the bid-scoring rule is a starting point and will likely need tuning as production data arrives". The deeper concern: the **shape** of `BidResponse` may need to change once tuning starts (e.g. add `historicalAccuracy`, `tenantAffinityScore`, `region`). Deferring the wire format to W2 is fine; deferring the *shape* invites breaking changes.
- Risk severity: Moderate. The L0 commitment names the field list; W2 redesign of the field list breaks the L0 contract claim. Either the L0 list must be treated as exemplar, or the W2 protocol must constrain itself to the L0 fields.
- Mitigation already in place: ADR-0052 §"Wave staging" defers Java types to W2; §"Out of scope" defers cryptographic signature and wire format. The Negative consequences explicitly call out scoring-rule tuning.
- Residual risk: v2 §Skill Topology Scheduler reads as "shape is stable, wire format deferred". The truth is "field list is a starting point that will likely grow". A future reviewer doing whitepaper-alignment will then re-find this gap.
- Fix proposal: Add a one-line note to ADR-0052 §Wave staging W2 row: "field list may extend; existing fields are stable". Accept as residual risk.

### Finding 5 — `IntentEvent.permissionEnvelopeRef` introduces a chicken-and-egg between ADR-0050 and ADR-0052
- Severity: P2
- Defect category: sequencing-risk
- 4-shape label: N/A
- The L0 commitment: ADR-0050 line 55: `IntentEvent` carries `permissionEnvelopeRef` (reference to a `PermissionEnvelope` issued by the S-side per ADR-0052). ADR-0052 line 122-134: `PermissionEnvelope` is issued **after** bidding concludes.
- Feasibility concern: `IntentEvent` is the **pre-bid** payload published to the bus (ADR-0050 lines 50-57). `PermissionEnvelope` is the **post-bid** envelope issued to the winning delegate (ADR-0052 line 122-134). Then `IntentEvent.permissionEnvelopeRef` can only reference an envelope that doesn't exist yet. Either (a) `IntentEvent` actually references an upstream envelope from a parent run (subsumption case), or (b) the field is populated only on the re-issued `IntentEvent` sent to the winner after bidding, in which case the bus has two `IntentEvent` shapes: bid-request and dispatch. ADR-0050 and ADR-0052 do not disambiguate.
- Risk severity: Moderate. This is a small ambiguity that will surface during W2 implementation as "which shape are we receiving?" Currently both ADRs read as if there is only one shape.
- Mitigation already in place: None explicit. ADR-0052 §"Reconciliation with ADR-0030, ADR-0038, ADR-0050" line 152 says "the `IntentEvent` carried on the bus references `PermissionEnvelope` via `permissionEnvelopeRef`. The `WorkflowIntermediary` consumes the envelope when admitting work" — implying post-bid dispatch — but ADR-0050's `BidRequest` is also an `IntentEvent` per ADR-0050 §Bidding contracts.
- Residual risk: A W2 implementer will need to split `IntentEvent` into `BidIntent` and `DispatchIntent`, or make `permissionEnvelopeRef` nullable + add a state flag. The L0 contract does not pre-decide.
- Fix proposal: Add to ADR-0052 line 88-89 a clarifying note: "`BidRequest` is distinct from the post-bid dispatch `IntentEvent`; the latter carries `permissionEnvelopeRef`. ADR-0050 `IntentEvent` shape is the union; precise discrimination is W2 wire-format work". Accept as residual risk.

### Finding 6 — `spring-cloud-starter-vault-config` retention with autoconfig disabled is a transitive-dep risk
- Severity: P3
- Defect category: dep-risk
- 4-shape label: N/A
- The L0 commitment: v2 §CI Hardening: "Spring Cloud Vault autoconfig pulled in under Boot 4 — Disabled in `agent-platform/application.yml` (W0 doesn't use Vault)".
- Feasibility concern: `spring-cloud-starter-vault-config` remains a runtime dependency (`agent-platform/pom.xml:87`); only the autoconfig is gated off via `spring.cloud.vault.enabled: false`. The starter pulls in `spring-vault-core`, retry, and Spring Cloud Context. Two latent risks: (a) any *other* Spring Cloud component added at W1 may trigger Vault bootstrap by transitive activation (e.g. `spring-cloud-starter-bootstrap` re-enables bootstrap context which Vault hooks into); (b) the `enabled: false` key is a Vault property, not a Spring Cloud Context property — `BootstrapImportSelector` and `PropertySourceLocator` for Vault may still try to contact Vault during early bootstrap when `bootstrap.yml` is added (W1 secrets work).
- Risk severity: Low. The autoconfig disable currently works because Boot 4 routes Vault through standard autoconfig (not legacy bootstrap). W1 may flip this when bootstrap.yml is added for Spring Cloud Config or similar.
- Mitigation already in place: `application.yml` comment line 17-19 documents the W0 disable; `PlatformOssApiProbe` is the only consumer and only references `VaultProperties` for compile-time citation.
- Residual risk: First W1 PR that adds `spring-cloud-starter-bootstrap` or `spring-cloud-config-client` will likely re-trigger Vault bootstrap. The current disable does not survive that change.
- Fix proposal: Add a `bootstrap.yml` with `spring.cloud.vault.enabled: false` *now*, or pre-emptively `<exclusions>` the Vault transitives. Accept as known W1 trip-hazard; document in W1 milestone notes.

### Finding 7 — 14 deferred engineering rules are well-justified but Rule 11 (Contract Spine) trigger is imminent
- Severity: P2
- Defect category: deferral-vacuum
- 4-shape label: N/A
- The L0 commitment: v2 baseline: "Active engineering rules: 11; Deferred engineering rules: 14 (with documented re-introduction triggers)".
- Feasibility concern: Reviewing `docs/CLAUDE-deferred.md`, the deferrals are individually well-justified with explicit triggers. However, **Rule 11 (Contract Spine Completeness)** has trigger "first persistent record class committed (e.g., `RunRecord`, `IdempotencyRecord` with Postgres-backed `IdempotencyStore`)". v2 §"Capabilities Shipped at W0" lists `IdempotencyRecord` entity as shipped with "mandatory `tenantId` (Rule 11 target)". The entity is already committed; only the *Postgres-backed store* is W1. The deferral trigger is ambiguous: is the trigger "entity class exists" (already true) or "durable persistence exists" (W1)? If the former, Rule 11 should already be active.
- Risk severity: Moderate. If the trigger reading is "entity exists", v2's "14 deferred" count is off by one. Other deferrals (Rule 7, 8, 13, 14, 15, 16, 17, 18, 19, 22, 23, 24, 26, 27) all have triggers that are clearly W1+. Rule 11 is the borderline case.
- Mitigation already in place: Rule 11 trigger text names `IdempotencyStore` (the store, not the record), suggesting "durable persistence" is the trigger. The "Rule 11 target" annotation on the W0 entity is forward-pointing, not retro-active.
- Residual risk: A future reviewer will read v2 and ADR-0011/Rule 11 text and find the wording inconsistent. Worth clarifying.
- Fix proposal: Add to Rule 11 trigger text: "first persistent **record class with durable storage** committed". One-word fix in `docs/CLAUDE-deferred.md`.

### Finding 8 — `WorkflowIntermediary` is required in every Agent Service instance but has no W0 placeholder
- Severity: P3
- Defect category: feasibility-risk
- 4-shape label: N/A
- The L0 commitment: ADR-0050 line 44: "`WorkflowIntermediary` — a per-Agent-Service local supervisor. **Required** in every Agent Service instance under the ADR-0048 microservice deployment."
- Feasibility concern: W0 ships `SyncOrchestrator` which is the local executor but has no admission-control, mailbox-polling, or backpressure-emission surface. When W2 introduces `WorkflowIntermediary`, the question is: does it wrap `SyncOrchestrator`, replace it, or run alongside? ADR-0050 §"Reconciliation with ADR-0031" line 142 says ADR-0031's in-process three-track SPI is "preserved unchanged" — but ADR-0031's `RunControlSink` is HTTP/SSE northbound, not bus-southbound. The relationship between `WorkflowIntermediary` (bus-southbound admission) and `Orchestrator` (in-process execution) is not pre-decided.
- Risk severity: Low. The work is W2 and the SPI seam is preserved. But "required in every Agent Service instance" is a strong claim that the W0 codebase has no anchor for.
- Mitigation already in place: ADR-0050 §"Wave staging" defers Java types to W2.
- Residual risk: First W2 implementer will need to design the `WorkflowIntermediary` ↔ `Orchestrator` composition. Two reasonable shapes exist (decorator vs sibling).
- Fix proposal: Accept as residual risk; ADR-0050 W2 follow-up should add the composition decision before code is written.

## Categorized summary

| Category | Count | Findings |
|----------|-------|----------|
| feasibility-risk | 3 | F1 (codec deferral cost), F4 (bid-shape stability), F8 (intermediary composition) |
| over-commitment | 1 | F3 (PlaceholderPreservationPolicy "ship-blocking" scope) |
| sequencing-risk | 2 | F2 (Rhythm narrows substrate), F5 (IntentEvent shape ambiguity) |
| dep-risk | 1 | F6 (Vault transitives at W1) |
| deferral-vacuum | 1 | F7 (Rule 11 trigger ambiguity) |

**No P0 findings.** One P1 (PlaceholderPreservationPolicy scope). The L0 v2 release note is feasibly implementable as written; the eight findings are forward-looking risks that will surface at W2/W3 implementation time and are each addressable with a localised wording fix in either v2 or the relevant ADR. The deferral discipline is unusually strong — every deferred rule has a real trigger, every deferred capability has an ADR + YAML row, and no commitment surveyed exceeds what the SPI surface can actually accommodate.

**Recommendation:** ship L0 v2 as PASS-WITH-OBSERVATIONS; address F3 wording (over-commitment risk) in a follow-up edit since "ship-blocking" without scope is the only finding that could mislead a downstream reviewer reading only the release note.

## Relevant absolute file paths

- D:\chao_workspace\spring-ai-ascend\docs\releases\2026-05-13-L0-architecture-release-v2.en.md
- D:\chao_workspace\spring-ai-ascend\docs\adr\0048-service-layer-microservice-architecture-commitment.md
- D:\chao_workspace\spring-ai-ascend\docs\adr\0049-c-s-dynamic-hydration-protocol.md
- D:\chao_workspace\spring-ai-ascend\docs\adr\0050-workflow-intermediary-mailbox-rhythm-track.md
- D:\chao_workspace\spring-ai-ascend\docs\adr\0051-memory-knowledge-ownership-boundary.md
- D:\chao_workspace\spring-ai-ascend\docs\adr\0052-skill-topology-scheduler-and-capability-bidding.md
- D:\chao_workspace\spring-ai-ascend\docs\CLAUDE-deferred.md
- D:\chao_workspace\spring-ai-ascend\agent-runtime\src\main\java\ascend\springai\runtime\orchestration\spi\Orchestrator.java
- D:\chao_workspace\spring-ai-ascend\agent-runtime\src\main\java\ascend\springai\runtime\orchestration\spi\SuspendSignal.java
- D:\chao_workspace\spring-ai-ascend\agent-runtime\src\main\java\ascend\springai\runtime\orchestration\spi\Checkpointer.java
- D:\chao_workspace\spring-ai-ascend\agent-runtime\src\main\java\ascend\springai\runtime\orchestration\spi\RunContext.java
- D:\chao_workspace\spring-ai-ascend\agent-platform\pom.xml
- D:\chao_workspace\spring-ai-ascend\agent-platform\src\main\resources\application.yml
