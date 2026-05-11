# Incident Response Runbook

> Owner: platform-engineering | Maturity: L0 | Posture: research/prod | Last refreshed: 2026-05-10

## Trigger

Any production anomaly: 5xx spike, latency p99 breach, data-access anomaly, security alert.

## Severity

| Sev | Criteria | Response SLA |
|-----|----------|-------------|
| P1 | Total service down, data loss risk | 15 min |
| P2 | Partial degradation > 20% traffic | 30 min |
| P3 | Isolated failure, workaround available | 2 hours |

## Procedure

1. **Detect**: alert fires (Grafana / PagerDuty).
2. **Triage**: run `gate/doctor.sh`. Check `/v1/health`. Check pod logs (`kubectl logs -l app=spring-ai-ascend --tail=100`).
3. **Contain**: if data loss risk, scale to 0 (`kubectl scale deploy/spring-ai-ascend --replicas=0`) and open DR runbook.
4. **Mitigate**: apply rollback runbook if root cause is a recent deploy.
5. **Communicate**: post P1/P2 status to status page within 30 min.
6. **Resolve**: confirm `gate/doctor.sh` exits 0. Monitor for 30 min post-fix.
7. **Post-mortem**: open ticket within 24 hours. 5-whys. Action items.

## Useful commands

- `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`
- `kubectl exec -it <pod> -- bash -c "curl -s localhost:8080/v1/health"`
- Check gate logs: `ls gate/log/` for recent runs.

## Honest gaps (W4)

- No runbook automation / playbook bot.
- No SLO burn-rate alerts configured.
- On-call rotation not yet defined.
