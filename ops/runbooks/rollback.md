# Deployment Rollback Runbook

> Owner: platform-engineering | Maturity: L0 | Posture: research/prod | Last refreshed: 2026-05-10

## Trigger

Post-deploy regression: elevated error rate, latency spike, health probe failure.

## Prerequisites

- `helm` CLI access to the target cluster.
- kubectl context set.
- Previous Helm release history available.

## Procedure

1. Confirm regression: `gate/doctor.sh` exits non-zero OR `/v1/health` returns non-200 for > 2 minutes.
2. List releases: `helm history spring-ai-ascend -n <namespace>`
3. Roll back: `helm rollback spring-ai-ascend <previous-revision> -n <namespace>`
4. Verify pods restart: `kubectl rollout status deployment/spring-ai-ascend -n <namespace>`
5. Confirm health: `gate/doctor.sh` exits 0.
6. If schema migration involved: coordinate with DBA before rollback (Flyway migrations are NOT auto-reversed).
7. Open incident post-mortem ticket.

## Verification

`/v1/health` returns 200. Error rate at pre-deploy baseline (check Grafana).

## Rollback of rollback

If rollback itself fails: scale deployment to 0, restore from last known-good image tag manually.

## Honest gaps (W4)

- Flyway migration rollback strategy not yet defined.
- No automated canary/blue-green rollout (W4 delivery).
