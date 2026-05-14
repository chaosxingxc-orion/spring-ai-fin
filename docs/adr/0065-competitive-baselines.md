# ADR-0065 — Competitive Baselines (Four Pillars)

- Status: Accepted
- Date: 2026-05-14
- Authority: User directive — "Platform competitiveness must rest on four continuously-improving dimensions: platform performance, platform usage cost, developer barrier to entry, agent governance level."
- Scope: Make the four competitive pillars a first-class, gate-enforced artefact (`docs/governance/competitive-baselines.yaml`) so every release has a published baseline for performance, cost, developer onboarding, and governance. Anchors CLAUDE.md Rule 30 and ARCHITECTURE.md §4 #61.
- Cross-link: ADR-0064 (Layer-0 governing principles), Rule 13 (P1 cost-of-use — deferred W3), Rule 18 (Eval harness — deferred W4).

## Context

The user's competitive strategy rests on four continuously-improving dimensions; without a baseline file, those dimensions stay aspirational and drift undetected.

Rule 28 forbids prose-only constraints. The principle ships in `CLAUDE.md` as Layer-0 P-B, but the enforceable expression must live as a yaml + a gate rule + a release-note enforcement.

Measurement automation for performance and cost is genuinely not available at L1 (no perf benchmark harness; no cost-accounting hook — those are Rule 13 / Rule 18 deferred items). The yaml therefore uses `N/A` placeholders with a `measurement_status:` explanation, NOT silently empty fields.

## Decision

### 1. Required file: `docs/governance/competitive-baselines.yaml`

Schema:

```yaml
version: 1
generated_at: <ISO date>
release: <release tag>
dimensions:
  performance:
    baseline_metric: <string>
    current_value: <number | "N/A">
    measurement_status: <string>
    last_measured: <ISO date | null>
  cost:        { ...same shape... }
  developer_onboarding: { ...same shape... }
  governance:  { ...same shape... }
```

Each dimension has the same four sub-keys. Optional `regression_adr: ADR-NNNN` on any dimension that regressed vs the previous file revision (full git-diff regression check is deferred per `CLAUDE-deferred.md` 30.b).

### 2. Required release-note pattern

The most recent `docs/releases/*.md` MUST mention all four pillar names (`performance`, `cost`, `developer_onboarding`, `governance`) so reviewers see the dimensions tracked per release.

### 3. Enforcement

- Gate Rule 32 `competitive_baselines_present_and_wellformed` (enforcer E50) — file exists + 4 required keys present.
- Gate Rule 33 `release_note_references_four_pillars` (enforcer E51) — latest release note mentions all 4 pillar names.

### 4. Deferred sub-clauses

- `CLAUDE-deferred.md` 30.b — git-diff regression → `regression_adr:` pairing enforcer.
- `CLAUDE-deferred.md` 30.d.performance — perf benchmark harness (activates with first benchmark in CI).
- `CLAUDE-deferred.md` 30.d.cost — automated cost accounting (activates with Rule 13).

## Alternatives considered

**Alt A — Put baselines in the release-note prose only.** Rejected: text drifts; a structured yaml + gate rule is the truth.

**Alt B — Wait until measurement automation is available before adding the file.** Rejected: the dimensions need to be visible NOW even at `N/A` — that visibility is what drives the team to add measurement.

**Alt C — Track only the two measurable dimensions (developer onboarding, governance) today.** Rejected: the user named four pillars; partial coverage would tempt scope drift.

## Consequences

- **Positive**: All four pillars are publicly tracked from L1 onward; future regressions trigger a gate-failure-with-message; the yaml is the single point of truth.
- **Negative**: Two dimensions (`performance`, `cost`) carry `N/A` until W2/W3 measurement automation lands — visible but not yet quantified.
- **Risk surfaced**: `N/A` values could become permanent if no one revisits; mitigation: the deferred-rule triggers (30.d.*) are tied to capability-landing events.

## Enforcers (Rule 28)

- E50 Gate Rule 32 `competitive_baselines_present_and_wellformed`.
- E51 Gate Rule 33 `release_note_references_four_pillars`.

## §16 Review Checklist

- [x] Four pillars (performance, cost, developer_onboarding, governance) are named.
- [x] Yaml schema (4 sub-keys per dimension) is locked.
- [x] Release-note enforcement is bound to a gate rule.
- [x] Deferred sub-clauses (measurement automation) have explicit triggers.
- [x] §4 #61 anchors Rule 30 in the architectural corpus.
