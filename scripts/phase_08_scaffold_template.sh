#!/usr/bin/env bash
# ==============================================================================
# Phase 8 — Copy Per-Project Scaffold Templates
#
# Script Name : phase_08_scaffold_template.sh
# Purpose     : Copy REPO_ROOT/templates/project/ to ~/.claude/templates/project/
#               recursively.
# Phase       : 8 of 12
# Exit Criteria: ~/.claude/templates/project/ exists and contains all source files.
#
# Run with: bash scripts/phase_08_scaffold_template.sh
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

abort() {
    log_fail "$*"
    echo -e "\n${C_RED}[ABORTED] Phase 8 did not complete successfully.${C_RESET}"
    exit 1
}

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------
SOURCE_DIR="$REPO_ROOT/templates/project"
DEST_DIR="$HOME/.claude/templates/project"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 8 — Scaffold Templates"
echo      "  Repo Root : $REPO_ROOT"
echo      "  Source    : $SOURCE_DIR"
echo      "  Dest      : $DEST_DIR"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 — Verify source directory is non-empty
# ==============================================================================
log_section "Step 1: Verify source directory"

[ -d "$SOURCE_DIR" ] || abort "Source directory not found: $SOURCE_DIR"
log_pass "Source directory exists: $SOURCE_DIR"

source_count=$(find "$SOURCE_DIR" -type f | wc -l)
if [ "$source_count" -eq 0 ]; then
    abort "Source directory is empty. Nothing to copy: $SOURCE_DIR"
fi
log_pass "Source contains $source_count file(s)."

# ==============================================================================
# Step 2 — Create destination directory
# ==============================================================================
log_section "Step 2: Create destination directory"

if [ -d "$DEST_DIR" ]; then
    log_info "Destination already exists: $DEST_DIR"
else
    mkdir -p "$DEST_DIR" || abort "Failed to create destination directory: $DEST_DIR"
    log_pass "Created: $DEST_DIR"
fi

# ==============================================================================
# Step 3 — Copy recursively
# ==============================================================================
log_section "Step 3: Copy template directory (recurse)"

if cp -r "$SOURCE_DIR/." "$DEST_DIR/"; then
    log_pass "Copy completed without errors."
else
    abort "Failed to copy templates to '$DEST_DIR'."
fi

# ==============================================================================
# Step 4 — File count verification
# ==============================================================================
log_section "Step 4: File count verification"

dest_count=$(find "$DEST_DIR" -type f | wc -l)

log_info "Source file count : $source_count"
log_info "Dest file count   : $dest_count"

if [ "$dest_count" -ge "$source_count" ]; then
    log_pass "All $source_count source file(s) accounted for in destination."
    count_status="PASS"
else
    log_warn "Destination has fewer files ($dest_count) than source ($source_count)."
    count_status="WARN"
fi

# ==============================================================================
# Step 5 — List top-level contents of destination
# ==============================================================================
log_section "Step 5: Top-level contents of $DEST_DIR"

while IFS= read -r item; do
    name=$(basename "$item")
    if [ -d "$item" ]; then
        log_info "[DIR]  $name"
    else
        log_info "[FILE] $name"
    fi
done < <(find "$DEST_DIR" -maxdepth 1 -mindepth 1 | sort)

# ==============================================================================
# Summary
# ==============================================================================
echo -e "\n${C_CYAN}  Source files : $source_count"
echo -e   "  Dest files   : $dest_count${C_RESET}"

if [ "$count_status" = "WARN" ]; then
    echo -e "\n${C_YELLOW}[RESULT] Phase 8 completed with warnings. Verify destination manually.${C_RESET}\n"
    exit 0
else
    echo -e "\n${C_GREEN}[RESULT] Phase 8 completed successfully. Scaffold templates are in place.${C_RESET}\n"
    exit 0
fi
