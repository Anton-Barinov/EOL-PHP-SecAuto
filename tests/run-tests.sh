#!/usr/bin/env bash
# ==============================================================================
# EOL-PHP-SecAuto - Comprehensive Test Runner
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

chmod +x "${SCRIPT_DIR}"/test-*.sh

echo "1. Testing CLI Parser & Options..."
"${SCRIPT_DIR}/test-cli-parser.sh"

echo -e "\n2. Testing Dockerfile Generator & Static Compliance..."
"${SCRIPT_DIR}/test-generator.sh"

echo -e "\n3. Testing Container Runtime Guard Unit Tests..."
php "${SCRIPT_DIR}/test-runtime-guard.php"

echo -e "\n4. Testing Chaos & Fault Injection Edge Cases..."
"${SCRIPT_DIR}/test-chaos-faults.sh"

echo -e "\n5. Testing Advanced Non-Root & Multi-Distro Architectural Tests..."
"${SCRIPT_DIR}/test-advanced-chaos.sh"

echo -e "\nAll EOL-PHP-SecAuto test suites passed successfully!"
