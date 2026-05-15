---
affects_level: L0
affects_view: scenarios
proposal_status: accepted
authors: ["Claude (W1.x Phase 7 executor)"]
related_adrs: [ADR-0068, ADR-0069]
related_rules: [Rule-33, Rule-34]
affects_artefact:
  - ARCHITECTURE.md
  - agent-platform/ARCHITECTURE.md
  - agent-runtime/ARCHITECTURE.md
---

# W1.x Phase 7 — Activate freeze convention on phase-released L0/L1 ARCHITECTURE.md

> **Date:** 2026-05-15
> **Status:** Accepted (lands together with the Phase 7 commit it authorises)
> **Affects:** L0 + L1 ARCHITECTURE.md corpus (`scenarios` view per ADR-0068)

## 1. Background

ADR-0068 introduced Rule 33 (Layered 4+1 Discipline) which mandates that "phase-released L0/L1 artefacts are read-only — further edits MUST flow through `docs/reviews/`." The W1 wave (commit `5e6c54a`) shipped the front-matter substrate (every ARCHITECTURE.md carries `freeze_id:` field) but left the value at `null` so the gate (`frozen_doc_edit_path_compliance`, Gate Rule 44) was a no-op.

The L1 modular-russell release is shipped (per `docs/releases/2026-05-14-L1-modular-russell-release.en.md`) and the W1 substrate (Rules 33+34, architecture-graph, gate Rules 37-44) is now live. The conditions to arm the freeze convention are met.

This proposal authorises Phase 7 of the W1.x wave to set `freeze_id: W1-russell-2026-05-14` on the three phase-released ARCHITECTURE.md files and to add `.github/CODEOWNERS` requiring chief-architect review for the broader governance corpus.

## 2. Scope statement

`affects_level: L0` — amending the convention surface that all subsequent architecture work depends on. Chief Architect approval applies; this proposal is the approval record.

Three frozen artefacts named in front-matter `affects_artefact:`. Files NOT in scope (and therefore staying `freeze_id: null` for now): `docs/L2/README.md` (scaffold only), `docs/adr/0068-*.yaml` (still receiving extensions in W1.x), `docs/adr/0069-*.yaml` (just landed; W1.x in progress).

## 3. Root cause / strongest interpretation (Rule 1)

1. **Observed failure / motivation**: `freeze_id: null` everywhere makes Gate Rule 44 a no-op even after L1 release; phase-frozen files can be silently edited.
2. **Execution path**: gate Rule 44 reads `freeze_id` from front-matter; on `null` it skips the file; modifications go undetected.
3. **Root cause**: the freeze convention shipped its enforcement infrastructure but never the activation values.
4. **Evidence**: `gate/check_architecture_sync.sh:1857-1864` (skip-on-null logic); `ARCHITECTURE.md:5` (freeze_id: null); `agent-platform/ARCHITECTURE.md:6`; `agent-runtime/ARCHITECTURE.md:6`.

## 4. Proposed change

- `ARCHITECTURE.md`, `agent-platform/ARCHITECTURE.md`, `agent-runtime/ARCHITECTURE.md` front-matter: `freeze_id: null` → `freeze_id: W1-russell-2026-05-14`.
- New file `.github/CODEOWNERS` requires `@chaosxingxc-orion/chief-architect` review for L0/L1 ARCHITECTURE.md, ADR yamls, CLAUDE.md, governance YAMLs, gate scripts, module-metadata.yaml files, DFX docs, CLAUDE-deferred.md.
- No code changes; no enforcer additions (Gate Rule 44 already exists from W1, just becomes operative).
- No ADR introduced (this proposal IS the rationale; the convention is documented in ADR-0068).

## 5. Alternatives considered

| Alternative | Why rejected |
|---|---|
| Freeze only ARCHITECTURE.md (root), defer per-module | Per-module L1 docs are equally subject to drift after release; partial freeze recreates the multi-source-of-truth problem ADR-0068 was designed to eliminate. |
| Use `freeze_id: 5e6c54a` (commit SHA) instead of phase id | SHA is opaque; phase id (`W1-russell-2026-05-14`) reads as architectural intent and is human-comprehensible in code-review. |
| Wait for W1.x complete before freezing W1 docs | W1 is ALREADY released; not freezing it now lets W1.x edits silently mutate a released artefact. The convention is meant to FORCE W1.x changes through `docs/reviews/`. |

## 6. Verification plan

- [x] `bash gate/check_architecture_sync.sh` passes (Gate Rule 44 now arms; this commit is the FIRST modification of `freeze_id`-tagged files; this proposal under `affects_artefact:` satisfies the rule)
- [x] `bash gate/test_architecture_sync_gate.sh` passes (cases r44_pos / r44_neg already cover positive + negative)
- [x] Manual verification: edit ARCHITECTURE.md without an accompanying review proposal → next gate run fails with `frozen_doc_edit_path_compliance` violation

## 7. Rollout

- Wave: W1.x (Phase 7 of the comprehensive wave)
- Freeze impact: this proposal IS the freeze activation; it does not unfreeze anything.

## 8. Self-audit (Rule 9)

No open ship-blocking findings. The convention activation is mechanical; the gate logic was tested in W1.

---

## Authority

- CLAUDE.md Rule 33 (Layered 4+1 Discipline)
- ADR-0068 (Layered 4+1 + Architecture Graph as Twin Sources of Truth)
- Gate Rule 44 (`frozen_doc_edit_path_compliance`) — enforcer E63
- Approved by: Chief Architect (via this proposal record + `.github/CODEOWNERS` requirement landed in the same commit)
