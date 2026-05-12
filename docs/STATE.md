# Current State (W0)

<!-- columns: capability | shipped | code-path | test-path | posture-coverage | claim -->

## Shipped (W0)

| capability | shipped | code-path | test-path | posture-coverage | claim |
|------------|---------|-----------|-----------|------------------|-------|
| health-endpoint | true | `agent-platform/src/main/java/ascend/springai/platform/web/HealthController.java` | `agent-platform/src/test/java/ascend/springai/platform/HealthEndpointIT.java` | dev/research/prod | GET /v1/health returns 200 |
| tenant-filter | true | `agent-platform/src/main/java/ascend/springai/platform/tenant/TenantContextFilter.java` | `agent-platform/src/test/java/ascend/springai/platform/tenant/TenantContextFilterTest.java` | dev/research/prod | X-Tenant-Id validated; dev default on missing |
| idempotency-filter | true | `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilter.java` | `agent-platform/src/test/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilterTest.java` | dev/research/prod | Idempotency-Key validated; dev accepts missing |
| idempotency-store | false | `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyStore.java` | `agent-platform/src/test/java/ascend/springai/platform/idempotency/IdempotencyStoreTest.java` | dev (W0); research/prod throws | W0 stub; W1 will add Postgres-backed claimOrFind |
| graphmemory-spi | false | `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java` (interface) | `agent-runtime/src/test/java/ascend/springai/runtime/memory/spi/MemorySpiArchTest.java` | no runtime path | SPI contract only; no impl; ArchUnit enforces isolation |
| oss-api-probe | true | `agent-runtime/src/main/java/ascend/springai/runtime/probe/OssApiProbe.java` | `agent-runtime/src/test/java/ascend/springai/runtime/probe/OssApiProbeTest.java` | dev | Smoke test: Spring AI + MCP + Temporal + Tika compile |
| run-entity | true | `agent-runtime/src/main/java/ascend/springai/runtime/runs/Run.java` | `agent-runtime/src/test/java/ascend/springai/runtime/runs/RunTest.java` | dev | Run entity with mode (GRAPH\|AGENT_LOOP), parentRunId, parentNodeKey, SUSPENDED status; contract-spine for Rule 11 |
| idempotency-record-entity | true | `agent-runtime/src/main/java/ascend/springai/runtime/idempotency/IdempotencyRecord.java` | `agent-runtime/src/test/java/ascend/springai/runtime/idempotency/IdempotencyRecordTest.java` | dev | IdempotencyRecord entity with mandatory tenantId; contract-spine for Rule 11 |
| orchestration-spi | true | `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/` | `agent-runtime/src/test/java/ascend/springai/runtime/orchestration/spi/` | dev | Orchestrator + GraphExecutor + AgentLoopExecutor + SuspendSignal + Checkpointer + RunContext + ExecutorDefinition SPIs; pure java.* only (ArchUnit enforced) |
| inmemory-orchestrator | true | `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/` | `agent-runtime/src/test/java/ascend/springai/runtime/orchestration/NestedDualModeIT.java` | dev | SyncOrchestrator + SequentialGraphExecutor + IterativeAgentLoopExecutor; 3-level graph↔agent-loop nesting proved; dev-posture only |

---

## Designed not shipped — competitive analysis (2026-05-12)

*Added via competitive analysis vs SAA + AgentScope-Java. See `docs/reviews/2026-05-12-competitive-analysis-and-enhancements.en.md`.*

| capability | code-path | wave | claim |
|---|---|---|---|
| runtime-hook-spi | `agent-runtime/.../action/spi/RuntimeHook.java` (future) | W2 | HookChain at BEFORE/AFTER MODEL, TOOL, AGENT; PII + token counter + summariser + tool-call-limit ref hooks; Rule 19 gate |
| graph-dsl-conformance | `agent-runtime/.../orchestration/spi/ExecutorDefinition.java` (extend) | W3 | KeyStrategy registry + typed Edge with predicate + JSON/Mermaid export; backward-compat factory retained |
| eval-harness-contract | `docs/eval/` (future) | W4 | corpus.jsonl + evaluator.yaml + thresholds.yaml per capability; EvalThresholdGate blocks merge on regression; Rule 18 gate |
| trace-replay-dev-surface | `agent-runtime/.../trace/TraceReplayMcpServer.java` (future) | W4 | MCP tools get_run_trace + list_runs; OTel-driven from trace_store; no Admin UI |
| sandbox-executor-spi | `agent-runtime/.../action/spi/SandboxExecutor.java` (future) | W3 | ActionGuard Bound stage; NoOp default; GraalVM polyglot pluggable; ADR-0018 |
| a2a-federation-strategic | `docs/adr/0016-a2a-federation-strategic-deferral.md` | post-W4 | AgentCard + AgentRegistry + RemoteAgentClient contract surface; registry-binding pluggable |
| multi-backend-checkpointer | `agent-runtime/.../orchestration/inmemory/` (extend) | W2 | Postgres + Redis + file Checkpointer impls behind existing SPI |
| hybrid-rag-bm25 | `agent-runtime/.../memory/` (extend) | W3 | MemoryService L2 + BM25 keyword index + alpha-blended scoring |
| planner-as-tool-pattern | `agent-runtime/.../orchestration/spi/AgentLoopDefinition.java` (extend) | W4 | PlanNotebook toolset for IterativeAgentLoopExecutor; plan rows in run_memory |

---

## Deferred

- Rule 8 gate runs (N≥3 real-LLM sequential runs) and Rule 11 contract-spine fields (`tenant_id` on all
  persistent records) are tracked in [`docs/CLAUDE-deferred.md`](CLAUDE-deferred.md).
- Architecture-level capability status and L-level assignments are tracked in
  [`docs/governance/architecture-status.yaml`](governance/architecture-status.yaml).

---

## Design rationale

Archived pre-refresh docs: `docs/v6-rationale/`

---

## Reading order for new team members

1. `README.md` — project name, status, modules, quick start
2. `docs/STATE.md` — this file; per-capability shipped/deferred table
3. `ARCHITECTURE.md` — system boundary, decision chains, SPI contracts
