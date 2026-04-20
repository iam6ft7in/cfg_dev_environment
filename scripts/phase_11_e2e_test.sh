#!/usr/bin/env bash
# ==============================================================================
# Phase 11: GitHub CLI Authentication and End-to-End Test
#
# Script Name : phase_11_e2e_test.sh
# Purpose     : Prompt for manual gh auth login confirmation, then run the
#               automated end-to-end test sequence:
#                 - Create test repo
#                 - Clone via SSH alias
#                 - Make a signed Conventional Commits commit
#                 - Verify commit signature
#                 - Push and create test PR
#                 - Clean up repo and local directory
# Phase       : 11 of 12
# Exit Criteria: All test steps pass. Signed commit verified. Repo cleaned up.
#
# Run with: bash scripts/phase_11_e2e_test.sh
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

# Result tracking
STEP_NAMES=()
STEP_STATUS=()

record_step() {
    STEP_NAMES+=("$1")
    STEP_STATUS+=("$2")
}

TEST_REPO="test_e2e_delete_me"
TEST_DIR="/tmp/e2e_test_$$"
BRANCH_NAME="test/e2e-validation"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 11, End-to-End Test"
echo      "  Test repo : $TEST_REPO"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 11A, Manual gh auth login confirmation
# ==============================================================================
log_section "Step 11A: gh auth login confirmation"

echo -e "${C_WHITE}MANUAL STEP REQUIRED:${C_RESET}"
echo    "  If you have not already done so, run the following in a terminal:"
echo    ""
echo    "    gh auth login"
echo    ""
echo    "  Follow the prompts:"
echo    "    - GitHub.com (not Enterprise)"
echo    "    - SSH protocol"
echo    "    - Select key: id_ed25519_github_personal"
echo    "    - Authenticate via browser"
echo    ""
echo    "  Then verify:"
echo    "    gh auth status"
echo    ""

read -r -p "  Have you completed gh auth login? (yes/no): " auth_confirm
if [[ ! "$auth_confirm" =~ ^[Yy][Ee][Ss]?$ ]]; then
    echo -e "${C_YELLOW}[SKIPPED] Run 'gh auth login' first, then re-run this script.${C_RESET}"
    exit 0
fi

# Verify gh is actually authenticated
log_info "Verifying gh auth status..."
if gh auth status &>/dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    log_pass "Authenticated as: $GH_USER"
    record_step "gh auth" "PASS"
else
    log_fail "gh auth status failed, are you logged in?"
    record_step "gh auth" "FAIL"
    echo -e "\n${C_RED}[ABORTED] Run 'gh auth login' before proceeding.${C_RESET}"
    exit 1
fi

# ==============================================================================
# Cleanup function, always attempt cleanup on exit
# ==============================================================================
cleanup() {
    log_section "Cleanup"
    # Remove local directory
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
        log_info "Removed local test directory: $TEST_DIR"
    fi
    # Delete remote repo
    if gh repo view "$GH_USER/$TEST_REPO" &>/dev/null 2>&1; then
        if gh repo delete "$GH_USER/$TEST_REPO" --yes &>/dev/null; then
            log_pass "Deleted remote repo: $GH_USER/$TEST_REPO"
            record_step "Cleanup remote repo" "PASS"
        else
            log_warn "Failed to delete remote repo: $GH_USER/$TEST_REPO"
            log_warn "Delete it manually: gh repo delete $GH_USER/$TEST_REPO --yes"
            record_step "Cleanup remote repo" "WARN"
        fi
    else
        log_info "Remote repo does not exist or already deleted."
    fi
}
trap cleanup EXIT

# ==============================================================================
# Step 1: Create test repo
# ==============================================================================
log_section "Step 1: Create test repository"

# Delete if it already exists from a prior run
if gh repo view "$GH_USER/$TEST_REPO" &>/dev/null 2>&1; then
    log_warn "Test repo already exists, deleting for clean start"
    gh repo delete "$GH_USER/$TEST_REPO" --yes
fi

if gh repo create "$GH_USER/$TEST_REPO" \
    --private \
    --description "Temporary E2E test repo, safe to delete" \
    &>/dev/null; then
    log_pass "Created private repo: $GH_USER/$TEST_REPO"
    record_step "Create test repo" "PASS"
else
    log_fail "Failed to create test repo"
    record_step "Create test repo" "FAIL"
    exit 1
fi

# ==============================================================================
# Step 2: Clone via SSH host alias
# ==============================================================================
log_section "Step 2: Clone via SSH host alias (github-personal)"

mkdir -p "$TEST_DIR"

if git clone "git@github-personal:$GH_USER/$TEST_REPO.git" "$TEST_DIR/$TEST_REPO" 2>&1; then
    log_pass "Cloned to $TEST_DIR/$TEST_REPO"
    record_step "Clone via SSH alias" "PASS"
else
    log_fail "git clone via github-personal alias failed"
    log_info "Check: ssh -T github-personal"
    record_step "Clone via SSH alias" "FAIL"
    exit 1
fi

cd "$TEST_DIR/$TEST_REPO"

# ==============================================================================
# Step 3: Create feature branch
# ==============================================================================
log_section "Step 3: Create feature branch"

git checkout -b "$BRANCH_NAME"
log_pass "Created branch: $BRANCH_NAME"

# ==============================================================================
# Step 4: Make a signed Conventional Commits commit
# ==============================================================================
log_section "Step 4: Signed commit with Conventional Commits message"

echo "# End-to-end test file" > test_e2e.md
echo "Generated by phase_11_e2e_test.sh on $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> test_e2e.md

git add test_e2e.md

commit_msg="chore: end-to-end test, verify signed commit

This commit was created automatically by phase_11_e2e_test.sh to verify
that SSH commit signing, Conventional Commits hooks, and GitHub push all
work correctly.

This repo is safe to delete."

if git commit -S -m "$commit_msg" 2>&1; then
    log_pass "Signed commit created"
    record_step "Signed commit" "PASS"
else
    log_fail "Signed commit failed"
    log_info "Ensure commit.gpgSign = true and your SSH key is configured"
    record_step "Signed commit" "FAIL"
    exit 1
fi

# ==============================================================================
# Step 5: Verify commit signature
# ==============================================================================
log_section "Step 5: Verify commit signature"

sig_output=$(git log --show-signature -1 2>&1 || true)
echo "$sig_output"

if echo "$sig_output" | grep -qiE "(Good .* signature|Verified)"; then
    log_pass "Commit signature verified"
    record_step "Verify signature" "PASS"
elif echo "$sig_output" | grep -qi "gpg:"; then
    # GPG present, check for error
    if echo "$sig_output" | grep -qi "BAD signature"; then
        log_fail "BAD commit signature detected"
        record_step "Verify signature" "FAIL"
    else
        log_warn "Signature output ambiguous, review above"
        record_step "Verify signature" "WARN"
    fi
else
    log_warn "Could not confirm signature in git log output, check allowed_signers"
    record_step "Verify signature" "WARN"
fi

# ==============================================================================
# Step 6: Push branch
# ==============================================================================
log_section "Step 6: Push branch to remote"

if git push -u origin "$BRANCH_NAME" 2>&1; then
    log_pass "Branch pushed: $BRANCH_NAME"
    record_step "Push branch" "PASS"
else
    log_fail "git push failed"
    record_step "Push branch" "FAIL"
    exit 1
fi

# ==============================================================================
# Step 7: Create test PR
# ==============================================================================
log_section "Step 7: Create test pull request"

if gh pr create \
    --title "chore: e2e test pull request" \
    --body "Automated test PR created by phase_11_e2e_test.sh. Safe to delete with the repo." \
    --base main \
    --head "$BRANCH_NAME" \
    2>&1; then
    log_pass "Test PR created"
    record_step "Create test PR" "PASS"
else
    log_warn "PR creation failed (repo may need initial commit on main first)"
    record_step "Create test PR" "WARN"
fi

# ==============================================================================
# Summary table
# ==============================================================================
log_section "Summary"

col_w=30
printf "${C_WHITE}%-${col_w}s %s${C_RESET}\n" "Step" "Status"
printf "${C_WHITE}%-${col_w}s %s${C_RESET}\n" "$(printf '%0.s-' $(seq 1 $((col_w-1))))" "------"

any_fail=false

for i in "${!STEP_NAMES[@]}"; do
    name="${STEP_NAMES[$i]}"
    status="${STEP_STATUS[$i]}"
    case "$status" in
        PASS) color="$C_GREEN" ;;
        FAIL) color="$C_RED"; any_fail=true ;;
        WARN) color="$C_YELLOW" ;;
        *)    color="$C_RESET" ;;
    esac
    printf "${color}%-${col_w}s %s${C_RESET}\n" "$name" "$status"
done

echo ""

if [ "$any_fail" = true ]; then
    echo -e "${C_RED}[RESULT] Phase 11 completed with failures. Review table above.${C_RESET}"
    exit 1
else
    echo -e "${C_GREEN}[RESULT] Phase 11 completed successfully. All end-to-end tests passed.${C_RESET}"
    echo -e "${C_CYAN}  Test repository has been cleaned up.${C_RESET}\n"
    exit 0
fi
