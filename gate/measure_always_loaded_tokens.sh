#!/usr/bin/env bash
# Reports byte / line / estimated-token counts of the always-loaded
# governance/architecture set, enforces per-file ceilings declared in
# gate/always-loaded-budget.txt, and prints a TOTAL line.
#
# Token estimate uses bytes/4 (English+code heuristic; YAML and prose
# average ~3.8-4.2 chars/token in production tokenisers).
#
# Exit 0 -- every file is at or below its declared ceiling.
# Exit 1 -- any file exceeds its ceiling OR the budget file is missing OR a
#           listed file is missing on disk.
#
# Called standalone by humans:  bash gate/measure_always_loaded_tokens.sh
# Called from gate Rule 70:     bash gate/check_architecture_sync.sh
#
# Authority: docs/governance/rules/rule-70.md (CLAUDE.md token-optimization
# wave, 2026-05-17). Enforcer E100.

set -uo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

budget_file="gate/always-loaded-budget.txt"
if [[ ! -f "$budget_file" ]]; then
  echo "ERROR: $budget_file missing -- cannot measure" >&2
  exit 1
fi

fail=0
total_bytes=0
total_lines=0
file_count=0

printf '%-55s %10s %8s %10s %10s %s\n' "FILE" "BYTES" "LINES" "~TOKENS" "CEIL_BYTES" "STATUS"
printf '%-55s %10s %8s %10s %10s %s\n' "----" "-----" "-----" "-------" "----------" "------"

while IFS= read -r raw || [[ -n "$raw" ]]; do
  # Strip comments and trim
  line="${raw%%#*}"
  line="${line## }"
  line="${line%% }"
  [[ -z "$line" ]] && continue
  # Parse <relpath>=<max_bytes>
  fpath="${line%%=*}"
  ceil="${line##*=}"
  if [[ -z "$fpath" || -z "$ceil" || "$fpath" == "$ceil" ]]; then
    echo "ERROR: malformed line in $budget_file: $raw" >&2
    fail=1
    continue
  fi
  if ! [[ "$ceil" =~ ^[0-9]+$ ]]; then
    echo "ERROR: non-numeric ceiling for '$fpath' in $budget_file: $ceil" >&2
    fail=1
    continue
  fi

  file_count=$((file_count + 1))

  if [[ ! -f "$fpath" ]]; then
    printf '%-55s %10s %8s %10s %10d %s\n' "$fpath" "MISSING" "-" "-" "$ceil" "MISSING"
    fail=1
    continue
  fi

  bytes=$(wc -c < "$fpath" 2>/dev/null | tr -d ' \r\n\t')
  lines=$(wc -l < "$fpath" 2>/dev/null | tr -d ' \r\n\t')
  [[ -z "$bytes" ]] && bytes=0
  [[ -z "$lines" ]] && lines=0
  tokens=$((bytes / 4))

  total_bytes=$((total_bytes + bytes))
  total_lines=$((total_lines + lines))

  if [[ "$ceil" -eq 0 ]]; then
    # Ceiling of 0 = file kept on disk but excluded from the always-loaded budget.
    status="EXCLUDED"
  elif [[ "$bytes" -gt "$ceil" ]]; then
    status="OVER"
    fail=1
  else
    status="ok"
  fi

  printf '%-55s %10d %8d %10d %10d %s\n' "$fpath" "$bytes" "$lines" "$tokens" "$ceil" "$status"
done < "$budget_file"

total_tokens=$((total_bytes / 4))
printf '%-55s %10s %8s %10s %10s %s\n' "----" "-----" "-----" "-------" "----------" "------"
printf '%-55s %10d %8d %10d %10s %s\n' "TOTAL (${file_count} files)" "$total_bytes" "$total_lines" "$total_tokens" "-" "-"

exit "$fail"
