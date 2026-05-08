# evolve -- Postmortem + Experiments + Champion/Challenger (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`evolve/` owns the **evolution primitives**: postmortem, experiment management, champion/challenger versioning, recurrence ledger. At v1, this package provides primitives only -- the full **auto-optimization flywheel** (Reflection -> Sedimentation -> Auto-optimizer) is **deferred to v1.1** as a research-posture-only opt-in feature (per L0 sec-9 and the v5.0 review M7).

Owns:

- `ExperimentStore` -- versioned experiment records; per-tenant
- `ChampionChallenger` -- A/B traffic split between champion (production) and challenger versions
- `PostmortemAnalyser` -- structured analysis of failed runs; outputs human-reviewable findings
- `RecurrenceLedger` -- repeat-cause tracking (mirrors hi-agent's `recurrence-ledger.yaml` discipline)
- `RegressionDetector` -- Golden-Set comparison for behaviour drift

Does NOT own:

- Run execution (delegated to `../runner/`)
- LLM-powered reflection (deferred to v1.1; would be `ReflectionEngine` here when adopted)
- DSPy-based asset sedimentation (Tier-3 deferred per L0 sec-9)
- Auto-optimizer (Tier-3 deferred)

---

## 2. Why primitives at v1, flywheel at v1.1

The v5.0 review (M7) demoted "continuous cost reduction" and "continuous evolution" from first principles to operational disciplines. v1 ships:

- **ExperimentStore** primitive -- store experiment records for manual review
- **ChampionChallenger** primitive -- manual A/B split for skill versions
- **PostmortemAnalyser** primitive -- schema for structured postmortem; LLM-aided analysis is opt-in
- **RecurrenceLedger** primitive -- repeated-defect tracking

What's deferred:

- **Reflection engine** (LLM analyses failure traces) -- v1.1 research-posture opt-in with Rule 7 four-prong
- **Sedimentation** (DSPy mining successful patterns) -- v1.1 Tier-3
- **Auto-optimizer** (proposes prompt/model changes from reflection + sedimentation) -- v1.1 with HITL approval gate
- **Dreaming engine** (memory consolidation) -- v1.1 in `../memory/L2DreamConsolidator`

The v1 architecture is **flywheel-ready**: outbox emits `cost_observed` and `trace_emitted` events; ExperimentStore primitive in place; capability maturity ladder allows incremental rollout.

---

## 3. ExperimentStore + ChampionChallenger

```java
public record ExperimentRecord(
    @NonNull String tenantId,                  // spine
    @NonNull String experimentId,
    @NonNull String name,
    @NonNull String hypothesis,
    @NonNull ExperimentStage stage,            // PROPOSED / RUNNING / CONCLUDED / ROLLED_BACK
    @NonNull TrafficSplit split,               // {champion: 0.9, challenger: 0.1}
    @NonNull Map<String, Double> metrics,      // observed metrics
    @NonNull Instant createdAt,
    @Nullable Instant concludedAt
) {
    // spine validation
}

public class ChampionChallenger {
    public Decision route(String tenantId, String capabilityName, RunContext ctx) {
        var exp = experimentStore.findActive(tenantId, capabilityName);
        if (exp == null) return Decision.useChampion();
        return random.nextDouble() < exp.split().challengerFraction()
            ? Decision.useChallenger(exp.experimentId())
            : Decision.useChampion();
    }
    
    public void concludeIfWinnerClear(String experimentId, Map<String, Double> metrics) {
        // posture-aware: research/prod requires HITL approval to promote challenger
        // dev: auto-promote when challenger metrics > champion + threshold
    }
}
```

---

## 4. PostmortemAnalyser

```java
public record PostmortemFinding(
    @NonNull String tenantId,
    @NonNull String runId,
    @NonNull String classification,           // LLM_ERROR / TOOL_ERROR / TIMEOUT / GATE_REJECTED / etc.
    @NonNull String rootCauseHypothesis,
    @NonNull List<String> affectedStages,
    @NonNull Severity severity,
    @NonNull Instant analysedAt,
    @Nullable String llmAnalysis              // optional; deferred to v1.1 Reflection
) {
    // spine validation
}

public class PostmortemAnalyser {
    public PostmortemFinding analyse(RunRecord failedRun) {
        // v1: deterministic classification from RunRecord shape + spine events
        // v1.1: optional LLM analysis (research posture opt-in)
        var classification = classifyFromEvents(failedRun.events());
        var hypothesis = inferRootCause(failedRun);
        return new PostmortemFinding(
            failedRun.tenantId(), failedRun.runId(), classification, hypothesis,
            affectedStages(failedRun), severity(failedRun), Instant.now(), null);
    }
}
```

---

## 5. RecurrenceLedger

YAML file `docs/governance/recurrence-ledger.yaml` (mirrors hi-agent):

```yaml
# Each entry tracks a repeated-cause defect across waves
- id: REC-001
  classification: LLM_TIMEOUT
  affected_capability: kyc.lookup
  occurrence_count: 7
  first_observed_wave: W2
  last_observed_wave: W4
  root_cause: "DeepSeek V4 Pro intermittent latency > 30s; needs failover to Volces"
  resolution_wave: W5
  resolution_commit: <SHA>
```

`RecurrenceLedgerLinter` runs in CI and:

1. Validates yaml shape
2. Asserts every closed defect has resolution_wave + resolution_commit
3. Flags entries with occurrence_count >= 3 as "recurrence-class defects" requiring system-level fix

---

## 6. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Primitives at v1; flywheel at v1.1** | Outbox-ready; ExperimentStore + Postmortem + RecurrenceLedger only | Review M7 fix; cost/evolution-as-day-0-flywheel was premature |
| **AD-2: Postmortem deterministic at v1** | LLM-aided analysis opt-in at v1.1 (research posture only) | Avoid silent-degradation engine class (review H3 fix) |
| **AD-3: Champion/Challenger HITL approval under research/prod** | Auto-promotion only in dev | Production behaviour change requires human sign-off |
| **AD-4: RecurrenceLedger as YAML (not DB)** | Git-tracked; reviewer-friendly | Same pattern as hi-agent; allows PR comments on entries |
| **AD-5: Spine on every record** | tenant_id required | Rule 11 |
| **AD-6: Experiment-rolled-back is a first-class state** | Stage `ROLLED_BACK` distinct from `CONCLUDED` | Audit trail for failed experiments |
| **AD-7: `RegressionDetector` uses Golden Set** | Customer-supplied Golden Set in `fin-domain-pack/` | Customer's behaviour-pinning workflow |

---

## 7. Cross-cutting hooks

- **Rule 7**: every experiment promotion failure emits `springaifin_experiment_promotion_errors_total`
- **Rule 11**: spine on every record; PostmortemFinding canonical-constructor-validates
- **Rule 14**: RecurrenceLedger is part of the manifest scorecard
- **Rule 15**: defect closure requires recurrence-ledger entry update
- **Posture-aware**: dev permits auto-promotion; research/prod requires HITL

---

## 8. Quality

| Attribute | Target | Verification |
|---|---|---|
| ExperimentStore restart-survival | yes | `tests/integration/ExperimentStoreCrashIT` |
| PostmortemAnalyser deterministic | same input -> same output | `tests/unit/PostmortemDeterministicTest` |
| RecurrenceLedger schema validity | YAML lints clean | `RecurrenceLedgerLinterTest` in CI |
| Champion/Challenger correctness | traffic split matches configured fraction | `tests/integration/ChampionChallengerSplitIT` |

## 9. Risks

- **v1.1 Reflection LLM cost**: deferred adoption mitigates cost-creep
- **Customer-supplied Golden Set quality**: out-of-repo; quality is customer's responsibility
- **Experiment statistical significance**: at low traffic, A/B inconclusive; HITL judgment required

## 10. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Skill versioning: [`../skill/ARCHITECTURE.md`](../skill/ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/hi_agent/evolve/` and `docs/governance/recurrence-ledger.yaml`
