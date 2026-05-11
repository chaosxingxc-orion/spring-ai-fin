# 0009. HashiCorp Vault (OSS) for secrets, not env vars / K8s Secrets only

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Provider keys, JWT secrets, and DB passwords need rotation and audit trail for financial-services compliance.

## Context

The system handles LLM provider API keys, JWT signing secrets, and database passwords.
Financial-services compliance requires that secrets be rotatable without redeployment
and that every access event produce an audit trail. Kubernetes Secrets alone provide
neither rotation nor audit.

## Decision Drivers

- Self-hostable; works on-prem for v1 customer requirement.
- Vault's Watcher API supports hot-reload via Spring Cloud Vault.
- Per-secret audit trail satisfies finserv compliance requirements.
- Vault community is large; managed offerings (HCP Vault) exist as an upgrade path.

## Considered Options

1. Vault OSS + Spring Cloud Vault + per-tenant subpaths (`secret/tenant/<id>/...`).
2. K8s Secrets only -- no rotation; no audit trail; insufficient for finserv.
3. AWS Secrets Manager / Azure Key Vault -- cloud-locked; incompatible with on-prem.
4. SOPS + git-secret -- file-based; no audit trail.

## Decision Outcome

**Chosen option:** Option 1 (Vault OSS + per-tenant subpaths), because it is the only
option that is self-hostable, supports hot-reload rotation, and provides a per-secret
audit trail meeting finserv compliance requirements.

### Consequences

**Positive:**
- Self-hostable on-prem; no cloud vendor lock-in.
- Hot-reload rotation via Spring Cloud Vault Watcher API.
- Per-secret audit trail for compliance.
- HCP Vault available as a managed upgrade path.

**Negative:**
- Vault HA cluster (3-node) adds operational complexity.
- Vault outage degrades application readiness probes.

### Reversal cost

medium (Spring Cloud Vault config swap to alternative provider)

## Pros and Cons of Options

### Option 1: Vault OSS + Spring Cloud Vault

- Pro: Self-hostable; on-prem compatible.
- Pro: Hot-reload rotation without redeployment.
- Pro: Per-secret audit trail satisfies finserv compliance.
- Con: 3-node Vault HA cluster adds operational complexity.
- Con: Vault outage affects readiness probe health.

### Option 2: K8s Secrets only

- Pro: Zero additional infrastructure.
- Con: No rotation without redeployment.
- Con: No audit trail; fails finserv compliance requirements.

### Option 3: AWS Secrets Manager / Azure Key Vault

- Pro: Fully managed; no cluster to operate.
- Con: Cloud-locked; incompatible with on-prem v1 customer requirement.

### Option 4: SOPS + git-secret

- Pro: Lightweight; no runtime dependency.
- Con: File-based; no audit trail.
- Con: Rotation requires a commit; no hot-reload.

## References

- `docs/cross-cutting/secrets-lifecycle.md`
- `docs/cross-cutting/deployment-topology.md`

> NOTE 2026-05-12: `docs/cross-cutting/secrets-lifecycle.md` moved to `docs/v6-rationale/v6-secrets-lifecycle.md` in 2026-05-12 Occam pass.
