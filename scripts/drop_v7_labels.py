#!/usr/bin/env python3
"""Replace 'v7 L1/L2 architecture' / 'v7 module' labels with refresh-style
labels across the active doc set, and update systems-engineering plan
references that pointed at the temporary architecture-v7.0.md path.

Idempotent.
"""
import os
import re
import sys

REPLACEMENTS = [
    # Header replacements in L1 / L2 / module docs
    (re.compile(r"-- v7 L1 architecture"), "-- L1 architecture (2026-05-08 refresh)"),
    (re.compile(r"-- v7 L2 architecture"), "-- L2 architecture (2026-05-08 refresh)"),
    (re.compile(r"-- v7 module architecture"), "-- module architecture (2026-05-08 refresh)"),
    # Path references
    (re.compile(r"docs/architecture-v7\.0\.md"), "ARCHITECTURE.md"),
    (re.compile(r"docs/plans/v7-systems-engineering-plan\.md"),
     "docs/plans/architecture-systems-engineering-plan.md"),
    # Plan titles
    (re.compile(r"^# v7 Systems-Engineering Plan -- L0 / L1 / L2 Drill-Down", re.MULTILINE),
     "# Architecture Systems-Engineering Plan -- L0 / L1 / L2 Drill-Down"),
    # Inline 'v7' in narrative passages (only where it would be confusing).
    # We retain v7_disposition field names for backward compatibility; only
    # human-facing prose is rewritten.
    (re.compile(r"the v7 design "), "the refresh design "),
    (re.compile(r"the v7 surface"), "the active design surface"),
    (re.compile(r"the v7 reset"), "the 2026-05-08 reset"),
    (re.compile(r"the v7 component matrix"), "the active component matrix"),
    (re.compile(r"v7 supersedes"), "the refresh supersedes"),
    (re.compile(r"v7 explicit deferrals"), "explicit deferrals"),
    (re.compile(r"v7 surviving"), "refresh-surviving"),
    (re.compile(r"v7 active"), "current-refresh active"),
    (re.compile(r"v7 active corpus"), "active corpus"),
    (re.compile(r"v7 doc set"), "refresh doc set"),
    (re.compile(r"v7 document set"), "refresh document set"),
    (re.compile(r"\(v7\)"), "(2026-05-08 refresh)"),
    (re.compile(r"v7 design"), "refresh design"),
    (re.compile(r"v7 cut"), "refresh cut"),
    (re.compile(r"v7 supersession"), "the supersession"),
    (re.compile(r"v7 module"), "current module"),
    (re.compile(r"v7 capabilities"), "refresh capabilities"),
    (re.compile(r"v7 capability"), "refresh capability"),
    (re.compile(r"v7-aligned"), "refresh-aligned"),
    (re.compile(r"v7-flavored"), "refresh-flavored"),
    (re.compile(r"v7 framing"), "refresh framing"),
    (re.compile(r"v7 evidence"), "refresh evidence"),
    (re.compile(r"per v7"), "per the refresh"),
]

# We do NOT rewrite:
# - field name `v7_disposition` (machine-readable; will be renamed to
#   `refresh_disposition` in a follow-up if desired);
# - `architecture-meta-reflection-2026-05-08.en.md` (historical record
#   of the meta-reflection itself);
# - the `feedback_no_major_version_bumps.md` memory file (records the
#   rule that produced this rewrite).

TARGETS = [
    "ARCHITECTURE.md",
    "agent-platform/ARCHITECTURE.md",
    "agent-runtime/ARCHITECTURE.md",
    "agent-eval/ARCHITECTURE.md",
    "agent-platform/web/ARCHITECTURE.md",
    "agent-platform/auth/ARCHITECTURE.md",
    "agent-platform/tenant/ARCHITECTURE.md",
    "agent-platform/idempotency/ARCHITECTURE.md",
    "agent-platform/bootstrap/ARCHITECTURE.md",
    "agent-platform/config/ARCHITECTURE.md",
    "agent-platform/contracts/ARCHITECTURE.md",
    "agent-runtime/run/ARCHITECTURE.md",
    "agent-runtime/llm/ARCHITECTURE.md",
    "agent-runtime/tool/ARCHITECTURE.md",
    "agent-runtime/action/ARCHITECTURE.md",
    "agent-runtime/memory/ARCHITECTURE.md",
    "agent-runtime/outbox/ARCHITECTURE.md",
    "agent-runtime/temporal/ARCHITECTURE.md",
    "agent-runtime/observability/ARCHITECTURE.md",
    "docs/plans/engineering-plan-W0-W4.md",
    "docs/plans/architecture-systems-engineering-plan.md",
    "docs/governance/current-architecture-index.md",
    "docs/governance/active-corpus.yaml",
    "docs/systematic-architecture-remediation-cycle-8-response.en.md",
]


def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo)
    changed_total = 0
    for path in TARGETS:
        if not os.path.exists(path):
            print(f"SKIP missing: {path}")
            continue
        with open(path, "r", encoding="utf-8", newline="\n") as fh:
            content = fh.read()
        new = content
        for pattern, repl in REPLACEMENTS:
            new = pattern.sub(repl, new)
        if new != content:
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(new)
            print(f"FIX  {path}")
            changed_total += 1
        else:
            print(f"OK   {path} (no v7 labels)")
    print(f"---\nFiles changed: {changed_total}")


if __name__ == "__main__":
    sys.exit(main())
