# New Architecture Governance Convention: The Revival of the 4+1 Views and Physical Demarcation in the Vibe Coding Era

**Date:** 2026-05-14
**Authors:** Chief Architect Zhengqiu, LucioIT
**Status:** Draft / Pending Review
**Target:** Architecture Group (Alignment document for all architects)

---

## 1. Background & Pain Points: Architectural Loss of Control and the "Text Flattening" Trap in Vibe Coding

As we deeply integrated AI-assisted programming (Vibe Coding) into our project, we discovered that the rate of architectural decay did not decrease; instead, it intensified in a new form. After profound reflection and inventory, we confirmed the fundamental crisis of our current architecture governance model: **treating "plain text rule enumerations (ADRs)" as "architectural design."**

In the past, over 60 flattened ADRs and dozens of `ARCHITECTURE.md` constraints constituted our architectural guidance. However, in the Vibe Coding era, large models (AI Agents), acting as "hyper-local super typewriters," exhibit severe **tubular vision and context collapse**:
*   **The Limitation of the Rules Perspective**: AI treats flattened ADRs as `If-Else` constraints to be satisfied one by one. It might remember Constraint A (e.g., C/S separation) but forget Constraint B (e.g., Payload expiration strategy).
*   **Deep Logical Fractures**: AI can write code that perfectly passes a single test, but the assembled system exhibits "Frankenstein" phenomena that cannot self-reconcile, such as state machine deadlocks (e.g., conflicts between DFA constraints and backpressure mechanisms) and distributed GC vulnerabilities.

**Core Conclusion: Vibe Coding solves the "implementation efficiency" problem but cannot solve "system entropy." In the AI era, architects must not abandon traditional software engineering. Instead, they must return to the most hardcore, highly cohesive, and loosely coupled modular designs, using physical isolation to frame the AI's divergent boundaries.**

## 2. The Breakthrough: New Interpretation of 4+1 Views in the Era of AI Programming

"Flattened constraints are just laws, while cohesive modules are city walls." 
To combat the hallucinations and tubular vision of large models, the final deliverable of architectural design must never be just a pile of Markdown text. It must be a skeleton with strict "tri-state limits" (development state, deployment state, runtime state). We must reintroduce and upgrade the traditional **4+1 Views**, serving as a **"physical barrier"** to restrict AI's overstepping behaviors.

### 2.1 Development View — Contain Code-Level Coupling
*   **Traditional Meaning**: Module division and code organization.
*   **Significance in the AI Era**: Using compilers and package managers (e.g., Maven/Gradle) as a defense line. By establishing an absolutely pure SPI contract pool and forcing unidirectional dependencies (e.g., `agent-runtime` must absolutely not depend on `agent-platform`), we ensure that even if the AI hallucinates, it cannot introduce unauthorized code into the contract modules (ArchUnit will reject it directly at compile time).

### 2.2 Process View — Contain State Chaos and Ghost Invocations
*   **Traditional Meaning**: Concurrency, synchronous/asynchronous communication.
*   **Significance in the AI Era**: AI severely lacks intuition regarding race conditions, network latency, and concurrency blocking. The process view must hardcode the system's "blood vessels." For example, explicitly specifying the physical isolation of the control flow, data flow, and rhythm flow (three-track bus), and forcing all long-running tasks to use the Suspend paradigm. AI can only fill logic within these established channels and cannot arbitrarily create choke points.

### 2.3 Physical (Deployment) View — Contain Resource Explosion and Security Overstepping
*   **Traditional Meaning**: Deployment topology, containers, and networks.
*   **Significance in the AI Era**: Defining the physical boundaries of process execution. Explicitly distinguishing between the S-Cloud where the core engine resides and the physically isolated Sandbox where untrusted AI-generated tool code executes. Once an AI-generated crawler or data script attempts to write to the main node's disk, it will be directly intercepted by the read-only file system at the OS/container level.

### 2.4 Logical View — Contain Domain Model Collapse
*   **Traditional Meaning**: Domain models, entity relationships.
*   **Significance in the AI Era**: Establishing insurmountable conceptual red lines (e.g., the boundary between C-Side and S-Side). Through strict generics and immutable objects, we restrict AI from sneaking private data into the state machine, ensuring the enforcement of the Cognition-Action separation principle.

### +1. Scenarios View — The Touchstone Across Boundaries
Using golden links (e.g., multi-agent relay collaboration, human-in-the-loop approvals) to penetrate and inspect the above four views, verifying whether boundaries are self-consistent and interactions are deadlock-free.

## 3. Architecture Governance Convention

Based on the above reflections, the architecture group establishes the following new conventions as ironclad rules for all subsequent architectural evolution:

### Convention 1: Layered 4+1 Views Unfolding Principle
All architectural designs must abandon single-dimensional flattened documents. The system architecture must be strictly divided into three progressive levels, and **each level must be elaborated according to the 4+1 views** (the L2 level allows the omission of irrelevant views):
*   **L0 (Top-Level Design)**: Defines global boundaries, core philosophies, and principles (the highest consensus, not involving specific technical details).
*   **L1 (Domain Design)**: Under the L0 framework, expands subsystem 4+1 views for specific core capability blocks (e.g., memory subsystem, bus protocols).
*   **L2 (Technical Detailed Design)**: Physical and execution designs oriented towards specific features and requirement use cases.

### Convention 2: Absolute Rigidity of Code-as-Contract
Text constraints without automated verification are uniformly considered invalid.
*   Any architectural constraint written into L0/L1 must be bound to automated guardian tests (e.g., ArchUnit tests, verification scripts, database Schema constraints) in `docs/governance/enforcers.yaml`.
*   Before AI-assisted generated code can be merged, it must pass five strict gates: routine code checks, L0 principle conflict validation, L1 boundary scope validation, L2 detailed design consistency validation, and automated Code-as-Contract validation.

### Convention 3: Architectural Phase Release and Freeze Mechanism
*   **Release means Freeze**: Architecture documents should be released by Phase. Once a release is finalized, absolutely no one is allowed to directly modify the original document.
*   **Archive Advanced Designs**: Any architectural ideas or designs that exceed the current phase (no matter how excellent) must be forcibly isolated and Archived, strictly forbidding them from interfering with the current iteration's development and AI code generation context.

### Convention 4: Standardized Change Review Flow
All architecture modification proposals (especially challenges to existing ADR boundaries) must go through the following standard process:
1.  Form an independent Markdown proposal under the `docs/reviews/` directory.
2.  The proposal must explicitly indicate **"which view (logical/development/process/physical) of which level (L0/L1/L2) is affected."**
3.  Only after deep review and approval by the Chief Architect team can it be applied to the latest phase's architectural documents by designated personnel.

---
*"In the era of the AI explosion, an excellent architect does not teach AI how to write every line of code, but rather forges an insurmountable steel fence around it."*