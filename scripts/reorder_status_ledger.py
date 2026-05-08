#!/usr/bin/env python3
"""
Re-order docs/governance/architecture-status.yaml so each capability row has:
  1. maturity:       <L0..L4>          # primary readiness language (Rule 12)
  2. status:         <enum>            # legacy alias for evidence_state
  3. evidence_state: <enum>            # cycle-8 sec-E1 primary lifecycle field

Idempotent: running twice is a no-op.
"""

import re
import sys
import os

PATH = "docs/governance/architecture-status.yaml"


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_root)
    with open(PATH, "r", encoding="utf-8", newline="\n") as fh:
        lines = fh.read().split("\n")

    # Walk the file. When we see a capability key (2-space indent + name + ':'),
    # collect the indented child lines, find the status/maturity lines, and
    # re-emit them in cycle-8 order with evidence_state alias.

    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Capability key: starts with two spaces, alpha+underscore, ends with ':'.
        m = re.match(r"^  ([A-Za-z][A-Za-z0-9_]*):\s*$", line)
        if not m:
            out.append(line)
            i += 1
            continue
        # Check this is under the `capabilities:` block by looking back.
        # Simpler: only act on rows whose first child line is `    status:` or
        # `    maturity:`.
        peek = lines[i + 1] if i + 1 < len(lines) else ""
        peek2 = lines[i + 2] if i + 2 < len(lines) else ""
        if not (peek.startswith("    status:") or peek.startswith("    maturity:")
                or peek.startswith("    evidence_state:") or peek2.startswith("    status:")
                or peek2.startswith("    maturity:")
                or peek2.startswith("    evidence_state:")):
            out.append(line)
            i += 1
            continue

        # Collect the block of 4-space indented lines.
        block_start = i + 1
        block_end = block_start
        while block_end < len(lines) and (
            lines[block_end].startswith("    ") or lines[block_end] == ""
        ):
            # Stop at the next top-level capability or section.
            nxt = block_end + 1
            block_end += 1
            # If the next non-empty line has indent <= 2, we've left the block.
            if (
                block_end < len(lines)
                and lines[block_end] != ""
                and not lines[block_end].startswith("    ")
            ):
                break

        block = lines[block_start:block_end]

        # Extract values.
        maturity = None
        status = None
        evidence_state = None
        kept = []
        for bl in block:
            mm = re.match(r"^    maturity:\s*(.+?)\s*$", bl)
            if mm and maturity is None:
                maturity = mm.group(1).rstrip()
                continue
            ms = re.match(r"^    status:\s*(.+?)\s*$", bl)
            if ms and status is None:
                status = ms.group(1).rstrip()
                continue
            me = re.match(r"^    evidence_state:\s*(.+?)\s*$", bl)
            if me and evidence_state is None:
                evidence_state = me.group(1).rstrip()
                continue
            kept.append(bl)

        # If neither maturity nor status was present, leave block as-is.
        if maturity is None and status is None and evidence_state is None:
            out.append(line)
            out.extend(block)
            i = block_end
            continue

        # Determine evidence_state: prefer explicit; else use status; else null.
        if evidence_state is None:
            evidence_state = status if status is not None else "null"
        if status is None:
            status = evidence_state

        out.append(line)
        if maturity is not None:
            out.append(f"    maturity: {maturity}")
        out.append(f"    status: {status}")
        out.append(f"    evidence_state: {evidence_state}")
        out.extend(kept)
        i = block_end

    new_content = "\n".join(out)
    with open(PATH, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(new_content)
    print(f"Reordered {PATH}.")


if __name__ == "__main__":
    sys.exit(main())
