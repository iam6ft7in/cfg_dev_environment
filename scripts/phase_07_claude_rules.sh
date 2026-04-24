#!/usr/bin/env bash
# ==============================================================================
# Phase 7 - Deploy Claude Rules and Stacks (diff-before-copy)
#
# Script Name : phase_07_claude_rules.sh
# Purpose     : Deploy Claude rule and stack files from the repo to the
#               per-user Claude config directory, preserving any local
#               personalizations the user has made to the deployed copies.
#
# Two categories are deployed, in order:
#   - rules  : REPO_ROOT/claude-rules/   -> ~/.claude/rules/
#              Auto-loaded by Claude Code for universal rules or via
#              extension triggers.
#   - stacks : REPO_ROOT/claude-stacks/  -> ~/.claude/stacks/
#              Opt-in. Do NOT auto-load. Repos @-import them from
#              CLAUDE.md when needed.
#
# For each expected file in each category:
#   - If the deployed copy does not exist: create it (no drift risk).
#   - If the deployed copy is byte-identical to the repo source: no-op,
#     report IN-SYNC.
#   - If the deployed copy differs: show a unified diff and prompt the user
#     per file: [o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit.
#     Skipping preserves the deployed personalization.
#
# Non-TTY runs (piped stdin, CI, scheduled tasks) skip every drifted file
# and warn on stderr. Re-run with --force to override and overwrite every
# drifted file without prompting. An "All" / "None" choice applies to the
# remainder of the current category and carries over into the next.
#
# Phase       : 7 of 12
# Exit Criteria:
#   - Every expected rule and stack file resolves to IN-SYNC, CREATED,
#     OVERWRITE, SKIP (user), or SKIP (non-TTY).
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
            sed -n '3,36p' "$0" | sed 's/^# \{0,1\}//'
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
# Categories and expected files
# ------------------------------------------------------------------------------
# Bash 3 lacks arrays-of-arrays, so each category is encoded as three
# parallel indexed arrays. Adding a category means one entry in each of
# CAT_NAMES / CAT_SOURCES / CAT_DESTS and one entry in FILES_FOR_<name>
# below. RESULTS is keyed by "category:filename" to keep categories
# separate in the summary.
CAT_NAMES=(
    "rules"
    "stacks"
)
CAT_SOURCES=(
    "${REPO_ROOT}/claude-rules"
    "${REPO_ROOT}/claude-stacks"
)
CAT_DESTS=(
    "${HOME}/.claude/rules"
    "${HOME}/.claude/stacks"
)

FILES_FOR_rules=(
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
FILES_FOR_stacks=(
    "vmware.md"
)

# Associative arrays need bash 4+. The script already requires bash (shebang),
# and every Windows dev env covered here has Git Bash's bash 4.x or higher.
declare -A RESULTS
# Ordered list of result keys ("cat:fname") in deployment order, for a
# deterministic summary.
RESULT_ORDER=()

# Resolve the expected-files array for a category by name. Bash has no
# clean way to pass an array by name across boundaries; an indirect
# expansion is the least-bad option.
files_for_category() {
    local cat="$1"
    local varname="FILES_FOR_${cat}[@]"
    printf '%s\n' "${!varname}"
}

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
mode_label="Prompt on drift"
if [ "${FORCE}" -eq 1 ]; then
    mode_label="Force (overwrite all)"
fi

echo -e "\n${C_CYAN}=============================================="
echo      "  Phase 7 - Deploy Claude Rules and Stacks"
echo      "  Repo Root : ${REPO_ROOT}"
for i in "${!CAT_NAMES[@]}"; do
    printf "  %-8s : %s -> %s\n" "${CAT_NAMES[$i]}" "${CAT_SOURCES[$i]}" "${CAT_DESTS[$i]}"
done
echo      "  Mode      : ${mode_label}"
echo -e   "==============================================${C_RESET}\n"

# ==============================================================================
# Step 1 - Verify source directories and expected files
# ==============================================================================
log_section "Step 1: Verify source directories"

for i in "${!CAT_NAMES[@]}"; do
    cat_name="${CAT_NAMES[$i]}"
    src_dir="${CAT_SOURCES[$i]}"

    [ -d "${src_dir}" ] || abort "Source directory for '${cat_name}' not found: ${src_dir}"
    log_pass "Source directory exists (${cat_name}): ${src_dir}"

    missing=()
    while IFS= read -r fname; do
        if [ -f "${src_dir}/${fname}" ]; then
            log_pass "Found (${cat_name}): ${fname}"
        else
            log_fail "Missing (${cat_name}): ${fname}"
            missing+=("${fname}")
        fi
    done < <(files_for_category "${cat_name}")

    if [ "${#missing[@]}" -gt 0 ]; then
        abort "Missing expected files in source (${cat_name}): ${missing[*]}"
    fi
done

# ==============================================================================
# Step 2 - Create destination directories
# ==============================================================================
log_section "Step 2: Create destination directories"

for i in "${!CAT_NAMES[@]}"; do
    dest_dir="${CAT_DESTS[$i]}"
    if [ -d "${dest_dir}" ]; then
        log_info "Exists: ${dest_dir}"
    else
        mkdir -p "${dest_dir}" || abort "Failed to create destination directory: ${dest_dir}"
        log_pass "Created: ${dest_dir}"
    fi
done

# ==============================================================================
# Step 3 - Per-file deploy decision
# ==============================================================================
log_section "Step 3: Deploy files (diff-before-copy)"

# Short-circuit flags flip once the user picks an "All" or "None" option.
# They persist across categories: if the user picks "All" during rules,
# stacks inherits that, which matches the user's evident intent.
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
    # sha256sum prepends '\' to the hash when the filename contains
    # backslashes or newlines (escaped-name form). Strip any leading
    # backslash so the compared hashes match regardless of path style.
    # Paths under ~/.claude/... never contain backslashes, but keep the
    # guard for parity with phase_07b.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{h=$1; sub(/^\\/, "", h); print h}'
    else
        shasum -a 256 "$1" | awk '{h=$1; sub(/^\\/, "", h); print h}'
    fi
}

# Show a unified diff for the two files. diff -u exits 1 on difference,
# 0 on identical; we only call it when we already know they differ, so the
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

for i in "${!CAT_NAMES[@]}"; do
    cat_name="${CAT_NAMES[$i]}"
    src_dir="${CAT_SOURCES[$i]}"
    dest_dir="${CAT_DESTS[$i]}"

    echo ""
    echo -e "${C_WHITE}-- Category: ${cat_name}${C_RESET}"

    while IFS= read -r fname; do
        key="${cat_name}:${fname}"
        RESULT_ORDER+=("${key}")
        src="${src_dir}/${fname}"
        dest="${dest_dir}/${fname}"

        if [ "${aborted}" -eq 1 ]; then
            RESULTS["${key}"]="SKIP (quit)"
            continue
        fi

        if [ ! -f "${dest}" ]; then
            cp -f "${src}" "${dest}"
            log_pass "CREATED: ${cat_name}/${fname}"
            RESULTS["${key}"]="CREATED"
            continue
        fi

        src_hash=$(file_hash "${src}")
        dest_hash=$(file_hash "${dest}")

        if [ "${src_hash}" = "${dest_hash}" ]; then
            log_info "IN-SYNC: ${cat_name}/${fname}"
            RESULTS["${key}"]="IN-SYNC"
            continue
        fi

        if [ "${auto_overwrite}" -eq 1 ]; then
            cp -f "${src}" "${dest}"
            log_pass "OVERWRITE: ${cat_name}/${fname} (forced)"
            RESULTS["${key}"]="OVERWRITE"
            continue
        fi

        if [ "${auto_skip}" -eq 1 ]; then
            log_info "SKIP: ${cat_name}/${fname} (batch-skip)"
            RESULTS["${key}"]="SKIP"
            continue
        fi

        if [ "${is_tty}" -eq 0 ]; then
            log_warn "SKIP: ${cat_name}/${fname} (drift detected, stdin is not a TTY; re-run with --force to overwrite)"
            RESULTS["${key}"]="SKIP (non-TTY)"
            continue
        fi

        echo ""
        echo -e "${C_YELLOW}DRIFT: ${cat_name}/${fname}${C_RESET}"
        show_rule_diff "${src}" "${dest}"
        action=$(read_file_action)

        case "${action}" in
            overwrite)
                cp -f "${src}" "${dest}"
                log_pass "OVERWRITE: ${cat_name}/${fname}"
                RESULTS["${key}"]="OVERWRITE"
                ;;
            skip)
                log_info "SKIP: ${cat_name}/${fname}"
                RESULTS["${key}"]="SKIP"
                ;;
            all-overwrite)
                cp -f "${src}" "${dest}"
                log_pass "OVERWRITE: ${cat_name}/${fname} (All)"
                RESULTS["${key}"]="OVERWRITE"
                auto_overwrite=1
                ;;
            all-skip)
                log_info "SKIP: ${cat_name}/${fname} (None)"
                RESULTS["${key}"]="SKIP"
                auto_skip=1
                ;;
            quit)
                log_warn "QUIT: ${cat_name}/${fname} (user aborted; remaining files will be marked skipped)"
                RESULTS["${key}"]="SKIP (quit)"
                aborted=1
                ;;
        esac
    done < <(files_for_category "${cat_name}")
done

# ==============================================================================
# Summary
# ==============================================================================
log_section "Summary"

in_sync=0; created=0; overwritten=0; skipped=0

echo ""
echo -e "${C_WHITE}  Per-file status:${C_RESET}"
for key in "${RESULT_ORDER[@]}"; do
    status="${RESULTS[${key}]:-UNKNOWN}"
    case "${status}" in
        IN-SYNC)         color="${C_CYAN}";   (( in_sync++ ))     || true ;;
        CREATED)         color="${C_GREEN}";  (( created++ ))     || true ;;
        OVERWRITE)       color="${C_GREEN}";  (( overwritten++ )) || true ;;
        SKIP*)           color="${C_YELLOW}"; (( skipped++ ))     || true ;;
        *)               color="${C_WHITE}" ;;
    esac
    printf "    ${color}%-28s %s${C_RESET}\n" "${key}" "${status}"
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
