#!/usr/bin/env python3
"""
Normalize active corpus files to ASCII.

Per docs/systematic-architecture-remediation-plan-2026-05-08-cycle-8.en.md
sec-D1 and docs/systemic-remediation-operating-plan-2026-05-08.en.md Phase 3.

Reads docs/governance/active-corpus.yaml, replaces a fixed set of common
Unicode glyphs with ASCII equivalents in each active document, and writes
back. Skips historical_documents.

This is a one-shot remediation tool, not a gate. The gate is
ascii_only_active_corpus inside check_architecture_sync.{sh,ps1}.
"""

import re
import sys
import os

# ASCII replacement table.
REPLACEMENTS = {
    "—": "--",      # em dash
    "–": "-",       # en dash
    "→": "->",      # right arrow
    "←": "<-",      # left arrow
    "↔": "<->",     # left-right arrow
    "↘": "->",      # SE arrow
    "⇒": "=>",      # right double arrow
    "⇐": "<=",      # left double arrow
    "≤": "<=",      # less-than-or-equal
    "≥": ">=",      # greater-than-or-equal
    "≠": "!=",      # not equal
    "≈": "~=",      # almost equal
    "∈": "in",      # element of
    "×": "x",       # multiplication sign
    "·": ".",       # middle dot
    "•": "*",       # bullet
    "§": "sec-",    # section sign
    "µ": "u",       # micro sign
    "✓": "[x]",     # check mark
    "✅": "[x]",     # check mark emoji (button)
    "✗": "[no]",    # ballot x
    "▼": "v",       # down-pointing triangle
    "▲": "^",       # up-pointing triangle
    "►": ">",       # right-pointing triangle
    "◄": "<",       # left-pointing triangle
    # Box-drawing characters degrade to ASCII pipes and dashes.
    "─": "-",
    "│": "|",
    "┌": "+",
    "┐": "+",
    "└": "+",
    "┘": "+",
    "├": "+",
    "┤": "+",
    "┬": "+",
    "┴": "+",
    "┼": "+",
    # Smart quotes and ellipsis.
    "‘": "'",
    "’": "'",
    "“": '"',
    "”": '"',
    "…": "...",
    # Non-breaking space.
    " ": " ",
    # Latin-1 accented letters most likely in this corpus
    # (Protege, Cafe, etc.). Names of products/people degrade to ASCII.
    "à": "a", "á": "a", "â": "a", "ã": "a",
    "ä": "a", "å": "a",
    "À": "A", "Á": "A", "Â": "A", "Ã": "A",
    "Ä": "A", "Å": "A",
    "è": "e", "é": "e", "ê": "e", "ë": "e",
    "È": "E", "É": "E", "Ê": "E", "Ë": "E",
    "ì": "i", "í": "i", "î": "i", "ï": "i",
    "Ì": "I", "Í": "I", "Î": "I", "Ï": "I",
    "ò": "o", "ó": "o", "ô": "o", "õ": "o",
    "ö": "o",
    "Ò": "O", "Ó": "O", "Ô": "O", "Õ": "O",
    "Ö": "O",
    "ù": "u", "ú": "u", "û": "u", "ü": "u",
    "Ù": "U", "Ú": "U", "Û": "U", "Ü": "U",
    "ç": "c", "Ç": "C",
    "ñ": "n", "Ñ": "N",
    "ß": "ss",
}


def parse_active_paths(yaml_path):
    """Crude YAML walker for active_documents (avoids a PyYAML dep)."""
    paths = []
    in_active = False
    with open(yaml_path, "r", encoding="utf-8") as fh:
        for line in fh:
            stripped = line.rstrip("\n")
            if stripped == "active_documents:":
                in_active = True
                continue
            if stripped.startswith("historical_documents:"):
                in_active = False
                continue
            if not in_active:
                continue
            m = re.match(r"^\s+-\s+path:\s+(\S+)\s*$", stripped)
            if m:
                paths.append(m.group(1))
    return paths


def normalize_file(path):
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
    except FileNotFoundError:
        return -1, "missing", []
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        return -1, "decode_error", []

    changed = 0
    summary = {}
    unknown = []
    out = []
    for ch in text:
        if ord(ch) < 128:
            out.append(ch)
            continue
        if ch in REPLACEMENTS:
            out.append(REPLACEMENTS[ch])
            summary[ch] = summary.get(ch, 0) + 1
            changed += 1
            continue
        # Unknown glyph: drop. Emit warning so reviewer can audit.
        unknown.append(ch)
        out.append("")
        summary[ch] = summary.get(ch, 0) + 1
        changed += 1

    if changed == 0:
        return 0, "", []

    new_text = "".join(out)
    new_bytes = new_text.encode("utf-8")
    with open(path, "wb") as fh:
        fh.write(new_bytes)
    detail = ", ".join(f"U+{ord(c):04X}x{n}" for c, n in summary.items())
    return changed, detail, unknown


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_root)
    yaml_path = "docs/governance/active-corpus.yaml"
    paths = parse_active_paths(yaml_path)
    if not paths:
        print(f"FAIL: no active_documents found in {yaml_path}", file=sys.stderr)
        return 2
    total = 0
    any_unknown = False
    for p in paths:
        changed, detail, unknown = normalize_file(p)
        if changed < 0:
            if detail == "missing":
                print(f"SKIP {p} (missing)")
            else:
                print(f"FAIL {p} ({detail})", file=sys.stderr)
        elif changed == 0:
            print(f"OK   {p} (already ASCII)")
        else:
            print(f"FIX  {p}: {changed} chars [{detail}]")
            if unknown:
                any_unknown = True
                cset = sorted(set(unknown))
                names = ", ".join(f"U+{ord(c):04X}" for c in cset)
                print(f"     UNKNOWN-DROPPED: {names}", file=sys.stderr)
            total += changed
    print(f"---\nTotal characters replaced: {total}")
    if any_unknown:
        print("WARNING: at least one file contained glyphs not in the table; they were dropped.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
