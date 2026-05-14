# spring-ai-ascend L0 Architecture - Wave 1 Request

**Date:** 2026-05-14
**Author:** LucioIT
**Status:** Draft / Pending Review

## 1. Project Positioning
`spring-ai-ascend` is an enterprise-grade open-source Agent development and runtime tool foundation, deeply adapted to Huawei's Kunpeng and Ascend computing ecosystems, backed by Java and Spring framework standards, and openly compatible with various mainstream open-source Agent frameworks. It provides enterprise developers with a highly reliable infrastructure to rapidly build and deploy digital employee applications that support long-horizon execution and swarm intelligence collaboration. As an open-source enablement tool project, it focuses on providing framework and runtime support.

## 2. Design Philosophy
*   **Business-System Interface Separation**: 
    The integration boundary between the system and the business is strictly defined at the "task layer". The business system does not need to care about the agent's underlying thought trajectories or tool invocation details, but only focuses on the intermediate phase results; similarly, the agent does not need to comprehensively grasp the continuous long-horizon business processes or touch core business privacy, but only focuses on the specific task requirements currently assigned. This bidirectional interface separation completely decouples the enterprise platform architecture from specific businesses, avoiding the platform falling into a centralized bottleneck or endless custom development.
*   **Multi-Track Agent Bus Design**: 
    The platform's underlying architecture adopts a multi-track physically separated bus design comprising agent control flow, data flow, and rhythm flow (heartbeat/timeline). This design fundamentally prevents business blockage and congestion caused by intensive multi-agent collaboration or users inputting massive multi-modal data (like complex text, images, and videos), laying a solid foundational capability for large-scale, high-concurrency deployment of enterprise-grade agent applications.
*   **Intermediary-Dependent Interrupt & Interaction**: 
    The platform allows agents to accept interrupt requests from other agents or real users at any time, at the trajectory execution granularity or even finer context granularity. Through this intermediary scheduling mechanism, the system can support real-time direction adjustments, instruction abortion, and safe state rollbacks during agent runtime, accurately satisfying core risk control and intervention requirements in complex real-world enterprise scenarios.
*   **Open Compatibility for Heterogeneous Frameworks**: 
    The platform architecture does not pursue a closed, unipolar ecosystem, but allows the dynamic loading of heterogeneous agent framework runtimes. It supports seamless switching and nested invocation between "rigid" (e.g., strict SOP flowcharts) and "flexible" (e.g., LLM free exploration flows) agent execution modes. This philosophy not only protects enterprises' existing agent assets but also endows the system with flexible adaptation and composable capabilities for future open requirements.
*   **Developer-Centric Full Lifecycle Support**: 
    As a tool foundation, the platform places the developer experience at its core. While providing the basic runtime, the platform built-in or seamlessly integrates rich development and debugging tools (for orchestration and troubleshooting), operations observability tools (for monitoring foundation and computing power health), and operations visualization tools (for analyzing agent efficiency and trajectories), comprehensively lowering the usage barrier and troubleshooting costs for enterprise developers.

## 3. Architectural Principles
*(This section is temporarily left blank, reserved for domain architects to jointly discuss and supplement system-level core ironclad rules in subsequent reviews.)*

## 4. L0 Logical View
The system logic is strictly decoupled into six core modules, distinctly delineating the boundaries between business applications, execution environments, and platform infrastructure:

1.  **Agent Client**: Oriented towards business developers. It can be integrated into business IT systems or enterprise user terminals (PC/Mobile). Responsibilities include managing static business configurations (authorized tools, skills, etc.), dynamic task requirements, completion validation, and progress tracking; maintaining business-related knowledge systems and semantic constraints; and handling environment observation and manipulation on the business application side.
2.  **Agent Runtime**: Oriented towards business developers (recommended for direct deployment, supports secondary development). Responsibilities include reactive APP service encapsulation; supporting A2A (Agent-to-Agent) service exposure and acting as a client to invoke other agent services; managing agent sessions and tasks; integrating middleware; and providing compatibility and adaptation for agents developed via heterogeneous frameworks.
3.  **Agent Execution Engine**: Oriented towards business developers. It supports dual-mode execution: rigidly constrained "Workflow" mode (supporting low-code orchestration) and dynamic "AgentLoop" mode (supporting configuration and hook attachment). It is recommended to use open-source frameworks like `openJiuwen` or other mainstream agent frameworks for development.
4.  **Agent Evolution Layer**: Oriented towards business developers. It builds a data flywheel by collecting comprehensive operational data, providing a dual-track agent self-learning and continuous evolution mechanism.
5.  **Agent Bus**: Oriented towards platform developers (recommended for direct deployment, supports secondary development). It acts as the communication hub, handling client-to-server access, Server-to-Server A2A invocations, and agent self-triggered heartbeat rhythms.
6.  **Agent Middleware**: Oriented towards platform developers (recommended for direct deployment, supports secondary development). It provides standardized core infrastructure services, including the agent memory system, agent skill center, and agent sandbox services.

## 5. L0 Development View
*   **Lazy Mounting with State and Control Decoupling**:
    Only lightweight control instructions and data pointers (URI/Hash) are allowed to be passed during the flow lifecycle. Heavyload data (e.g., research report parsing results) falls into a bypass physical sandbox, and On-demand lazy mounting is executed via Hooks only when actual reading occurs.
*   **Rollback Isolation**:
    When an anomaly rolls back, only the control flow pointer cursor is rolled back. The heavyload data in the bypass pool does not undergo repeated serialization and deserialization along with the logical flow, reducing I/O overhead and code coupling.

## 6. L0 Process View
*   **Workflow Intermediary Hub**:
    The bus only Pushes intents to the intermediary mailbox fronting the compute node; the Agent compute engine Pulls tasks based on its own capacity watermark, forming a backpressure buffer.
*   **Decentralization of Rhythm Management**:
    Agent code-level `sleep()` is prohibited. Long-horizon sleep is converted to be taken over by the bus-level Tick Engine. During sleep, the compute process self-destructs (Chronos Hydration), and is only pulled up again when the bus wake-up pulse is delivered.
*   **Three-Track Isolation of Physical Channels**:
    1. **Strong Control Flow (High-priority Out-of-band)**: PAUSE, RESUME, KILL instructions.
    2. **Data Compute Flow (In-band)**: Business heavy payloads and asynchronous tool return results.
    3. **Heartbeat/Rhythm Flow**: Pulses maintaining survival status.

## 7. L0 Physical View
*   **Skill-Dimensional Resource Pooling**:
    Establish a global skill topology scheduler. When a high-frequency skill concurrency pool is full, it precisely suspends and queues only the specific Agent instances depending on that skill, without blocking lightweight reasoning Agents. Resource arbitration presents a dual-axis determination of "Tenant Quota × Global Skill Capacity".
*   **Bidding and Collaborative Permission Issuance**:
    *   **Pre-Authorized Access**: Capability registration is bound to domain permission identifiers issued by the S-Side.
    *   **Delegate Bidding System**: When an intent is thrown, only certified delegate nodes participate in bidding.
    *   **Skill Subsumption**: The S-Side strictly controls permission issuance. The winning delegate decomposes and distributes permissions downward to sub-agents, ensuring logical authorization aligns with underlying physical sandbox constraints.

## 8. Layered Architecture & Code Contribution Guidelines and Processes

### 8.1 4+1 View Consensus Definition
To ensure alignment of design language across architects and development teams, all architecture documents must be based on the "4+1 View" model:
*   **Logical View**: Focuses on domain division, entity models, module interfaces, and system responsibility boundaries.
*   **Development View**: Focuses on code organization, package structure, module dependencies (reverse dependencies prohibited), and anti-corruption layers.
*   **Process View**: Focuses on concurrency models, synchronous/asynchronous communication paradigms, and the timing and blocking control of data flow/control flow/rhythm flow.
*   **Physical (Deployment) View**: Focuses on deployment topology, compute node allocation, storage physical isolation levels, and runtime environments.
*   **Scenarios View (+1)**: Uses core business scenarios or flow links to connect the above 4 views, verifying the feasibility and self-consistency of the architectural design.

### 8.2 Layered Architecture Specifications
The system architecture is strictly divided into three progressive levels. **Each level should be expanded according to the 4+1 views**:
*   **L0 (Top-Level Design)**: Describes the global boundaries, core philosophies, and principles of the system. The L0 level 4+1 views only set consensus and macroscopic frameworks.
*   **L1 (Domain Design)**: Under the L0 framework, expands subsystem-level 4+1 view designs for specific core capability blocks.
*   **L2 (Technical Detailed Design)**: Detailed physical and execution designs oriented towards specific features and requirement use cases. L2 level 4+1 views can do "omission of irrelevant views" based on specific features, focusing on core implementation details.

### 8.3 Architecture Document Flow and Review Mechanism
*   **Release and Freeze by Phase**: Architecture documents should be Released by Phase. Once released and finalized, direct modifications are absolutely prohibited.
*   **Archive Isolation of Advanced Designs**: Any architectural design that exceeds the current phase (regardless of whether it belongs to L0/L1/L2) should be Archived to avoid interfering with the engineering implementation of the current phase.
*   **Architecture Change Review Flow**: All architecture modification proposals must first enter the `docs/reviews/` directory to form a proposal, and the proposal **must explicitly indicate the involved architecture level and affected view scope**.
*   **Modification Approval**: Change proposals must undergo strict review by the Chief Architect (or their authorized AI architecture assistant). Only after approval can authorized personnel update the official architecture documents of the current phase.

### 8.4 Code Contribution Guidelines
All PRs merged into the main branch must meet the following rigid constraints:
1.  **Routine Code Checks**: Must pass all unit tests, linting, and basic static checks.
2.  **L0 Principle Conflict Validation**: Code logic must not violate the core principles and design philosophies declared in the L0 architecture.
3.  **L1 Boundary Scope Validation**: Package references, dependencies, and module communications must strictly comply with the anti-corruption boundaries and visibility controls defined in the L1 domain views.
4.  **L2 Detailed Design Consistency Validation**: Code-level class structures, interface definitions, and sequences must be highly consistent with the L2 technical detailed design.
5.  **Code-as-Contract**: Related architectural constraints must be bound to automated guardian tests (ArchUnit or verification scripts) in `docs/governance/enforcers.yaml`. Code without automated constraint guarantees is strictly prohibited from being merged.

## Appendix: Ubiquitous Language
*(To be uniformly converged and supplemented during L1/L2 deepening: Task Cursor, Workflow Intermediary, Dynamic Hydration, YieldResponse, etc.)*