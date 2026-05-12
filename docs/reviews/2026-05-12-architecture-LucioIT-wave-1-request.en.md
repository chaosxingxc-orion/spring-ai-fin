# Architecture Review Feedback: Wave 1 Refinement
**Date:** 2026-05-12  
**Reviewer:** LucioIT (Architecture Committee)  
**Subject:** Refinement of Hierarchy, Edge Deployment, and Bus Event Model

## 1. Hierarchy Management: Decoupling by Scope, Not Mode
### Context
The original design proposed a rigid nesting constraint between Graph (Rigid) and Dynamic (Flexible) modes.
### Feedback
Hierarchical boundaries should be defined by **Management Scope** rather than Execution Mode. The "Rigid-Flexible Inter-invocation" is an atomic capability. We propose a two-layer scenario structure:
- **Internal/Step Level:** P2P communication for control and data flows. Used for "sub-cortex" logic (e.g., a flexible agent calling a rigid SOP). Minimizes latency through direct context sharing or local pointers.
- **Social/Collaboration (Swarm) Level:** Control flow must escalate to the **Agent Bus** for global auditing, tenant quota management, and lifecycle orchestration. Data flow remains P2P via payload pointers (URI/Hash) to prevent bus congestion.
- **Outcome:** This ensures that "who is leading whom" is determined by business scope (RootRun vs. Sub-Run), allowing any mode to call any other mode within defined boundaries.

## 2. Dual-Posture Edge Deployment: Maintaining C/S Logic Integrity
### Context
Handling edge devices with local compute power while maintaining cloud-edge synergy.
### Feedback
We endorse a **"Logical Identity Equivalence"** model. The S-Side (Agent Runtime) should be a portable containerized kernel deployed on both cloud and edge.
- **Path A (C-Edge → S-Cloud):** Standard thin-client business call for heavy-duty analysis.
- **Path B (S-Local ↔ S-Cloud):** A2A (Agent-to-Agent) collaboration. The Local S-Side handles privacy-sensitive data and "suspends" to delegate intents to the Cloud S-Side.
- **Outcome:** This preserves the C/S logical boundary. S-Side remains the "Compute Factory" regardless of physical location, enabling seamless **Context Roaming** and privacy-preserving intelligence.

## 3. Distributed Event-Driven Bus: Rejecting the "Sync Trap"
### Context
The Whitepaper suggested using SyncOrchestrator with external intermediaries for backpressure as a temporary W1 solution.
### Feedback
We strongly reject the synchronous orchestration model even for the MVP. It creates significant architectural debt.
- **Proposed Model:** Distributed In-Memory Message Queue (e.g., Redis Streams, NATS). 
- **Advantage:** Agents are natively asynchronous. Using an event-driven model from Day 1 aligns with the "Fire-and-forget" cognitive loop.
- **Backpressure:** Implement a **Pull-based** mechanism where S-Side nodes fetch tasks based on local capacity (VRAM/CPU), rather than being "pushed" into thread-pool exhaustion.
- **Evolutionary Path:** This establishes the "Protocol Prototype" for the future centralized Agent Bus, allowing for a seamless SPI-level swap without refactoring agent logic.

## Summary
The refined architecture moves from a "Cloud-centric Rigid Pipeline" to a **"Cloud-Edge Synergistic Distributed Intelligence OS."** The focus shifts to lifecycle hydration, scope-based routing, and a true event-driven spine.
