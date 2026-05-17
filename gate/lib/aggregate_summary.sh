#!/usr/bin/env bash
# gate/lib/aggregate_summary.sh -- finalize one gate-run log directory.
#
# Invoked by gate/check_parallel.sh (and future PR-E5 orchestrator) AFTER all
# rule subshells have exited:
#
#   bash gate/lib/aggregate_summary.sh <GATE_LOG_DIR>
#
# Behaviour:
#   1. Reads <GATE_LOG_DIR>/per-rule.ndjson (one JSON object per line, emitted
#      by log_jsonl in gate/lib/common.sh).
#   2. Sorts the lines in-place ASCENDING by rule_number (then rule_id for
#      sub-rules like 28a, 28b...). Keeps the file usable for the
#      rule_e2_ndjson_sorted_by_rule_number self-test.
#   3. Computes summary aggregates:
#        - rules_total, rules_passed, rules_failed
#        - total_duration_ms (sum)
#        - workers (distinct worker_pid count)
#        - slowest_10 (top 10 by duration_ms, with delta_vs_median_pct against
#          gate/log/benchmarks/median.json)
#        - regression_alerts (placeholder for PR-E4 / Rule 72; emits [] today)
#   4. Reads <GATE_LOG_DIR>/manifest.txt for run-scoped metadata (run_id,
#      git_sha, started_at) injected by the orchestrator.
#   5. Writes <GATE_LOG_DIR>/summary.json matching the PR-E2 schema:
#        {
#          "record_type": "summary",
#          "run_id":      "<sha>_<unix_ts>",
#          "git_sha":     "<sha>",
#          "started_at":  "<iso8601>",
#          "finished_at": "<iso8601>",
#          "total_duration_ms": <int>,
#          "rules_total":   <int>,
#          "rules_passed":  <int>,
#          "rules_failed":  <int>,
#          "workers":       <int>,
#          "slowest_10":    [ {rule_id, rule_slug, duration_ms, delta_vs_median_pct} ... ],
#          "regression_alerts": []
#        }
#
# Honors GATE_LOGGING_SUMMARY_ENABLED: if "false", does sort-in-place only and
# skips summary.json emission (per CLAUDE.md Rule 10 posture defaults).
#
# Authority: PR-E2 plan (gate-script efficiency wave) + docs/governance/rules.

set -uo pipefail
export LC_ALL=C

GATE_LOG_DIR_ARG="${1:-}"
if [[ -z "$GATE_LOG_DIR_ARG" ]]; then
  echo "FAIL: aggregate_summary -- missing GATE_LOG_DIR argument" >&2
  exit 2
fi
if [[ ! -d "$GATE_LOG_DIR_ARG" ]]; then
  echo "FAIL: aggregate_summary -- directory not found: $GATE_LOG_DIR_ARG" >&2
  exit 2
fi

NDJSON_FILE="${GATE_LOG_DIR_ARG}/per-rule.ndjson"
SUMMARY_FILE="${GATE_LOG_DIR_ARG}/summary.json"
MANIFEST_FILE="${GATE_LOG_DIR_ARG}/manifest.txt"

if [[ ! -f "$NDJSON_FILE" ]]; then
  # No rule lines (e.g. all rules filtered out) -- emit an empty NDJSON so
  # downstream self-tests still find the file.
  : > "$NDJSON_FILE"
fi

# Resolve python (gate already depends on python; jq is NOT a repo dependency).
_python_bin="$(command -v python3 || command -v python || echo '')"
if [[ -z "$_python_bin" ]]; then
  echo "FAIL: aggregate_summary -- no python interpreter found" >&2
  exit 2
fi

# Resolve benchmarks median.json (optional; absent -> all delta_vs_median_pct = null).
_repo_root="${GATE_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_median_file="${_repo_root}/gate/log/benchmarks/median.json"
[[ -f "$_median_file" ]] || _median_file=""

_summary_enabled="${GATE_LOGGING_SUMMARY_ENABLED:-true}"
_finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z')"

# Hand off to python for the JSON-heavy work. Python reads the NDJSON, sorts
# by (rule_number, rule_id) ascending, rewrites it in place, then emits
# summary.json (unless disabled).
"$_python_bin" - "$NDJSON_FILE" "$SUMMARY_FILE" "$MANIFEST_FILE" "$_median_file" "$_summary_enabled" "$_finished_at" <<'PYEOF'
import io
import json
import os
import sys

ndjson_path  = sys.argv[1]
summary_path = sys.argv[2]
manifest_path = sys.argv[3]
median_path  = sys.argv[4]
summary_enabled = sys.argv[5].lower() == "true"
finished_at  = sys.argv[6]

# ---- Load NDJSON lines ----------------------------------------------------
rows = []
try:
    with io.open(ndjson_path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                # Tolerate a malformed line rather than abort the whole run.
                sys.stderr.write("WARN: aggregate_summary skipping malformed NDJSON line: %s\n" % line[:200])
except IOError as e:
    sys.stderr.write("FAIL: aggregate_summary cannot read %s: %s\n" % (ndjson_path, e))
    sys.exit(2)

def sort_key(r):
    # Sort by rule_number ascending, then by rule_id (covers 28a < 28b etc.)
    return (int(r.get("rule_number", 0)), str(r.get("rule_id", "")))

rows.sort(key=sort_key)

# ---- Rewrite NDJSON in-place (sorted) -------------------------------------
tmp_path = ndjson_path + ".tmp"
with io.open(tmp_path, "w", encoding="utf-8", newline="\n") as fh:
    for r in rows:
        fh.write(json.dumps(r, separators=(",", ":"), ensure_ascii=False))
        fh.write("\n")
os.replace(tmp_path, ndjson_path)

if not summary_enabled:
    sys.exit(0)

# ---- Aggregate ------------------------------------------------------------
rules_total  = len(rows)
rules_passed = sum(1 for r in rows if r.get("status") == "PASS")
rules_failed = sum(1 for r in rows if r.get("status") == "FAIL")
total_duration_ms = sum(int(r.get("duration_ms", 0) or 0) for r in rows)
workers = len({r.get("worker_pid") for r in rows if r.get("worker_pid") is not None})

# Load benchmarks median (keyed by rule_slug -> median_ms).
median = {}
if median_path and os.path.isfile(median_path):
    try:
        with io.open(median_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
            if isinstance(data, dict):
                # Two supported shapes:
                #   { "slug": 1234 }
                #   { "slug": {"median_ms": 1234} }
                for k, v in data.items():
                    if isinstance(v, (int, float)):
                        median[k] = float(v)
                    elif isinstance(v, dict) and "median_ms" in v:
                        try: median[k] = float(v["median_ms"])
                        except (TypeError, ValueError): pass
    except Exception as e:
        sys.stderr.write("WARN: aggregate_summary could not parse %s: %s\n" % (median_path, e))

def delta_pct(slug, dur):
    if slug in median and median[slug] > 0:
        return round(((float(dur) - median[slug]) / median[slug]) * 100.0, 1)
    return None

slowest = sorted(rows, key=lambda r: int(r.get("duration_ms", 0) or 0), reverse=True)[:10]
slowest_10 = []
for r in slowest:
    slug = r.get("rule_slug", "")
    dur  = int(r.get("duration_ms", 0) or 0)
    slowest_10.append({
        "rule_id":              r.get("rule_id", ""),
        "rule_slug":            slug,
        "duration_ms":          dur,
        "delta_vs_median_pct":  delta_pct(slug, dur),
    })

# ---- Load orchestrator manifest -------------------------------------------
manifest = {}
if manifest_path and os.path.isfile(manifest_path):
    try:
        with io.open(manifest_path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                manifest[k.strip()] = v.strip()
    except Exception as e:
        sys.stderr.write("WARN: aggregate_summary could not parse %s: %s\n" % (manifest_path, e))

summary = {
    "record_type":        "summary",
    "run_id":             manifest.get("run_id", os.path.basename(os.path.dirname(ndjson_path))),
    "git_sha":            manifest.get("git_sha", "nogit"),
    "started_at":         manifest.get("started_at", finished_at),
    "finished_at":        finished_at,
    "total_duration_ms":  total_duration_ms,
    "rules_total":        rules_total,
    "rules_passed":       rules_passed,
    "rules_failed":       rules_failed,
    "workers":            workers,
    "slowest_10":         slowest_10,
    "regression_alerts":  [],
}

with io.open(summary_path, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(summary, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PYEOF

_rc=$?
exit "$_rc"
