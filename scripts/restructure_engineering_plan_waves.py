#!/usr/bin/env python3
"""Restructure W1..W4 in docs/plans/engineering-plan-W0-W4.md so each
wave has the same 10-subsection skeleton as W0:

  X.1 Goal
  X.2 Scope (in)
  X.3 Scope (out, deferred)
  X.4 OSS dependencies pinned
  X.5 Glue modules
  X.6 Tests
  X.7 Acceptance gates
  X.8 Out-of-scope reviewer findings
  X.9 Risks + mitigations
  X.10 Rollback

The script inserts Scope (out, deferred) and Out-of-scope reviewer
findings subsections where missing, and adds dedicated Tests subsections
for W3 and W4. It then renumbers downstream subsections.

Idempotent (does nothing on already-restructured input).
"""
import os
import re
import sys

PATH = "docs/plans/engineering-plan-W0-W4.md"

# Per-wave new content additions. Keyed by section header.
WAVE_PATCHES = {
    "## 3. W1 -- Identity, tenancy, RLS": {
        "scope_out": """- Synchronous run lifecycle (`agent-runtime/run/`): W2.
- LLM provider clients: W2.
- ActionGuard 5-stage chain: W3.
- Memory tiers, vector store: W2/W3.
- Temporal durable workflows: W4.
- Prod-grade rate limit + circuit breaker tuning: W2.
- Per-tenant config overrides via Spring Cloud Config: W2.""",
        "reviewer_findings": """The architecture-sync gate WILL find drift on tenancy / RLS prose
across the L2 corpus. **Do not fix as they appear.** Batch into a
single audit-trail commit at W1 close that bumps the
`tenant_spine_capability` row in `architecture-status.yaml` and
records the W1 maturity advance.""",
    },
    "## 4. W2 -- LLM gateway + run lifecycle (synchronous)": {
        "scope_out": """- ActionGuard 5-stage chain: W3.
- MCP tool registry: W3.
- Memory L2 (pgvector): W3.
- Temporal durable workflows + long-running runs: W4.
- Eval harness: W4.
- Helm production chart (only single-replica skeleton in W2): W4.
- Real LLM providers in CI on every PR (kept nightly only).""",
        "reviewer_findings": """Reviewer findings about LLM-prompt-security wording, run-state
machine drift, or outbox semantics are batched. The W2 audit-trail
commit advances `llm_gateway`, `run_lifecycle`, and `outbox_capability`
rows in `architecture-status.yaml`.""",
    },
    "## 5. W3 -- ActionGuard + tools + memory + cost-down": {
        "scope_out": """- Temporal durable workflow swap (still synchronous orchestrator in W3): W4.
- Skill registry plug-in loading (capability beans only, no SPI hot-reload): W4.
- Eval harness wiring: W4.
- HA / chaos / multi-replica tests: W4.
- Production audit chain Merkle anchoring (in-Postgres only in W3): W4 optional.""",
        "tests": """| Test | Layer | Asserts |
|---|---|---|
| `ActionGuardE2EIT` | E2E | Unauthorized tool call -> 403 + audit row |
| `ActionGuardLatencyIT` | Integration | OPA p99 < 5ms with sidecar |
| `ActionGuardOpaOutageIT` | Integration | OPA down -> deny in research/prod |
| `AuditAppendOnlyIT` | Integration | UPDATE / DELETE on audit_log fails (role) |
| `ToolAllowlistIT` | Integration | http_get rejects non-allowlisted host |
| `ToolDispatchE2EIT` | E2E | LLM tool-call -> ActionGuard -> tool -> result |
| `MemoryRecallIT` | E2E | Write fact in run 1; retrieve in run 2 of same session |
| `MemoryRlsIsolationIT` | E2E | Tenant A's memory invisible to B (RLS) |
| `BudgetCapIT` | Integration | Tenant budget exceeded -> 429 |
| `PromptABRolloutIT` | Integration | A/B rollout assigns deterministically |
| `OpaPolicyUnitTest` (Rego) | Unit | Each rule allow / deny case |""",
        "reviewer_findings": """ActionGuard semantic findings batched. The W3 audit-trail commit
advances `action_guard`, `skill_runtime_authz`, `memory_capability`,
and `llm_prompt_security` rows in `architecture-status.yaml`.""",
    },
    "## 6. W4 -- Long-running workflows + eval + HA": {
        "scope_out": """- Multi-framework dispatch (LangChain4j / Python sidecar): W4+ post.
- Knowledge-graph integration (Apache Jena): deferred indefinitely.
- L3 memory warehouse export: W4+ post.
- Cross-region active-active deployment: W4+ post.
- Production multi-tenant Temporal Cloud subscription: ops-track.""",
        "tests": """| Test | Layer | Asserts |
|---|---|---|
| `LongRunResumeIT` | E2E | Kill workers mid-run; restart; run completes |
| `CancelLiveRunIT` | E2E | Signal cancellation -> CANCELLED <= 5s |
| `WorkflowDeterminismLintIT` | CI | non-deterministic patterns rejected |
| `ActivityIdempotencyIT` | Integration | Replay activity twice; no double side effect |
| `TemporalProviderOutageIT` | Integration | Temporal hiccup; workflow recovers |
| `KillReplicaIT` | E2E | Kill 1 replica during 100-req load; zero 5xx outside drain |
| `EvalRegressionIT` | Nightly | baseline pass-rate not regressed |
| `EvalNightlyJobIT` | Nightly | full suite runs + report uploaded |
| `SkillRegistryHotLoadIT` | Integration | adding a skill JAR works without redeploy (dev only) |""",
        "reviewer_findings": """Final-wave findings batched. The W4 audit-trail commit advances all
remaining capability rows to maturity L1 (W4 closes design coverage)
and records the operator-shape Rule 8 PASS evidence.""",
    },
}


def restructure(text: str) -> str:
    """Insert Scope (out), Tests (where missing), Reviewer-findings; renumber."""
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Detect a wave header.
        wave_header_match = None
        for header in WAVE_PATCHES:
            if line.strip() == header:
                wave_header_match = header
                break
        if not wave_header_match:
            out.append(line)
            i += 1
            continue
        # Capture the wave block until next "## " at top level or "## 7."
        block_start = i
        block_end = block_start + 1
        while block_end < len(lines):
            stripped = lines[block_end].rstrip()
            if stripped.startswith("## ") and not stripped.startswith("### "):
                break
            block_end += 1
        block = lines[block_start:block_end]
        new_block = restructure_wave_block(block, WAVE_PATCHES[wave_header_match])
        out.extend(new_block)
        i = block_end
    return "\n".join(out)


SUBSECTION_RE = re.compile(r"^### (\d+)\.(\d+)\s+(.+)$")


def restructure_wave_block(block, patches):
    """Take a wave block (list of lines) and inject patches in canonical
    skeleton order, renumbering subsections."""
    # First, parse subsections.
    sections = []  # list of dicts: {num, title, lines}
    current = None
    for line in block:
        m = SUBSECTION_RE.match(line)
        if m:
            if current is not None:
                sections.append(current)
            major = int(m.group(1))
            minor = int(m.group(2))
            title = m.group(3).strip()
            current = {"major": major, "minor": minor, "title": title, "lines": [line]}
        else:
            if current is None:
                # pre-subsection content (header + intro)
                if not sections:
                    current = {"major": None, "minor": None, "title": None, "lines": [line]}
                else:
                    current["lines"].append(line)
            else:
                current["lines"].append(line)
    if current is not None:
        sections.append(current)

    # Find the wave's major number (3 / 4 / 5 / 6).
    major = None
    for s in sections:
        if s["major"] is not None:
            major = s["major"]
            break
    if major is None:
        return block

    # Map titles to canonical positions (1..10).
    canonical = [
        ("Goal", "goal"),
        ("Scope (in)", "scope_in"),
        ("Scope (out, deferred)", "scope_out"),
        ("OSS dependencies pinned", "oss"),
        (None, "glue"),  # match by partial title
        ("Tests", "tests"),
        (None, "acceptance"),  # "Acceptance gates"
        (None, "reviewer_findings"),  # "Out-of-scope reviewer findings"
        (None, "risks"),  # "Risks + mitigations"
        ("Rollback", "rollback"),
    ]

    # Match existing sections to canonical slots.
    slots = {key: None for _, key in canonical}
    for s in sections:
        if s["title"] is None:
            continue
        title = s["title"]
        if title.startswith("Goal"):
            slots["goal"] = s
        elif title.startswith("Scope (in)"):
            slots["scope_in"] = s
        elif title.startswith("Scope (out"):
            slots["scope_out"] = s
        elif title.startswith("OSS dependencies"):
            slots["oss"] = s
        elif title.startswith("Glue"):
            slots["glue"] = s
        elif title.startswith("Tests"):
            slots["tests"] = s
        elif title.startswith("Acceptance"):
            slots["acceptance"] = s
        elif title.startswith("Out-of-scope reviewer") or title.startswith("Reviewer"):
            slots["reviewer_findings"] = s
        elif title.startswith("Risks"):
            slots["risks"] = s
        elif title.startswith("Rollback"):
            slots["rollback"] = s

    # Inject missing sections from patches.
    if slots["scope_out"] is None and "scope_out" in patches:
        slots["scope_out"] = {
            "major": major,
            "minor": 0,
            "title": "Scope (out, deferred)",
            "lines": [
                "### {major}.X Scope (out, deferred)".format(major=major),
                "",
                patches["scope_out"],
                "",
            ],
        }
    if slots["tests"] is None and "tests" in patches:
        slots["tests"] = {
            "major": major,
            "minor": 0,
            "title": "Tests",
            "lines": [
                "### {major}.X Tests".format(major=major),
                "",
                patches["tests"],
                "",
            ],
        }
    if slots["reviewer_findings"] is None and "reviewer_findings" in patches:
        slots["reviewer_findings"] = {
            "major": major,
            "minor": 0,
            "title": "Out-of-scope reviewer findings during the wave",
            "lines": [
                "### {major}.X Out-of-scope reviewer findings during the wave".format(major=major),
                "",
                patches["reviewer_findings"],
                "",
            ],
        }

    # Renumber and emit in canonical order.
    canonical_keys = [k for _, k in canonical]
    new_lines = []
    # Pre-subsection content (everything before the first subsection).
    for s in sections:
        if s["major"] is None:
            new_lines.extend(s["lines"])
            break

    new_minor = 1
    for key in canonical_keys:
        s = slots[key]
        if s is None:
            continue
        # Rewrite the header line with canonical number.
        if not s["lines"]:
            continue
        first = s["lines"][0]
        m = SUBSECTION_RE.match(first)
        if m:
            new_first = "### {major}.{minor} {title}".format(
                major=major, minor=new_minor, title=m.group(3).strip()
            )
            s["lines"][0] = new_first
        else:
            # fabricated section; replace placeholder X with new_minor
            s["lines"][0] = s["lines"][0].replace(
                "{major}.X".format(major=major),
                "{major}.{minor}".format(major=major, minor=new_minor),
            ).replace(
                "X ", "{minor} ".format(minor=new_minor), 1
            )
        new_lines.extend(s["lines"])
        new_minor += 1

    return new_lines


def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo)
    with open(PATH, "r", encoding="utf-8", newline="\n") as fh:
        text = fh.read()
    new = restructure(text)
    if new == text:
        print("No changes; plan already canonical.")
        return 0
    with open(PATH, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(new)
    print(f"Restructured {PATH}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
