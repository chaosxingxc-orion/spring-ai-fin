> Owner: agent-eval | Maturity: L1 | Posture: research | Last refreshed: 2026-05-10

# Eval CI Hook

This document describes the role of the `agent-eval/` module, the nightly CI hook that drives it, and the P3 evolving-intelligence loop that uses eval results to improve the platform over time.

---

## agent-eval/ role

`agent-eval/` is the canonical eval suite for the spring-ai-fin platform. It contains:

- A set of canonical prompt fixtures covering the KYC happy path and known edge cases.
- A JUnit 5-based test harness that runs those prompts against the deployed platform endpoint (or a test double) and scores the responses.
- A Ragas-Java port for answer relevance and faithfulness scoring (W4 deliverable).
- A regression gate: the eval pass rate must not drop below the configured threshold (`eval_pass_rate_baseline >= 0.85` at W4 close; see ARCHITECTURE.md section 5.4).

The eval suite is separate from unit and integration tests. It is not part of `./mvnw verify`. It runs in a dedicated CI job against a research-posture deployment.

---

## Nightly CI hook (W4 deliverable)

The nightly CI hook runs `agent-eval/` against the last green build on the `main` branch. If the eval pass rate drops below the threshold, the build is marked as a regression and the on-call engineer is paged.

Hook configuration (GitHub Actions, W4):

```yaml
# .github/workflows/nightly-eval.yml
on:
  schedule:
    - cron: '0 2 * * *'   # 02:00 UTC nightly

jobs:
  eval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run canonical eval suite
        env:
          APP_POSTURE: research
          EVAL_TARGET_URL: ${{ secrets.EVAL_TARGET_URL }}
        run: ./mvnw -pl agent-eval verify -Peval
      - name: Assert pass rate
        run: scripts/assert-eval-pass-rate.sh 0.85
```

The `assert-eval-pass-rate.sh` script reads the Micrometer `eval_pass_rate{suite="canonical"}` metric from the eval run output and exits non-zero if the rate is below the threshold.

---

## P3 evolving-intelligence loop

The nightly eval feeds the P3 (persistently evolving intelligence) loop:

1. **Eval run**: nightly CI evaluates canonical prompts; scores written to `eval_results` Postgres table.
2. **Regression detection**: `eval_pass_rate` metric compared against prior 7-day rolling average; regression triggers an alert.
3. **Root-cause triage**: on-call engineer reviews the diff between passing and failing prompts; identifies prompt version, model version, or retrieval quality as root cause.
4. **A/B prompt rollout**: updated prompt versions deployed to a 10% traffic slice in research posture; eval re-runs on the slice.
5. **Graduation**: if the slice eval pass rate exceeds baseline for 3 consecutive nightly runs, the prompt version is promoted to 100%.

This loop is the mechanism behind the `prompt_ab_rollout_outcomes_per_quarter >= 4` proxy metric (ARCHITECTURE.md section 5.4).

---

## Cost/token counter SPI intent (W2)

W2 will add a `CostTokenCounter` SPI intent (not yet a full SPI interface) that records per-run LLM token usage and cost. The eval harness will consume this to track `median_run_cost_usd_p50` against the `<= $0.005` W4 target.

The counter is not yet a formal SPI interface (L0); it will be promoted to L1 when the eval harness wires it at W2 close. The `agent_run_cost_usd_total{tenant,model}` Prometheus counter is the interim observable (W2).

---

## Related documents

- [ARCHITECTURE.md](../../ARCHITECTURE.md) sections 4.8 and 5.4 for P3 and measurable proxies
- [docs/plans/engineering-plan-W0-W4.md](../plans/engineering-plan-W0-W4.md) for W4 eval harness wave plan
- [docs/contracts/telemetry-contracts.md](../contracts/telemetry-contracts.md) for metric naming and cardinality
