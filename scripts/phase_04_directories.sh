#!/usr/bin/env bash
# ==============================================================================
# Phase 4: Project Directory Structure
#
# Script Name : phase_04_directories.sh
# Purpose     : Create all required project and tool directories.
# Phase       : 4 of 12
# Exit Criteria: All directories exist.
#
# Run with: bash scripts/phase_04_directories.sh
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(dirname "$(dirname "$0")")"

# ------------------------------------------------------------------------------
# Colour helpers
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
    C_RED='\033[0;31m';  C_WHITE='\033[1;37m'; C_RESET='\033[0m'
else
    C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_WHITE=''; C_RESET=''
fi

log_info()    { echo -e "${C_CYAN}  [INFO]  $*${C_RESET}"; }
log_pass()    { echo -e "${C_GREEN}  [PASS]  $*${C_RESET}"; }
log_warn()    { echo -e "${C_YELLOW}  [WARN]  $*${C_RESET}"; }
log_fail()    { echo -e "${C_RED}  [FAIL]  $*${C_RESET}"; }
log_section() { echo -e "\n${C_WHITE}=== $* ===${C_RESET}"; }

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 4, Directory Structure"
echo -e   "========================================${C_RESET}\n"

# ------------------------------------------------------------------------------
# Read projects_root and github_username from ~/.claude/config.json (Phase 3)
# ------------------------------------------------------------------------------
CLAUDE_CONFIG="${HOME}/.claude/config.json"
if [ ! -f "${CLAUDE_CONFIG}" ]; then
    log_fail "${CLAUDE_CONFIG} not found. Run Phase 3 first; it prompts for projects_root and github_username and persists both."
    exit 1
fi

read_config_value() {
    local key="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg k "${key}" '.[$k] // empty' "${CLAUDE_CONFIG}" 2>/dev/null || true
    else
        grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "${CLAUDE_CONFIG}" \
            | sed -E "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/" \
            | head -n1
    fi
}

PROJECTS_ROOT="$(read_config_value 'projects_root')"
GITHUB_USERNAME="$(read_config_value 'github_username')"

if [ -z "${PROJECTS_ROOT}" ]; then
    log_fail "projects_root missing from ${CLAUDE_CONFIG}. Re-run Phase 3."
    exit 1
fi
if [ -z "${GITHUB_USERNAME}" ]; then
    log_fail "github_username missing from ${CLAUDE_CONFIG}. Re-run Phase 3."
    exit 1
fi

log_info "Projects root  : ${PROJECTS_ROOT}"
log_info "GitHub username: ${GITHUB_USERNAME}"

# ------------------------------------------------------------------------------
# Directory list (derived from config)
# ------------------------------------------------------------------------------
DIRS=(
    # Personal repo subtree (under ${GITHUB_USERNAME})
    "${PROJECTS_ROOT}/${GITHUB_USERNAME}/public"
    "${PROJECTS_ROOT}/${GITHUB_USERNAME}/private"
    "${PROJECTS_ROOT}/${GITHUB_USERNAME}/collaborative"

    # Other project roots
    "${PROJECTS_ROOT}/client"
    "${PROJECTS_ROOT}/arduino/upstream"
    "${PROJECTS_ROOT}/arduino/custom"

    # Claude-launcher shortcuts (Phase 7b)
    "$HOME/.claude/shortcuts"

    # Git template hooks
    "$HOME/.git-templates/hooks"

    # Claude directories
    "$HOME/.claude/rules"
    "$HOME/.claude/skills"        # Populated by Phase 7b
    "$HOME/.claude/scripts"       # Populated by Phase 7b
    "$HOME/.claude/templates"

    # Tool config directories
    "$HOME/.cspell"
    "$HOME/.oh-my-posh"
)

# ==============================================================================
# Create directories
# ==============================================================================
log_section "Creating directories"

pass_count=0
fail_count=0
skip_count=0

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log_warn "Already exists: $dir"
        (( skip_count++ )) || true
    else
        if mkdir -p "$dir"; then
            log_pass "Created: $dir"
            (( pass_count++ )) || true
        else
            log_fail "Failed to create: $dir"
            (( fail_count++ )) || true
        fi
    fi
done

# ==============================================================================
# Verify all directories exist
# ==============================================================================
log_section "Verification"

verify_fail=0
for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log_pass "Exists: $dir"
    else
        log_fail "Missing: $dir"
        (( verify_fail++ )) || true
    fi
done

# ==============================================================================
# Summary
# ==============================================================================
echo -e "\n${C_CYAN}  Total directories : ${#DIRS[@]}"
echo      "  Created           : $pass_count"
echo      "  Already existed   : $skip_count"
echo -e   "  Failed            : $fail_count${C_RESET}"

if [ "$verify_fail" -gt 0 ] || [ "$fail_count" -gt 0 ]; then
    echo -e "\n${C_RED}[RESULT] Phase 4 completed with errors. $verify_fail directory/ies missing.${C_RESET}"
    exit 1
else
    echo -e "\n${C_GREEN}[RESULT] Phase 4 completed successfully. All directories are in place.${C_RESET}\n"
    exit 0
fi
