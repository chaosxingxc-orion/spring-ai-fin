# Performance Benchmarks -- spring-ai-ascend

> Owner: platform-engineering | Maturity: L0 | Last refreshed: 2026-05-10

## Strategy

Benchmarks are run on every minor version cut (W4+ cadence). The JMH
module under perf/jmh/ provides the harness. Baseline numbers are committed
to perf/baseline-<date>.md after each benchmark run.

## Regression policy

If a benchmark result exceeds 2x the baseline p99 for the same operation,
the PR is blocked until the regression is explained or the baseline is
updated with justification.

## Current state

No captured benchmark numbers yet (W0). Named test classes exist in
agent-platform (ConcurrencyLoadIT, RunHappyPathIT) as L2 targets for W4.
Baseline file at perf/baseline-2026-05-10.md records this state.

## References

- NFR targets: docs/cross-cutting/non-functional-requirements.md
- JMH harness: perf/jmh/
