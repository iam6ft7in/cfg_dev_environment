#!/usr/bin/env bash
# ==============================================================================
# Phase 7b - Deploy Claude Skills and Helper Scripts (diff-before-copy)
#
# For each file under claude-skills/*/ and the two helpers in claude-scripts/,
# compare repo source against the deployed counterpart:
#   - Missing on deployed side: CREATED.
#   - Byte-identical: IN-SYNC.
#   - Differs: show unified diff and prompt per file
#     [o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit.
#     Skipping preserves the deployed personalization.
#
# Deployed-only files under a skill dir (user customizations) are left alone
# and reported as KEPT.
#
# Non-interactive runs (piped stdin, scheduled tasks) skip every drifted file
# and warn on stderr. Pass --force to overwrite every drifted file without
# prompting.
#
# Phase       : 7b of 12 (runs after Phase 7 rules, before Phase 8 templates)
#
# Run with: bash scripts/phase_07b_claude_skills_and_scripts.sh
# Force:    bash scripts/phase_07b_claude_skills_and_scripts.sh --force
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
            sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'
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
    echo -e "\n${C_RED}[ABORTED] Phase 7b did not complete successfully.${C_RESET}" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------
SOURCE_SKILLS_DIR="${REPO_ROOT}/claude-skills"
SOURCE_SCRIPTS_DIR="${REPO_ROOT}/claude-scripts"
DEST_SKILLS_DIR="${HOME}/.claude/skills"
DEST_SCRIPTS_DIR="${HOME}/.claude/scripts"
SHORTCUTS_DIR="${HOME}/.claude/shortcuts"

BOARD_HELPER_SRC="${SOURCE_SCRIPTS_DIR}/setup_project_board.ps1"
BOARD_HELPER_DEST="${DEST_SCRIPTS_DIR}/setup_project_board.ps1"
SHORTCUTS_SRC="${SOURCE_SCRIPTS_DIR}/regenerate_shortcuts.ps1"
SHORTCUTS_DEST="${SHORTCUTS_DIR}/regenerate.ps1"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
mode_label="Prompt on drift"
if [ "${FORCE}" -eq 1 ]; then
    mode_label="Force (overwrite all)"
fi

echo -e "\n${C_CYAN}========================================"
echo      "  Phase 7b - Claude Skills and Helper Scripts"
echo      "  Repo Root      : ${REPO_ROOT}"
echo      "  Skills source  : ${SOURCE_SKILLS_DIR}"
echo      "  Skills dest    : ${DEST_SKILLS_DIR}"
echo      "  Scripts source : ${SOURCE_SCRIPTS_DIR}"
echo      "  Scripts dest   : ${DEST_SCRIPTS_DIR}"
echo      "  Shortcuts dest : ${SHORTCUTS_DIR}"
echo      "  Mode           : ${mode_label}"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 - Verify sources
# ==============================================================================
log_section "Step 1: Verify source directories"

[ -d "${SOURCE_SKILLS_DIR}" ]  || abort "Source skills directory not found: ${SOURCE_SKILLS_DIR}"
log_pass "Source skills directory exists: ${SOURCE_SKILLS_DIR}"

[ -d "${SOURCE_SCRIPTS_DIR}" ] || abort "Source scripts directory not found: ${SOURCE_SCRIPTS_DIR}"
log_pass "Source scripts directory exists: ${SOURCE_SCRIPTS_DIR}"

mapfile -t SKILL_DIRS < <(find "${SOURCE_SKILLS_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
if [ "${#SKILL_DIRS[@]}" -eq 0 ]; then
    abort "No skill subdirectories found under ${SOURCE_SKILLS_DIR}"
fi
log_pass "Found ${#SKILL_DIRS[@]} skill(s) in source"

[ -f "${BOARD_HELPER_SRC}" ] || abort "Source helper missing: ${BOARD_HELPER_SRC}"
[ -f "${SHORTCUTS_SRC}" ]    || abort "Source helper missing: ${SHORTCUTS_SRC}"
log_pass "Both helper scripts present in source"

# ==============================================================================
# Step 2 - Create destination directories
# ==============================================================================
log_section "Step 2: Create destination directories"

for dir in "${DEST_SKILLS_DIR}" "${DEST_SCRIPTS_DIR}" "${SHORTCUTS_DIR}"; do
    if [ -d "${dir}" ]; then
        log_info "Exists: ${dir}"
    else
        mkdir -p "${dir}" || abort "Failed to create '${dir}'"
        log_pass "Created: ${dir}"
    fi
done

# ==============================================================================
# Step 3 - Build the (source, dest, label) work list
# ==============================================================================
log_section "Step 3: Enumerate source files"

# Parallel arrays rather than an associative one so ordering is stable.
declare -a SRC_LIST=()
declare -a DEST_LIST=()
declare -a LABEL_LIST=()

for skill_path in "${SKILL_DIRS[@]}"; do
    skill_name="$(basename "${skill_path}")"
    skill_dest_root="${DEST_SKILLS_DIR}/${skill_name}"

    mapfile -t skill_files < <(find "${skill_path}" -type f | sort)
    if [ "${#skill_files[@]}" -eq 0 ]; then
        log_warn "Skipping ${skill_name}: source dir has no files"
        continue
    fi

    # Require SKILL.md at the skill root; malformed otherwise.
    if [ ! -f "${skill_path}/SKILL.md" ]; then
        log_warn "Skipping ${skill_name}: no SKILL.md at skill root"
        continue
    fi

    for f in "${skill_files[@]}"; do
        rel="${f#${skill_path}/}"
        SRC_LIST+=("${f}")
        DEST_LIST+=("${skill_dest_root}/${rel}")
        LABEL_LIST+=("skills/${skill_name}/${rel}")
    done
done

# Helper scripts
SRC_LIST+=("${BOARD_HELPER_SRC}")
DEST_LIST+=("${BOARD_HELPER_DEST}")
LABEL_LIST+=("scripts/setup_project_board.ps1")

SRC_LIST+=("${SHORTCUTS_SRC}")
DEST_LIST+=("${SHORTCUTS_DEST}")
LABEL_LIST+=("shortcuts/regenerate.ps1")

pairs_count="${#SRC_LIST[@]}"
log_pass "${pairs_count} file(s) enumerated for deployment"

# ==============================================================================
# Step 4 - Per-file deploy decision
# ==============================================================================
log_section "Step 4: Deploy (diff-before-copy)"

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

for (( i = 0; i < pairs_count; i++ )); do
    src="${SRC_LIST[${i}]}"
    dest="${DEST_LIST[${i}]}"
    label="${LABEL_LIST[${i}]}"

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
# Step 5 - Report deployed-only files per skill (KEPT)
# ==============================================================================
log_section "Step 5: Deployed-only files (preserved)"

kept_count=0
for skill_path in "${SKILL_DIRS[@]}"; do
    skill_name="$(basename "${skill_path}")"
    skill_dest_root="${DEST_SKILLS_DIR}/${skill_name}"
    [ -d "${skill_dest_root}" ] || continue

    # Build the set of relative paths that exist in the source for this skill.
    declare -A src_set
    src_set=()
    while IFS= read -r -d '' f; do
        rel="${f#${skill_path}/}"
        src_set["${rel}"]=1
    done < <(find "${skill_path}" -type f -print0)

    while IFS= read -r -d '' d; do
        rel="${d#${skill_dest_root}/}"
        if [ -z "${src_set[${rel}]:-}" ]; then
            log_info "KEPT: skills/${skill_name}/${rel}"
            (( kept_count++ )) || true
        fi
    done < <(find "${skill_dest_root}" -type f -print0)
done
if [ "${kept_count}" -eq 0 ]; then
    log_info "No deployed-only files."
fi

# ==============================================================================
# Summary
# ==============================================================================
log_section "Summary"

in_sync=0; created=0; overwritten=0; skipped=0
for (( i = 0; i < pairs_count; i++ )); do
    label="${LABEL_LIST[${i}]}"
    status="${RESULTS[${label}]:-UNKNOWN}"
    case "${status}" in
        IN-SYNC)   (( in_sync++ ))     || true ;;
        CREATED)   (( created++ ))     || true ;;
        OVERWRITE) (( overwritten++ )) || true ;;
        SKIP*)     (( skipped++ ))     || true ;;
    esac
done

echo ""
echo -e "${C_CYAN}  Files processed : ${pairs_count}${C_RESET}"
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
    echo -e "\n${C_YELLOW}[RESULT] Phase 7b aborted by user. Re-run to continue.${C_RESET}"
    exit 2
fi

echo -e "\n${C_GREEN}[RESULT] Phase 7b completed. Drifted files were preserved unless overwritten.${C_RESET}\n"
exit 0
