#!/usr/bin/env bash
# ==============================================================================
# EOL-PHP-SecAuto - Test Runner
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

chmod +x "${SCRIPT_DIR}"/test-*.sh

"${SCRIPT_DIR}/test-cli-parser.sh"
echo ""
"${SCRIPT_DIR}/test-generator.sh"
echo ""
echo "All EOL-PHP-SecAuto tests passed successfully!"
