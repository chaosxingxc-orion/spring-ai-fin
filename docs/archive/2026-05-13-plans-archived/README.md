# Archived Plans — 2026-05-13

This directory contains planning documents that were archived on 2026-05-13 as part of the
combined sixth + seventh reviewer response cycle. See ADR-0037 (Wave Authority Consolidation).

## Why archived

Both `roadmap-W0-W4.md` and `engineering-plan-W0-W4.md` contained multiple contradictions with
the authoritative `ARCHITECTURE.md`. Maintaining two parallel planning documents alongside
`ARCHITECTURE.md` is a root cause of wave-boundary drift (documented in hidden defects 4.1–4.9).

## What to use instead

**Active wave authority** (in priority order):

1. **`ARCHITECTURE.md`** — wave-boundary constraints, §4 constraints, OSS matrix.
2. **`docs/governance/architecture-status.yaml`** — per-capability shipped/deferred status.
3. **`docs/CLAUDE-deferred.md`** — deferred engineering rules with re-introduction triggers.

## Contents

| File | Description |
|---|---|
| `roadmap-W0-W4.md` | Original W0–W4 roadmap (superseded; contains Spring AI 1.0.x and LangChain4j references) |
| `engineering-plan-W0-W4.md` | Original engineering plan (superseded; contains 32-dimension scoring framework) |

These files are preserved for historical context only. Do not use them to make wave-planning decisions.
