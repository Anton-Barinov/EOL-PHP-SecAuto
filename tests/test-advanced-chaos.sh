#!/usr/bin/env bash
# ==============================================================================
# EOL-PHP-SecAuto Advanced Chaos & Non-Root / Multi-Distro / Signal Test Suite
# Part of EOL-PHP-SecAuto by Anton Barinov
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../bin/eol-php-secauto"

PASS=0
FAIL=0

assert_test() {
    local name="$1"
    local condition="$2"
    local detail="$3"

    if [ "$condition" = "true" ]; then
        echo "  [PASS] ${name} -> ${detail}"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] ${name} -> ${detail}"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Running EOL-PHP-SecAuto Advanced Chaos & Architecture Tests ==="
TMP_DIR=$(mktemp -d -t secauto_adv_XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# -------------------------------------------------------------
# 1. Non-Root User Compatibility (USER 1000:1000)
# -------------------------------------------------------------
echo -e "\n1. Testing Non-Root User (0644 Permissions) Compatibility..."

DF_NON_ROOT="${TMP_DIR}/Dockerfile.nonroot"
"$BIN" -b php:7.4-fpm -o "$DF_NON_ROOT" >/dev/null 2>&1

HAS_CHMOD=$(grep -qi 'chmod.*644.*/opt/secauto-guard/guard.php' "$DF_NON_ROOT" && echo "true" || echo "false")
assert_test "Runtime guard has explicit 0644 readable permissions" "$HAS_CHMOD" "Non-root users can read runtime-guard.php"

HAS_INI_CHMOD=$(grep -qi 'chmod.*644.*99-eol-secauto-hardening.ini' "$DF_NON_ROOT" && echo "true" || echo "false")
assert_test "Hardening ini has explicit 0644 readable permissions" "$HAS_INI_CHMOD" "Non-root users can read php.ini"

# -------------------------------------------------------------
# 2. Container Signal Handling & STOPSIGNAL
# -------------------------------------------------------------
echo -e "\n2. Testing Container Graceful Shutdown (STOPSIGNAL)..."

HAS_STOPSIGNAL=$(grep -qi '^STOPSIGNAL SIGQUIT' "$DF_NON_ROOT" && echo "true" || echo "false")
assert_test "FPM container declares STOPSIGNAL SIGQUIT" "$HAS_STOPSIGNAL" "Prevents 10-second timeout on docker stop"

DF_APACHE="${TMP_DIR}/Dockerfile.apache"
"$BIN" -b php:7.4-apache -o "$DF_APACHE" >/dev/null 2>&1
HAS_APACHE_SIGNAL=$(grep -qi '^STOPSIGNAL SIGWINCH' "$DF_APACHE" && echo "true" || echo "false")
assert_test "Apache container declares STOPSIGNAL SIGWINCH" "$HAS_APACHE_SIGNAL" "Ensures graceful worker termination for Apache"

# -------------------------------------------------------------
# 3. Multi-Distro Distinctions (Alpine vs Debian)
# -------------------------------------------------------------
echo -e "\n3. Testing Multi-Distro Isolation (Alpine vs Debian)..."

DF_ALPINE="${TMP_DIR}/Dockerfile.alpine"
"$BIN" -b php:7.4-fpm-alpine -o "$DF_ALPINE" >/dev/null 2>&1

ALPINE_HAS_DEBIAN_ARCHIVE=$(grep -qi 'archive\.debian\.org' "$DF_ALPINE" && echo "true" || echo "false")
assert_test "Alpine image omits Debian-specific APT sources rewrite" "$([ "$ALPINE_HAS_DEBIAN_ARCHIVE" = "false" ] && echo "true" || echo "false")" "Clean distro separation"

# -------------------------------------------------------------
# 4. Layer Caching & Instruction Order
# -------------------------------------------------------------
echo -e "\n4. Testing Docker Layer Caching & Build Optimization..."

# Verify RUN commands are concatenated to minimize image layers
LAYER_COUNT=$(grep -c '^RUN' "$DF_NON_ROOT")
assert_test "Hardening layer uses <= 4 RUN statements" "$([ "$LAYER_COUNT" -le 4 ] && echo "true" || echo "false")" "Only ${LAYER_COUNT} RUN layer(s) generated"

echo -e "\n---------------------------------------------------------"
echo "Results: ${PASS} Passed, ${FAIL} Failed"
echo "---------------------------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo "ADVANCED TESTS FAILED! ❌"
    exit 1
fi

echo "ALL ADVANCED CHAOS & ARCHITECTURE TESTS PASSED! 🎉"
exit 0
