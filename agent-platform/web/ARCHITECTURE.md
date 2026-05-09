# agent-platform/web -- L2 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W0 | Maturity: L0 | Reads: -- | Writes: --
> Last refreshed: 2026-05-08

## 1. Purpose

Spring Web MVC controllers + exception handlers + OpenAPI annotations.
Stateless front door; delegates to lower modules (`tenant/`, `runtime`)
for any per-request state.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Boot starter web | 3.5.x | DispatcherServlet, MessageConverters |
| Hibernate Validator | (BOM) | `@Valid` |
| Jackson | (BOM) | JSON |
| springdoc-openapi-starter-webmvc-ui | 2.x | OpenAPI doc + Swagger UI |
| Resilience4j | 2.x | `@RateLimiter` annotations |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `web/HealthController.java` | `/v1/health` | 40 |
| `web/WorkspaceController.java` | `/v1/workspace` (W1) | 60 |
| `web/RunController.java` (proxy to runtime) | `/v1/runs` (W2) | 80 |
| `web/GlobalExceptionHandler.java` | `@ControllerAdvice` | 80 |
| `web/ProblemDetail.java` (record) | RFC-7807 | 30 |
| `web/OpenApiConfig.java` | securitySchemes, info | 50 |

## 4. Public contract

OpenAPI 3.0 generated at `/v3/api-docs`, served at `/swagger-ui`.
Versioned URL prefix `/v1/`. RFC-7807 problem-details on errors. All
4xx have a stable `type` URI.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| `/swagger-ui` exposed | yes | localhost only | localhost only |
| Stack traces in error body | yes | no | no |
| Detailed validation messages | yes | minimal | minimal |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `HealthEndpointIT` | Integration | 200 + body schema |
| `ValidationProblemDetailIT` | Integration | 400 + RFC-7807 body |
| `OpenApiContractIT` | Integration | `/v3/api-docs` parses + matches pinned snapshot |
| `Generic5xxNoLeakIT` | Integration (research) | unhandled exception -> 500 + sanitized body |

## 7. Out of scope

- Auth (`auth/`), idempotency (`idempotency/`), tenancy (`tenant/`).
- Async streaming (W4 if needed; default is request-response).

## 8. Wave landing

W0 brings `HealthController`, `OpenApiConfig`, `GlobalExceptionHandler`.
W1 adds `WorkspaceController`. W2 adds `RunController` proxy.

## 9. Risks

- DispatcherServlet + virtual threads: enabled by
  `spring.threads.virtual.enabled=true`; verified by load test in W2.
- OpenAPI drift: `OpenApiContractIT` pins the schema; breaking changes
  bump the version prefix.
