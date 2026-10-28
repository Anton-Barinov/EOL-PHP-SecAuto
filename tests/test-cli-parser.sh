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

# Test 2: Full semver detection (php:7.4.33-fpm)
json_semver=$("$SECAUTO" -b php:7.4.33-fpm --json)
if echo "$json_semver" | grep -q '"php_version": "7.4"'; then
    echo "  [PASS] Full semver version extraction (7.4.33 -> 7.4) succeeded."
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Failed to extract from semver image tag!"
    FAILED=$((FAILED + 1))
fi

# Test 3: Multi-stage Dockerfile input extraction (-d)
tmp_dockerfile=$(mktemp)
cat <<EOF > "$tmp_dockerfile"
FROM composer:2 AS composer_stage
FROM node:18 AS frontend
FROM php:7.2.34-fpm-alpine AS runtime
COPY --from=composer_stage /usr/bin/composer /usr/bin/composer
EOF
json_extracted=$("$SECAUTO" -d "$tmp_dockerfile" --json)
rm -f "$tmp_dockerfile"

if echo "$json_extracted" | grep -q '"php_version": "7.2"' && echo "$json_extracted" | grep -q '"distribution": "alpine"'; then
    echo "  [PASS] CLI correctly extracted runtime PHP base from multi-stage Dockerfile."
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Failed to extract PHP stage from multi-stage Dockerfile!"
    FAILED=$((FAILED + 1))
fi

# Test 4: Custom Extra INI injection
tmp_out=$(mktemp)
"$SECAUTO" -b php:7.4-fpm --extra-ini "memory_limit=1G; opcache.enable=1" -o "$tmp_out" >/dev/null 2>&1
if grep -q "memory_limit=1G" "$tmp_out" && grep -q "opcache.enable=1" "$tmp_out"; then
    echo "  [PASS] Extra INI directives correctly injected into generated Dockerfile."
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Extra INI directives missing in generated Dockerfile!"
    FAILED=$((FAILED + 1))
fi
rm -f "$tmp_out"

# Test 5: Version flag
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
