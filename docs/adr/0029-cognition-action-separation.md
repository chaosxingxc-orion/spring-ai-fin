# 0029. Cognition-Action Separation Principle

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Fifth architecture reviewer raised Finding 2: the platform cannot solve
distributed defects C4 (cross-JVM serialization), C5 (resume privilege escalation), and C6 (lambda
closure serialization) within strongly-typed Java; prescribes "demote Java to a passive data adapter"
and "embed Python-brain via GraalVM Polyglot." Self-audit of Category B surfaced HD-B.1 (§1 scope
ambiguity between Python sidecar and in-process polyglot), HD-B.2 (ADR-0018 positions GraalPolyglot
only as sandbox, not as cognitive layer), HD-B.3 (the term "capability" is undefined), HD-B.4/B.5
(reviewer claims C5 and C6 are unsolvable in Java). This ADR:
  (a) names the Cognition-Action Separation principle;
  (b) explicitly accepts the principle while rejecting the "Python mandatory" prescription;
  (c) rebuts the C4/C5/C6 "Java-can't-solve" claims with pointers to existing solutions;
  (d) disambiguates §1 scope — network-IPC sidecar vs in-process polyglot.

## Context

The platform's cognitive surface (Spring AI `ChatClient`, iterative ReAct reasoning via
`AgentLoopExecutor`) and its action surface (tools, DB writes, outbox, RLS-enforced Postgres)
are both implemented in Java. At W0 this is correct: all cognitive reasoning is a simple
`Reasoner.reason(RunContext, Object, int)` call — the "hallucination tolerance" is the caller's
concern, and it trivially delegates to Spring AI.

The reviewer's claim is that **Java is structurally unable to tolerate LLM hallucinations** in
dynamic AST-driven loops, and that Python — embedded via GraalVM Polyglot — should own all
cognitive loops while Java owns physical side effects.

This claim raises two questions:

1. **Is the principle correct?** Yes: cognitive reasoning (non-deterministic, hallucination-prone,
   mutable intent) and action execution (deterministic, side-effecting, RLS-bound, auditable) are
   architecturally distinct concerns that should be decoupled.

2. **Is the prescription (Python-brain mandatory) correct?** No: the prescription conflates the
   isolation-from-sideeffects concern (already solved by the Cognition-Action SPI boundary) with
   the "which language is best at tolerating hallucinations" concern (a red herring; Spring AI
   abstracts LLM reasoning in Java perfectly well).

### Rebuttal of C4 / C5 / C6

| Reviewer claim | Existing solution | Status |
|---|---|---|
| **C4 — cross-JVM serialization** is a black hole | `PayloadCodec<T>` SPI (ADR-0022) + `CapabilityRegistry` named dispatch (§4 #15, ADR-0021) replace inline lambdas with named registry entries before W2. Named entries are serializable by design. | Committed design — W2. |
| **C5 — resume privilege escalation** is unsolvable | §4 #14 `resume_reauthorization_check` + Rule 17 (deferred W2): every resume re-validates `request.tenantId == Run.tenantId`; mismatch → HTTP 403. Java-tractable. | Committed design — W2. |
| **C6 — lambda closure serialization** is unsolvable | §4 #15 `executor_definition_serialization` mandates that `NodeFunction`/`Reasoner` lambdas MUST become named `CapabilityRegistry` entries before W2. Inline closures are eliminated by design, not by embedding Python. | Committed design — W2. |

The reviewer correctly identifies that **inline Java lambdas cannot be serialized across JVM
boundaries** (C6). This is true. Our solution is to **not serialize them**: `CapabilityRegistry`
maps names to implementations; names are serialized; implementations are resolved locally. This is
the standard approach in Temporal, Akka, and Flink — all Java/JVM frameworks that solve this problem
without Python.

### §1 scope disambiguation — HD-B.1

`ARCHITECTURE.md §1` says: "Not in scope: admin UI, LangChain4j dispatch, **Python sidecars**,
multi-region replication, on-device models."

"Python sidecar" means a Python process communicating with the JVM over an IPC boundary (gRPC, HTTP,
shared memory IPC, named pipe). This is excluded because it introduces an out-of-process failure
domain, a separate deployment lifecycle, and serialization at every cognition call.

"In-process polyglot" means running Python code within the JVM via GraalVM's polyglot engine (same
heap, no IPC). This is **not the same as a sidecar**. ADR-0018 already designates
`GraalPolyglotSandboxExecutor` as an optional W3 `SandboxExecutor` implementation. This ADR
clarifies: in-process polyglot execution is a valid W3 option under `SandboxExecutor` SPI — it is
**not a re-scoping of §1**; it was already in scope via ADR-0018.

The §1 exclusion is updated to read: "Python sidecars (out-of-process IPC)" to make this distinction
explicit.

## Decision Drivers

- Financial-services deployments require deterministic, auditable, RLS-bound action execution. Java
  provides this. Replacing the action layer with Python would compromise it.
- Spring AI Java provides a production-ready cognitive surface (ChatClient, VectorStore, MCP adapters).
  MCP Java SDK 2.0.0-M2 is the cross-language tool protocol — a Java client calling any-language tool
  server. No GraalVM required for cross-language tool composition.
- GraalVM polyglot Python support is experimental at 24.2 for non-JS languages (ADR-0018 §Negative).
  Making it mandatory for the cognitive layer would introduce an unstable dependency at the platform's
  core reasoning path.
- The existing SPI boundary between Orchestrator/Executor (cognitive loop) and SuspendSignal/Checkpointer
  (action persistence) IS the Cognition-Action separation seam. It is architectural, not linguistic.

## Considered Options

1. **Formal principle with optional GraalPolyglot (this decision)** — accept the Cognition-Action
   separation principle; keep ADR-0018 GraalPolyglot as one optional W3 SandboxExecutor impl; rebut
   the mandatory-Python prescription.
2. **Commit Java-to-Python migration path as W3 deliverable** — amend §1 to add "Python cognitive
   core via GraalVM Polyglot" as W3 in-scope. Higher risk; GraalVM polyglot still experimental.
3. **Reject Finding 2 entirely** — no ADR; leave §1 wording unchanged. Misses the genuine principle
   (Cognition-Action decoupling) and leaves the §1 ambiguity unresolved.

## Decision Outcome

**Chosen option:** Option 1.

### The Cognition-Action Separation Principle (§4 #26)

> **Cognitive processes** (LLM-driven reasoning, hallucination tolerance, dynamic plan revision,
> memory synthesis) are isolated from **Action processes** (database writes, tool invocations,
> tenant-scoped RLS queries, idempotent outbox events) by the platform's SPI boundary. Cognitive
> processes observe the world and produce *intent*; Action processes execute *verified intent* with
> full determinism and auditability. Neither layer may bypass the SPI to reach the other directly.

**At W0:** The SPI boundary is:
- Cognitive side: `Reasoner.reason(RunContext, Object, int) → ReasoningResult`
- Action side: `RunContext.suspendForChild(...)` → triggers `SuspendSignal` → `Orchestrator` executes child run
- The orchestrator mediates: it reads ReasoningResult.terminal, routes through the SuspendSignal path,
  invokes the action executor, and returns the result to the cognitive side as the next iteration input.

**At W2+:** The SPI boundary is also:
- `CapabilityRegistry.resolve(name) → Skill` — cognitive side declares intent by name; action side
  executes the named skill under `SandboxPolicy` constraints.
- `CausalPayloadEnvelope.ontology` — marks the epistemic class of data crossing the boundary.

**Language policy:** The cognitive layer MAY be implemented in any language that can call the
`Orchestrator` SPI. At W0-W2: Spring AI Java (ChatClient). At W3+: GraalPolyglot (ADR-0018,
optional impl), MCP tool server (any language, MCP Java SDK bridge), or native Java `CapabilityRegistry`
entry. No language is mandatory.

### Capability taxonomy — HD-B.3

The term "capability" in §4 #15 (`CapabilityRegistry`) is defined as one of:

```
SkillKind:
  JAVA_NATIVE         — a Java class implementing the Skill SPI (ADR-0030); fastest, no isolation
  MCP_TOOL            — a tool reachable via MCP Java SDK; language-neutral; network-called
  SANDBOXED_CODE_INTERPRETER — code block executed via SandboxExecutor SPI (ADR-0018); polyglot
```

Each `CapabilityRegistry` entry has a `SkillKind`, an `operationId`, and a `SkillTrustTier`
(`VETTED | UNTRUSTED`). This taxonomy eliminates the ambiguity between "capability" = Java code
and "capability" = Python/MCP tool.

### Consequences

**Positive:**
- The Cognition-Action SPI is explicitly named and documented — future implementors know where the
  boundary is.
- The §1 scope clarification ends the ambiguity about Python sidecar vs in-process polyglot.
- The capability taxonomy grounds the `CapabilityRegistry` contract in concrete `SkillKind` values.
- The C4/C5/C6 rebuttal is on record; reviewers expecting "Java can't do this" have a clear reference.

**Negative:**
- Rejecting mandatory Python means the reviewer's proposed Python-brain experimentation remains
  opt-in; teams that want it must explicitly configure `GraalPolyglotSandboxExecutor`.

### Reversal cost

Low — this ADR adds a named principle and a vocabulary; no code changes. If a future wave commits
to a Python cognitive core, ADR-0029 would be superseded with a decision that explicitly narrows
the "language policy" clause.

## Pros and Cons of Options

### Option 1: Formal principle, optional GraalPolyglot (chosen)
- Pro: names the genuine architectural principle without over-committing on implementation.
- Pro: resolves §1 ambiguity.
- Con: GraalPolyglot path remains opt-in; may require further direction at W3.

### Option 2: Commit Java-to-Python migration as W3
- Pro: stronger competitive signal vs SAA Python sandbox.
- Con: GraalVM polyglot Python still experimental; locks W3 roadmap before maturity is demonstrated.

### Option 3: Reject Finding 2 entirely
- Con: misses the genuine Cognition-Action principle; leaves §1 wording ambiguous.

## References

- Fifth-reviewer document: `docs/reviews/spring-ai-ascend-implementation-guidelines-en.md` §2
- Response document: `docs/reviews/2026-05-12-fifth-reviewer-response.en.md` (Cat-B)
- ADR-0018: SandboxExecutor SPI (GraalPolyglotSandboxExecutor — optional W3 impl)
- ADR-0021: Layered SPI taxonomy (CapabilityRegistry)
- ADR-0022: PayloadCodec SPI (C4 solution)
- §4 #14 (resume re-authorization — C5 solution)
- §4 #15 (capability registry + executor definition serialization — C6 solution)
- §4 #26 (new, this ADR)
- `architecture-status.yaml` row: `cognition_action_separation`
