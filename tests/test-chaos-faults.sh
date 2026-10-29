#!/usr/bin/env bash
# ==============================================================================
# EOL-PHP-SecAuto Chaos & Fault Injection Test Suite
# Tests edge cases, corrupted inputs, hostile injection, and system errors
# Part of EOL-PHP-SecAuto by Anton Barinov
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../bin/eol-php-secauto"
VERIFY="${SCRIPT_DIR}/../bin/eol-verify"

PASS=0
FAIL=0

assert_fault() {
    local name="$1"
    local expected_code="$2"
    local actual_code="$3"
    local detail="$4"

    if [ "$expected_code" -eq "$actual_code" ]; then
        echo "  [PASS] ${name} (exit code ${actual_code}) -> ${detail}"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] ${name} (expected exit code ${expected_code}, got ${actual_code}) -> ${detail}"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Running EOL-PHP-SecAuto Chaos & Fault Injection Tests ==="
TMP_DIR=$(mktemp -d -t secauto_chaos_XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# -------------------------------------------------------------
# 1. Corrupted & Edge-Case Dockerfiles
# -------------------------------------------------------------
echo -e "\n1. Testing Corrupted & Edge-Case Dockerfiles..."

# Empty Dockerfile
EMPTY_DF="${TMP_DIR}/Dockerfile.empty"
touch "$EMPTY_DF"
set +e
"$BIN" -d "$EMPTY_DF" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Empty Dockerfile (0 bytes) rejected" 1 $CODE "Handled without hang or fatal exception"

# Dockerfile without FROM
NO_FROM_DF="${TMP_DIR}/Dockerfile.nofrom"
echo "# Just comments" > "$NO_FROM_DF"
set +e
"$BIN" -d "$NO_FROM_DF" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Dockerfile without FROM directive rejected" 1 $CODE "Caught missing base image"

# Dockerfile with hostile/malformed FROM
BAD_FROM_DF="${TMP_DIR}/Dockerfile.badfrom"
echo "FROM &&&:::bad_name" > "$BAD_FROM_DF"
set +e
"$BIN" -d "$BAD_FROM_DF" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Malformed FROM image (&&&:::bad_name) rejected" 1 $CODE "Invalid image syntax blocked"

# Multi-stage Dockerfile with PHP in middle stage (stage 2 of 5)
MULTI_DF="${TMP_DIR}/Dockerfile.multi"
cat << 'EOF' > "$MULTI_DF"
FROM golang:1.20 AS go-builder
RUN echo "go"
FROM php:7.3-fpm AS php-app
RUN echo "php"
FROM node:18 AS frontend
RUN echo "node"
FROM redis:alpine AS cache
RUN echo "redis"
FROM nginx:alpine AS final
COPY --from=php-app /var/www /var/www
EOF
set +e
OUT_MULTI="${TMP_DIR}/Dockerfile.multi.out"
"$BIN" -d "$MULTI_DF" -o "$OUT_MULTI" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Multi-stage Dockerfile correctly identifies PHP middle stage" 0 $CODE "PHP stage accurately targeted"
if [ $CODE -eq 0 ]; then
    grep -q 'FROM php:7.3-fpm' "$OUT_MULTI" && echo "     ✓ Verified target FROM matches php:7.3-fpm"
fi

# -------------------------------------------------------------
# 2. Hostile CLI Arguments & Injections
# -------------------------------------------------------------
echo -e "\n2. Testing Hostile CLI Arguments & Injections..."

# Hostile Command Injection attempt in --extra-ini
OUT_INI="${TMP_DIR}/Dockerfile.ini.out"
set +e
"$BIN" -b php:7.4-fpm --extra-ini "memory_limit=1G'; rm -rf /; echo '" -o "$OUT_INI" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Shell injection attempt in --extra-ini sanitized/rejected" 1 $CODE "Dangerous shell syntax safely blocked"

# Invalid strategy
set +e
"$BIN" -b php:7.4-fpm -s "hacker_strategy" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Unsupported strategy flag rejected" 1 $CODE "Invalid strategy refused"

# Invalid patch flavor
set +e
"$BIN" -b php:7.4-fpm -f "evil_flavor" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Unsupported patch flavor rejected" 1 $CODE "Invalid flavor refused"

# Output to read-only / protected directory
set +e
"$BIN" -b php:7.4-fpm -o "/sys/kernel/test_forbidden_secauto" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "Write attempt to read-only/forbidden path rejected" 1 $CODE "Permission failure handled cleanly"

# -------------------------------------------------------------
# 3. CLI Exit Code Conformance on Invalid Usage
# -------------------------------------------------------------
echo -e "\n3. Testing CLI Exit Code Conformance on Invalid Usage..."

# Missing arguments on eol-php-secauto
set +e
"$BIN" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "eol-php-secauto without arguments returns code > 0" 1 $CODE "Exit code is 1"

# Missing arguments on eol-verify
set +e
"$VERIFY" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "eol-verify without arguments returns code > 0" 1 $CODE "Exit code is 1"

# Non-existent Dockerfile on eol-verify
set +e
"$VERIFY" -d "/non_existent_file_path" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "eol-verify on non-existent Dockerfile returns code > 0" 1 $CODE "Exit code is 1"

# Non-compliant Dockerfile evaluation
NON_COMPLIANT_DF="${TMP_DIR}/Dockerfile.vulnerable"
echo "FROM php:7.4-fpm" > "$NON_COMPLIANT_DF"
set +e
"$VERIFY" -d "$NON_COMPLIANT_DF" >/dev/null 2>&1
CODE=$?
set -e
assert_fault "eol-verify correctly returns exit 1 for non-compliant image" 1 $CODE "Unpatched image flagged as non-compliant"

echo -e "\n---------------------------------------------------------"
echo "Results: ${PASS} Passed, ${FAIL} Failed"
echo "---------------------------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo "CHAOS TESTS FAILED! ❌"
    exit 1
fi

echo "ALL CHAOS & FAULT INJECTION TESTS PASSED! 🎉"
exit 0
