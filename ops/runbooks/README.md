# Runbooks Index

> Owner: platform-engineering | Maturity: L0 | Posture: all | Last refreshed: 2026-05-10

Operational runbooks for spring-ai-ascend. Each runbook covers trigger,
scope, prerequisites, step-by-step procedure, verification, and rollback.

All runbooks are L0 (design skeleton). Procedures are validated when the
W4 operator-shape gate runs a real-dependency long-lived process.

## Index

| Runbook | Trigger | Status |
|---------|---------|--------|
| [Disaster Recovery](dr.md) | Data loss or total region failure | L0 skeleton |
| [Digest Re-pin](digest-pin.md) | Image digest expiry or CVE in base image | L0 skeleton |
| [Deployment Rollback](rollback.md) | Regression detected post-deploy | L0 skeleton |
| [Total Credential Loss](total-credential-loss.md) | Vault compromise or mass secret rotation | L0 skeleton |
| [Incident Response](incident-response.md) | Any production incident | L0 skeleton |

## References

- Helm chart: ops/helm/spring-ai-ascend/
- Doctor script: gate/doctor.sh (POSIX) / gate/doctor.ps1 (Windows)
- Posture model: docs/cross-cutting/posture-model.md
- Deployment topology: docs/cross-cutting/deployment-topology.md

## Topology

| Posture | Topology |
|---------|----------|
| `dev` | Single JVM (agent-platform + agent-runtime) + Postgres 16 + Valkey 7 + Temporal single-node — all via `ops/compose.yml` |
| `research` | Single-region: 2 replicas behind ALB; managed Postgres (RDS/Aurora); Temporal Cloud or self-hosted 3-node |
| `prod` | Multi-region active/active option (W4+); same components as research with HA Postgres and Temporal cluster |

Full topology design rationale: `docs/v6-rationale/` (archived).
