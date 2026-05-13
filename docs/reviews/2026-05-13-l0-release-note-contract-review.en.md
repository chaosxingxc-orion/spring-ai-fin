# L0 Release Note Contract Review

Date: 2026-05-13
Reviewer role: Java microservices and agentic runtime architecture reviewer
Input reviewed: `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md`

## Verdict

The L0 architecture is close to release-ready and the implementation evidence is healthy. I did not find a new deep architecture gap in the Java microservice boundary, the W0 runtime kernel, or the agent-oriented design model for planning, skills, memory, and knowledge. The current L0 stance is appropriately small: W0 ships a minimal runtime kernel plus contract guards, while dynamic planning, durable memory, skill lifecycle, capability registry, sandboxing, and knowledge retrieval are explicitly staged as W1-W4 design contracts.

However, the published release note is not yet clean enough to serve as the final L0 truth artifact. It contains several release-text contract drifts where future-wave or non-existent API surface is described as W0 shipped behavior. These are documentation-contract issues, not implementation failures, but they block a fully clean L0 release note under the Architecture-Text Truth rule.

## Verification Performed

- `powershell -ExecutionPolicy Bypass -File gate/check_architecture_sync.ps1`: 25/25 rules PASS
- `bash gate/check_architecture_sync.sh`: 25/25 rules PASS
- `bash gate/test_architecture_sync_gate.sh`: 24/24 self-tests PASS
- `.\mvnw.cmd -q test`: PASS

## Agent Architecture Assessment

Dynamic planning is acceptable for L0. The shipped W0 surface proves graph-to-agent-loop nesting through `SyncOrchestrator`, `SequentialGraphExecutor`, `IterativeAgentLoopExecutor`, `SuspendSignal`, and checkpoint/resume behavior. Scope-based planning, `RunScope`, `PlanState`, `RunPlanRef`, dispatcher routing, and cross-JVM serialization are correctly held as design-only W2/W3 items.

Skill architecture is acceptable for L0. The Skill SPI lifecycle, resource matrix, trust tiers, cost receipt, resume token, and sandbox mandate are intentionally design-only. That is the right L0 decision because shipping partial skill execution without resource and sandbox gates would create a stronger production contract than the code can enforce.

Memory and knowledge architecture is acceptable for L0. The six-category memory taxonomy, `MemoryMetadata`, Graphiti selection, and GraphMemory starter posture are clear as long as they remain wave-qualified. The W0 starter registers no runtime bean, which is consistent with the current architecture-status record and avoids premature memory persistence claims.

There is no strong evidence of overdesign at L0 as long as the release artifact keeps the shipped/deferred boundary precise. The design breadth is high, but the code surface remains intentionally small and gate-backed.

## Required Corrections

### P1. Release note lists `RunLifecycle` as a W0 shipped SPI

Observed failure: `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:49` lists "`RunLifecycle` SPI" in the W0 Runtime Kernel shipped table and describes actual orchestration SPI types under that name.

Execution path: A downstream implementer reads the release note, treats `RunLifecycle` as a W0 Java SPI, and looks for lifecycle operations such as cancel/resume/retry in the shipped runtime package. The implementation does not contain a `RunLifecycle` class or interface, while the canonical governance row marks it as `shipped: false`.

Root cause statement: The release note reused the future-wave `RunLifecycle` name as a grouping label for the already-shipped orchestration SPIs, which turns a W2 design-only interface into an apparent W0 contract.

Evidence:
- `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:49`
- `docs/governance/architecture-status.yaml:556-562`
- `docs/adr/0020-runlifecycle-spi-and-runstatus-formal-dfa.md:72-73`
- Shipped W0 source contains `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`, `Checkpointer`, and `RunContext`, but no `RunLifecycle` interface.

Required fix: Rename the release-note row to "`Orchestration SPI`" and list only the actual W0 symbols. Keep `RunLifecycle` in the deferred/known-limitations section as a W2 interface for cancel/resume/retry.

Suggested wording:

```markdown
| `Orchestration` SPI | `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`, `Checkpointer`, `RunContext` - pure-Java SPIs; no framework imports. `RunLifecycle` cancel/resume/retry remains design-only for W2. |
```

### P1. Release note claims `RunContext.posture()` exists

Observed failure: `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:50` says `RunContext` exposes `tenantId()`, `runId()`, and `posture()`.

Execution path: A node, graph executor, or agent-loop implementation compiled against the release note would call `RunContext.posture()`. The actual W0 interface does not provide that method, so the documented contract cannot compile.

Root cause statement: The release note conflates posture enforcement with `RunContext`; W0 posture is enforced through `AppPostureGate` and posture-aware constructors/policies, not through a `RunContext` accessor.

Evidence:
- `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:50`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/RunContext.java:18-37`
- `docs/governance/architecture-status.yaml:312`

Required fix: Replace the method list with the actual W0 interface surface: `runId()`, `tenantId()`, `checkpointer()`, and `suspendForChild(...)`. Explicitly state that posture is not carried on `RunContext` at W0.

Suggested wording:

```markdown
| `RunContext` | Interface: `runId()`, `tenantId()`, `checkpointer()`, `suspendForChild(...)`; tenant identity is sourced from the runtime context, not from the HTTP ThreadLocal. Posture is enforced by construction-time gates and policy components, not by `RunContext`. |
```

### P2. OpenAPI snapshot enforcement is attributed to the wrong test

Observed failure: `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:59` says `ApiCompatibilityTest` fails if the OpenAPI snapshot diverges from the live spec.

Execution path: A reviewer or CI owner looking for the OpenAPI contract check opens `ApiCompatibilityTest` and finds ArchUnit SPI/dependency-direction rules, not the live OpenAPI snapshot comparison. The actual snapshot check is in `OpenApiContractIT` and `OpenApiSnapshotComparator`.

Root cause statement: The release note names the general compatibility ArchUnit test instead of the specific OpenAPI integration test that performs the snapshot diff.

Evidence:
- `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:59`
- `docs/governance/architecture-status.yaml:128-147`
- `agent-platform/src/test/java/ascend/springai/platform/contracts/OpenApiContractIT.java`
- `agent-platform/src/test/java/ascend/springai/platform/contracts/OpenApiSnapshotComparator.java`
- `agent-platform/src/test/java/ascend/springai/platform/api/ApiCompatibilityTest.java`

Required fix: Change the release note to say `OpenApiContractIT` performs the live spec comparison via `OpenApiSnapshotComparator`. Keep `ApiCompatibilityTest` only for ArchUnit SPI purity and module dependency direction.

### P3. `AppPostureGate` is placed under the HTTP edge and described too broadly

Observed failure: `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:41` places `AppPostureGate` under "HTTP Edge (agent-platform)", and `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:75` says all runtime components receive posture as a constructor argument.

Execution path: A reader infers that `AppPostureGate` is an agent-platform HTTP component and that every runtime component has a posture constructor parameter. In code, `AppPostureGate` lives in `agent-runtime`, and the hard evidence is narrower: `SyncOrchestrator`, `InMemoryRunRegistry`, and `InMemoryCheckpointer` call `AppPostureGate.requireDevForInMemoryComponent(...)` from construction.

Root cause statement: The release note generalized a correct in-memory-component posture guard into a broader module and constructor contract than the implementation and architecture-status row assert.

Evidence:
- `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:41`
- `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:75`
- `agent-runtime/src/main/java/ascend/springai/runtime/posture/AppPostureGate.java`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java:40`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryRunRegistry.java:24`
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryCheckpointer.java:30`
- `docs/governance/architecture-status.yaml:772-785`

Required fix: Move `AppPostureGate` to the Runtime Kernel section or a cross-cutting posture section. Narrow the statement to "in-memory runtime components that require dev-only posture gating call `AppPostureGate` during construction."

### P4. Release SHA wording is ambiguous after the metadata follow-up commit

Observed failure: The release note says `HEAD SHA: 82a1397`, while the current repository HEAD is `776d4e7`. The latter is a metadata follow-up commit that sets `latest_semantic_pass_sha: 82a1397` and updates the release note SHA field.

Execution path: A reviewer checking out the current branch runs `git rev-parse --short HEAD` and sees `776d4e7`, then reads the release note and sees `HEAD SHA: 82a1397`.

Root cause statement: The release note uses "HEAD SHA" for what appears to be the semantic release commit, while the branch has advanced by a metadata-only commit.

Evidence:
- `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md:4`
- `docs/governance/architecture-status.yaml:66`
- Current `git log`: `776d4e7` after `82a1397`

Required fix: Either update the line to the actual current HEAD or rename the field to `Semantic release SHA: 82a1397` and add `Metadata follow-up SHA: 776d4e7` if that distinction is intentional.

## Gate Hardening Recommendation

The current gates are passing, which is good, but the release note exposed a narrow blind spot: active release documents can still overclaim a shipped SPI by name if the phrase does not match the existing Rule 25 patterns.

Recommended follow-up:

1. Add a release-note shipped-surface check for `docs/releases/*.md`.
2. Block `RunLifecycle` inside a W0 "What Is Shipped" or "Runtime Kernel" section unless the surrounding sentence contains `W2`, `design-only`, `deferred`, or `not shipped`.
3. Add a targeted `RunContext` method-list check for active docs: if a document claims `RunContext` methods, it must match the current Java interface names or cite a future wave.
4. Add a self-test for both negative cases.

This can be implemented as an extension of the existing contract-surface truth gates rather than as a broad new architecture rule.

## Release Decision

Do not issue the final clean L0 release note until the four release-note corrections above are made. No new Java implementation is required for L0 based on this review. Once the release text is corrected and the existing verification remains green, the L0 architecture can be declared ready with a clean release note.
