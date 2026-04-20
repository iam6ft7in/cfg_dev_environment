#!/usr/bin/env bash
# ==============================================================================
# Phase 7b - Deploy Claude Skills and Helper Scripts
#
# Script Name : phase_07b_claude_skills_and_scripts.sh
# Purpose     : Deploy the three external assets the /new-repo, /migrate-repo,
#               and /apply-standard skills call out to:
#                 1. claude-skills/*/SKILL.md -> ~/.claude/skills/*/SKILL.md
#                 2. claude-scripts/setup_project_board.ps1
#                      -> ~/.claude/scripts/setup_project_board.ps1
#                 3. claude-scripts/regenerate_shortcuts.ps1
#                      -> {projects_root}/shortcuts/regenerate.ps1
#
# Phase       : 7b of 12 (runs after Phase 7 rules, before Phase 8 templates)
# Exit Criteria:
#   - Every SKILL.md in claude-skills/ has a copy at the matching path under
#     ~/.claude/skills/
#   - setup_project_board.ps1 is present in ~/.claude/scripts/
#   - regenerate.ps1 is present in {projects_root}/shortcuts/
#
# Projects root resolution: reads ~/.claude/config.json (key projects_root),
# written by Phase 4. Falls back to $HOME/projects and warns if config is
# missing or key is absent.
#
# Run with: bash scripts/phase_07b_claude_skills_and_scripts.sh
# Idempotent - safe to re-run.
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
    echo -e "\n${C_RED}[ABORTED] Phase 7b did not complete successfully.${C_RESET}"
    exit 1
}

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------
SOURCE_SKILLS_DIR="${REPO_ROOT}/claude-skills"
SOURCE_SCRIPTS_DIR="${REPO_ROOT}/claude-scripts"
DEST_SKILLS_DIR="${HOME}/.claude/skills"
DEST_SCRIPTS_DIR="${HOME}/.claude/scripts"
CONFIG_PATH="${HOME}/.claude/config.json"

# Resolve projects root. The skills read projects_root from config.json, so
# honouring it here keeps the shortcuts directory consistent with them.
# jq would be cleaner but is not guaranteed to be present after Phase 1;
# a grep extraction keeps this script portable.
DEFAULT_ROOT="${HOME}/projects"
PROJECTS_ROOT="${DEFAULT_ROOT}"
if [ -f "${CONFIG_PATH}" ]; then
    if command -v jq >/dev/null 2>&1; then
        cfg_root=$(jq -r '.projects_root // empty' "${CONFIG_PATH}" 2>/dev/null || true)
    else
        # Fallback grep: matches "projects_root": "value" and extracts value.
        cfg_root=$(grep -oE '"projects_root"[[:space:]]*:[[:space:]]*"[^"]+"' "${CONFIG_PATH}" \
                   | sed -E 's/.*"projects_root"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
                   | head -n1 || true)
    fi
    if [ -n "${cfg_root:-}" ]; then
        # JSON escapes backslashes as \\; collapse them back to single \ so
        # Windows-style paths written by PowerShell survive the round-trip.
        PROJECTS_ROOT="${cfg_root//\\\\/\\}"
    else
        log_warn "~/.claude/config.json exists but projects_root is unset. Falling back to ${DEFAULT_ROOT}."
    fi
else
    log_warn "~/.claude/config.json not found - run Phase 4 first. Falling back to ${DEFAULT_ROOT}."
fi
SHORTCUTS_DIR="${PROJECTS_ROOT}/shortcuts"

BOARD_HELPER_SRC="${SOURCE_SCRIPTS_DIR}/setup_project_board.ps1"
BOARD_HELPER_DEST="${DEST_SCRIPTS_DIR}/setup_project_board.ps1"
SHORTCUTS_SRC="${SOURCE_SCRIPTS_DIR}/regenerate_shortcuts.ps1"
SHORTCUTS_DEST="${SHORTCUTS_DIR}/regenerate.ps1"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 7b - Claude Skills and Helper Scripts"
echo      "  Repo Root      : ${REPO_ROOT}"
echo      "  Skills source  : ${SOURCE_SKILLS_DIR}"
echo      "  Skills dest    : ${DEST_SKILLS_DIR}"
echo      "  Scripts source : ${SOURCE_SCRIPTS_DIR}"
echo      "  Scripts dest   : ${DEST_SCRIPTS_DIR}"
echo      "  Shortcuts dest : ${SHORTCUTS_DIR}"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 - Verify source trees
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
log_pass "Found: $(basename "${BOARD_HELPER_SRC}")"

[ -f "${SHORTCUTS_SRC}" ]    || abort "Source helper missing: ${SHORTCUTS_SRC}"
log_pass "Found: $(basename "${SHORTCUTS_SRC}")"

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
# Step 3 - Copy every skill
# ==============================================================================
log_section "Step 3: Copy skill files"

copied_skills=0
skipped_skills=0
skill_failures=0

for skill_path in "${SKILL_DIRS[@]}"; do
    skill_name="$(basename "${skill_path}")"
    dest_skill="${DEST_SKILLS_DIR}/${skill_name}"
    skill_md_src="${skill_path}/SKILL.md"

    if [ ! -f "${skill_md_src}" ]; then
        log_warn "Skipping ${skill_name}: no SKILL.md in source dir"
        (( skipped_skills++ )) || true
        continue
    fi

    # Remove the existing destination so we do not end up with stale supporting
    # files (e.g. an old aliases.json) when a skill is renamed or slimmed down.
    rm -rf "${dest_skill}"
    if cp -R "${skill_path}" "${dest_skill}"; then
        log_pass "Copied: ${skill_name}"
        log_info "     -> ${dest_skill}"
        (( copied_skills++ )) || true
    else
        log_fail "Failed to copy skill '${skill_name}'"
        (( skill_failures++ )) || true
    fi
done

# ==============================================================================
# Step 4 - Copy helper scripts
# ==============================================================================
log_section "Step 4: Copy helper scripts"

helper_failures=0

copy_helper() {
    local src="$1" dest="$2" label="$3"
    if cp -f "${src}" "${dest}"; then
        log_pass "Copied: ${label}"
        log_info "     -> ${dest}"
    else
        log_fail "Failed to copy ${label}"
        (( helper_failures++ )) || true
    fi
}

copy_helper "${BOARD_HELPER_SRC}" "${BOARD_HELPER_DEST}" 'setup_project_board.ps1'
copy_helper "${SHORTCUTS_SRC}"    "${SHORTCUTS_DEST}"    'regenerate.ps1 (shortcuts)'

# ==============================================================================
# Step 5 - Verification pass
# ==============================================================================
log_section "Step 5: Verify deployed files"

verify_fail=0

for skill_path in "${SKILL_DIRS[@]}"; do
    skill_name="$(basename "${skill_path}")"
    expected="${DEST_SKILLS_DIR}/${skill_name}/SKILL.md"
    if [ -f "${expected}" ]; then
        log_pass "SKILL.md present: ${skill_name}"
    else
        # Source dirs without SKILL.md were intentionally skipped above.
        if [ -f "${skill_path}/SKILL.md" ]; then
            log_fail "Missing after copy: ${expected}"
            (( verify_fail++ )) || true
        fi
    fi
done

for pair in "${BOARD_HELPER_DEST}:setup_project_board.ps1" "${SHORTCUTS_DEST}:regenerate.ps1"; do
    path="${pair%%:*}"
    label="${pair##*:}"
    if [ -f "${path}" ]; then
        log_pass "${label} present at ${path}"
    else
        log_fail "Missing after copy: ${path}"
        (( verify_fail++ )) || true
    fi
done

# ==============================================================================
# Summary
# ==============================================================================
log_section "Summary"

echo -e "\n${C_CYAN}  Skills copied       : ${copied_skills} / ${#SKILL_DIRS[@]}"
echo      "  Skills skipped      : ${skipped_skills}"
echo      "  Helper scripts      : 2 (board + shortcuts)"
echo -e   "${C_RESET}"

total_fail=$(( skill_failures + helper_failures + verify_fail ))
if [ "${total_fail}" -gt 0 ]; then
    echo -e "\n${C_RED}[RESULT] Phase 7b completed with errors. Review failures above.${C_RESET}"
    exit 1
else
    echo -e "\n${C_GREEN}[RESULT] Phase 7b completed successfully. Skills and helper scripts deployed.${C_RESET}\n"
    exit 0
fi
