# API Conventions -- cross-cutting policy

> Owner: platform | Wave: W0 | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Standardizes the public HTTP / REST surface so every controller,
DTO, and OpenAPI operation looks the same. Owned by
`agent-platform/contracts/`. Replaces ad-hoc per-endpoint conventions.

## 2. URL versioning

- Major version in URL prefix: `/v1/...`, `/v2/...`.
- A breaking change increments the major version; the prior version
  remains for at least 90 days (research) / 180 days (prod).
- No minor / patch versioning in URL; non-breaking additions ride on
  the existing major.
- `/health`, `/actuator/**`, `/v3/api-docs`, `/swagger-ui` are
  un-versioned (operational endpoints).

## 3. HTTP methods + idempotency

| Method | Idempotent? | Body? | Notes |
|---|---|---|---|
| GET | yes | none | safe; cache-friendly |
| POST | NO unless `Idempotency-Key` provided | yes | mutating; default for create |
| PUT | yes | yes | full replace; rare in our API |
| PATCH | NO unless `Idempotency-Key` | yes | partial update |
| DELETE | yes | none/optional | soft-delete preferred |

`Idempotency-Key` header is required on every POST in `research`/`prod`.
See `agent-platform/idempotency/`.

## 4. Resource naming

- Plural nouns: `/v1/runs`, `/v1/tools`, `/v1/workspaces`.
- Sub-resources via path segments: `/v1/runs/{run_id}/cancel`.
- Verbs allowed only as sub-actions on a resource: `/cancel`,
  `/replay`, `/feedback`.
- No verbs as top-level paths (no `/v1/cancelRun`).
- IDs are UUIDs (per `docs/cross-cutting/data-model-conventions.md`).

## 5. Status codes

| Code | Meaning | When |
|---|---|---|
| 200 | OK | GET / safe operation success |
| 201 | Created | POST that creates a resource (return Location header) |
| 202 | Accepted | POST that starts an async operation (return run_id) |
| 204 | No Content | DELETE success |
| 400 | Bad Request | malformed request; validation failure |
| 401 | Unauthorized | missing / invalid JWT |
| 403 | Forbidden | authenticated but lacks capability |
| 404 | Not Found | resource does not exist OR belongs to different tenant (RLS hides) |
| 409 | Conflict | idempotency-key in-flight; concurrent state mutation |
| 422 | Unprocessable Entity | semantic validation failure (preferred over 400 when format is OK) |
| 429 | Too Many Requests | rate limit; budget exceeded |
| 500 | Internal Server Error | unexpected; sanitized body in research/prod |
| 502 | Bad Gateway | upstream LLM/tool returned non-recoverable error |
| 503 | Service Unavailable | dependency down (Postgres / Vault / OPA) + circuit breaker open |
| 504 | Gateway Timeout | upstream timeout exceeded |

## 6. Error body (RFC 7807)

Every 4xx / 5xx response uses `application/problem+json`:

```json
{
  "type": "https://errors.spring-ai-ascend.example/<error-code>",
  "title": "Short human-readable summary",
  "status": 422,
  "detail": "Concrete explanation of this occurrence",
  "instance": "/v1/runs/abc-123",
  "code": "RUN_PROMPT_TOO_LONG",
  "tenant_id": "<uuid|null>",
  "trace_id": "<otel-trace-id>",
  "timestamp": "2026-05-09T13:00:00Z",
  "errors": [
    { "field": "prompt", "code": "TOO_LONG", "max": 32768 }
  ]
}
```

`code` is a stable string that clients may switch on. `errors[]` is
present for validation failures.

## 7. Error code taxonomy

| Prefix | Domain | Example |
|---|---|---|
| `AUTH_*` | authentication | `AUTH_TOKEN_EXPIRED`, `AUTH_ALG_REJECTED` |
| `AUTHZ_*` | authorization | `AUTHZ_TENANT_MISMATCH`, `AUTHZ_TOOL_DENIED` |
| `TENANT_*` | tenancy | `TENANT_GUC_EMPTY`, `TENANT_SUSPENDED` |
| `RUN_*` | run lifecycle | `RUN_PROMPT_TOO_LONG`, `RUN_NOT_FOUND`, `RUN_CANCEL_LATE` |
| `TOOL_*` | tool dispatch | `TOOL_NOT_REGISTERED`, `TOOL_VERSION_NOT_FOUND`, `TOOL_HOST_NOT_ALLOWED` |
| `LLM_*` | LLM gateway | `LLM_PROVIDER_UNAVAILABLE`, `LLM_QUOTA_EXCEEDED` |
| `BUDGET_*` | cost / quota | `BUDGET_TENANT_EXHAUSTED`, `BUDGET_RUN_LIMIT` |
| `IDEM_*` | idempotency | `IDEM_KEY_CONFLICT`, `IDEM_KEY_REQUIRED` |
| `MEM_*` | memory | `MEM_QUOTA_EXCEEDED`, `MEM_DIM_MISMATCH` |
| `CONTRACT_*` | request/response | `CONTRACT_FIELD_MISSING`, `CONTRACT_FIELD_INVALID` |
| `SYS_*` | system | `SYS_DEPENDENCY_DOWN`, `SYS_INTERNAL_ERROR` |

## 8. Pagination

Cursor-based pagination on collection endpoints:

- Request: `?limit=100&cursor=<opaque-base64>`
- Response: `{ "items": [...], "next_cursor": "<opaque|null>" }`
- `limit` default = 20, max = 200.
- Cursor is opaque to the client; encodes (last_id, last_ts).
- Sort is stable: `ORDER BY ts DESC, id DESC`.

Offset pagination is NOT supported (poor performance under multi-tenant
load).

## 9. Filtering and sorting

- Filtering: `?filter.<field>=<value>`. Equality only; no DSL.
  Multiple `filter.` params combine with AND.
- Sorting: not exposed in v1 (default sort is enforced).
- Search: per-resource `q` param when applicable; no full-text in v1.

## 10. Headers

Required:

- `Authorization: Bearer <jwt>` (except `/health`).
- `Content-Type: application/json` for body-bearing requests.

Recommended:

- `Idempotency-Key: <opaque-string>` (required on POST in
  `research`/`prod`).
- `X-Request-ID: <uuid>` (generated if absent; echoed back).

Response always includes:

- `X-Request-ID`
- `X-Trace-ID` (OpenTelemetry trace id)

Conditional / future:

- `Idempotent-Replayed: true` when replay (cycle-9-aligned).
- `Deprecation` + `Sunset` headers on deprecated endpoints.

## 11. OpenAPI

- `/v3/api-docs` exposed by springdoc (W0).
- `/swagger-ui` exposed in `dev`; localhost-only in `research`/`prod`.
- The OpenAPI spec is versioned and snapshot-tested
  (`OpenApiContractIT` in `agent-platform/contracts/`).
- Operations have stable `operationId` matching the controller method
  name.
- Every operation has `x-error-codes: [<code>, ...]` listing possible
  error codes.

## 12. Streaming responses

- Server-Sent Events for streaming (`text/event-stream`).
- Reserved for `POST /v1/runs:stream` (W3+); not in v1.
- WebSocket is NOT supported in v1.

## 13. Deprecation

- A deprecated endpoint returns `Deprecation: true` header + a
  `Sunset: <RFC 1123 date>` header.
- Removal happens at the major-version bump.
- Communication: changelog + per-tenant email (manual in v1).

## 14. Tests

| Test | Layer | Asserts |
|---|---|---|
| `OpenApiContractIT` | Integration | spec matches snapshot |
| `ProblemDetailShapeIT` | Integration | every 4xx / 5xx returns RFC-7807 |
| `ErrorCodeRegistryIT` | Integration | every emitted `code` is in the taxonomy table |
| `IdempotencyOnPOSTIT` | Integration | research/prod POST without key -> 400 |
| `PaginationCursorIT` | Integration | cursor round-trip works; offset rejected |
| `DeprecationHeaderIT` | Integration (W4+) | deprecated endpoints emit headers |

## 15. Out of scope

- gRPC / GraphQL transports (W4+ if customer demand).
- Server-push beyond SSE (WebSocket rejected for v1).
- HATEOAS / hypermedia (not used).
- API gateway-level features (auth, rate-limit) -- those live at TB-1.

## 16. References

- `agent-platform/contracts/ARCHITECTURE.md`
- `agent-platform/web/ARCHITECTURE.md`
- `docs/cross-cutting/data-model-conventions.md` (ID strategy + UUID format)
