# agent-eval — deferred to W4

> Archived from `agent-eval/ARCHITECTURE.md` by C31 (2026-05-12).
> Module deleted from reactor: zero Java sources, W4 timeline, dishonest under Rule 3.
> Re-introduce when W4 starts: add module to root pom.xml, seed EvalRunner interface + impl.

---

## Original design (W4 target)

Nightly + on-demand evaluation harness. Runs canonical prompt suites
against the platform, asserts pass-rate threshold, blocks deploys on
regression. Backbone of first-principle P3 (intelligence improves over
time).

### OSS dependencies

| Dep | Version | Role |
|---|---|---|
| JUnit 5 | 5.x | test runner |
| Spring Boot | 4.0.5 | wiring |
| Testcontainers | 1.21.x | spin platform per eval run |
| (optional) Ragas-Java port or custom metrics | -- | RAG eval metrics |

### Planned glue

| File | Purpose | LOC |
|---|---|---|
| `eval/EvalRunner.java` | top-level runner | 200 |
| `eval/canonical/PromptCases.java` | curated cases | 300 |
| `eval/metrics/PassRateMetric.java` | aggregate pass-rate | 80 |
| `eval/metrics/Faithfulness.java` | RAG faithfulness | 100 |
| `eval/baseline.json` | committed baseline thresholds | 200 |
| `eval/EvalRegressionGate.java` | exit-code gate | 80 |
| `db/migration/V7__eval.sql` | eval_run + eval_result tables | 60 |

### Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Real provider used | optional | yes (nightly) | yes (nightly) |
| Threshold | informational | enforced | enforced |
| Suite size | small (10) | full (200) | full (200) |
