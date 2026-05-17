#!/usr/bin/env bash
# gate/lib/extract_shipped_rows.sh -- one-pass awk extraction of capability data
# from docs/governance/architecture-status.yaml.
#
# Authority: docs/governance/rules/rule-70.md + token-optimization wave PR-E3.b.
# Used by gate/lib/scan_cache.sh to populate $_SCAN_SHIPPED_ROWS so that Rules
# 7, 19, 24 can do ONE TSV lookup instead of N per-line printf|grep subshell
# spawns (the actual bottleneck — Rules 7/19/24 were taking 6-8 minutes each
# on Git Bash for Windows because each subprocess spawn is ~10ms).
#
# Output: TSV with three columns per line:
#   <capability_id>\t<field>\t<value>
# where field is one of:
#   shipped           value: "true" or "false"
#   impl              value: a path from implementation: list (NOT
#                     deprecated_implementations:)
#   test              value: a path from tests: list
#   l2_doc            value: a path from l2_documents: list
#   latest_delivery   value: a single path from latest_delivery_file:
#   tests_marker      value: "present" (tests: key exists) or "absent"
#   tests_count       value: integer count of tests: list items
#
# Indent contract (matches docs/governance/architecture-status.yaml today):
#   - top-level `capabilities:` at column 0
#   - capability_id at 2-space indent (followed by `:` and newline)
#   - capability fields at 4-space indent (`status:`, `shipped:`, `tests:`,
#     `implementation:`, `l2_documents:`, `latest_delivery_file:`,
#     `allowed_claim:`, `deprecated_implementations:`, etc.)
#   - list items at 6-space indent (`      - value`)
#
# Inline comments (`# foo`) after values or list items are stripped.
#
# Single argument: path to architecture-status.yaml.
# Exit 0 always (errors silenced; downstream rules tolerate empty cache).

set -uo pipefail
export LC_ALL=C

_status_file="${1:?usage: extract_shipped_rows.sh <architecture-status.yaml>}"
[[ -f "$_status_file" ]] || exit 0

awk '
BEGIN {
  cap = ""
  in_impl = 0; in_tests = 0; in_l2 = 0
  tests_count = 0; tests_marker = "absent"
}

function strip_inline_comment(s,    i) {
  # Strip "# comment" if preceded by whitespace.
  i = match(s, /[[:space:]]+#/)
  if (i > 0) s = substr(s, 1, i - 1)
  sub(/[[:space:]]+$/, "", s)
  return s
}

function flush_cap() {
  if (cap != "") {
    printf "%s\ttests_marker\t%s\n", cap, tests_marker
    printf "%s\ttests_count\t%d\n", cap, tests_count
  }
}

# Skip top-level "capabilities:" header.
/^capabilities:[[:space:]]*$/ { next }

# New capability: 2-space indent, identifier followed by colon, no value.
/^  [a-zA-Z][a-zA-Z_0-9]+:[[:space:]]*$/ {
  flush_cap()
  cap = $0
  sub(/^[[:space:]]+/, "", cap)
  sub(/:[[:space:]]*$/, "", cap)
  in_impl = 0; in_tests = 0; in_l2 = 0
  tests_count = 0; tests_marker = "absent"
  next
}

# 4-space indented field of a capability: ANY recognised key closes the
# currently-open list, then the specific key may re-open its own list.
/^    [a-zA-Z][a-zA-Z_0-9]+:/ {
  key = $0
  sub(/^[[:space:]]+/, "", key)
  sub(/:.*$/, "", key)
  value = $0
  sub(/^[[:space:]]+[a-zA-Z_][a-zA-Z_0-9]*:[[:space:]]*/, "", value)
  value = strip_inline_comment(value)

  # Close any open list first.
  in_impl = 0; in_tests = 0; in_l2 = 0

  if (key == "shipped") {
    printf "%s\tshipped\t%s\n", cap, value
  } else if (key == "latest_delivery_file") {
    if (value != "") printf "%s\tlatest_delivery\t%s\n", cap, value
  } else if (key == "implementation") {
    if (value == "" ) in_impl = 1
    else if (value == "[]") in_impl = 0
    # inline non-empty value is unusual; ignore
  } else if (key == "tests") {
    tests_marker = "present"
    if (value == "") in_tests = 1
    else if (value == "[]") in_tests = 0
    # inline non-empty value: rare; ignore
  } else if (key == "l2_documents") {
    if (value == "") in_l2 = 1
    else if (value == "[]") in_l2 = 0
  }
  # All other 4-space keys (allowed_claim, status, note, l0_decision,
  # deprecated_implementations, architecture_doc, dfx_doc, owner, notes, ...)
  # simply close lists (already done above) and emit nothing.
  next
}

# 6-space indented list item ("      - value")
/^      -[[:space:]]+/ {
  val = $0
  sub(/^[[:space:]]+-[[:space:]]+/, "", val)
  val = strip_inline_comment(val)
  if (in_impl) {
    if (val != "") printf "%s\timpl\t%s\n", cap, val
  } else if (in_tests) {
    if (val != "") {
      printf "%s\ttest\t%s\n", cap, val
      tests_count++
    }
  } else if (in_l2) {
    if (val != "") printf "%s\tl2_doc\t%s\n", cap, val
  }
  next
}

END { flush_cap() }
' "$_status_file"
