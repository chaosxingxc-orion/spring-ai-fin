# agent-platform/contracts -- L2 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W0 | Maturity: L0 | Reads: -- | Writes: --
> Last refreshed: 2026-05-08

## 1. Purpose

Owns the **public REST surface** as DTO records (Java `record`) and
springdoc-openapi annotations. Generates the OpenAPI 3 spec consumed by
clients. The spec, not prose, is the authoritative contract.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Jackson | (BOM) | JSON binding |
| springdoc-openapi-starter-webmvc-ui | 2.x | OpenAPI generation |
| Hibernate Validator | (BOM) | `@Valid` constraints on DTOs |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `contracts/v1/RunRequest.java` (record) | POST body for `/v1/runs` | 40 |
| `contracts/v1/RunResponse.java` (record) | response body | 40 |
| `contracts/v1/Run.java` (record) | GET response | 40 |
| `contracts/v1/ProblemDetail.java` (record) | RFC-7807 | 40 |
| `contracts/v1/RunStatus.java` (enum) | enum | 30 |
| `contracts/openapi-snapshots/v1.yaml` | committed snapshot for regression test | 200 |

## 4. Public contract

Generated OpenAPI v3 published at `/v3/api-docs`. URL prefix `/v1/`.
Breaking changes bump to `/v2/` and the snapshot is rotated. The
generated spec must validate against the committed snapshot in
`OpenApiContractIT` at the wave boundary.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Allow undocumented fields in response | yes | reject CI | reject CI |
| Allow `additionalProperties: true` | yes | no | no |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `OpenApiContractIT` | Integration | generated spec matches committed snapshot |
| `DtoValidationIT` | Integration | `@Valid` violations -> 400 + RFC-7807 |
| `BackwardCompatNeg1IT` | Integration | request with extra fields -> ignored, not 400 |

## 7. Out of scope

- Internal Java APIs between modules (use plain interfaces, no DTO records).
- gRPC or other transports (W4+ if a customer demands).

## 8. Wave landing

W0 brings v1 records + springdoc annotations + snapshot.

## 9. Risks

- Spec drift from implementation: snapshot test catches.
- Deserialization vulnerabilities: Jackson default + no polymorphism;
  any `@JsonTypeInfo` change reviewed.
