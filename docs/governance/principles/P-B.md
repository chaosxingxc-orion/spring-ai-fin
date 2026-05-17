---
principle_id: P-B
title: "Four Competitive Pillars"
level: L0
view: scenarios
authority: "Layer 0 governing principle (CLAUDE.md)"
enforced_by_rules: [30]
kernel: |
  P-B — Four Competitive Pillars.
  Platform competitiveness rests on four continuously-improvable dimensions —
  **Performance** (latency, throughput),
  **Cost** (per-call + infra),
  **Developer Onboarding** (time-to-first-agent + surface complexity),
  **Governance** (tenant isolation, audit, eval, safety).
  Each dimension MUST have a published baseline that future releases can be
  measured against. Enforced by Rule 30.
---

## Motivation

This principle exists because a platform without a **published baseline** on each competitive dimension cannot detect regression — every release will silently trade latency for cost or onboarding-time for governance, and there will be no audit trail to argue the trade was deliberate. The four pillars — **Performance**, **Cost**, **Developer Onboarding**, **Governance** — were chosen as the minimum set such that every external buyer comparison reduces to one of them. Rule 30 makes the baseline a release-blocking artifact (`docs/governance/competitive-baselines.yaml`), and any regression must be paired with a `regression_adr:` reference so the rationale lives next to the number.

## Operationalising rules

- Rule 30 — Competitive Baselines Required ([`docs/governance/rules/rule-30.md`](../rules/rule-30.md))

## Cross-references

- ADR-0065 (origin of Rule 30 and the four-pillar baseline corpus)
- Deferred sub-clauses 30.b (git-diff regression-ADR pairing), 30.d (measurement automation — W2/W3) — see [`docs/CLAUDE-deferred.md`](../../CLAUDE-deferred.md)
- Related: every release note under `docs/releases/*.md` must mention all four pillar names (Gate Rule 33)
