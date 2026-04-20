#!/usr/bin/env bash
# ==============================================================================
# Phase 7 - Deploy Claude Rules (diff-before-copy)
#
# Script Name : phase_07_claude_rules.sh
# Purpose     : Deploy rule files from REPO_ROOT/claude-rules/ to
#               ~/.claude/rules/, preserving any local personalizations the
#               user has made to the deployed copies.
#
# For each expected rule file:
#   - If the deployed copy does not exist: create it (no drift risk).
#   - If the deployed copy is byte-identical to the repo source: no-op,
#     report IN-SYNC.
#   - If the deployed copy differs: show a unified diff and prompt the user
#     per file: [o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit.
#     Skipping preserves the deployed personalization.
#
# Non-TTY runs (piped stdin, CI, scheduled tasks) skip every drifted file
# and warn on stderr. Re-run with --force to override and overwrite every
# drifted file without prompting.
#
# Phase       : 7 of 12
# Exit Criteria:
#   - Every expected rule file resolves to IN-SYNC, CREATED, OVERWRITE,
#     SKIP (user), or SKIP (non-TTY).
#
# Run with: bash scripts/phase_07_claude_rules.sh
# Force:    bash scripts/phase_07_claude_rules.sh --force
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(dirname "$(dirname "$0")")"

# ------------------------------------------------------------------------------
# Flags
# ------------------------------------------------------------------------------
FORCE=0
for arg in "$@"; do
    case "${arg}" in
        -f|--force) FORCE=1 ;;
        -h|--help)
            sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown argument: ${arg}" >&2
            echo "Use --force to overwrite every drifted file without prompting." >&2
            exit 64
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Colour helpers
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
    C_RED='\033[0;31m';  C_WHITE='\033[1;37m'; C_GRAY='\033[0;90m'
    C_RESET='\033[0m'
else
    C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_WHITE=''; C_GRAY=''; C_RESET=''
fi

log_info()    { echo -e "${C_CYAN}  [INFO]  $*${C_RESET}"; }
log_pass()    { echo -e "${C_GREEN}  [PASS]  $*${C_RESET}"; }
log_warn()    { echo -e "${C_YELLOW}  [WARN]  $*${C_RESET}" >&2; }
log_fail()    { echo -e "${C_RED}  [FAIL]  $*${C_RESET}" >&2; }
log_section() { echo -e "\n${C_WHITE}=== $* ===${C_RESET}"; }

abort() {
    log_fail "$*"
    echo -e "\n${C_RED}[ABORTED] Phase 7 did not complete successfully.${C_RESET}" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Paths and expected files
# ------------------------------------------------------------------------------
SOURCE_DIR="${REPO_ROOT}/claude-rules"
DEST_DIR="${HOME}/.claude/rules"

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

# Associative arrays need bash 4+. The script already requires bash (shebang),
# and every Windows dev env covered here has Git Bash's bash 4.x or higher.
declare -A RESULTS

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
mode_label="Prompt on drift"
if [ "${FORCE}" -eq 1 ]; then
    mode_label="Force (overwrite all)"
fi

echo -e "\n${C_CYAN}========================================"
echo      "  Phase 7 - Deploy Claude Rules"
echo      "  Repo Root : ${REPO_ROOT}"
echo      "  Source    : ${SOURCE_DIR}"
echo      "  Dest      : ${DEST_DIR}"
echo      "  Mode      : ${mode_label}"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 - Verify source directory and expected files
# ==============================================================================
log_section "Step 1: Verify source directory"

[ -d "${SOURCE_DIR}" ] || abort "Source directory not found: ${SOURCE_DIR}"
log_pass "Source directory exists: ${SOURCE_DIR}"

missing=()
for fname in "${EXPECTED_FILES[@]}"; do
    if [ -f "${SOURCE_DIR}/${fname}" ]; then
        log_pass "Found: ${fname}"
    else
        log_fail "Missing: ${fname}"
        missing+=("${fname}")
    fi
done

if [ "${#missing[@]}" -gt 0 ]; then
    abort "Missing expected rule files in source: ${missing[*]}"
fi

# ==============================================================================
# Step 2 - Create destination directory
# ==============================================================================
log_section "Step 2: Create destination directory"

if [ -d "${DEST_DIR}" ]; then
    log_info "Exists: ${DEST_DIR}"
else
    mkdir -p "${DEST_DIR}" || abort "Failed to create destination directory: ${DEST_DIR}"
    log_pass "Created: ${DEST_DIR}"
fi

# ==============================================================================
# Step 3 - Per-file deploy decision
# ==============================================================================
log_section "Step 3: Deploy rule files (diff-before-copy)"

# Short-circuit flags flip once the user picks an "All" or "None" option.
auto_overwrite=${FORCE}
auto_skip=0
aborted=0

# Detect whether stdin is interactive. `[ -t 0 ]` is the portable TTY test.
is_tty=0
if [ -t 0 ]; then
    is_tty=1
fi

# Portable sha256 helper: prefer sha256sum (coreutils, Git Bash ships it),
# fall back to shasum -a 256 (macOS default).
file_hash() {
    # sha256sum prepends '\' to the hash when the filename contains backslashes
    # or newlines (escaped-name form). Strip any leading backslash so the
    # compared hashes match regardless of path style. ~/.claude/rules/ paths
    # never contain backslashes, but keep the guard for parity with phase_07b.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{h=$1; sub(/^\\/, "", h); print h}'
    else
        shasum -a 256 "$1" | awk '{h=$1; sub(/^\\/, "", h); print h}'
    fi
}

# Show a unified diff for the two files. diff -u exits 1 on difference, 0 on
# identical; we only call it when we already know they differ, so the
# non-zero exit is expected and swallowed with `|| true`.
show_rule_diff() {
    local src="$1" dest="$2"
    echo -e "${C_GRAY}--- deployed: ${dest}${C_RESET}"
    echo -e "${C_GRAY}+++ repo:     ${src}${C_RESET}"
    diff -u "${dest}" "${src}" || true
}

# Prompt the user for one file. Echoes the decision word.
read_file_action() {
    local answer
    while true; do
        read -r -p "[o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit: " answer
        case "${answer}" in
            ''|s|S)   echo "skip"; return ;;
            o|O)      echo "overwrite"; return ;;
            A)        echo "all-overwrite"; return ;;
            N)        echo "all-skip"; return ;;
            q|Q)      echo "quit"; return ;;
            *)        log_warn "Invalid choice: '${answer}'. Try again." ;;
        esac
    done
}

for fname in "${EXPECTED_FILES[@]}"; do
    src="${SOURCE_DIR}/${fname}"
    dest="${DEST_DIR}/${fname}"

    if [ "${aborted}" -eq 1 ]; then
        RESULTS["${fname}"]="SKIP (quit)"
        continue
    fi

    if [ ! -f "${dest}" ]; then
        cp -f "${src}" "${dest}"
        log_pass "CREATED: ${fname}"
        RESULTS["${fname}"]="CREATED"
        continue
    fi

    src_hash=$(file_hash "${src}")
    dest_hash=$(file_hash "${dest}")

    if [ "${src_hash}" = "${dest_hash}" ]; then
        log_info "IN-SYNC: ${fname}"
        RESULTS["${fname}"]="IN-SYNC"
        continue
    fi

    if [ "${auto_overwrite}" -eq 1 ]; then
        cp -f "${src}" "${dest}"
        log_pass "OVERWRITE: ${fname} (forced)"
        RESULTS["${fname}"]="OVERWRITE"
        continue
    fi

    if [ "${auto_skip}" -eq 1 ]; then
        log_info "SKIP: ${fname} (batch-skip)"
        RESULTS["${fname}"]="SKIP"
        continue
    fi

    if [ "${is_tty}" -eq 0 ]; then
        log_warn "SKIP: ${fname} (drift detected, stdin is not a TTY; re-run with --force to overwrite)"
        RESULTS["${fname}"]="SKIP (non-TTY)"
        continue
    fi

    echo ""
    echo -e "${C_YELLOW}DRIFT: ${fname}${C_RESET}"
    show_rule_diff "${src}" "${dest}"
    action=$(read_file_action)

    case "${action}" in
        overwrite)
            cp -f "${src}" "${dest}"
            log_pass "OVERWRITE: ${fname}"
            RESULTS["${fname}"]="OVERWRITE"
            ;;
        skip)
            log_info "SKIP: ${fname}"
            RESULTS["${fname}"]="SKIP"
            ;;
        all-overwrite)
            cp -f "${src}" "${dest}"
            log_pass "OVERWRITE: ${fname} (All)"
            RESULTS["${fname}"]="OVERWRITE"
            auto_overwrite=1
            ;;
        all-skip)
            log_info "SKIP: ${fname} (None)"
            RESULTS["${fname}"]="SKIP"
            auto_skip=1
            ;;
        quit)
            log_warn "QUIT: ${fname} (user aborted; remaining files will be marked skipped)"
            RESULTS["${fname}"]="SKIP (quit)"
            aborted=1
            ;;
    esac
done

# ==============================================================================
# Summary
# ==============================================================================
log_section "Summary"

in_sync=0; created=0; overwritten=0; skipped=0

echo ""
echo -e "${C_WHITE}  Per-file status:${C_RESET}"
for fname in "${EXPECTED_FILES[@]}"; do
    status="${RESULTS[${fname}]:-UNKNOWN}"
    case "${status}" in
        IN-SYNC)         color="${C_CYAN}";   (( in_sync++ ))     || true ;;
        CREATED)         color="${C_GREEN}";  (( created++ ))     || true ;;
        OVERWRITE)       color="${C_GREEN}";  (( overwritten++ )) || true ;;
        SKIP*)           color="${C_YELLOW}"; (( skipped++ ))     || true ;;
        *)               color="${C_WHITE}" ;;
    esac
    printf "    ${color}%-20s %s${C_RESET}\n" "${fname}" "${status}"
done

echo ""
echo -e "${C_CYAN}  In-sync     : ${in_sync}${C_RESET}"
echo -e "${C_GREEN}  Created     : ${created}${C_RESET}"
echo -e "${C_GREEN}  Overwritten : ${overwritten}${C_RESET}"
if [ "${skipped}" -gt 0 ]; then
    echo -e "${C_YELLOW}  Skipped     : ${skipped}${C_RESET}"
else
    echo -e "${C_GREEN}  Skipped     : ${skipped}${C_RESET}"
fi

if [ "${aborted}" -eq 1 ]; then
    echo -e "\n${C_YELLOW}[RESULT] Phase 7 aborted by user. Re-run to continue.${C_RESET}"
    exit 2
fi

echo -e "\n${C_GREEN}[RESULT] Phase 7 completed. Drifted files were preserved unless overwritten.${C_RESET}\n"
exit 0
