# 0051. Memory and Knowledge Ownership Boundary

**Status:** accepted
**Deciders:** architecture, chaos.xing.xc@gmail.com
**Date:** 2026-05-13
**Technical story:** Reviewer finding P0-5 (`docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md`): the whitepaper §2.4 splits memory ownership into C-Side (business ontology + business facts) and S-Side (execution trajectory + platform state). Current ADR-0034 defines the M1–M6 memory taxonomy from the S-Side perspective but does **not** codify the ownership boundary. Without it, `GraphMemoryRepository`, M3 Semantic Long-Term, M4 Graph Relationship Memory, and M5 Knowledge Index can be misread as platform-owned business memory. ADR-0034 is amended; this ADR adds the ownership boundary, the `BusinessFactEvent` emission path, and the `PlaceholderPreservationPolicy` as a first-class rule.

## Context

Whitepaper §2.4 (Dual-Track Memory Isolation):

> "Business Ontology and Fact Accumulation (Attributed to C-Side): 'User preferences' and 'business entity state changes' discovered by the agent during dialogues must be thrown out as structured events by the S-Side, ultimately to be persisted by the C-Side's business database (Knowledge Graph or Business DB). This is highly sensitive."
>
> "Underlying Execution Trajectories and Multi-Tenant State (Attributed to S-Side `spring-ai-ascend`): The S-Side must maintain its own underlying database (like the current `RunRepository`) to record 'how many Tokens were consumed,' 'which model version was called,' and 'which API experienced retries.' This serves platform resource management and billing."
>
> "Placeholder Exemption Rule: When the C-Side, to protect privacy, passes constraints containing placeholders (e.g., `[USER_ID_102]`), the S-Side's context engine must possess powerful 'symbolic algebra' deduction capabilities. It does not need to know who this user is; it only needs to keep the placeholder logic from collapsing throughout the entire agent trajectory, returning the result containing the placeholder back to the C-Side along the original route after completing the task."

The reviewer observed that ADR-0034 was correct for **platform memory taxonomy** (M1–M6) but silent on **business-memory ownership**. Without the ownership boundary, M3/M4/M5 can absorb business ontology by default, and `GraphMemoryRepository` (the platform's graph memory SPI) can be read as "the canonical place to store customer business facts" — which is exactly the failure mode the whitepaper warns about.

This ADR adds the ownership table and three new contracts (`BusinessFactEvent`, `OntologyUpdateCandidate`, `PlaceholderPreservationPolicy`, `SymbolicReturnEnvelope`) so that any future memory adapter (Graphiti, mem0, Cognee, custom) must declare which side owns its data.

## Decision Drivers

- Reviewer P0-5: no active prose should imply S-side memory owns C-side business facts by default.
- Whitepaper §2.4: business ontology belongs to C-Side; S-Side stores trajectories.
- Whitepaper Placeholder Exemption Rule must be a **first-class rule**, not an incidental privacy note.
- `GraphMemoryRepository` (ADR-0034) and future `Graphiti` adapter must state explicitly whether they store platform graph state, delegated business graph state, or both.

## Considered Options

1. **Codify the ownership boundary + `BusinessFactEvent` emission + Placeholder Preservation as a first-class rule** (this decision).
2. **Add a note to ADR-0034 only** — rejected: the ownership boundary affects multiple ADRs (0030 Skill SPI, 0049 C/S Hydration) and deserves a dedicated decision record.
3. **Defer to W2 when memory adapters land** — rejected per reviewer P0-5: the ambiguity exists today and must be closed at L0 contract level.

## Decision Outcome

**Chosen option:** Option 1.

### Memory ownership table

The platform recognizes three ownership categories. Every memory adapter, every M-category, and every storage path MUST be classified.

#### C-Side owned memory (business)

The C-Side (whitepaper §2.1 Business Brain) owns these categories:

- **Business ontology** — entities, types, relationships defined by the customer's domain (e.g. for a financial-services CRM: `Account`, `Customer`, `Position`, `RegulatoryFlag`).
- **Business entity state** — current values of business-meaningful attributes (e.g. account balance, KYC status, last review date).
- **User preferences** — end-user preferences discovered during agent interaction (tone, language, contact channel preferences, accessibility needs).
- **Domain facts discovered during agent execution** — new business facts the agent learns (e.g. "Customer X confirmed they prefer email contact"; "Account Y's beneficiary changed").
- **Business knowledge graph or business DB persistence** — the canonical store is the C-Side's own database / knowledge graph, NOT the platform.

The S-Side **emits** newly discovered C-side memory candidates via `BusinessFactEvent` (see below). The C-Side decides whether to accept, transform, store, or discard.

#### S-Side owned memory (platform)

The S-Side (whitepaper §2.1 Platform Runtime — `spring-ai-ascend`) owns these categories:

- **Run trajectory** — sequence of node executions, tool calls, LLM messages, suspend/resume events.
- **Token usage** — per-Run, per-tenant, per-skill consumption (for billing, quota, rate limiting).
- **Model version + gateway telemetry** — which LLM model version was used, which gateway, response times, error rates.
- **Tool-call trace** — which tools were invoked, with what inputs, returning what outputs (anonymised; placeholders preserved per rule below).
- **Retry and failure diagnostics** — circuit-breaker state, retry counts, fallback paths exercised.
- **Execution snapshots required for resume** — `Checkpointer`-stored byte payloads sufficient to rehydrate a `Run` (per §4 #9, §4 #13, ADR-0021, ADR-0028).
- **Platform scheduling, quota, and billing state** — tenant quotas, skill capacity, audit rows.

The S-Side persists these in its own stores (`RunRepository`, `Checkpointer`, future Postgres outbox). They are **never** business ontology.

#### Shared or delegated memory

C-Side memory MAY be stored in S-Side-operated infrastructure ONLY via an **explicit delegation contract**. The delegation contract MUST declare:

- `tenantScope` — which tenant's data this delegation covers.
- `retention` — how long the platform stores it; deletion semantics.
- `redactionState` — what redaction is applied at storage time (e.g. tokenisation, hashing, full redaction).
- `visibilityScope` — who can read it (the tenant only, the platform only, both, an external audit system).
- `exportDeleteSemantics` — how the C-Side requests export or deletion; SLAs.
- `placeholderPolicy` — whether placeholders may be resolved into identities at this scope.

No memory is shared **by default**. A new delegation contract requires explicit C-Side consent (a `DelegationGrant` record on the C-Side and a mirror entry on the S-Side).

### `BusinessFactEvent` and `OntologyUpdateCandidate`

When the S-Side agent discovers a candidate business fact during execution, it MUST emit it as a structured event for the C-Side to consume:

- **`BusinessFactEvent`** — structured event from S-Side to C-Side. Carries:
  - `tenantId`, `runId`, `taskCursorRef` (links back to the C-Side `TaskCursor` per ADR-0049).
  - `factType` (e.g. `USER_PREFERENCE_DISCOVERED`, `ENTITY_STATE_CHANGE`, `RELATIONSHIP_ASSERTED`).
  - `factPayload` (structured representation — entity refs, attribute key, value, confidence).
  - `evidence` (which Run step produced this fact; placeholder-preserving).
  - `proposalSemantics` ∈ {`HYPOTHESIS`, `OBSERVATION`, `INFERENCE`}. The S-Side does NOT claim factual authority; the C-Side decides acceptance.
- **`OntologyUpdateCandidate`** — a `BusinessFactEvent` that proposes adding a new entity type, relationship, or attribute to the C-Side ontology. Requires explicit C-Side acceptance (cannot be auto-applied).

Transport: emitted on the Data track (Track 2 per ADR-0050) as part of the `SubStreamFrame` or `SyncStateResponse` payload (per ADR-0049). The S-Side MUST NOT directly write to the C-Side's knowledge graph.

### Placeholder Preservation Rule (first-class)

When the C-Side passes constraints or context containing **placeholders** (opaque tokens that represent identities the C-Side has chosen not to resolve, e.g. `[USER_ID_102]`, `[ACCOUNT_HASH_4f8c]`, `[ORG_REF_XYZ]`):

- **`PlaceholderPreservationPolicy`** — the S-Side MUST:
  - Treat each placeholder as an opaque symbol.
  - Preserve the placeholder verbatim through every LLM prompt, tool call, intermediate result, and final return.
  - **NEVER** attempt to resolve the placeholder to a real identity unless an explicit `DelegationGrant` authorises identity resolution at this scope.
  - **NEVER** ask the LLM to "guess what `[USER_ID_102]` refers to" — placeholders are treated as algebraic symbols, not pronouns.
- **`SymbolicReturnEnvelope`** — when the S-Side returns a result via `SyncStateResponse` or `SubStreamFrame`, any placeholder that appeared in the input MUST appear in the output **unchanged**. The C-Side performs final identity substitution after receiving the result.

Violation of this rule is a **ship-blocking defect** on any tool, LLM call, or memory operation. The Skill SPI (ADR-0030, ADR-0052) `SkillTrustTier=VETTED` skills MUST be audited for placeholder preservation; `UNTRUSTED` skills MUST run inside a sandbox (ADR-0018) that enforces placeholder opacity at the wire boundary.

### Update to ADR-0034 (M1–M6 mapping)

ADR-0034 defines six memory categories M1–M6. Under this ADR's ownership boundary, the categories are re-classified:

- **M1 Short-Term Run Context** — S-Side owned (in-process per-run; TTL = run lifetime). Never holds business ontology beyond placeholder-preserved tokens.
- **M2 Episodic Session Memory** — S-Side owned operationally; MAY contain C-Side-delegated session state via a delegation contract. Without delegation: trajectory data only (which prompts, which tool calls).
- **M3 Semantic Long-Term Memory** — **split**:
  - **Platform-derived operational memory** (S-Side): patterns learned about the platform's own behaviour (which prompts work best, which tool sequences are reliable).
  - **Business-owned ontology** (C-Side): canonical entities, types, relationships. NOT stored in M3 by default; emitted as `BusinessFactEvent`.
- **M4 Graph Relationship Memory** — **split**:
  - **Platform graph state** (S-Side): execution-graph relationships (Run → child Run, Run → tool, etc.).
  - **Delegated business graph state** (C-Side via delegation): the customer's domain graph, stored under explicit delegation.
  - The W1 reference adapter Graphiti remains valid for **platform graph relationship memory or delegated memory**, but is NOT the default sink for all customer business facts.
- **M5 Knowledge Index (RAG)** — **split**:
  - **Platform-shipped knowledge** (S-Side): docs about the platform itself, OSS API references.
  - **Customer knowledge corpus** (C-Side via delegation): the customer's documents indexed for RAG. Indexed by the platform under delegation; not platform-owned.
- **M6 Retrieved Context** — ephemeral; TTL = turn lifetime; classified by the source it was retrieved from.

`GraphMemoryRepository` is the platform SPI for M4. ADR-0034 forward note will state that `GraphMemoryRepository` is **NOT** the default owner of customer business ontology; M4 implementations MUST declare their ownership per the table above.

### Wave staging

- **L0 (this PR)**: ownership boundary named; `BusinessFactEvent`, `OntologyUpdateCandidate`, `PlaceholderPreservationPolicy`, `SymbolicReturnEnvelope` named at contract level; ADR-0034 updated via cross-ref forward note.
- **W2**: Java types for `BusinessFactEvent`, `OntologyUpdateCandidate`, delegation contract records (separate ADR).
- **W2**: Graphiti adapter ships under W1 reference (ADR-0034) — MUST declare ownership in its starter pom + `ARCHITECTURE.md` reference.
- **W3**: sandboxed enforcement of `PlaceholderPreservationPolicy` (ADR-0018 + `SandboxExecutor` per ADR-0052).

### Out of scope

- Java implementation of `BusinessFactEvent` / `OntologyUpdateCandidate` / delegation records (deferred W2).
- Specific delegation contract template (deferred W2; the column list above is the minimum schema).
- Selection of an emission transport for `BusinessFactEvent` (it composes with ADR-0049's `SubStreamFrame` / `SyncStateResponse` and ADR-0050's Data track — wire format deferred).

### Consequences

**Positive:**
- Reviewer P0-5 closed: the ownership boundary is named; `GraphMemoryRepository` is explicitly NOT the default owner of business ontology; placeholder preservation is a first-class rule.
- ADR-0034 is updated to reference this ADR; M4/M5 are split into platform-owned vs C-Side-delegated by default.
- Future memory adapters (mem0, Graphiti, Cognee, custom) MUST classify themselves under this boundary; the W1 reference for M4 (Graphiti) is unambiguously "platform or delegated", not "business ontology by default".
- Placeholder Preservation becomes ship-blocking for any tool or skill that violates it.

**Negative:**
- The ownership boundary adds a constraint surface (3+ new named contracts: `BusinessFactEvent`, `OntologyUpdateCandidate`, `PlaceholderPreservationPolicy`, `SymbolicReturnEnvelope`) without Java code at W0. Reviewers reading the codebase see prose-level types only.
- Delegation contract is a future complexity: when the platform DOES need to store delegated business memory, the delegation record schema must be designed and operationalised.
- Some operational simplicity is lost: the platform CANNOT simply absorb business facts into its own graph by default; explicit consent is required.

### Acceptance criteria (reviewer P0-5)

- No active architecture prose implies that S-side memory owns C-side business facts by default — Yes; the ownership table is explicit.
- Any future M4 or Graphiti adapter MUST state whether it stores platform graph state, delegated business graph state, or both — Yes; ADR-0034 forward note will encode this requirement.
- Placeholder preservation is represented as a first-class rule, not an incidental privacy note — Yes; `PlaceholderPreservationPolicy` is named as a ship-blocking rule.

## References

- Reviewer source: `docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md` (finding P0-5)
- Whitepaper: `docs/spring-ai-ascend-architecture-whitepaper-en.md` §2.4
- ARCHITECTURE.md §4 #49 (this ADR's anchoring constraint)
- ADR-0034: Memory and Knowledge Taxonomy at L0 (amended with forward note)
- ADR-0049: C/S Dynamic Hydration Protocol (defines `TaskCursor` opacity; `BusinessFactEvent` flows in `SubStreamFrame` / `SyncStateResponse`)
- ADR-0050: Workflow Intermediary, Mailbox, Rhythm Track (defines Data track that carries `BusinessFactEvent`)
- ADR-0018: SandboxExecutor SPI (W3 enforcement of `PlaceholderPreservationPolicy` for `UNTRUSTED` skills)
- ADR-0052: Skill Topology Scheduler and Capability Bidding (`VETTED` skill audit must include placeholder preservation)
- Whitepaper alignment matrix: `docs/governance/whitepaper-alignment-matrix.md` — rows for Business ontology ownership, S-side execution trajectory ownership, Placeholder exemption
- `architecture-status.yaml` row: `memory_knowledge_ownership_boundary`
