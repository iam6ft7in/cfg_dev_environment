#!/usr/bin/env bash
# {{REPO_NAME}}, {{DESCRIPTION}}
# Platform: bash/zsh

set -euo pipefail

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source helper libraries
if [[ -d "${LIB_DIR}" ]]; then
    for lib_file in "${LIB_DIR}"/*.sh; do
        # shellcheck source=/dev/null
        source "${lib_file}"
    done
fi

main() {
    echo "{{REPO_NAME}} starting..."
}

main "$@"
