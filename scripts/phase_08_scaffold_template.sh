#!/usr/bin/env bash
# ==============================================================================
# Phase 8 - Copy Per-Project Scaffold Templates (diff-before-copy)
#
# For each file under REPO_ROOT/templates/project/, compare against its
# counterpart under ~/.claude/templates/project/:
#   - Missing on deployed side: CREATED.
#   - Byte-identical: IN-SYNC.
#   - Differs: show unified diff and prompt per file
#     [o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit.
#     Skipping preserves the deployed personalization.
#
# Deployed-only files (user customizations added to the deployed scaffold)
# are left alone and reported as KEPT.
#
# Non-interactive runs (piped stdin, scheduled tasks) skip every drifted
# file and warn on stderr. Pass --force to overwrite every drifted file
# without prompting.
#
# Phase       : 8 of 12
#
# Run with: bash scripts/phase_08_scaffold_template.sh
# Force:    bash scripts/phase_08_scaffold_template.sh --force
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
            sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
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
    echo -e "\n${C_RED}[ABORTED] Phase 8 did not complete successfully.${C_RESET}" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------
SOURCE_DIR="${REPO_ROOT}/templates/project"
DEST_DIR="${HOME}/.claude/templates/project"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
mode_label="Prompt on drift"
if [ "${FORCE}" -eq 1 ]; then
    mode_label="Force (overwrite all)"
fi

echo -e "\n${C_CYAN}========================================"
echo      "  Phase 8 - Scaffold Templates"
echo      "  Repo Root : ${REPO_ROOT}"
echo      "  Source    : ${SOURCE_DIR}"
echo      "  Dest      : ${DEST_DIR}"
echo      "  Mode      : ${mode_label}"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 - Verify source
# ==============================================================================
log_section "Step 1: Verify source directory"

[ -d "${SOURCE_DIR}" ] || abort "Source directory not found: ${SOURCE_DIR}"

mapfile -t SRC_FILES < <(find "${SOURCE_DIR}" -type f | sort)
if [ "${#SRC_FILES[@]}" -eq 0 ]; then
    abort "Source directory is empty. Nothing to copy: ${SOURCE_DIR}"
fi
log_pass "Source contains ${#SRC_FILES[@]} file(s)."

# ==============================================================================
# Step 2 - Create destination
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
log_section "Step 3: Deploy scaffold (diff-before-copy)"

declare -A RESULTS
auto_overwrite=${FORCE}
auto_skip=0
aborted=0

is_tty=0
if [ -t 0 ]; then
    is_tty=1
fi

file_hash() {
    # sha256sum prepends '\' to the hash when the filename contains backslashes
    # or newlines (escaped-name form). Strip any leading backslash so the
    # compared hashes match regardless of path style.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{h=$1; sub(/^\\/, "", h); print h}'
    else
        shasum -a 256 "$1" | awk '{h=$1; sub(/^\\/, "", h); print h}'
    fi
}

show_file_diff() {
    local src="$1" dest="$2"
    echo -e "${C_GRAY}--- deployed: ${dest}${C_RESET}"
    echo -e "${C_GRAY}+++ repo:     ${src}${C_RESET}"
    diff -u "${dest}" "${src}" || true
}

read_file_action() {
    local answer
    while true; do
        read -r -p "[o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit: " answer
        case "${answer}" in
            ''|s|S)  echo "skip"; return ;;
            o|O)     echo "overwrite"; return ;;
            A)       echo "all-overwrite"; return ;;
            N)       echo "all-skip"; return ;;
            q|Q)     echo "quit"; return ;;
            *)       log_warn "Invalid choice: '${answer}'. Try again." ;;
        esac
    done
}

for src in "${SRC_FILES[@]}"; do
    rel="${src#${SOURCE_DIR}/}"
    label="${rel}"
    dest="${DEST_DIR}/${rel}"

    if [ "${aborted}" -eq 1 ]; then
        RESULTS["${label}"]="SKIP (quit)"
        continue
    fi

    mkdir -p "$(dirname "${dest}")"

    if [ ! -f "${dest}" ]; then
        cp -f "${src}" "${dest}"
        log_pass "CREATED: ${label}"
        RESULTS["${label}"]="CREATED"
        continue
    fi

    src_hash=$(file_hash "${src}")
    dest_hash=$(file_hash "${dest}")
    if [ "${src_hash}" = "${dest_hash}" ]; then
        log_info "IN-SYNC: ${label}"
        RESULTS["${label}"]="IN-SYNC"
        continue
    fi

    if [ "${auto_overwrite}" -eq 1 ]; then
        cp -f "${src}" "${dest}"
        log_pass "OVERWRITE: ${label} (forced)"
        RESULTS["${label}"]="OVERWRITE"
        continue
    fi
    if [ "${auto_skip}" -eq 1 ]; then
        log_info "SKIP: ${label} (batch-skip)"
        RESULTS["${label}"]="SKIP"
        continue
    fi
    if [ "${is_tty}" -eq 0 ]; then
        log_warn "SKIP: ${label} (drift, stdin is not a TTY; --force to overwrite)"
        RESULTS["${label}"]="SKIP (non-TTY)"
        continue
    fi

    echo ""
    echo -e "${C_YELLOW}DRIFT: ${label}${C_RESET}"
    show_file_diff "${src}" "${dest}"
    action=$(read_file_action)

    case "${action}" in
        overwrite)
            cp -f "${src}" "${dest}"
            log_pass "OVERWRITE: ${label}"
            RESULTS["${label}"]="OVERWRITE"
            ;;
        skip)
            log_info "SKIP: ${label}"
            RESULTS["${label}"]="SKIP"
            ;;
        all-overwrite)
            cp -f "${src}" "${dest}"
            log_pass "OVERWRITE: ${label} (All)"
            RESULTS["${label}"]="OVERWRITE"
            auto_overwrite=1
            ;;
        all-skip)
            log_info "SKIP: ${label} (None)"
            RESULTS["${label}"]="SKIP"
            auto_skip=1
            ;;
        quit)
            log_warn "QUIT: ${label} (user aborted; remaining files will be marked skipped)"
            RESULTS["${label}"]="SKIP (quit)"
            aborted=1
            ;;
    esac
done

# ==============================================================================
# Step 4 - Report deployed-only files (KEPT)
# ==============================================================================
log_section "Step 4: Deployed-only files (preserved)"

declare -A src_set
for src in "${SRC_FILES[@]}"; do
    rel="${src#${SOURCE_DIR}/}"
    src_set["${rel}"]=1
done

kept_count=0
while IFS= read -r -d '' d; do
    rel="${d#${DEST_DIR}/}"
    if [ -z "${src_set[${rel}]:-}" ]; then
        log_info "KEPT: ${rel}"
        (( kept_count++ )) || true
    fi
done < <(find "${DEST_DIR}" -type f -print0)

if [ "${kept_count}" -eq 0 ]; then
    log_info "No deployed-only files."
fi

# ==============================================================================
# Summary
# ==============================================================================
log_section "Summary"

in_sync=0; created=0; overwritten=0; skipped=0
for src in "${SRC_FILES[@]}"; do
    rel="${src#${SOURCE_DIR}/}"
    status="${RESULTS[${rel}]:-UNKNOWN}"
    case "${status}" in
        IN-SYNC)   (( in_sync++ ))     || true ;;
        CREATED)   (( created++ ))     || true ;;
        OVERWRITE) (( overwritten++ )) || true ;;
        SKIP*)     (( skipped++ ))     || true ;;
    esac
done

echo ""
echo -e "${C_CYAN}  Files processed : ${#SRC_FILES[@]}${C_RESET}"
echo -e "${C_CYAN}  In-sync         : ${in_sync}${C_RESET}"
echo -e "${C_GREEN}  Created         : ${created}${C_RESET}"
echo -e "${C_GREEN}  Overwritten     : ${overwritten}${C_RESET}"
if [ "${skipped}" -gt 0 ]; then
    echo -e "${C_YELLOW}  Skipped         : ${skipped}${C_RESET}"
else
    echo -e "${C_GREEN}  Skipped         : ${skipped}${C_RESET}"
fi
echo -e "${C_CYAN}  Kept (untracked): ${kept_count}${C_RESET}"

if [ "${aborted}" -eq 1 ]; then
    echo -e "\n${C_YELLOW}[RESULT] Phase 8 aborted by user. Re-run to continue.${C_RESET}"
    exit 2
fi

echo -e "\n${C_GREEN}[RESULT] Phase 8 completed. Drifted files were preserved unless overwritten.${C_RESET}\n"
exit 0
