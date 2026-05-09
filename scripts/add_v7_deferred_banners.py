#!/usr/bin/env python3
"""Prepend a DEFERRED-in-v7 banner to v6-only L2 docs.

Per docs/plans/v7-systems-engineering-plan.md sec-1 disposition table.
"""
import os
import sys

# (path, disposition_text)
FILES = [
    ("agent-platform/api/ARCHITECTURE.md",
     "MERGED INTO `agent-platform/web/ARCHITECTURE.md`"),
    ("agent-platform/runtime/ARCHITECTURE.md",
     "DEFERRED in v7. The v7 design uses Spring Boot's main class + dependency injection directly; no separate runtime-binding layer."),
    ("agent-platform/facade/ARCHITECTURE.md",
     "DEFERRED in v7. Facade responsibilities are folded into `agent-platform/ARCHITECTURE.md` (L1)."),
    ("agent-platform/cli/ARCHITECTURE.md",
     "DEFERRED in v7. CLI is not part of waves W0..W4."),
    ("agent-runtime/server/ARCHITECTURE.md",
     "RENAMED to `agent-runtime/run/ARCHITECTURE.md` in v7."),
    ("agent-runtime/runner/ARCHITECTURE.md",
     "MERGED INTO `agent-runtime/run/ARCHITECTURE.md` in v7."),
    ("agent-runtime/runtime/ARCHITECTURE.md",
     "MERGED INTO `agent-runtime/run/` and `agent-runtime/temporal/` in v7."),
    ("agent-runtime/skill/ARCHITECTURE.md",
     "MERGED INTO `agent-runtime/tool/ARCHITECTURE.md` in v7."),
    ("agent-runtime/capability/ARCHITECTURE.md",
     "MERGED INTO `agent-runtime/tool/` and `agent-runtime/action/` in v7."),
    ("agent-runtime/knowledge/ARCHITECTURE.md",
     "DEFERRED indefinitely in v7. Knowledge graph (Apache Jena) requires a customer demand to revive."),
    ("agent-runtime/adapters/ARCHITECTURE.md",
     "DEFERRED in v7 to wave W4+. Multi-framework dispatch (LangChain4j / Python sidecar) is not in W0..W4 scope."),
    ("agent-runtime/audit/ARCHITECTURE.md",
     "REPLACED in v7 by OpenTelemetry traces (per `agent-runtime/observability/`) + an `audit_log` table owned by `agent-runtime/action/`. The v6 5-class taxonomy is dropped."),
    ("agent-runtime/evolve/ARCHITECTURE.md",
     "REPLACED in v7 by `agent-eval/ARCHITECTURE.md` (eval harness, W4) + skill registry in `agent-runtime/tool/`."),
    ("agent-runtime/posture/ARCHITECTURE.md",
     "MOVED to `docs/cross-cutting/posture-model.md` in v7. The boot-time guard moves to `agent-platform/bootstrap/ARCHITECTURE.md`."),
    ("agent-runtime/auth/ARCHITECTURE.md",
     "MOVED to `agent-platform/auth/ARCHITECTURE.md` in v7. Auth is a platform-edge concern; runtime trusts the upstream binding."),
    ("agent-runtime/action-guard/ARCHITECTURE.md",
     "RENAMED to `agent-runtime/action/ARCHITECTURE.md` in v7. The 11-stage v6 design is collapsed to the 5-stage v7 design."),
]


def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo)
    changed = 0
    for relpath, disposition in FILES:
        if not os.path.exists(relpath):
            print(f"SKIP missing: {relpath}")
            continue
        with open(relpath, "r", encoding="utf-8", newline="\n") as fh:
            existing = fh.read()
        if existing.startswith("> **v6 design rationale (DEFERRED IN v7)**"):
            print(f"OK   already banner: {relpath}")
            continue
        banner = (
            "> **v6 design rationale (DEFERRED IN v7)**\n"
            f"> {disposition}\n"
            "> The authoritative L0 is `docs/architecture-v7.0.md`; the\n"
            "> systems-engineering plan is `docs/plans/v7-systems-engineering-plan.md`.\n"
            "> This file is retained as v6 design rationale and will be\n"
            "> archived under `docs/v6-rationale/` at W0 close.\n"
            "\n"
        )
        with open(relpath, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(banner + existing)
        print(f"ADD  banner: {relpath}")
        changed += 1
    print(f"---\nFiles updated: {changed}")


if __name__ == "__main__":
    sys.exit(main())
