#!/usr/bin/env bash
# ==============================================================================
# Phase 1: Verify and Install Prerequisites
#
# Script Name : phase_01_prerequisites.sh
# Purpose     : Check all required development tools at minimum versions.
#               winget is not available in Git Bash, prints manual install
#               instructions for any missing tool.
# Phase       : 1 of 12
# Exit Criteria: All tools report PASS in the summary table. No FAIL entries
#                remain. Git, GitHub CLI, and OpenSSH must pass for a zero
#                exit code.
#
# Run with: bash scripts/phase_01_prerequisites.sh
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(dirname "$(dirname "$0")")"

# ------------------------------------------------------------------------------
# Colour helpers (ANSI, gracefully degraded if not a terminal)
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
    C_RED='\033[0;31m';  C_WHITE='\033[1;37m'; C_RESET='\033[0m'
else
    C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_WHITE=''; C_RESET=''
fi

log_info()    { echo -e "${C_CYAN}  [INFO] $*${C_RESET}"; }
log_pass()    { echo -e "${C_GREEN}  [PASS] $*${C_RESET}"; }
log_warn()    { echo -e "${C_YELLOW}  [WARN] $*${C_RESET}"; }
log_fail()    { echo -e "${C_RED}  [FAIL] $*${C_RESET}"; }
log_section() { echo -e "\n${C_WHITE}==> $*${C_RESET}"; }

# ------------------------------------------------------------------------------
# Version comparison helper
# Returns 0 (true) if actual >= minimum
# ------------------------------------------------------------------------------
version_ge() {
    local actual="$1" minimum="$2"
    # Strip any leading 'v'
    actual="${actual#v}"
    minimum="${minimum#v}"
    # Use sort -V if available, otherwise fall back to awk
    printf '%s\n%s\n' "$minimum" "$actual" \
        | sort -V --check=quiet 2>/dev/null && return 0
    # Fallback: awk-based comparison
    awk -v a="$actual" -v m="$minimum" 'BEGIN {
        n=split(a,A,"."); split(m,M,".")
        for(i=1;i<=n||i<=3;i++){
            av=A[i]+0; mv=M[i]+0
            if(av>mv) exit 0
            if(av<mv) exit 1
        }
        exit 0
    }'
}

# Extract first version-like string from input
extract_version() {
    echo "$*" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Result tracking: parallel arrays (bash 3 compat)
TOOL_NAMES=()
TOOL_STATUS=()  # PASS | FAIL | WARN

record_result() {
    TOOL_NAMES+=("$1")
    TOOL_STATUS+=("$2")
}

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 1, Prerequisites Check"
echo      "  Repo root: $REPO_ROOT"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# 1. Git (minimum 2.42)
# ==============================================================================
log_section "Git (minimum 2.42)"

git_ok=false
if raw=$(git --version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "2.42"; then
        log_pass "Git $ver, meets minimum 2.42"
        git_ok=true
    else
        log_fail "Git $ver found but minimum is 2.42"
        log_info "Manual install: https://git-scm.com/download/win"
        log_info "  winget install --id Git.Git -e"
    fi
else
    log_fail "Git not found"
    log_info "Manual install: https://git-scm.com/download/win"
    log_info "  winget install --id Git.Git -e"
fi

record_result "Git" "$([ "$git_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 2. GitHub CLI / gh (minimum 2.40)
# ==============================================================================
log_section "GitHub CLI / gh (minimum 2.40)"

gh_ok=false
if raw=$(gh --version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "2.40"; then
        log_pass "gh $ver, meets minimum 2.40"
        gh_ok=true
    else
        log_fail "gh $ver found but minimum is 2.40"
        log_info "Manual install: https://cli.github.com/"
        log_info "  winget install --id GitHub.cli -e"
    fi
else
    log_fail "gh not found"
    log_info "Manual install: https://cli.github.com/"
    log_info "  winget install --id GitHub.cli -e"
fi

record_result "GitHub CLI (gh)" "$([ "$gh_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 3. OpenSSH Client
# ==============================================================================
log_section "OpenSSH Client"

ssh_ok=false
if ssh_path=$(command -v ssh 2>/dev/null); then
    log_pass "ssh found at $ssh_path"
    ssh_ok=true
elif [ -f "/c/Windows/System32/OpenSSH/ssh.exe" ]; then
    log_pass "ssh.exe found at /c/Windows/System32/OpenSSH/ssh.exe"
    ssh_ok=true
else
    log_fail "ssh not found on PATH"
    log_info "Manual fix: Settings -> Apps -> Optional Features -> Add a feature -> OpenSSH Client"
    log_info "Or run in PowerShell (Admin): Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
fi

record_result "OpenSSH Client" "$([ "$ssh_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 4. gitleaks (minimum 8.18)
# ==============================================================================
log_section "gitleaks (minimum 8.18)"

gitleaks_ok=false
if raw=$(gitleaks version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "8.18"; then
        log_pass "gitleaks $ver, meets minimum 8.18"
        gitleaks_ok=true
    else
        log_fail "gitleaks $ver found but minimum is 8.18"
        log_info "Manual install: https://github.com/gitleaks/gitleaks/releases"
        log_info "  winget install --id Zricethezav.gitleaks -e"
    fi
else
    log_fail "gitleaks not found"
    log_info "Manual install options:"
    log_info "  1. winget install --id Zricethezav.gitleaks -e"
    log_info "  2. Download Windows x64 zip from https://github.com/gitleaks/gitleaks/releases"
    log_info "     Extract gitleaks.exe and add it to your PATH"
fi

record_result "gitleaks" "$([ "$gitleaks_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 5. NASM (minimum 2.16)
# ==============================================================================
log_section "NASM (minimum 2.16)"

nasm_ok=false
if raw=$(nasm --version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "2.16"; then
        log_pass "NASM $ver, meets minimum 2.16"
        nasm_ok=true
    else
        log_fail "NASM $ver found but minimum is 2.16"
        log_info "Manual install: https://nasm.us/pub/nasm/releasebuilds/"
        log_info "  winget install --id NASM.NASM -e"
    fi
else
    log_fail "NASM not found"
    log_info "Manual install: https://nasm.us/pub/nasm/releasebuilds/"
    log_info "  winget install --id NASM.NASM -e"
fi

record_result "NASM" "$([ "$nasm_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 6. uv, Python environment manager (minimum 0.4)
# ==============================================================================
log_section "uv, Python environment manager (minimum 0.4)"

uv_ok=false
if raw=$(uv --version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "0.4"; then
        log_pass "uv $ver, meets minimum 0.4"
        uv_ok=true
    else
        log_fail "uv $ver found but minimum is 0.4"
        log_info "Manual install: https://docs.astral.sh/uv/getting-started/installation/"
        log_info "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
else
    log_fail "uv not found"
    log_info "Manual install:"
    log_info "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    log_info "  Or: https://docs.astral.sh/uv/getting-started/installation/"
fi

record_result "uv" "$([ "$uv_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 7. ruff, Python linter/formatter (minimum 0.3)
# ==============================================================================
log_section "ruff, Python linter/formatter (minimum 0.3)"

ruff_ok=false
if raw=$(ruff --version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "0.3"; then
        log_pass "ruff $ver, meets minimum 0.3"
        ruff_ok=true
    else
        log_fail "ruff $ver found but minimum is 0.3"
        log_info "Upgrade: uv tool install ruff"
    fi
else
    log_fail "ruff not found"
    if [ "$uv_ok" = true ]; then
        log_info "Installing ruff via uv..."
        if uv tool install ruff 2>&1; then
            # Refresh PATH for uv tools
            export PATH="$HOME/.local/bin:$PATH"
            if raw=$(ruff --version 2>&1); then
                ver=$(extract_version "$raw")
                if [ -n "$ver" ] && version_ge "$ver" "0.3"; then
                    log_pass "ruff $ver installed successfully via uv"
                    ruff_ok=true
                fi
            fi
        fi
        if [ "$ruff_ok" = false ]; then
            log_fail "ruff install via uv failed or ruff still not on PATH"
            log_info "Manual: uv tool install ruff  (then restart your shell)"
        fi
    else
        log_fail "uv is not available, cannot install ruff automatically"
        log_info "Manual: install uv first, then run: uv tool install ruff"
    fi
fi

record_result "ruff" "$([ "$ruff_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 8. delta, git diff pager (minimum 0.17)
# ==============================================================================
log_section "delta, git diff pager (minimum 0.17)"

delta_ok=false
if raw=$(delta --version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "0.17"; then
        log_pass "delta $ver, meets minimum 0.17"
        delta_ok=true
    else
        log_fail "delta $ver found but minimum is 0.17"
        log_info "Manual install: https://github.com/dandavison/delta/releases"
        log_info "  winget install --id dandavison.delta -e"
    fi
else
    log_fail "delta not found"
    log_info "Manual install: https://github.com/dandavison/delta/releases"
    log_info "  winget install --id dandavison.delta -e"
fi

record_result "delta" "$([ "$delta_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# 9. Oh My Posh (minimum 23)
# ==============================================================================
log_section "Oh My Posh, terminal prompt engine (minimum version 23)"

omp_ok=false
if raw=$(oh-my-posh --version 2>&1); then
    ver=$(extract_version "$raw")
    if [ -n "$ver" ] && version_ge "$ver" "23.0"; then
        log_pass "Oh My Posh $ver, meets minimum 23"
        omp_ok=true
    else
        log_fail "Oh My Posh $ver found but minimum is 23"
        log_info "Manual install: https://ohmyposh.dev/docs/installation/windows"
        log_info "  winget install --id JanDeDobbeleer.OhMyPosh -e"
    fi
else
    log_fail "oh-my-posh not found"
    log_info "Manual install: https://ohmyposh.dev/docs/installation/windows"
    log_info "  winget install --id JanDeDobbeleer.OhMyPosh -e"
fi

record_result "Oh My Posh" "$([ "$omp_ok" = true ] && echo PASS || echo FAIL)"

# ==============================================================================
# Summary table
# ==============================================================================
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 1, Summary"
echo -e   "========================================${C_RESET}\n"

col_w=30
printf "${C_WHITE}%-${col_w}s %s${C_RESET}\n" "Tool" "Status"
printf "${C_WHITE}%-${col_w}s %s${C_RESET}\n" "$(printf '%0.s-' $(seq 1 $((col_w-1))))" "------"

any_fail=false
critical_fail=false
critical_tools=("Git" "GitHub CLI (gh)" "OpenSSH Client")

for i in "${!TOOL_NAMES[@]}"; do
    name="${TOOL_NAMES[$i]}"
    status="${TOOL_STATUS[$i]}"
    case "$status" in
        PASS) color="$C_GREEN" ;;
        FAIL) color="$C_RED"   ;;
        WARN) color="$C_YELLOW";;
        *)    color="$C_RESET" ;;
    esac
    printf "${color}%-${col_w}s %s${C_RESET}\n" "$name" "$status"
    if [ "$status" = "FAIL" ]; then
        any_fail=true
        for ct in "${critical_tools[@]}"; do
            if [ "$ct" = "$name" ]; then
                critical_fail=true
                break
            fi
        done
    fi
done

echo ""

if [ "$critical_fail" = true ]; then
    log_fail "One or more CRITICAL tools (Git, GitHub CLI, OpenSSH) failed. Fix them before proceeding to Phase 2."
    exit 1
elif [ "$any_fail" = true ]; then
    log_warn "Some non-critical tools failed. Review the table above and install them manually if needed."
    log_warn "You may proceed to Phase 2, but functionality will be limited."
    exit 0
else
    log_pass "All tools passed. You are ready to proceed to Phase 2."
    exit 0
fi
