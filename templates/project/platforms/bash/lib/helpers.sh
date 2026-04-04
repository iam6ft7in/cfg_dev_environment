#!/usr/bin/env bash
# Helper functions for {{REPO_NAME}}

# Print a status message with color
# Usage: log_info "message" | log_success "message" | log_error "message" | log_warn "message"

log_info()    { echo -e "\033[0;36m[INFO]\033[0m  ${1}"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m    ${1}"; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m ${1}" >&2; }
log_warn()    { echo -e "\033[0;33m[WARN]\033[0m  ${1}"; }

# Check if a command exists
# Usage: require_command git "Git is required"
require_command() {
    local cmd="${1}"
    local msg="${2:-Command ${cmd} is required but not found}"
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "${msg}"
        return 1
    fi
}
