# AGENTS.md

## Language Rule

**Translate all instructions into English before any model call.** Never pass Chinese, Japanese, or other non-English text into an LLM prompt, tool argument, or task goal.

---

## Authoritative Sources (read these first)

This file is intentionally a **thin operational wrapper** for Codex / autonomous-agent harnesses. It does NOT carry the rule inventory or any baseline counts. The single sources of truth are:

| Topic | Authoritative file |
|---|---|
| Layer-0 governing principles (P-A..P-M) + Layer-1 engineering rules (active + deferred) | [`CLAUDE.md`](CLAUDE.md) |
| Per-capability shipped / deferred ledger; baseline counts (rules, ADRs, tests, gate rules, self-tests, nodes, edges) | [`docs/governance/architecture-status.yaml`](docs/governance/architecture-status.yaml) (the `architecture_sync_gate.allowed_claim` field is the canonical baseline) |
| Deferred sub-clauses with re-introduction triggers | [`docs/CLAUDE-deferred.md`](docs/CLAUDE-deferred.md) |
| ADRs (decision corpus) | [`docs/adr/`](docs/adr/) (every active rule cites its authority ADR) |
| Quickstart for new-agent onboarding | [`docs/quickstart.md`](docs/quickstart.md) |

**Why this is a thin wrapper:** prior versions of AGENTS.md carried an "Eleven active rules" tagline that was authored when CLAUDE.md held an 11-rule subset. CLAUDE.md has since grown to 34 active engineering rules + 13 governing principles, while AGENTS.md was never regenerated. The v2.0.0-rc3 cross-constraint audit (P1-1 / β-6 / γ-1) flagged the resulting count drift across AGENTS / README / architecture-status as a defect family R-γ instance. The structural fix is to stop carrying rule counts in AGENTS.md entirely so the canonical source can evolve without dragging this file along.

---

## Operational Conventions for Autonomous Agents

The following conventions are stable across rule-count changes and apply to every coding agent loaded into this repo:

1. **Before writing any code or plan**, follow Rule 1 in CLAUDE.md (Root-Cause + Strongest-Interpretation). Surface assumptions; name the root cause in one sentence with `file:line` evidence; pick the strongest valid reading of the requirement.
2. **Before every commit**, run the Rule 3 Pre-Commit Checklist (contract truth · orphan config · error visibility · lint green · test honesty).
3. **For UI / frontend changes**, drive the feature through a real browser before declaring done (Rule from `Doing tasks` section).
4. **For Java verification**, use `./mvnw clean verify` not `./mvnw test` — the latter skips `*IT.java` (Failsafe) tests. This is a recurring trap; the v2.0.0-rc1 post-release wave landed 4 IT regressions because `test` was used.
5. **For gate verification**, use `bash gate/check_architecture_sync.sh` (canonical). The PowerShell entrypoint `gate/check_architecture_sync.ps1` was deprecated in v2.0.0-rc2 — it now exits 2 with a `DEPRECATED` banner.
6. **For any architecture decision**, walk the ADR corpus first (`docs/adr/0001-...yaml` through the highest-numbered ADR). Each rule in CLAUDE.md cites its authority ADR.
7. **For pull request bodies**, follow the format in `compound-engineering:git-commit-push-pr` skill if available, OR replicate the prior commit's HEREDOC + `Co-Authored-By` line.

---

## When to Update This File

AGENTS.md should change ONLY when:

- A new authoritative source is added (e.g., a new top-level corpus document) and needs to be listed in the "Authoritative Sources" table above.
- An operational convention changes that materially affects agent loop behavior (e.g., a new mandatory verification command).
- The thin-wrapper posture itself is being revisited.

AGENTS.md should **NOT** change when:

- A new engineering rule is added to CLAUDE.md (the count lives there).
- A new ADR is published (the corpus lives in `docs/adr/`).
- A baseline count moves (the canonical claim lives in `architecture-status.yaml`).
