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
The code engineering structure and anti-corruption boundaries of this system follow strict module division and repository matrix specifications to ensure the high cohesion and low coupling of the enterprise-grade foundation:

### 5.1 Repository Matrix and Technology Stack Planning
To maintain the vitality of the open-source community and leverage the advantages of heterogeneous ecosystems, core logical modules are recommended to be hosted as independent repositories in open-source communities (such as `openJiuwen`):
*   **Agent Execution Engine (`agent-core-java`)**: The pure engine of the system (built with Pure Java). Responsible for underlying scheduling such as DFA state machines and graph execution. It is strictly forbidden to contain any hard-bound annotations from the Spring framework layer, exposing only core SPIs.
*   **Agent Runtime (`agent-runtime-java`)**: The northbound service gateway of the system. Built with the Spring technology stack, it is responsible for encapsulating the pure Java logic of the Core layer into enterprise-grade REST/gRPC services, handling tenant interception and security control.
*   **Agent Client SDK (`agent-client-sdk-java`)**: Provides a non-intrusive integration toolkit oriented towards business development, supporting Zero-Dependency introduction into various business IT systems.
*   **Agent Bus (`agent-bus-java`)**: An independent hub carrying communication routing and heartbeat rhythms. Supports multi-level implementations (from memory-level buses in the development state to interfacing with distributed components like Kafka/Redpanda in the production state).
*   **Agent Evolution Layer (`agent-evolution-python`)**: A **heterogeneous ecosystem repository** dedicated to algorithms and self-learning. It leverages Python's ecological monopoly in machine learning, reinforcement learning, and Fine-tuning to handle heavy computing, trajectory analysis, and automatic prompt optimization. Physically, it naturally achieves isolation between offline analysis and online business.
*   **Agent Middleware Modules**: Temporary no independent repositories will be built. This is achieved by introducing mature open-source components at the Runtime layer (e.g., `Spring AI` interfacing with model gateways, `PostgreSQL` + `pgvector` acting as persistent runtime libraries and memory foundations).

### 5.2 Development-State Anti-Corruption Red Lines and Dependency Principles
1.  **Unidirectional Gravity and Kernel Purity Principle**: `Agent Client` and `Agent Runtime` can unidirectionally depend on `Agent Core`, but `Agent Core` must absolutely reside at the very bottom of the dependency tree. It is strictly forbidden to reversely introduce any code from upper layers (like the access layer or specific business scenarios).
2.  **Middleware SPI Inversion Principle**: Core logic must not be directly coupled with specific storage or middleware implementations. `agent-core-java` is only responsible for defining storage contracts (like the `Checkpointer SPI`); specific persistent adaptations (like the Postgres implementation) must be injected at Runtime.
3.  **Polyglot Collaboration Boundary**: Memory-level sharing or private library dependencies are absolutely forbidden between the Execution Engine (Java) and the Evolution Layer (Python). The two must and can only synchronize states and trigger reverse sampling through the Agent Bus and language-agnostic data serialization contracts (such as Protobuf or standard JSON Schema).

## 6. L0 Process View
The process view focuses on the concurrency model, cross-module communication paradigms, and blocking control strategies at runtime, aiming to ensure absolute robustness and high throughput of the system when facing massive multi-agent collaboration and long-horizon tasks:

### 6.1 C/S Asynchronous Interaction and Cursor Flow Paradigm
*   **Absolute Asynchronous Client Communication**: The interaction between the `Agent Client` and `Agent Runtime` strictly prohibits the use of traditional synchronous blocking models. After the client submits a long-horizon task, the system must immediately return a Task Cursor carrying the lifecycle status.
*   **Polymorphic Feedback Channels**: For process states, the client can establish a lightweight sub-stream via SSE (Server-Sent Events) to obtain real-time deduction processes. For intermediate phase results or blocking nodes requiring Human-in-the-loop intervention, the system must awaken the client via asynchronous Webhook callbacks, thoroughly eliminating the client's long-connection busy-waiting.

### 6.2 Shadow Traffic Consumption Model for Cross-Language Ecosystems
*   **Isolation of Main Pipeline and Evolution Layer**: Chain-of-thought trajectories, tool invocation latencies, and intermediate results generated by the Java Execution Engine must be thrown asynchronously to the data track of the bus in the form of "Event Sourcing."
*   **Bypass Consumption Closed-Loop**: The `Agent Evolution Layer` built with Python acts as an independent bypass consumer on the bus, receiving "Shadow Traffic" for offline cleansing, reinforcement learning scoring, and knowledge graph construction. It is strictly forbidden to synchronously wait for the algorithm layer's computing feedback on the main execution pipeline, ensuring that the core engine's processing latency is not dragged down by heavy-load algorithms like LLM fine-tuning.

### 6.3 Absolute Non-Blocking Ironclad Rule for External I/O Invocations
*   **Reactive and Virtual Thread Foundation**: For external invocations in the `Agent Middleware` layer that are highly prone to long latencies (e.g., large model reasoning generation, large vector database retrieval, sandbox script execution), the runtime must adopt a Reactive programming model or lightweight coroutines/Virtual Threads.
*   **Prohibition of I/O Monopolization**: During the tens of seconds of vacuum period waiting for the external API to return, the underlying OS-level compute threads must be forcibly released and yielded for other Agent instances to use, physically preventing system-level concurrency paralysis caused by external network I/O hanging.

### 6.4 Engine Internal Scheduling and Protection Baselines
*   **Pull-Mode Backpressure of Workflow Intermediaries**: Abandoning the bus's brute-force Push dispatching. The bus only delivers execution intents to the intermediary mailbox fronting the compute node. The Agent compute engine actively Pulls tasks based on its own current memory watermark and concurrency quota, forming a natural protective backpressure buffer.
*   **Rhythm Takeover and Process Self-Destruction**: The use of physical thread sleeping (like `sleep()`) is strictly prohibited in business code. All long-horizon sleeping must be converted to declarative suspension and taken over by the bus-level Tick Engine. During the sleep period, the compute process executing that Agent must immediately release or self-destruct (Chronos Hydration), and can only be rehydrated and pulled up when the bus wake-up pulse arrives.
*   **Three-Track Isolation of Physical Channels**: Cross-service internal communication is mandatorily sliced into three independent physical channels. The strong control flow (like PAUSE, KILL instructions) possesses the highest priority independent out-of-band channel; the data compute flow (like text-to-video file flow) takes the in-band heavy-load channel; the heartbeat/rhythm flow is responsible for maintaining survival status pulses. The three tracks are absolutely isolated to prevent global paralysis caused by any single type of network congestion.

## 7. L0 Physical View
The physical view focuses on the physical topology, isolation levels, and resource allocation boundaries of system components in a production environment, acting as the last line of defense to ensure high availability, high security, and avalanche prevention:

### 7.1 Distributed Five-Plane Deployment Topology
Physical deployment is strictly divided into five mutually isolated planes to ensure that workloads with different characteristics do not interfere with each other:
*   **Edge Access Plane**: The physical location of the `Agent Client` SDK. It can be embedded within business servers in an enterprise intranet or run directly on terminal devices. As the physical entry point for the entire foundation, its deployment characteristics are extremely lightweight, zero-state, and directly face security protections at the network edge.
*   **Compute & Control Plane**: The area where the `Agent Runtime` and `Agent Execution Engine` reside. Compute nodes in this plane must be stateless containerized clusters (like K8s Pods), responsible for processing highly concurrent instruction parsing and state machine transitions, supporting second-level horizontal elastic scaling.
*   **Bus & State Hub Plane**: The heavy data plane composed of the `Agent Bus` (acting as an independent physical Broker cluster, like Kafka/Redpanda) and `Agent Middleware` (like PostgreSQL, Vector DBs). This plane is the only physical anchor for system state and must be deployed on independent storage-compute nodes with extremely high I/O throughput and persistence guarantees.
*   **Sandbox Execution Plane**: The system's bottom-line physical security isolation zone. All dynamically generated code by large models (like Code Interpreter outputs) or unverified third-party tools are **absolutely forbidden** from executing in the Compute & Control Plane. They must be scheduled to run in disposable physical sandboxes, such as independent Serverless container groups or Firecracker microVMs.
*   **Evolution Plane**: An independent offline or near-real-time compute cluster where the `Agent Evolution Layer` (Python ecosystem) resides. To prevent model fine-tuning or massive data cleansing from dragging down CPU and memory required for online transactions, this plane must be deployed in an independent physical node group (like a dedicated GPU Node Pool), operating by subscribing to bypass traffic across planes via the bus.

### 7.2 Multi-Tenancy and Data Asset Physical Storage Red Line
As an enterprise-grade foundation, isolation logic at the application code layer is deemed "insecure." Multi-tenant data isolation must descend to the physical or mechanism bedrock of the storage engine. For instance, all Agent memories and trajectories persisted to the database are mandated to enable Row-Level Security (RLS) policies or adopt independent Schema/Database isolation at the underlying engine. This ensures that even if runtime code vulnerabilities allow unauthorized access, cross-tenant assets cannot be stolen at the physical storage engine level.

### 7.3 Skill-Dimensional Physical Resource Arbitration
To prevent a single high-frequency skill (e.g., a slow external API) from exhausting the entire cluster's connection pool and CPU resources, the system establishes a global skill topology scheduler at the physical level. When a skill concurrency pool is full, the scheduler precisely suspends and queues only specific Agent compute processes that depend on that skill, yielding underlying OS-level thread resources to other Agent instances executing lightweight reasoning, forming a two-dimensional physical defense net (Tenant Quota × Global Skill Capacity).

### 7.4 Bidding and Physical Sandbox Permission Alignment
Collaboration across physical nodes must be based on a "Zero Trust" assumption.
*   **Pre-Authorized Access**: Nodes initiating capability registration across networks must be bound to domain permission credentials issued by the platform.
*   **Sandbox Permission Subsumption**: After successful bus intent bidding, when the platform issues execution permissions downwards, it must map the logical authorization scope 1:1 to the system-level restrictions of the physical sandbox where the node resides (e.g., outbound network IP whitelists, CPU usage caps). This ensures that the logical issuance of execution rights does not breach the physical sandbox's isolation limits.

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