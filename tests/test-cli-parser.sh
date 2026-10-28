#!/usr/bin/env bash
# ==============================================================================
# EOL-PHP-SecAuto - Test CLI Parser & JSON Output
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECAUTO="${SCRIPT_DIR}/../bin/eol-php-secauto"

echo "=== Running EOL-PHP-SecAuto CLI Parser Tests ==="

PASSED=0
FAILED=0

# Test 1: JSON Output schema validation
json_out=$("$SECAUTO" -b php:7.4-fpm --json)
if echo "$json_out" | grep -q '"status": "success"' && echo "$json_out" | grep -q '"php_version": "7.4"'; then
    echo "  [PASS] CLI JSON Output contains valid schema."
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] CLI JSON Output invalid!"
    FAILED=$((FAILED + 1))
fi

# Test 2: Dockerfile input extraction (-d)
tmp_dockerfile=$(mktemp)
echo "FROM php:7.3-fpm-alpine" > "$tmp_dockerfile"
json_extracted=$("$SECAUTO" -d "$tmp_dockerfile" --json)
rm -f "$tmp_dockerfile"

if echo "$json_extracted" | grep -q '"php_version": "7.3"' && echo "$json_extracted" | grep -q '"distribution": "alpine"'; then
    echo "  [PASS] CLI correctly extracted base image from existing Dockerfile."
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Failed to extract from Dockerfile!"
    FAILED=$((FAILED + 1))
fi

# Test 3: Version flag
if "$SECAUTO" -v | grep -q "eol-php-secauto v"; then
    echo "  [PASS] Version flag output valid."
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Version flag output invalid!"
    FAILED=$((FAILED + 1))
fi

echo "---------------------------------------------------------"
echo "Results: ${PASSED} Passed, ${FAILED} Failed"
echo "---------------------------------------------------------"

[ $FAILED -eq 0 ] && exit 0 || exit 1
