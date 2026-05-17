---
level: L1
view: logical
module: agent-bus
status: skeleton
freeze_id: null
covers_views: [logical]
spans_levels: [L1]
authority: "ADR-0050 (Bus & State Hub plane); Layer-0 principles P-E (Three-Track Channel Isolation) and P-I (Five-Plane Distributed Topology); Rule 35 (Three-Track Channel Isolation)"
---

# agent-bus — L1 architecture (skeleton)

> Owner: AgentBus team | Wave: W2 | Maturity: skeleton (contracts only)
> Created: 2026-05-17 (six-module materialization PR)

## Status

**This module is a contract-scaffolding skeleton.** The three-track
channel isolation contract (`docs/governance/bus-channels.yaml`) ships
today; runtime implementations (WorkflowIntermediary, Mailbox,
AdmissionDecision, etc.) land in W2 per ADR-0050.

## 0.4 Layered 4+1 view map (W1 — ADR-0068)

Only the **logical** view is populated; **process** and **physical**
join when the runtime impls land.

| Section | View | Notes |
|---|---|---|
| §1 Role | logical | Bus & State Hub plane |
| §2 Three-track channel isolation | logical | Rule 35 / P-E |
| §3 SPI surface | logical | planned: WorkflowIntermediary, Mailbox, TickEngine |

## 1. Role

`agent-bus` is the **Bus & State Hub** of the platform. It owns:

- **Three physical channels** (`control`, `data`, `rhythm`) declared in
  `docs/governance/bus-channels.yaml` and enforced by gate Rule 45
  (`bus_channels_three_track_present`).
- **Workflow state durability** (work-state events, sleep declarations,
  wakeup pulses) that survive process restarts.
- **Tick engine** that re-hydrates suspended Runs on wake-pulse, per
  Chronos Hydration (Rule 38 / P-H).
- **Backpressure & admission control** at the bus boundary.

## 2. Three-track channel isolation (Rule 35 / P-E)

| Channel | Priority | Cargo | Failure mode if congested |
|---|---|---|---|
| `control` | highest | PAUSE / KILL / CANCEL intents | NEVER congested by `data` |
| `data` | normal | run payload bodies (≤16 KiB inline cap §4 #13) | may queue, never blocks `control` |
| `rhythm` | lowest | heartbeat / liveness pulses | drops oldest if saturated |

Authority: `docs/governance/bus-channels.yaml`. Each channel has a unique
`physical_channel:` identifier; gate Rule 45 enforces 3-channel presence
and uniqueness.

## 3. SPI surface (planned)

W2 will introduce:

- `WorkflowIntermediary` — interface for sending work-state events.
- `Mailbox` — per-Run inbox for control intents.
- `AdmissionDecision` — admit / suspend / reject at the bus boundary.
- `BackpressureSignal` — observable pressure metric per channel.
- `SleepDeclaration` + `WakeupPulse` — Chronos Hydration primitives.
- `TickEngine` — the timer-driven resume loop.

Until then, the runtime carries an in-process `SuspendSignal` /
`SyncOrchestrator` reference path. The cross-process bus replaces it in
W2 without changing the Run state-machine DFA (Rule 20).

## Reading order for new contributors

1. `module-metadata.yaml` — identity + dependency promises.
2. `docs/governance/bus-channels.yaml` — three-track schema.
3. `docs/dfx/agent-bus.yaml` — Design-for-X declarations.
4. ADR-0050, ADR-0069 — bus + ironclad-rule wave authority.
