# agent-eval -- module architecture (2026-05-08 refresh) (W4)

> Owner: runtime | Wave: W4 | Maturity: L0 | Reads: prompt_version, run history | Writes: eval_run, eval_result
> Last refreshed: 2026-05-08

## 1. Purpose

Nightly + on-demand evaluation harness. Runs canonical prompt suites
against the platform, asserts pass-rate threshold, blocks deploys on
regression. Backbone of first-principle P3 (intelligence improves over
time).

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| JUnit 5 | 5.10.x | test runner |
| Spring Boot | 3.5.x | wiring |
| Testcontainers | 1.20.x | spin platform per eval run |
| (optional) Ragas-Java port or custom metrics | -- | RAG eval metrics |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `eval/EvalRunner.java` | top-level runner | 200 |
| `eval/canonical/PromptCases.java` | curated cases | 300 |
| `eval/metrics/PassRateMetric.java` | aggregate pass-rate | 80 |
| `eval/metrics/Faithfulness.java` | RAG faithfulness | 100 |
| `eval/baseline.json` | committed baseline thresholds | 200 |
| `eval/EvalRegressionGate.java` | exit-code gate | 80 |
| `db/migration/V7__eval.sql` | eval_run + eval_result tables | 60 |

## 4. Public contract

CLI: `java -jar agent-eval.jar --suite=canonical --threshold=0.95`. CI
nightly job runs against staging; PR runs against ephemeral
Testcontainers stack.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Real provider used | optional | yes (nightly) | yes (nightly) |
| Threshold | informational | enforced | enforced |
| Suite size | small (10) | full (200) | full (200) |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `EvalRegressionIT` | E2E | baseline pass-rate not regressed |
| `EvalCaseUnitTest` | Unit | individual case scoring |
| `EvalMetricsUnitTest` | Unit | aggregator math |
| `EvalNightlyJobIT` | Nightly | full suite + report uploaded |

## 7. Out of scope

- A/B prompt rollout (`agent-runtime/llm/PromptVersionResolver`).
- User-facing feedback UI (W4+ admin UI).
- Fine-tuning corpus export (W4+).

## 8. Wave landing

W4 brings the module. Initial baseline is committed at W4 close;
subsequent baselines updated via PR.

## 9. Risks

- **Flaky LLM responses skew baselines**: per-case retry budget; flake
  rate flagged in the report.
- **Eval cost**: dedicated cheap-model lane in `LlmRouter`; nightly cost
  tracked; budget alarm in CI.
- **Baseline drift over time**: every prompt-version PR must include
  eval delta; baseline updates require rationale in PR description.
- **Eval suite gaming (training-on-test)**: canonical suite is held
  out from any prompt-tuning workflow; suite refresh requires fresh
  cases not used in training.
- **Coverage gaps**: rubric for what cases must exist (one per
  capability per posture); unmet rubric blocks W4 close.
- **Provider-specific capability bias**: each case asserts a
  capability, not a provider's exact phrasing; per-provider cases
  are explicitly marked.
