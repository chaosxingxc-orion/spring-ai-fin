# Secrets Lifecycle -- cross-cutting policy

> Owner: security | Wave: W2 (Vault binding) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Names every secret the platform consumes, where it lives, who owns
rotation, and what the application does on rotation events. Replaces
the pre-refresh `docs/secrets-lifecycle.md`.

## 2. Secrets registry

| Secret | Source of truth | Vault path scheme | Read by | Rotation cadence | Action on rotation |
|---|---|---|---|---|---|
| OIDC JWKS public keys | Identity provider (Keycloak / Auth0 / Cognito) | n/a (HTTP fetched) | `agent-platform/auth` | Provider's cadence (typically 90d) | JWKS cache TTL re-fetches; no app restart |
| HS256 BYOC HMAC secret | Customer | `secret/byoc/<tenant>/jwt-hmac-key` | `agent-platform/auth` (when carve-out enabled) | 30d | Hot-reload via Vault watcher |
| LLM provider API keys | Provider account | `secret/llm/<provider>/api-key` | `agent-runtime/llm` | 90d | Hot-reload via Vault watcher; W4 supports per-tenant keys |
| Postgres app role password | Cluster admin | `secret/db/app-user/password` | All Spring Boot replicas | 30d | Spring Cloud Vault refresh + HikariCP rebuild pool |
| Temporal namespace credentials | Cluster admin | `secret/temporal/<env>/credentials` | `agent-runtime/temporal` | 90d | Hot-reload via Vault watcher |
| OPA bundle signing key | Cluster admin | `secret/opa/bundle-key` | `agent-runtime/action` (OPA sidecar config) | 180d | OPA-sidecar restart |
| Object-store anchor credentials | Cluster admin | `secret/audit/s3-anchor` | `agent-runtime/action` (audit Merkle anchor; W4) | 90d | Hot-reload |
| Webhook outbound signing key | Per-tenant | `secret/webhook/<tenant>/sign-key` | `agent-runtime/outbox` (W4 sink) | 30d | Hot-reload |
| TLS cert (gateway) | Cert authority + ACME | `secret/tls/gateway-cert` | Edge gateway | 90d (Let's Encrypt); 365d (corporate CA) | Gateway reload |

## 3. Layering

```
Spring Cloud Vault Watcher
    |
    v
Spring Environment property
    |
    v
@ConfigurationProperties / @Value beans
    |
    v
Application code
```

In `dev`, secrets come from `compose.env` (or a developer's local
override). In `research`/`prod`, all secrets above MUST come from
Vault; PostureBootGuard refuses to start otherwise.

## 4. Rotation procedure (general)

1. Operator updates the secret in Vault (new version becomes current).
2. Spring Cloud Vault watcher detects the change within `secrets.refreshInterval` (default 60s).
3. Affected beans re-resolve via `@RefreshScope` (or a custom
   `Vault*Refresher` bean for non-trivial cases like HikariCP).
4. Metric increments: `app_secret_rotation_total{secret}`.
5. If rotation fails (refresh exception): metric
   `app_secret_rotation_failure_total{secret}` + WARN log + readiness
   probe degrades.

## 5. Tests

| Test | Layer | Asserts |
|---|---|---|
| `VaultBootIT` | Integration | App reads secrets from Vault on startup |
| `SecretRotationIT` | Integration | Secret rotation triggers refresh + metric |
| `MissingVaultProdIT` | Integration | `prod` posture refuses to start without Vault |
| `BYOCRotationIT` | Integration | HMAC key rotation hot-reloads without restart |

## 6. Open issues / deferred

- Per-tenant secret namespaces in Vault: W4+ post.
- HSM backing for Vault: ops-track decision.
- KMS-backed Postgres column-level encryption: W4+ optional.

## 7. References

- `agent-platform/bootstrap/ARCHITECTURE.md` (PostureBootGuard required keys)
- `agent-platform/config/ARCHITECTURE.md` (Spring Cloud Config + Vault binding)
- `docs/cross-cutting/security-control-matrix.md` C15
