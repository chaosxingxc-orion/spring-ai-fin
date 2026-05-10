# Disaster Recovery Runbook

> Owner: platform-engineering | Maturity: L0 | Posture: research/prod | Last refreshed: 2026-05-10

## Trigger

Total region failure, data loss affecting durable stores, or RPO breach.

## Scope

PostgreSQL (primary data store), Valkey (session cache), agent-platform deployment.

## Prerequisites

- AWS CLI configured with DR-region credentials
- kubectl context pointed at DR cluster
- Vault unsealed in DR region
- WAL-G or pg_basebackup restore access

## Procedure

1. Assess: confirm primary region unreachable (at least 2 of 3 health probes failing).
2. Failover DNS: update Route53 weighted record to DR endpoint (weight 100).
3. Restore Postgres: `aws s3 cp s3://springaifin-wal/<latest-base> - | pg_restore ...`
   - Target: RPO <= 1 hour (WAL streaming must have been active).
4. Unseal Vault in DR region. Verify all secrets accessible.
5. Apply Helm release in DR cluster: `helm upgrade --install spring-ai-fin ops/helm/spring-ai-fin/ -f values-prod-dr.yaml`
6. Smoke test: `bash gate/doctor.sh` exits 0 in DR cluster.
7. Notify on-call via PagerDuty P1.

## Verification

- `gate/doctor.sh` exits 0.
- `/v1/health` returns 200 with `db_ping_ns > 0`.
- Sample 3 recent run records visible in DR Postgres.

## Rollback of rollback

If DR restore fails, maintain primary region degraded-mode (read-only). Escalate to DBA.

## Contacts / Escalation

- On-call: PagerDuty rotation `spring-ai-fin-oncall`
- DBA: via #db-oncall Slack
- Vendor: AWS Support (if S3/RDS issue)

## Honest gaps (W4)

- No automated DR drill cadence defined.
- No multi-region Helm values file yet.
- WAL-G retention policy pending infra design.
