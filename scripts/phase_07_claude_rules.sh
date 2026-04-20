#!/usr/bin/env bash
# ==============================================================================
# Phase 7 — Copy Claude Rules
#
# Script Name : phase_07_claude_rules.sh
# Purpose     : Copy REPO_ROOT/claude-rules/*.md to ~/.claude/rules/
# Phase       : 7 of 12
# Exit Criteria: All expected .md rule files exist in ~/.claude/rules/
#
# Run with: bash scripts/phase_07_claude_rules.sh
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
    echo -e "\n${C_RED}[ABORTED] Phase 7 did not complete successfully.${C_RESET}"
    exit 1
}

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------
SOURCE_DIR="$REPO_ROOT/claude-rules"
DEST_DIR="$HOME/.claude/rules"

EXPECTED_FILES=(
    "core.md"
    "arduino.md"
    "python.md"
    "shell.md"
    "assembly.md"
    "vbscript.md"
    "command_paths.md"
    "powershell.md"
    "ssh.md"
)

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 7 — Copy Claude Rules"
echo      "  Repo Root : $REPO_ROOT"
echo      "  Source    : $SOURCE_DIR"
echo      "  Dest      : $DEST_DIR"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 — Verify source directory and expected files
# ==============================================================================
log_section "Step 1: Verify source directory"

[ -d "$SOURCE_DIR" ] || abort "Source directory not found: $SOURCE_DIR"
log_pass "Source directory exists: $SOURCE_DIR"

missing_files=()
for fname in "${EXPECTED_FILES[@]}"; do
    fpath="$SOURCE_DIR/$fname"
    if [ -f "$fpath" ]; then
        log_pass "Found: $fname"
    else
        log_fail "Missing: $fname"
        missing_files+=("$fname")
    fi
done

if [ "${#missing_files[@]}" -gt 0 ]; then
    abort "Missing expected rule files: ${missing_files[*]}. Cannot continue."
fi

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
# Step 3 — Copy each file
# ==============================================================================
log_section "Step 3 & 4: Copy rule files"

copied_count=0
copy_fail=0

for fname in "${EXPECTED_FILES[@]}"; do
    src="$SOURCE_DIR/$fname"
    dest="$DEST_DIR/$fname"
    if cp "$src" "$dest"; then
        log_pass "Copied: $src"
        log_info "     -> $dest"
        (( copied_count++ )) || true
    else
        log_fail "Failed to copy '$fname'"
        (( copy_fail++ )) || true
    fi
done

# ==============================================================================
# Step 4 — List destination contents
# ==============================================================================
log_section "Step 5: Files now in $DEST_DIR"

while IFS= read -r -d '' f; do
    fname=$(basename "$f")
    size=$(wc -c < "$f" 2>/dev/null || echo "?")
    # Convert bytes to KB
    size_kb=$(awk "BEGIN { printf \"%.1f\", $size/1024 }")
    mtime=$(date -r "$f" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
    log_info "$fname  (${size_kb} KB)  Last modified: $mtime"
done < <(find "$DEST_DIR" -maxdepth 1 -type f -print0 | sort -z)

# ==============================================================================
# Summary
# ==============================================================================
log_section "Summary"

dest_count=$(find "$DEST_DIR" -maxdepth 1 -type f | wc -l)

echo -e "\n${C_CYAN}  Files expected : ${#EXPECTED_FILES[@]}"
echo      "  Files copied   : $copied_count"
echo -e   "  Files in dest  : $dest_count${C_RESET}"

if [ "$copy_fail" -gt 0 ]; then
    echo -e "\n${C_RED}[RESULT] Phase 7 completed with errors. $copy_fail copy failure(s).${C_RESET}"
    exit 1
else
    echo -e "\n${C_GREEN}[RESULT] Phase 7 completed successfully. All Claude rules are in place.${C_RESET}\n"
    exit 0
fi
