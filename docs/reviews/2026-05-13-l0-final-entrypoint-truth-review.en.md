# L0 Final Entrypoint Truth Review

Date: 2026-05-13
Reviewer role: Java microservices and agentic runtime architecture reviewer
Input reviewed: `docs/releases/2026-05-13-L0-architecture-release.en.md`, root and module `ARCHITECTURE.md` files, `README.md`, `docs/governance/architecture-status.yaml`, Java runtime SPI sources, and gate rules.

## Verdict

The updated L0 release note has resolved the prior release-note contract drift. The shipped Java surface and the current release note now align on the major W0 contracts: `RunLifecycle` remains W2 design-only, `RunContext` lists only real methods, OpenAPI snapshot enforcement is attributed to `OpenApiContractIT`, and `AppPostureGate` is scoped to the three in-memory runtime components that actually call it.

From the Java microservice and agentic-runtime perspective, I do not see a new implementation gap in the W0 runtime kernel. The L0 boundary is intentionally narrow and still appropriate: HTTP health and posture-aware edge filters in `agent-platform`; orchestration SPIs, run state DFA, nested graph/agent-loop reference execution, posture-gated in-memory runtime components, and GraphMemory SPI scaffold in `agent-runtime`.

Dynamic planning, skills, memory, and knowledge are also in an acceptable L0 state. The architecture keeps the current executable surface small while documenting the future contracts with wave qualifiers: `RunScope`/`PlanState`/`RunPlanRef`, `Skill` lifecycle, `SkillResourceMatrix`, sandbox requirements, `CapabilityRegistry`, memory taxonomy, Graphiti sidecar, `PayloadCodec`, and durable storage are not prematurely implemented or described as W0 runtime behavior in the release note.

However, I found residual active-entrypoint documentation drift outside the release note. These are documentation-contract issues, not Java implementation failures, but they should be fixed before treating the L0 architecture package as fully polished.

## Verification Performed Before This Review Document

- Inspected latest commit chain: `56f52e3` metadata follow-up after `862be85` release-note contract-review response.
- Confirmed `docs/releases/2026-05-13-L0-architecture-release.en.md` now declares 44 architecture constraints, 46 ADRs, 26 gate rules, and 28 gate self-tests.
- Cross-checked `RunContext`, orchestration SPI, `AppPostureGate`, OpenAPI tests, `RunLifecycle`, skill, planner, and memory/knowledge claims against Java sources and `architecture-status.yaml`.

Final command verification is still required after this document lands.

## Required Corrections

### P1. Root README still advertises the pre-release-note-review architecture baseline

Observed failure: `README.md` remains at the post-seventh third-pass state. Its status paragraph stops at Gate Rules 24-25 / ADR-0045, and the runtime model section says "Forty-one architectural constraints" with a reference to `ARCHITECTURE.md #1-#41`.

Execution path: A new team member follows the repository reading order, reads `README.md` first, and concludes that the active architecture baseline is 41 constraints, 45 ADRs, 25 gate rules, and 24 self-tests. The actual release baseline is 44 constraints, 46 ADRs, 26 gate rules, and 28 self-tests.

Root cause statement: The release-note contract-review response updated the release note, root architecture, ADR index, governance ledger, and gate scripts, but did not refresh the root README entrypoint that summarizes the same architecture baseline.

Evidence:
- `README.md:5`
- `README.md:34`
- `ARCHITECTURE.md:491-504`
- `docs/governance/architecture-status.yaml:66-68`
- `docs/releases/2026-05-13-L0-architecture-release.en.md:24-28`
- `docs/releases/2026-05-13-L0-architecture-release.en.md:165`

Required fix:

1. Update the README status paragraph to include the L0 release-note contract review: Architecture section 4 #44, ADR-0046, Gate Rule 26, and 28 self-tests.
2. Change the runtime model sentence to "Forty-four architectural constraints ... `ARCHITECTURE.md section 4 #1-#44`."
3. Add bullets for #42, #43, and #44, or replace the long historical bullet list with a short current-baseline pointer to the release note and governance ledger.

Recommended gate hardening:

Add a narrow active-entrypoint baseline check that fails when `README.md` contains stale baseline tokens such as `#1-#41`, `Forty-one architectural constraints`, or a status paragraph ending at Gate Rules 24-25 after the governance ledger has advanced to Gate Rule 26.

### P2. System-boundary prose still uses present-tense wording for target capabilities not shipped at W0

Observed failure: Root `ARCHITECTURE.md` and `agent-runtime/ARCHITECTURE.md` describe LLM driving, tool-calling, durable side effects, and outbox emission in present tense in the top-level system boundary / purpose sections.

Execution path: A reader starts at the architecture boundary sections and interprets them as the current W0 runtime behavior. The Java sources do not yet include the real LLM gateway, tool registry, `RunController`, outbox publisher, durable Postgres checkpointer, or ActionGuard runtime. Those are deliberately staged as W1-W4 work elsewhere in the docs.

Root cause statement: The boundary sections describe the target multi-wave product architecture, but they are not explicitly labeled as target architecture and do not immediately distinguish the W0 shipped subset from W1-W4 deferred capabilities.

Evidence:
- `ARCHITECTURE.md:5-10`
- `agent-runtime/ARCHITECTURE.md:7-11`
- `agent-runtime/ARCHITECTURE.md:53-57`
- `docs/releases/2026-05-13-L0-architecture-release.en.md:44-55`
- `docs/releases/2026-05-13-L0-architecture-release.en.md:170-176`
- Java source search shows only `OssApiProbe` references Spring AI `ChatClient`; no production `LlmRouter`, `RunController`, `OutboxPublisher`, `ActionGuard`, `CapabilityRegistry`, or `PostgresCheckpointer` exists at W0.

Required fix:

Retitle or rewrite the boundary text so it clearly separates target architecture from W0 shipped behavior.

Suggested root wording:

```markdown
spring-ai-ascend is a self-hostable agent-runtime architecture for financial-services operators.
The target W1-W4 product accepts authenticated tenant HTTP requests, drives LLMs through a tool-calling loop with audit-grade evidence, and persists durable side effects through an idempotent outbox.
The W0 shipped subset is intentionally smaller: health endpoint, tenant/idempotency header filters, orchestration SPI contracts, run-state DFA, posture-gated in-memory reference executors, and GraphMemory SPI scaffold.
```

Suggested `agent-runtime/ARCHITECTURE.md` wording:

```markdown
`agent-runtime` is the cognitive runtime kernel. At W0 it ships orchestration SPI contracts, run-state entities, the DFA validator, posture-gated in-memory reference executors, resilience routing, and a GraphMemory SPI interface. The LLM gateway, tool registry, outbox publisher, durable storage, ActionGuard, and Temporal workflow implementations are target capabilities staged for W1-W4.
```

### P3. Active-document refresh metadata is no longer consistently meaningful

Observed failure: Several active entrypoint documents still say "Last updated/refreshed: post-seventh third-pass" even though the architecture package now has an L0 release-note contract-review pass with ADR-0046 and Gate Rule 26.

Execution path: A reviewer uses document headers to infer which files were included in the final L0 pass. Some files are genuinely unaffected by the tenth cycle, but the current metadata does not distinguish "not touched because unaffected" from "not refreshed and maybe stale."

Root cause statement: The release-note contract-review cycle updated central release artifacts but did not define a metadata policy for active documents after narrow-scope review cycles.

Evidence:
- `agent-runtime/ARCHITECTURE.md:1-4`
- `agent-platform/ARCHITECTURE.md:1-4`
- `docs/contracts/contract-catalog.md:4`
- `docs/contracts/http-api-contracts.md:4`
- `docs/cross-cutting/posture-model.md:3`
- `docs/cross-cutting/non-functional-requirements.md:3`
- `docs/observability/policy.md:4`
- Current release baseline: `docs/releases/2026-05-13-L0-architecture-release.en.md:3-6`

Required fix:

Choose one metadata convention and apply it consistently:

1. If a file was re-audited for the L0 release-note contract review, update its header to mention that pass.
2. If a file was intentionally unaffected, keep the old date but add a short scope qualifier such as "Content last changed in post-seventh third-pass; still covered by L0 release baseline via architecture-status.yaml."
3. Add a lightweight gate or scripted check only if the team wants headers to carry baseline counts or review-cycle names.

## Overdesign Assessment

The current design breadth is high, but I do not classify it as harmful overdesign at L0 because the future capabilities are not being shipped as half-built runtime paths. The architecture consistently uses ADRs and `architecture-status.yaml` rows to hold future contracts while keeping the current Java implementation small.

The main risk is not over-implementation. The main risk is entrypoint prose using broad target-language without enough W0/W1-W4 qualifiers. That risk is fixable by tightening the active entrypoint docs and optionally adding a README baseline truth gate.

## Release Decision

Do not open a new Java implementation workstream for L0 based on this review. The runtime architecture and release note are materially ready.

Before declaring the full L0 architecture package "final polished", ask the architecture team to correct the active-entrypoint drift above. After that, a clean release note can be issued without changing production code.
