#!/usr/bin/env bash
# spring-ai-ascend doctor script -- POSIX
# Checks that the local environment is minimally configured for dev posture.
# Exits 0 if healthy, 1 if any required condition fails.
# Usage: bash gate/doctor.sh

set -euo pipefail

PASS=0
FAIL=1
EXIT_CODE=0

check() {
    local label="$1"
    local result="$2"
    if [ "$result" = "ok" ]; then
        echo "[PASS] $label"
    else
        echo "[FAIL] $label -- $result"
        EXIT_CODE=$FAIL
    fi
}

# 1. Posture detection
POSTURE="${APP_POSTURE:-dev}"
check "APP_POSTURE set (current: $POSTURE)" "ok"

# 2. Required env vars for non-dev postures
if [ "$POSTURE" != "dev" ]; then
    if [ -z "${DATABASE_URL:-}" ]; then
        check "DATABASE_URL set (required in $POSTURE)" "MISSING"
    else
        check "DATABASE_URL set" "ok"
    fi
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        check "OPENAI_API_KEY set (required in $POSTURE)" "MISSING"
    else
        check "OPENAI_API_KEY set" "ok"
    fi
fi

# 3. Check for recent gate log
GATE_LOG_COUNT=$(find gate/log -name "*-posix.json" 2>/dev/null | wc -l || echo 0)
if [ "$GATE_LOG_COUNT" -gt 0 ]; then
    LATEST=$(ls -t gate/log/*-posix.json 2>/dev/null | head -1)
    check "Recent gate log present ($LATEST)" "ok"
else
    check "Recent gate log present" "MISSING -- run gate/check_architecture_sync.sh first"
fi

# 4. Maven wrapper executable
if [ -x "mvnw" ]; then
    check "mvnw is executable" "ok"
else
    check "mvnw is executable" "MISSING exec bit -- run: git update-index --chmod=+x mvnw"
fi

# 5. Java available
if command -v java >/dev/null 2>&1; then
    JAVA_VER=$(java -version 2>&1 | head -1)
    check "Java available ($JAVA_VER)" "ok"
else
    check "Java available" "MISSING -- install Java 21"
fi

exit $EXIT_CODE
