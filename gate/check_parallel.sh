#!/usr/bin/env bash
# gate/check_parallel.sh — parallel wrapper around gate/check_architecture_sync.sh
#
# Background: the canonical gate (check_architecture_sync.sh) runs 63+
# stateless rules sequentially in one bash process. On Windows / git-bash
# that takes ~20+ minutes because every grep/find/awk/sed spawns a Win32
# process (slow under MSYS).
#
# This wrapper:
#   1. Reads the canonical script and splits it on `# Rule N — <slug>` markers.
#   2. For each rule, extracts the body lines.
#   3. Round-robin distributes rules into JOBS batches.
#   4. Each batch is a bash script that sources the shared prologue ONCE,
#      then runs each rule body in a subshell that resets `fail_count`.
#   5. Batches run in parallel via xargs -P.
#   6. Outputs PASS/FAIL lines in deterministic rule-number order and
#      returns 0 if every rule's fail_count==0.
#
# Opt-out:  GATE_PARALLEL=0 bash gate/check_parallel.sh
#           (falls through to the canonical serial script).
#
# Profiling: GATE_PROFILE=1 bash gate/check_parallel.sh
#           (emits per-rule wall-clock to stderr at end).
#
# Per CLAUDE.md Rule 3 + Rule 28: this wrapper produces identical PASS/FAIL
# semantics (and deterministic ordering) to the canonical script, so CI,
# self-tests, and humans observe no behavioural difference.

set -uo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

SOURCE_SCRIPT="gate/check_architecture_sync.sh"
JOBS="${GATE_JOBS:-8}"
PROFILE="${GATE_PROFILE:-0}"

if [[ "${GATE_PARALLEL:-1}" == "0" ]]; then
  exec bash "$SOURCE_SCRIPT"
fi

if [[ ! -f "$SOURCE_SCRIPT" ]]; then
  echo "FAIL: parallel_wrapper -- $SOURCE_SCRIPT not found" >&2
  echo "GATE: FAIL"
  exit 1
fi

WORK_DIR="$(mktemp -d -t gate-parallel.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# ---------------------------------------------------------------------------
# Extract rule ranges from the source script.
# Boundary: `# Rule N — slug` header. End of last rule: `# Summary` marker.
# TSV: rule_order_index<TAB>rule_slug<TAB>start_line<TAB>end_line
# ---------------------------------------------------------------------------
awk '
  function emit_prev(end) {
    if (prev_slug != "") {
      idx = idx + 1
      printf "%03d\t%s\t%d\t%d\n", idx, prev_slug, prev_start, end
    }
  }
  BEGIN { prev_slug = ""; prev_start = 0; idx = 0 }
  /^# Rule [0-9]+[a-z]? — / {
    emit_prev(NR - 1)
    match($0, /^# Rule ([0-9]+[a-z]?) — ([a-z_]+)/, arr)
    prev_slug = arr[1] "_" arr[2]
    prev_start = NR
    next
  }
  /^# Summary$/ {
    emit_prev(NR - 1)
    prev_slug = ""
    exit
  }
  END { emit_prev(NR) }
' "$SOURCE_SCRIPT" > "$WORK_DIR/manifest.tsv"

total_rules=$(wc -l < "$WORK_DIR/manifest.tsv")
if [[ "$total_rules" -lt "$JOBS" ]]; then JOBS="$total_rules"; fi

# ---------------------------------------------------------------------------
# Build a shared prologue: everything before the first rule body, with the
# repo_root computation overridden (canonical computes it from $BASH_SOURCE,
# which would resolve to $WORK_DIR for our subscripts).
# ---------------------------------------------------------------------------
first_rule_line=$(head -1 "$WORK_DIR/manifest.tsv" | cut -f3)
sed -n "1,$((first_rule_line - 1))p" "$SOURCE_SCRIPT" \
  | sed -E "s|^repo_root=\"\\\$\\(cd .*\\)\"$|repo_root=\"$repo_root\"|" \
  > "$WORK_DIR/prologue.sh"

# Cross-rule shared constants (rule 28f defines _efile, rules 28i/28j read it;
# similar for a few others). Pre-define them in the prologue so each isolated
# rule body finds them. Safe to redefine — they are read-only file paths.
cat >> "$WORK_DIR/prologue.sh" <<'SHIM'
# --- gate/check_parallel.sh shared-context shim ---
_efile='docs/governance/enforcers.yaml'
_archfile='ARCHITECTURE.md'
_status_file='docs/governance/architecture-status.yaml'
_status_path='docs/governance/architecture-status.yaml'
_python_bin="$(command -v python3 || command -v python || echo '')"
# --- end shim ---
SHIM

# ---------------------------------------------------------------------------
# Extract each rule's body into its own file (just the rule's lines).
# ---------------------------------------------------------------------------
while IFS=$'\t' read -r idx slug start end; do
  sed -n "${start},${end}p" "$SOURCE_SCRIPT" > "$WORK_DIR/body_${idx}_${slug}.sh"
done < "$WORK_DIR/manifest.tsv"

# ---------------------------------------------------------------------------
# Round-robin distribute rules into JOBS batches.
# ---------------------------------------------------------------------------
awk -v jobs="$JOBS" '{ print ((NR - 1) % jobs) "\t" $0 }' \
    "$WORK_DIR/manifest.tsv" > "$WORK_DIR/manifest.batched.tsv"

for b in $(seq 0 $((JOBS - 1))); do
  batch_script="$WORK_DIR/batch_${b}.sh"
  {
    echo "#!/usr/bin/env bash"
    echo "set +e"
    # Source the shared prologue (helpers, paths, shim) ONCE per batch.
    echo "source \"$WORK_DIR/prologue.sh\""
  } > "$batch_script"
  awk -F'\t' -v want="$b" '$1 == want { print $2 "\t" $3 "\t" $4 "\t" $5 }' \
      "$WORK_DIR/manifest.batched.tsv" \
    | while IFS=$'\t' read -r idx slug _ _; do
        rule_id="${idx}_${slug}"
        body_file="$WORK_DIR/body_${rule_id}.sh"
        out_file="$WORK_DIR/out_${rule_id}.txt"
        exit_file="$WORK_DIR/exit_${rule_id}.txt"
        ms_file="$WORK_DIR/ms_${rule_id}.txt"
        cat >> "$batch_script" <<RULE
T0_${idx}=\$(date +%s%3N)
(
  fail_count=0
  source "$body_file"
  exit "\$fail_count"
) > "$out_file" 2>&1
echo "\$?" > "$exit_file"
echo "\$(( \$(date +%s%3N) - T0_${idx} ))" > "$ms_file"
RULE
      done
done

# ---------------------------------------------------------------------------
# Run batches in parallel.
# ---------------------------------------------------------------------------
find "$WORK_DIR" -maxdepth 1 -name 'batch_*.sh' -type f -print0 \
  | xargs -0 -n 1 -P "$JOBS" bash

# ---------------------------------------------------------------------------
# Aggregate in deterministic rule-number order.
# ---------------------------------------------------------------------------
failed_rules=0
total_subfailures=0
profile_rows=""
while IFS=$'\t' read -r idx slug _ _; do
  rule_id="${idx}_${slug}"
  cat "$WORK_DIR/out_${rule_id}.txt" 2>/dev/null || true
  rc=0
  [[ -s "$WORK_DIR/exit_${rule_id}.txt" ]] && rc="$(cat "$WORK_DIR/exit_${rule_id}.txt")"
  [[ -z "$rc" ]] && rc=0
  if [[ "$rc" -ne 0 ]]; then
    failed_rules=$((failed_rules + 1))
    total_subfailures=$((total_subfailures + rc))
  fi
  elapsed_ms=0
  [[ -s "$WORK_DIR/ms_${rule_id}.txt" ]] && elapsed_ms="$(cat "$WORK_DIR/ms_${rule_id}.txt")"
  profile_rows="${profile_rows}${elapsed_ms}\t${rule_id}\n"
done < "$WORK_DIR/manifest.tsv"

if [[ "$PROFILE" == "1" ]]; then
  echo "--- gate parallel profile (per-rule wall-clock, ms, slowest first) ---" >&2
  printf '%b' "$profile_rows" | sort -rn | head -20 >&2
fi

if [[ "$failed_rules" -eq 0 ]]; then
  echo "GATE: PASS"
  exit 0
else
  echo "GATE: FAIL ($failed_rules of $total_rules rules failed; $total_subfailures sub-failures total)"
  exit 1
fi
