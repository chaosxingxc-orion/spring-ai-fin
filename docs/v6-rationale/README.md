# docs/v6-rationale/

Pre-refresh design rationale from the 2026-05-12 Occam's Razor pass.

These files document architectural decisions and designs that were **deferred to W2+**
during the Occam pass. They are NOT active specifications. No code is expected to match
them. They are preserved for historical context only.

## Naming convention

Files are named `v6-<concept>.md`. The `v6` prefix marks them as originating from
the 2026-05-08 architecture refresh, prior to the Occam simplification.

## What each file contains

| File | Original location | Deferred to |
|------|------------------|-------------|
| v6-action.md | agent-runtime/action/ | W3 |
| v6-adapters.md | agent-runtime/adapters/ | W2 |
| v6-audit.md | agent-runtime/audit/ | W2 |
| v6-auth.md | agent-runtime/auth/ | W2 |
| v6-evolve.md | agent-runtime/evolve/ | W4 |
| v6-llm.md | agent-runtime/llm/ | W2 |
| v6-outbox.md | agent-runtime/outbox/ | W2 |
| v6-run.md | agent-runtime/run/ | W2 |
| v6-temporal.md | agent-runtime/temporal/ | W3 |
| v6-tool.md | agent-runtime/tool/ | W2 |

## Current state

For what is actually shipped, see [`docs/STATE.md`](../STATE.md) (created in C27).
For deferred capabilities with re-introduction triggers, see [`docs/CLAUDE-deferred.md`](../CLAUDE-deferred.md).
