#!/usr/bin/env bash
# ==============================================================================
# EOL-PHP-SecAuto - Test Generator Suite
# Validates Dockerfile generation across multiple PHP versions and strategies.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECAUTO="${SCRIPT_DIR}/../bin/eol-php-secauto"

echo "=== Running EOL-PHP-SecAuto Generator Tests ==="

test_cases=(
    "php:5.6-fpm|hybrid"
    "php:7.0-apache|hotpatch"
    "php:7.2-fpm-alpine|full-compile"
    "php:7.4-fpm|hybrid"
    "php:8.0-fpm|hotpatch"
    "php:8.1-apache|full-compile"
)

PASSED=0
FAILED=0

for tc in "${test_cases[@]}"; do
    IFS='|' read -r base strat <<< "$tc"
    tmp_out=$(mktemp)

    if "$SECAUTO" -b "$base" -s "$strat" -o "$tmp_out" >/dev/null 2>&1; then
        # Assert Dockerfile contains expected elements
        if grep -q "FROM ${base}" "$tmp_out" && grep -q "EOL-PHP-SecAuto" "$tmp_out"; then
            echo "  [PASS] Base: ${base} (Strategy: ${strat}) -> Valid Dockerfile generated."
            PASSED=$((PASSED + 1))
        else
            echo "  [FAIL] Base: ${base} (Strategy: ${strat}) -> Missing expected Dockerfile directives!"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  [FAIL] Base: ${base} (Strategy: ${strat}) -> CLI returned non-zero exit code!"
        FAILED=$((FAILED + 1))
    fi

    rm -f "$tmp_out"
done

echo "---------------------------------------------------------"
echo "Results: ${PASSED} Passed, ${FAILED} Failed"
echo "---------------------------------------------------------"

[ $FAILED -eq 0 ] && exit 0 || exit 1
