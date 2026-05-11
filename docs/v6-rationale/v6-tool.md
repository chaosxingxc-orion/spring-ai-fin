> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# agent-runtime/tool -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W3 | Maturity: L0 | Reads: tool_registry | Writes: tool_invocation (audit fold)
> Last refreshed: 2026-05-08

## 1. Purpose

Tool registry + invocation. Tools are MCP servers (process or in-VM
beans) registered per-tenant. The `LlmRouter` calls
`McpToolRegistry.find(tenantId, capability)` and dispatches via
ActionGuard. Replaces v6 `skill/` + parts of `capability/`.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| MCP Java SDK (`io.modelcontextprotocol.sdk:mcp`) | 2.0.0-M2 (milestone; U1) | tool protocol -- API may change at 2.0.0 GA |
| Spring Boot starter | (BOM) | bean lifecycle |
| Apache Tika | 2.x | document parser tool default |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `tool/McpToolRegistry.java` | per-tenant tool lookup | 120 |
| `tool/ToolDescriptor.java` (record) | name, schema, OPA capability | 50 |
| `tool/EchoTool.java` | stub for tests | 40 |
| `tool/HttpGetAllowlistTool.java` | safe http GET with allowlist | 100 |
| `tool/DocParserTool.java` | Tika-backed | 80 |
| `db/migration/V6__tool_registry.sql` | tenant-tool mapping | 50 |

## 4. Public contract

Tools register at startup via Spring `@Bean` of type `Tool`. Each
exposes:

- `name`: stable string.
- `inputSchema`: JSON schema.
- `outputSchema`: JSON schema.
- `capability`: maps to OPA capability string for `action/`.

Tenants enable tools via `tool_registry(tenant_id, tool_name,
enabled)`. Default = disabled.

External (MCP) tools run as separate processes attached via stdio or
HTTP+SSE per the MCP spec.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Tool default enable | all | none | none |
| Network egress without allowlist | allowed | denied | denied |
| MCP server out-of-process required | optional | required (sandbox) | required (sandbox) |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `ToolRegistrationIT` | Integration | beans registered; per-tenant lookup works |
| `ToolAllowlistIT` | Integration | http_get rejects non-allowlisted host |
| `ToolDispatchE2EIT` | E2E | LLM tool-call -> ActionGuard -> tool -> result |
| `McpExternalProcessIT` | Integration | external MCP server attaches + responds |
| `ToolUnknownToTenantIT` | Integration | tenant without enable -> denied at ActionGuard |

## 7. Out of scope

- ActionGuard policy (`action/`).
- LLM-side tool prompt formatting (`llm/`).
- Skill plug-in hot-reload (W4 via `agent-eval`).

## 8. Wave landing

W3 brings the registry + 2 reference tools (echo, http_get_allowlist).
Tika doc parser is W3; richer connectors are W4+ (per-customer).

## 9. Risks

- MCP protocol still evolving (0.x): pin one MCP SDK version per
  release; document migration on bump.
- Out-of-process tool overhead: only enforce in research/prod;
  benchmark in `McpExternalProcessIT`.
- Tool name collision across tenants: registry uses `(tenant, name)`
  as key.

## 10. Tool versioning + per-tenant quota + sandbox levels (added cycle-10 per TOOL-1, 2, 3)

### 10.1 Tool versioning

Every `ToolDescriptor` carries a SemVer-style `version` ("1.2.3").

`tool_registry`:

```
tenant_id uuid,
tool_name text,
tool_version text NOT NULL,
enabled boolean NOT NULL DEFAULT false,
sandbox_level smallint NOT NULL,
quota_per_run integer,
quota_per_day integer,
PRIMARY KEY (tenant_id, tool_name, tool_version)
```

Resolution rules:

1. If the LLM references a tool by `name@version`, exact match required.
2. If the LLM references just `name`, the registry returns the highest
   enabled version for that tenant.
3. If no enabled version, 422 `TOOL_VERSION_NOT_FOUND`.
4. Breaking changes require a new `tool_version`. Old version remains
   selectable by SemVer pin until tenant disables.

The `name@version` notation is also exposed via tool descriptor JSON
schema so the LLM sees the version label.

### 10.2 Per-tenant tool quota

Two caps per `(tenant, tool_name)`:

- `quota_per_run`: max calls of this tool within a single run. Default
  100. Exceeded -> 429 with `TOOL_QUOTA_RUN`.
- `quota_per_day`: max calls of this tool per UTC day per tenant.
  Default 10000. Exceeded -> 429 with `TOOL_QUOTA_DAY`.

Counters are kept in Valkey for hot-path cheap reads; reconciled to
Postgres daily.

### 10.3 Sandbox levels

| Level | Mechanism | Posture allowed |
|---|---|---|
| `0_none` | in-process Spring bean | dev only |
| `1_thread` | in-process bean with `SecurityManager` (deprecated) -- effectively level 0 in JDK 21+ | dev only |
| `2_subprocess` | MCP server in subprocess via stdio | dev / research / prod |
| `3_container` | MCP server in K8s sidecar pod | research / prod (recommended) |
| `4_wasm` | Wasm runtime (W4+ post; not committed) | future |

Per `tool_registry.sandbox_level`. `PostureBootGuard` blocks startup if
any tenant's tool uses sandbox_level 0/1 in `research`/`prod`.

### 10.4 Tool deprecation

A tool version may be marked `enabled=false` (deprecation) without
removal; the row is retained for audit. Tenants are notified via the
admin API. Hard-removal happens at 90 days.

### 10.5 Tests

| Test | Layer | Asserts |
|---|---|---|
| `ToolVersionResolutionIT` | Integration | `name@version` exact match works; bare `name` resolves to highest enabled |
| `ToolVersionMissingIT` | Integration | unknown version -> 422 TOOL_VERSION_NOT_FOUND |
| `ToolQuotaPerRunIT` | Integration | exceeding `quota_per_run` -> 429 |
| `ToolQuotaPerDayIT` | Integration | exceeding `quota_per_day` -> 429 |
| `SandboxLevelEnforcedIT` | Integration (research) | sandbox_level 0/1 in research -> startup fails |
| `ToolDeprecationFlagIT` | Integration | disabled version cannot be invoked even if explicitly requested |
