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
| MCP Java SDK (Anthropic) | latest 0.x | tool protocol |
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
