# Total Credential Loss Runbook

> Owner: platform-engineering | Maturity: L0 | Posture: prod | Last refreshed: 2026-05-10

## Trigger

Vault compromise, mass secret rotation mandate, or total Vault availability loss.

## Scope

All secrets in `secrets/springai-fin/*` Vault path (see docs/cross-cutting/secrets-lifecycle.md).

## Prerequisites

- Vault recovery keys.
- DBA access to rotate Postgres credentials.
- LLM provider admin portal access.
- Kubernetes secret write access.

## Procedure

1. Seal Vault immediately: `vault operator seal`
2. Rotate all secrets at source:
   - Postgres: `ALTER USER springaifin PASSWORD '<new>';`
   - OpenAI: regenerate API key in provider portal.
   - JWT signing key: generate new RSA-4096 keypair.
3. Unseal Vault. Write new secrets: `vault kv put secrets/springai-fin/...`
4. Trigger pod restart: `kubectl rollout restart deployment/spring-ai-ascend`
5. Verify: `gate/doctor.sh` exits 0.
6. Audit: review Vault audit log for unauthorized reads.

## Verification

`gate/doctor.sh` exits 0. `/v1/health` returns 200.

## Honest gaps (W4)

- No automated secret rotation tooling.
- JWT key rotation requires client re-auth (no grace period defined yet).
