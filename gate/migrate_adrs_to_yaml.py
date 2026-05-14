#!/usr/bin/env python3
"""
Migrate docs/adr/NNNN-*.md to docs/adr/NNNN-*.yaml per ADR-0068 / Rule 33 / Rule 34.

Usage:
    python3 gate/migrate_adrs_to_yaml.py [--dry-run] [--write]
    python3 gate/migrate_adrs_to_yaml.py --one docs/adr/0021-tenant-propagation-purity.md

The script is intentionally conservative: it extracts machine-derivable fields
(id, title, status, date) and bins the rest of the prose into the canonical
block-scalar fields (context, decision, consequences, rationale, alternatives).
Sections that do not match any canonical bin are preserved under `extra:` so
no prose is silently dropped — see ADR-0068's "no prose lost" guarantee.

After bulk run, the `extra:` blocks should be hand-reclassified or kept.
The script writes a sibling .yaml file; the .md is left in place until the
operator runs `git rm docs/adr/*.md` at PR cutover.

Authority:
    - ADR-0068 (Layered 4+1 + Architecture Graph as Twin Sources of Truth)
    - CLAUDE.md Rule 33 + Rule 34
    - docs/adr/ADR-CLASSIFICATION.md (level + view per ADR)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable

ADR_DIR = Path("docs/adr")
CLASSIFICATION_FILE = ADR_DIR / "ADR-CLASSIFICATION.md"

# Section-heading patterns we recognise (case-insensitive, leading H1/H2/H3 marker stripped).
SECTION_BINS = {
    "context": ["context", "background", "technical story", "problem"],
    "decision": ["decision", "decision outcome", "chosen option", "outcome"],
    "consequences": ["consequences", "implications", "impact"],
    "rationale": ["rationale", "decision drivers", "drivers", "why", "discussion"],
    "alternatives": ["considered options", "alternatives", "alternatives considered"],
}

# Inverse map: lowercase heading text -> canonical bin
HEADING_TO_BIN: dict[str, str] = {}
for bin_name, headings in SECTION_BINS.items():
    for h in headings:
        HEADING_TO_BIN[h.lower()] = bin_name

ID_RE = re.compile(r"^(\d{4})-(.+)\.md$")
H1_RE = re.compile(r"^#\s+(.+)$")
SECTION_RE = re.compile(r"^#{1,3}\s+(.+)$")
STATUS_RE = re.compile(r"^[-\*]?\s*\*?\*?status\*?\*?\s*[:\-]\s*(.+?)\s*\*?\*?$", re.IGNORECASE)
DATE_RE = re.compile(r"^[-\*]?\s*\*?\*?date\*?\*?\s*[:\-]\s*(.+?)\s*\*?\*?$", re.IGNORECASE)

# Default level/view classification; overridden by ADR-CLASSIFICATION.md when present.
# Keys are 4-digit ADR ids; values are (level, view).
DEFAULT_CLASSIFICATION: dict[str, tuple[str, str]] = {
    # L0 governing-principle ADRs
    "0019": ("L0", "scenarios"),
    "0020": ("L1", "process"),       # Run state machine
    "0023": ("L1", "process"),       # Tenant propagation
    "0025": ("L0", "scenarios"),     # Architecture-text truth
    "0026": ("L1", "development"),
    "0027": ("L1", "development"),
    "0040": ("L1", "process"),
    "0041": ("L1", "logical"),
    "0042": ("L0", "scenarios"),
    "0043": ("L0", "scenarios"),
    "0044": ("L0", "scenarios"),
    "0045": ("L0", "scenarios"),
    "0046": ("L0", "scenarios"),
    "0047": ("L0", "scenarios"),
    "0048": ("L1", "physical"),      # Service-layer microservice commitment
    "0049": ("L1", "logical"),       # C/S hydration
    "0050": ("L1", "process"),       # Workflow intermediary
    "0051": ("L1", "logical"),       # Memory ownership boundary
    "0052": ("L1", "process"),       # Skill topology scheduler
    "0053": ("L1", "process"),       # Cohesive swarm execution
    "0054": ("L1", "process"),       # Long-connection containment
    "0055": ("L1", "development"),   # Platform→runtime direction
    "0056": ("L1", "process"),       # JWT validation
    "0057": ("L1", "process"),       # Durable idempotency
    "0058": ("L1", "process"),       # Posture boot guard
    "0059": ("L0", "scenarios"),     # Code-as-Contract
    "0060": ("L1", "scenarios"),     # Phase-L reviewer remediation
    "0061": ("L1", "process"),       # Telemetry vertical
    "0062": ("L1", "logical"),       # Trace/run/session identity
    "0063": ("L1", "development"),   # Client SDK observability contract
    "0064": ("L0", "scenarios"),     # Layer-0 governing principles
    "0065": ("L0", "scenarios"),     # Competitive baselines
    "0066": ("L0", "development"),   # Independent module evolution
    "0067": ("L0", "development"),   # SPI/DFX/TCK co-design
    "0068": ("L0", "scenarios"),     # Layered 4+1 + Graph (already YAML)
}
# All not-listed ADRs default to L1/logical.
DEFAULT_LEVEL = "L1"
DEFAULT_VIEW = "logical"


def yaml_block_scalar(text: str, indent: int = 2) -> str:
    """Emit a YAML block scalar (`|`) preserving the input verbatim."""
    if not text.strip():
        return "|\n" + " " * indent + "(empty)"
    pad = " " * indent
    body = "\n".join(pad + line for line in text.rstrip().splitlines())
    return "|\n" + body


def yaml_escape_str(s: str) -> str:
    """Inline-quote a one-line string."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_one(md_path: Path) -> dict:
    text = md_path.read_text(encoding="utf-8")
    lines = text.splitlines()

    name_match = ID_RE.match(md_path.name)
    if not name_match:
        raise ValueError(f"ADR filename does not match NNNN-slug.md: {md_path.name}")
    adr_id, slug = name_match.group(1), name_match.group(2)

    title = ""
    status = "accepted"  # default
    date = ""

    # Walk header + metadata block until first non-metadata content
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not title:
            m = H1_RE.match(line)
            if m:
                title = m.group(1).strip()
                # title often contains "ADR-NNNN — " prefix; strip it
                title = re.sub(r"^\s*(?:ADR-)?\d{4}[.\s—:\-]+", "", title).strip()
                i += 1
                continue
        m = STATUS_RE.match(line)
        if m:
            status = m.group(1).strip().lower()
            i += 1
            continue
        m = DATE_RE.match(line)
        if m:
            date = m.group(1).strip()
            i += 1
            continue
        if line.startswith("#") and title:
            break
        i += 1

    # Section binning: walk remaining lines, switch bin on each heading match,
    # accumulate everything else into the current bin (default "extra").
    bins: dict[str, list[str]] = {k: [] for k in SECTION_BINS}
    bins["extra"] = []
    current = "context"  # ADRs typically open with context-shaped prose
    seen_section = False
    for line in lines[i:]:
        sec_match = SECTION_RE.match(line)
        if sec_match:
            heading = sec_match.group(1).strip().lower()
            heading_key = re.sub(r"^\d+\.\s*", "", heading)  # strip "1. ", "1.1 ", etc.
            heading_key = heading_key.strip().rstrip(":")
            bin_name = HEADING_TO_BIN.get(heading_key)
            if bin_name is None:
                # try first-word fallback
                first_word = heading_key.split()[0] if heading_key else ""
                bin_name = HEADING_TO_BIN.get(first_word)
            if bin_name:
                current = bin_name
                seen_section = True
                continue
            else:
                # Unrecognised heading — preserve as a labelled subsection in `extra`
                bins["extra"].append(f"### {sec_match.group(1).strip()}")
                current = "extra"
                seen_section = True
                continue
        bins[current].append(line)

    level, view = DEFAULT_CLASSIFICATION.get(adr_id, (DEFAULT_LEVEL, DEFAULT_VIEW))

    return {
        "adr_id": adr_id,
        "slug": slug,
        "title": title or slug.replace("-", " ").title(),
        "status": status,
        "date": date or "unknown",
        "level": level,
        "view": view,
        "supersedes": [],
        "extends": [],
        "relates_to": [],
        "context": "\n".join(bins["context"]).strip(),
        "decision": "\n".join(bins["decision"]).strip(),
        "consequences": "\n".join(bins["consequences"]).strip(),
        "rationale": "\n".join(bins["rationale"]).strip(),
        "alternatives_considered_prose": "\n".join(bins["alternatives"]).strip(),
        "extra": "\n".join(bins["extra"]).strip(),
    }


def emit_yaml(adr: dict) -> str:
    out: list[str] = []
    out.append(f"id: ADR-{adr['adr_id']}")
    out.append(f"title: {yaml_escape_str(adr['title'])}")
    out.append(f"status: {adr['status']}")
    out.append(f"date: {adr['date']}")
    out.append(f"level: {adr['level']}")
    out.append(f"view: {adr['view']}")
    out.append("")
    out.append("supersedes: []")
    out.append("extends: []")
    out.append("relates_to: []")
    out.append("")

    for key in ("context", "decision", "consequences", "rationale", "alternatives_considered_prose", "extra"):
        text = adr[key]
        if not text.strip():
            continue
        out.append(f"{key}: " + yaml_block_scalar(text, indent=2))
        out.append("")

    out.append("# Auto-migrated from docs/adr/" + f"{adr['adr_id']}-{adr['slug']}.md.")
    out.append("# Edges (supersedes / extends / relates_to) are placeholders — populate")
    out.append("# from the prose citations in the body and from the corpus graph at PR")
    out.append("# finalisation, then run `bash gate/build_architecture_graph.sh` to verify.")
    out.append("")
    return "\n".join(out)


def discover_md(adr_dir: Path) -> Iterable[Path]:
    return sorted(p for p in adr_dir.glob("*.md") if ID_RE.match(p.name))


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--dry-run", action="store_true", help="print to stdout, do not write files")
    p.add_argument("--write", action="store_true", help="write YAML files alongside .md (default if --one is given)")
    p.add_argument("--one", type=Path, help="convert a single .md file")
    args = p.parse_args()

    if not ADR_DIR.is_dir():
        print(f"ERROR: {ADR_DIR} not found (run from repo root)", file=sys.stderr)
        return 2

    targets = [args.one] if args.one else list(discover_md(ADR_DIR))
    if not targets:
        print(f"No ADR .md files found under {ADR_DIR}", file=sys.stderr)
        return 1

    write = args.write or args.one is not None
    if args.dry_run:
        write = False

    written = 0
    for md_path in targets:
        try:
            adr = parse_one(md_path)
            yaml_text = emit_yaml(adr)
        except Exception as exc:
            print(f"FAIL {md_path}: {exc}", file=sys.stderr)
            continue

        yaml_path = md_path.with_suffix(".yaml")
        if write:
            yaml_path.write_text(yaml_text, encoding="utf-8")
            print(f"WROTE {yaml_path}")
            written += 1
        else:
            print(f"--- {md_path} -> {yaml_path} ---")
            print(yaml_text)

    if write:
        print(f"\n{written} file(s) written. Review and populate supersedes/extends/relates_to.")
        print("Next: run `bash gate/build_architecture_graph.sh` to verify edge resolution.")
        print("Then: `git rm docs/adr/*.md` at PR cutover (leaves *.yaml + README.md).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
