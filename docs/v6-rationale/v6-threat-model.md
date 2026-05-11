> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# Threat Model -- cross-cutting policy

> Owner: security | Wave: W1 (initial) + iterative per wave | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

STRIDE-style threat model per trust boundary defined in
`docs/cross-cutting/trust-boundary-diagram.md`. For each (boundary,
category) cell, lists threats, mitigations (which OSS + glue + test),
and residual risk.

This model is iterated each wave: W1 covers TB-1/TB-2 (auth + tenancy);
W3 covers TB-3 (ActionGuard); W4 covers TB-4 (DB + outbound) + cross-region.

## 2. STRIDE per boundary

### TB-1 Edge (gateway + JWT validation)

| Threat | STRIDE | Mitigation | Residual |
|---|---|---|---|
| Forged JWT | S | RS256/RS512/EdDSA only; JWKS with TTL; explicit alg allowlist (cycle-7 auth_algorithm_policy) | Compromised IdP root key (out-of-scope for v1) |
| Replayed JWT | S | `Idempotency-Key` dedup at TB-2; `jti` recorded in dedup row (W1) | Pre-dedup window race (mitigated by 409 on concurrent retry) |
| Algorithm confusion (HS256 forced) | S | Validator constructed from explicit allowlist, not from JWT header (cycle-6 hs256_prod_conflict) | None |
| Token theft via XSS in client | S | Out-of-scope (client responsibility); document recommendations for token-binding (DPoP) in W4+ |
| Spoofed tenant_id claim | S | JWT signature covers `tenant_id`; `aud` claim checked | Compromised IdP user (out-of-scope) |
| TLS downgrade | T | TLS 1.2+ enforced at gateway; HSTS header | None at v1 |
| Audit-log evasion via direct call | T/R | All paths through filter chain; lint rule `ActionGuardBypassDetectionIT` (W3) | Direct DB write -- mitigated by RLS + assertion trigger at TB-4 |
| Anonymous DoS | D | Rate-limit at TB-1 (W1; Resilience4j) | Sophisticated distributed DoS (CDN / WAF responsibility) |
| Information disclosure via verbose errors | I | RFC-7807 problem-detail with sanitized body in research/prod (`Generic5xxNoLeakIT`) | Stack traces in dev only |
| Privilege escalation via reused token | E | Short token TTL (15min default); JWKS rotation supported | None at v1 |

### TB-2 Application (request scope + idempotency + tx with SET LOCAL)

| Threat | STRIDE | Mitigation | Residual |
|---|---|---|---|
| Cross-tenant read | I | RLS policy on every tenant table; assertion trigger fires when GUC empty (cycle-2 server_rls_protocol) | None at design level; integration tests required |
| Cross-tenant write | T | Same as above; trigger blocks INSERT/UPDATE | None |
| Idempotency-Key abuse (DoS via key explosion) | D | Per-tenant cap on active keys (W1); pg_cron cleanup | None |
| Idempotency-Key collision | T | (tenant_id, key) UNIQUE INDEX; same key returns same row | None |
| Time-of-check / time-of-use on tenant binding | T | TenantBinder is a `OncePerRequestFilter`; tenant context is request-scoped + transaction-scoped | None |
| Connection-pool tenant leakage | I | `SET LOCAL` is auto-discarded by Postgres on COMMIT/ROLLBACK; no per-checkout reset (cycle-2 / 3 / 5 corrections) | None |
| Large-body DoS | D | Spring Boot `server.tomcat.max-http-form-post-size` + `spring.servlet.multipart.max-file-size` (W0) | None |

### TB-3 ActionGuard (re-asserted auth + OPA + bound + execute + witness)

| Threat | STRIDE | Mitigation | Residual |
|---|---|---|---|
| Bypass of authorization | E | All side effects routed through `ActionGuardChain`; `ActionGuardBypassDetectionIT` enforces in CI | Engineer adds new side-effect API outside chain -- mitigated by lint |
| OPA outage opens authorization | D/E | `research`/`prod`: fail-closed (deny); `dev`: warn-allow | None in research/prod |
| Capability allowlist bypass | E | Tool registry + `tool_registry.enabled` checked at TB-3; OPA policy double-checks | None |
| Token budget bypass | E | `BudgetGuard` checks before LLM call; advisory locks per tenant | None |
| Audit log poisoning | T | Append-only INSERT-only role; UPDATE/DELETE rejected by Postgres role permissions | Compromised DB superuser (out-of-scope) |
| Outbox event tampering | T | Outbox row written in same transaction as side effect; cannot be deleted by app role | None |
| Action-replay against fake idempotency key | E | `IdempotencyFilter` checks at TB-2 before reaching TB-3 | None |
| Prompt-injection via tool output | T | Tool outputs classified as untrusted in `PromptSection`; ActionGuard re-checks before any side effect | Subtle indirect injection (active research; W4+ eval suite) |

### TB-4a Database (RLS + assertion trigger + audit append-only)

| Threat | STRIDE | Mitigation | Residual |
|---|---|---|---|
| SQL injection | T | Parameterized queries via Spring Data JDBC; no string concatenation (CI lint) | None |
| Privilege escalation via app role | E | App role has no DDL grant; cannot disable RLS | Compromised superuser (out-of-scope) |
| Backup theft | I | Backups encrypted at rest (Postgres + customer KMS in prod) | Customer KMS compromise (out-of-scope) |
| Audit log tampering | T/R | INSERT-only role + W4 Merkle root anchor in S3 Object Lock | Pre-anchor 1-hour window (acceptable for v1) |
| Schema drift | T | Flyway migrations checked in; no manual schema changes | None |
| pgvector index DoS | D | Per-tenant rate-limit on `INSERT INTO long_term_memory`; embedding-dimension validation | Mass-insert by compromised app role (mitigated by per-row tx) |

### TB-4b Outbound (LLM + tool + external HTTP)

| Threat | STRIDE | Mitigation | Residual |
|---|---|---|---|
| Provider key leakage in logs | I | LogbackConfig + `CardinalityGuard` block known secret patterns; Vault watcher rotates keys; SecretsLifecycle | None at v1 |
| SSRF via tool URL | T/E | `HttpGetAllowlistTool` per-call host check; `research`/`prod` enforce allowlist | None |
| Provider request smuggling | T | One Spring AI ChatClient per provider; no header pass-through from user input | None |
| Provider response prompt-injection | T | Outputs classified untrusted; ActionGuard re-checks (TB-3); see TB-3 injection note |
| Provider quota exhaustion (DoS) | D | `tenant_budget` cap + 429; Resilience4j circuit breaker on provider | None |
| External tool sandbox escape | E | MCP server runs out-of-process in `research`/`prod`; future Wasm option (W4+) | In-process beans (dev only) |

## 3. Cross-cutting threats

| Threat | STRIDE | Mitigation | Residual |
|---|---|---|---|
| Supply-chain attack via Maven dep | T | `--strict-checksums`; Dependabot; Snyk; SBOM (`docs/cross-cutting/supply-chain-controls.md`) | Zero-day in pinned dep |
| Supply-chain attack via container image | T | Digest-pinned base image; SLSA Level-2 provenance | Zero-day in base image |
| Insider threat (engineer commits secret) | I | git-secrets pre-commit hook (W0); GitGuardian on push | None |
| Configuration drift | T | Spring Cloud Config single source; per-tenant overrides audited (W3) | None |
| Time-of-check / time-of-use on posture | E | `AppPosture` is final + read once; `PostureBootGuard` at startup | None |

## 4. Assumptions and out-of-scope

Assumptions:

- The IdP (Keycloak default) is trusted; its compromise is out-of-scope.
- The JVM is trusted; we do not defend against malicious Java code in
  the same process. Tool sandboxing is out-of-process via MCP.
- The Postgres superuser is trusted (cluster admin only).
- Network between app and Postgres / Valkey / Temporal is trusted
  (private network or mTLS in W4+ post).

Out of scope (v1):

- Side-channel attacks on the JVM.
- Social engineering of Keycloak admins.
- Physical compromise of the deployment environment.
- DoS at the network layer (CDN / WAF responsibility).

## 5. Tests

Threats above translate to tests in the relevant L2 modules. The
`docs/cross-cutting/security-control-matrix.md` lists every control's
named test. This threat model is the rationale layer; the matrix is
the verification layer.

## 6. Iteration cadence

- Re-run the model each wave; new boundaries / surfaces add new STRIDE
  cells.
- Tabletop exercise per wave close: pick 3 threats from this doc and
  trace through the Mitigation -> Test -> Code path to verify the
  defense is real, not just documented.
- W4: external pen-test against the deployed runtime; findings
  back-feed this doc.

## 7. References

- `docs/cross-cutting/trust-boundary-diagram.md`
- `docs/cross-cutting/security-control-matrix.md`
- `docs/cross-cutting/secrets-lifecycle.md`
- `docs/cross-cutting/supply-chain-controls.md`
- `docs/cross-cutting/posture-model.md`
