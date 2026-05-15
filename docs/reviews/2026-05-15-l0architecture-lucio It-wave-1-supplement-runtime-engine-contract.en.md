# L0 Architecture Proposal: Runtime-Engine Contract for Heterogeneous Agent Execution

**Date:** 2026-05-15
**Status:** Draft / Pending Review
**Architecture Level:** L0
**Scope:** Runtime-engine contract, engine configuration envelope, client-side capability callback, and evolution scope boundary

---

## 1. Motivation

This proposal clarifies several architectural rules required for heterogeneous agent execution in enterprise scenarios.

The key problem is not how to implement one specific agent engine, but how to define the boundary among four concerns:

1. how different execution engine configurations are represented and selected;
2. how Runtime-level middleware policies can take effect during engine execution;
3. how server-side execution can invoke client-side capabilities when necessary;
4. how far the evolution mechanism should manage execution traces and behaviors.

The proposal intentionally stays at L0 level. It defines responsibility boundaries and architectural constraints, not concrete APIs, schemas, protocols, or implementation classes.

---

## 2. Proposal Summary

This proposal introduces four L0-level decisions:

1. Introduce a lightweight configuration envelope for heterogeneous execution engines.
2. Require execution engine configurations to be executed only by matching engines.
3. Let Runtime own middleware integration through engine lifecycle hooks.
4. Limit the evolution scope to server-controlled execution by default.

It also introduces one interaction pattern:

* server-side execution may asynchronously invoke client-side capabilities during task execution.

---

## 3. Lightweight Configuration Envelope

### 3.1 Decision

Introduce a lightweight configuration envelope for different agent execution engines.

The purpose of this envelope is to provide a unified management surface for Runtime-level registration, validation, discovery, routing, governance, and observability.

The envelope may include simple metadata such as:

* name and identifier;
* version;
* owner or provider;
* engine type;
* engine version;
* runtime hints;
* observability hints;
* compatibility declaration;
* engine-specific configuration payload.

### 3.2 Boundary

The envelope is not a universal semantic DSL.

At this stage, the so-called unified DSL should only be understood as a shallow wrapper around heterogeneous engine configurations. It may standardize metadata and management fields, but it must not attempt to translate one engine's execution semantics into another engine's execution semantics.

For example, a workflow definition, graph definition, planner configuration, tool routing rule, memory behavior, or agent loop policy from one engine should not be automatically converted into another engine's format.

### 3.3 Rationale

A lightweight envelope gives the platform a common control plane without forcing premature standardization of all execution semantics.

This avoids three risks:

1. building an over-abstracted DSL too early;
2. hiding semantic differences among engines;
3. creating silent behavior drift when configurations are interpreted by the wrong engine.

---

## 4. Engine Matching Rule

### 4.1 Decision

Each engine-specific configuration must be executed by a compatible execution engine.

The Runtime may inspect the envelope to select the target engine, but the actual engine-specific payload must remain bound to the matching engine.

### 4.2 Required Behavior

If the required engine is available and compatible, the Runtime may dispatch the task to that engine.

If the required engine is unavailable, incompatible, or disabled by policy, the Runtime should reject the execution request or follow an explicit fallback policy.

The Runtime should not silently reinterpret the payload as another engine's configuration.

### 4.3 Rationale

Different execution engines may have different assumptions about:

* task state;
* graph topology;
* tool invocation semantics;
* memory access;
* suspension and resume behavior;
* error propagation;
* retry semantics;
* concurrency model.

Therefore, configuration compatibility must be explicit rather than implicit.

---

## 5. Runtime-Owned Middleware Integration

### 5.1 Decision

Middleware integration should be owned by the Runtime layer.

The execution engine owns the actual execution semantics. The Runtime owns cross-cutting policies and middleware integration.

### 5.2 Runtime Responsibilities

The Runtime may be responsible for decisions such as:

* model gateway selection;
* tool authorization;
* memory access governance;
* tenant policy enforcement;
* quota and rate limit checks;
* observability event emission;
* sandbox routing;
* risk control;
* checkpoint and suspension policy;
* failure handling policy.

These responsibilities should not be hard-coded into every execution engine.

### 5.3 Engine Responsibilities

The execution engine should expose lifecycle hook capabilities at important execution points, so that the Runtime can regain control and apply middleware policies.

Representative hook points may include:

* before LLM invocation;
* after LLM invocation;
* before tool invocation;
* after tool invocation;
* before memory read;
* after memory write;
* before suspension;
* before resume;
* on error.

These hook names are illustrative. The final hook set should be defined in lower-level design.

### 5.4 Boundary

The engine should not directly depend on concrete middleware implementations.

Instead, the engine should provide control points, while the Runtime provides the actual hook functions, policies, interceptors, or callbacks.

This keeps the execution engine focused on execution semantics and keeps enterprise middleware integration centralized in the Runtime.

---

## 6. Server-to-Client Capability Invocation

### 6.1 Decision

During server-side task execution, the Runtime may invoke client-side capabilities when the required tool, observation, or business-side operation is only available in the client environment.

This should be treated as an asynchronous callback pattern rather than a normal local tool call.

### 6.2 Typical Cases

Client-side capabilities may include:

* local business system access;
* private environment observation;
* user-side approval;
* client-local validation;
* browser-side or desktop-side operation;
* enterprise network-only tool access.

### 6.3 Execution Pattern

A typical flow is:

1. The server-side task is running under the Runtime and a selected execution engine.
2. The engine reaches a step that requires a client-side capability.
3. The engine yields control to the Runtime through a hook or suspension point.
4. The Runtime sends a capability invocation request to the client.
5. The server-side task suspends, checkpoints, or waits according to Runtime policy.
6. The client performs the local operation and returns the result.
7. The Runtime validates and records the result.
8. The execution engine resumes or continues with an alternative path.

### 6.4 Architectural Implications

This pattern introduces additional complexity, including:

* higher execution latency;
* client offline handling;
* timeout policy;
* retry policy;
* idempotency control;
* duplicate result handling;
* partial failure handling;
* security and authorization checks;
* trace correlation between server and client.

Therefore, client-side capability invocation should be explicitly modeled and governed by the Runtime. It should not be treated as a transparent local function call.

---

## 7. Evolution Scope Boundary

### 7.1 Decision

The evolution mechanism should manage only server-controlled execution scope by default.

Client-autonomous execution should not be included in the direct evolution target unless the client explicitly exports telemetry, traces, or events through agreed contracts.

### 7.2 In Scope

The following data and behaviors may be included in the default evolution scope:

* server-side execution traces;
* Runtime decisions;
* engine lifecycle events;
* middleware interaction records;
* model invocation records;
* server-side tool invocation records;
* checkpoint and resume events;
* task outcomes controlled by the server-side execution path.

### 7.3 Out of Scope by Default

The following should be outside the default evolution scope:

* client-local private state;
* client-autonomous decision logic;
* client-side tool behavior that is not exported;
* business-side operations hidden behind the client;
* local user interactions not published through telemetry contracts.

### 7.4 Rationale

This boundary prevents the evolution layer from expanding into an uncontrolled full-chain learning system.

It also avoids ambiguity around:

* privacy;
* authorization;
* business ownership;
* observability;
* responsibility for local side effects;
* quality attribution across server and client boundaries.

---

## 8. Architectural Decisions

### ADR-1: Lightweight Engine Configuration Envelope

**Decision:** Introduce a shallow configuration envelope for heterogeneous execution engines.

**Reason:** The platform needs unified metadata, routing, and governance without prematurely defining a universal agent execution DSL.

**Consequence:** Engine-specific payloads remain engine-bound.

---

### ADR-2: Strict Engine Matching

**Decision:** Engine-specific configurations must be executed by compatible engines.

**Reason:** Execution semantics differ across engines and should not be silently translated.

**Consequence:** Runtime dispatch must validate engine type and compatibility before execution.

---

### ADR-3: Runtime-Mediated Middleware Control

**Decision:** Middleware integration belongs to Runtime, and execution engines must expose lifecycle hooks.

**Reason:** Cross-cutting enterprise policies should be centralized, while execution semantics remain inside the engine.

**Consequence:** Engines need hook capability, but should not depend on concrete middleware implementations.

---

### ADR-4: Client Capability Callback

**Decision:** Server-side execution may asynchronously invoke client-side capabilities through Runtime-controlled callbacks.

**Reason:** Some tools, observations, and business operations are only available on the client side.

**Consequence:** Runtime must handle latency, timeout, retry, idempotency, authorization, and trace correlation.

---

### ADR-5: Server-Controlled Evolution Scope

**Decision:** The evolution mechanism manages server-controlled execution scope by default.

**Reason:** Client-autonomous behavior may be private, unobservable, or outside server-side responsibility.

**Consequence:** Client-side behavior can be used for evolution only when explicitly exported through agreed telemetry or trace contracts.

---

## 9. Non-Goals

This proposal does not define:

1. a complete DSL grammar;
2. cross-engine semantic translation;
3. concrete hook SPI;
4. concrete callback protocol;
5. concrete client transport mechanism;
6. detailed timeout and retry implementation;
7. evolution algorithms or training pipelines;
8. specific Java classes, package names, or interfaces.

These should be handled in L1 or L2 design after the L0 boundaries are accepted.

---

## 10. Open Questions for Later Design

1. What metadata fields are mandatory in the configuration envelope?
2. How should engine compatibility be represented and validated?
3. Which lifecycle hooks are mandatory for every execution engine?
4. How should hook ordering and failure propagation work?
5. What should happen when a Runtime hook rejects or modifies an engine action?
6. What transport should be used for server-to-client capability invocation?
7. How should client callback idempotency and correlation IDs be standardized?
8. What minimum telemetry contract is required before client-side behavior can enter the evolution scope?

---

## 11. Summary

This proposal defines a small but important L0 contract for heterogeneous agent execution:

1. Use a lightweight configuration envelope instead of a premature universal DSL.
2. Keep engine-specific configurations bound to matching execution engines.
3. Let Runtime own middleware policies through execution engine hooks.
4. Support asynchronous server-to-client capability invocation when server-side execution needs client-side tools or observations.
5. Limit evolution to server-controlled execution scope by default.

The goal is to make heterogeneous execution manageable without hiding engine differences, overloading the Runtime, or expanding evolution beyond the controllable server-side boundary.
