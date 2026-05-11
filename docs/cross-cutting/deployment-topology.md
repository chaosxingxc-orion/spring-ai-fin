# Deployment Topology -- cross-cutting policy

> Owner: ops + architecture | Wave: W0 (compose) + W2 (single-region Helm) + W4 (multi-region option) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Defines the runtime topology -- replicas, regions, dependencies, HA / DR
posture, scaling triggers, and rollout strategy. Replaces implicit
"it'll be K8s" assumptions. Owned by ops with architecture review.

## 2. Topology by posture

### 2.1 dev (single-host compose)

```
+-----------------------------------------------+
| Developer laptop                              |
|                                               |
|  +-----------------+   +------------------+   |
|  | spring-ai-ascend   |-->| Postgres 16      |   |
|  | (agent-platform |   | (compose)        |   |
|  |  + agent-runtime|   +------------------+   |
|  |  in one JVM)    |                          |
|  +-----------------+   +------------------+   |
|         |              | Valkey 7         |   |
|         |              +------------------+   |
|         |              +------------------+   |
|         |------------> | Temporal 1.24    |   |
|         |              | (single-node)    |   |
|         |              +------------------+   |
|         |              +------------------+   |
|         |------------> | Keycloak 25      |   |
|         |              +------------------+   |
|         |              +------------------+   |
|         |------------> | OPA 0.65         |   |
|         |              +------------------+   |
|         |              +------------------+   |
|         |------------> | Vault (dev mode) |   |
|         |              +------------------+   |
|         |              +------------------+   |
|         |------------> | Grafana + Loki   |   |
|         |              +------------------+   |
+-----------------------------------------------+
```

Bringup: `docker compose up`.

Tradeoffs: single-host; everything in one box; LLM calls go to real
provider OR fake provider (configurable).

### 2.2 research / single-customer prod (single-region K8s)

```
                  +-----------+
                  |   CDN /   |
                  | LoadBlnce |
                  +-----+-----+
                        |
              +---------+---------+
              | Spring Cloud GW   |
              | (Ingress; 2x HA)  |
              +---------+---------+
                        |
              +---------+---------+
              | spring-ai-ascend app |
              | (2-4 replicas;    |
              |  HPA on CPU + RPS)|
              +-----+---+-----+---+
                    |       |
        +-----------+       +-----------+
        |                               |
+-------v-------+              +--------v-------+
| Postgres 16   |              | Valkey 7       |
| (RWO; backup  |              | (single node;  |
|  to S3 daily) |              |  ephemeral)    |
+---------------+              +----------------+

+----------------+  +----------------+  +-----------+
| Temporal       |  | OPA            |  | Vault HA  |
| Cluster (3    )|  | sidecars per   |  | (3-node)  |
| frontends, 3  )|  | app pod        |  +-----------+
| matching, 3   )|  +----------------+
| history,      )|
| Postgres back )|
+----------------+

+----------------+  +----------------+
| Keycloak HA    |  | Grafana + Loki |
| (or external   |  | + Tempo + Pmth |
|  IdP)          |  +----------------+
+----------------+
```

App: K8s Deployment with HPA, PDB (minAvailable=1), readiness/liveness
probes. Graceful shutdown 30s. SecurityContext non-root.

Postgres: managed RDS or operator-managed (`zalando/postgres-operator`)
in v1. Backup: pg_basebackup + WAL archiving to S3 daily; PITR window
24h. RPO/RTO per `non-functional-requirements.md` sec-2.4.

Helm chart structure: one umbrella chart with subcharts per dependency
(Postgres, Valkey, Temporal, Keycloak, OPA, Grafana stack). Customers
can replace any subchart with their own managed service.

### 2.3 prod multi-region (W4+ option)

```
        +----------+         +----------+
        | Region A |         | Region B |
        | (active) |<--XDC-->| (passive |
        |          |  repln  |  + read) |
        +----------+         +----------+

  Postgres: streaming replication (region B as read replica + DR target)
  Temporal: per-region cluster; cross-cluster replication W4+ option
  Valkey: per-region; not cross-region replicated
  Audit log: S3 cross-region replication enabled
```

Failover: manual in v1 (RTO ~ 15min). Automatic failover is W4+ post.

This topology is OPTIONAL and only triggered by:

- Customer with regulatory requirement (e.g., data must stay in EU).
- Single-region availability target unmet.

## 3. Replica counts and resource budgets (per posture)

| Posture | App replicas | Postgres replicas | Temporal cluster | Memory per app pod | CPU per app pod |
|---|---|---|---|---|---|
| dev | 1 | 1 | 1 | 1 GiB | 1 vCPU |
| research | 2 | 1 (RWO) | 3 (single-node ok) | 2 GiB | 2 vCPU |
| prod | 3-10 (HPA) | 1 RW + 1 RO | 3-9 (frontend/match/history) | 4 GiB | 4 vCPU |
| prod multi-region | 6-20 across 2 regions | 1 RW + 2 RO (cross-region) | per-region cluster | 4 GiB | 4 vCPU |

HPA triggers: CPU > 70% sustained 60s, OR `agent_runs_pending` > 100
per replica.

## 4. Scaling assumptions

The v1 design assumes one customer per deployment (single-tenant
isolation at the cluster level for prod; multi-tenant within at the
application level). Cross-customer multi-tenancy in a single cluster
is supported but not the prod default; customers asking for it accept
the shared blast radius.

For the v1 scaling target (1000 tenants, 100k runs/tenant/day,
~50 RPS sustained), a single-region 3-replica deployment with
managed Postgres `db.r6g.xlarge` is sufficient. Beyond that:

- Add Postgres read replica (2x).
- Move long_term_memory to Qdrant (above 5M rows; pgvector trigger
  per `agent-runtime/memory/`).
- Move Temporal off shared Postgres.

## 5. Network policies

K8s NetworkPolicy resources (W2):

- App pods may egress to: Postgres, Valkey, Temporal, OPA, Vault,
  Keycloak, configured LLM provider hostnames, configured tool
  hostnames.
- App pods may NOT egress to anything else (deny by default).
- Postgres / Valkey / Temporal / Vault / Keycloak / OPA pods are
  cluster-internal only.

mTLS between app and Postgres / Vault: W4+ option.

## 6. Rollout strategy

- Deployment strategy: RollingUpdate with maxSurge=25%, maxUnavailable=0.
- PodDisruptionBudget: minAvailable=1 (or 50% in prod-multi).
- Pre-deploy: gate must PASS (architecture-sync) + CI green.
- Post-deploy: smoke test against `/health` + 1 sample run.
- Canary: not in v1 (W4+ option using Argo Rollouts).
- Rollback: helm rollback to previous revision.

## 7. Disaster recovery procedure

1. Postgres RWO failure -> promote read replica -> restore from S3 if both lost.
2. Temporal cluster failure -> workflows paused; resume on cluster recovery.
3. Region failure (multi-region prod) -> failover to passive region; manual.
4. App-pod failure -> K8s reschedules; Temporal resumes in-flight work.
5. Keycloak failure -> cached JWKS continues to serve; no new logins.
6. Vault failure -> cached secrets continue; rotation paused.

DR runbook lives in `ops/runbooks/dr.md` (W4+).

## 8. Capacity / cost model

| Posture | Monthly infra cost (typical) | Notes |
|---|---|---|
| dev | $0 (laptop) | -- |
| research single-customer | ~$300/mo | 2 app pods + RDS small + minimal observability |
| prod single-customer | ~$1500/mo | 3 app pods + RDS medium + Temporal cluster + full observability |
| prod multi-tenant (1000 tenants) | ~$5000/mo | adds replica + larger Postgres + cross-region S3 |
| prod multi-region | ~$12000/mo | doubles app + adds Postgres replication + S3 CRR |

Cost telemetry per tenant: `agent_run_cost_usd_total{tenant,model}`
(LLM cost only); infra cost is allocated proportionally outside the
app.

## 9. Tests

| Test | Layer | Asserts |
|---|---|---|
| `KillReplicaIT` | E2E (W4) | Kill 1 of N pods; zero 5xx outside graceful drain |
| `PostgresFailoverIT` | E2E (W4 staging) | RWO failure -> RO promotion succeeds |
| `HelmChartLintIT` | CI | Helm template + lint passes |
| `NetworkPolicyEgressIT` | E2E (W2) | App cannot egress to non-allowlisted host |
| `GracefulShutdownIT` | Integration | SIGTERM completes in-flight requests <= 30s |
| `HpaScaleIT` | Manual (W4) | Synthetic load triggers scale-up + scale-down |

## 10. Out of scope

- Service mesh (Istio / Linkerd): W4+ optional.
- Cross-region active-active write: W4+ post.
- BYO-cluster customer deployments: customer-side responsibility,
  documented contract only.
- Edge / CDN beyond standard ingress: customer-side.

## 11. References

- `docs/cross-cutting/non-functional-requirements.md` sec-2 (SLOs)
- `docs/cross-cutting/secrets-lifecycle.md` (Vault topology)
- `docs/cross-cutting/security-control-matrix.md` (network controls)
- `docs/plans/engineering-plan-W0-W4.md` sec-2/4 (W0 compose; W2 Helm)
