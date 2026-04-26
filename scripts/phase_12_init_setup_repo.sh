#!/usr/bin/env bash
# ==============================================================================
# Phase 12: Initialize cfg_dev_environment as First Gold Standard Repo
#
# Script Name : phase_12_init_setup_repo.sh
# Purpose     : Prompt for license, get gh username, create GitHub repo,
#               copy files, git init, set remote, make signed commit, push,
#               apply branch protection and topics.
# Phase       : 12 of 12
# Exit Criteria: Repo live on GitHub, first commit shows Verified badge,
#                branch protection active, repo is private.
#
# Run with: bash scripts/phase_12_init_setup_repo.sh
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
    echo -e "\n${C_RED}[ABORTED] Phase 12 did not complete successfully.${C_RESET}"
    exit 1
}

REPO_NAME="personal_cfg_dev_environment"

# Resolve install location from ~/.claude/config.json (Phase 3).
CLAUDE_CONFIG="${HOME}/.claude/config.json"
if [ ! -f "${CLAUDE_CONFIG}" ]; then
    log_fail "~/.claude/config.json not found. Run Phase 3 first."
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
if [ -z "${PROJECTS_ROOT}" ] || [ -z "${GITHUB_USERNAME}" ]; then
    log_fail "projects_root or github_username missing from ${CLAUDE_CONFIG}. Re-run Phase 3."
    exit 1
fi
# Normalize to forward slashes for shell use.
PROJECTS_ROOT="${PROJECTS_ROOT//\\//}"
LOCAL_DIR="${PROJECTS_ROOT}/${GITHUB_USERNAME}/public/cfg_dev_environment"
SCAFFOLD_SRC="$HOME/.claude/templates/project"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 12, Initialize cfg_dev_environment Repo"
echo      "  Repo name  : $REPO_NAME"
echo      "  Local dir  : $LOCAL_DIR"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1: Prompt for license
# ==============================================================================
log_section "Step 1: Choose a license"

echo -e "${C_WHITE}Choose a license for the cfg_dev_environment repository:${C_RESET}"
echo    "  1) MIT"
echo    "  2) Apache-2.0"
echo    "  3) GPL-3.0"
echo    "  4) None (proprietary / all rights reserved)"
echo    ""

license_choice=""
while true; do
    read -r -p "  Enter your choice (1/2/3/4): " choice
    case "$choice" in
        1) license_choice="mit";       license_display="MIT";                   break ;;
        2) license_choice="apache-2.0"; license_display="Apache-2.0";          break ;;
        3) license_choice="gpl-3.0";   license_display="GPL-3.0";              break ;;
        4) license_choice="none";      license_display="None (proprietary)";   break ;;
        *) echo "  Please enter 1, 2, 3, or 4." ;;
    esac
done

log_pass "License selected: $license_display"

# ==============================================================================
# Step 2: Get GitHub username
# ==============================================================================
log_section "Step 2: Get GitHub username"

if ! gh auth status &>/dev/null; then
    abort "Not authenticated with gh. Run 'gh auth login' first."
fi

GH_USER=$(gh api user --jq '.login' 2>/dev/null) || abort "Failed to get GitHub username from gh api"
log_pass "GitHub user: $GH_USER"

# ==============================================================================
# Step 3: Create GitHub repository
# ==============================================================================
log_section "Step 3: Create GitHub repository"

if gh repo view "$GH_USER/$REPO_NAME" &>/dev/null 2>&1; then
    log_warn "Repository $GH_USER/$REPO_NAME already exists on GitHub."
    read -r -p "  Continue with existing repo? (yes/no): " use_existing
    if [[ ! "$use_existing" =~ ^[Yy][Ee][Ss]?$ ]]; then
        abort "Aborting to avoid overwriting existing repository."
    fi
    log_info "Using existing remote repository."
else
    GH_CREATE_ARGS=(
        repo create "$GH_USER/$REPO_NAME"
        --private
        --description "Gold-standard GitHub environment setup scripts and configuration templates"
    )

    if [ "$license_choice" != "none" ]; then
        GH_CREATE_ARGS+=(--license "$license_choice")
    fi

    if gh "${GH_CREATE_ARGS[@]}" &>/dev/null; then
        log_pass "Created GitHub repo: $GH_USER/$REPO_NAME"
    else
        abort "Failed to create GitHub repository."
    fi
fi

# ==============================================================================
# Step 4: Create local directory and copy files
# ==============================================================================
log_section "Step 4: Create local directory"

if [ -d "$LOCAL_DIR" ]; then
    log_warn "Local directory already exists: $LOCAL_DIR"
    if [ -d "$LOCAL_DIR/.git" ]; then
        log_warn "Already a git repo, skipping copy and init steps."
        SKIP_INIT=true
    else
        SKIP_INIT=false
    fi
else
    mkdir -p "$LOCAL_DIR"
    log_pass "Created: $LOCAL_DIR"
    SKIP_INIT=false
fi

if [ "$SKIP_INIT" = false ]; then
    # Copy scaffold template files if they exist
    if [ -d "$SCAFFOLD_SRC" ] && [ "$(find "$SCAFFOLD_SRC" -type f | wc -l)" -gt 0 ]; then
        log_info "Copying scaffold templates from $SCAFFOLD_SRC"
        cp -r "$SCAFFOLD_SRC/." "$LOCAL_DIR/"
        tmpl_count=$(find "$LOCAL_DIR" -type f | wc -l)
        log_pass "Copied scaffold templates ($tmpl_count files)"
    else
        log_warn "Scaffold template directory is empty or missing: $SCAFFOLD_SRC"
        log_info "Run phase 08 first, or the repo will start with minimal files."
    fi

    # Copy all setup scripts from the repo root
    log_info "Copying setup scripts from $REPO_ROOT/scripts/"
    mkdir -p "$LOCAL_DIR/scripts"
    if [ -d "$REPO_ROOT/scripts" ]; then
        cp "$REPO_ROOT/scripts/"*.ps1 "$LOCAL_DIR/scripts/" 2>/dev/null || true
        cp "$REPO_ROOT/scripts/"*.sh  "$LOCAL_DIR/scripts/" 2>/dev/null || true
        script_count=$(find "$LOCAL_DIR/scripts" -type f | wc -l)
        log_pass "Copied $script_count script file(s) to $LOCAL_DIR/scripts/"
    fi

    # Copy config directory
    if [ -d "$REPO_ROOT/config" ]; then
        log_info "Copying config/ directory"
        cp -r "$REPO_ROOT/config" "$LOCAL_DIR/"
        log_pass "Copied config/"
    fi

    # Copy claude-rules
    if [ -d "$REPO_ROOT/claude-rules" ]; then
        log_info "Copying claude-rules/ directory"
        cp -r "$REPO_ROOT/claude-rules" "$LOCAL_DIR/"
        log_pass "Copied claude-rules/"
    fi

    # Copy claude-stacks (opt-in rule files @-imported per repo)
    if [ -d "$REPO_ROOT/claude-stacks" ]; then
        log_info "Copying claude-stacks/ directory"
        cp -r "$REPO_ROOT/claude-stacks" "$LOCAL_DIR/"
        log_pass "Copied claude-stacks/"
    fi

    # Copy templates
    if [ -d "$REPO_ROOT/templates" ]; then
        log_info "Copying templates/ directory"
        cp -r "$REPO_ROOT/templates" "$LOCAL_DIR/"
        log_pass "Copied templates/"
    fi

    # Copy implementation docs
    for doc in IMPLEMENTATION_STEPS.md IMPLEMENTATION_STEPS.txt; do
        if [ -f "$REPO_ROOT/$doc" ]; then
            cp "$REPO_ROOT/$doc" "$LOCAL_DIR/"
            log_pass "Copied $doc"
        fi
    done
fi

# ==============================================================================
# Step 5: Git init and remote setup
# ==============================================================================
log_section "Step 5: Git init and remote setup"

cd "$LOCAL_DIR"

if [ ! -d ".git" ]; then
    git init -b main
    log_pass "git init (branch: main)"
else
    log_info "Git repo already initialised"
fi

# Set or update remote
if git remote get-url origin &>/dev/null 2>&1; then
    log_warn "Remote 'origin' already set: $(git remote get-url origin)"
else
    git remote add origin "git@github-personal:$GH_USER/$REPO_NAME.git"
    log_pass "Remote origin set: git@github-personal:$GH_USER/$REPO_NAME.git"
fi

# ==============================================================================
# Step 6: First signed commit
# ==============================================================================
log_section "Step 6: First signed commit"

# Check if there are any commits
if git rev-parse HEAD &>/dev/null 2>&1; then
    log_warn "Repository already has commits, skipping initial commit."
else
    git add -A

    # Verify there is something to commit
    if git diff --cached --quiet; then
        log_warn "Nothing staged, creating a minimal README to commit"
        cat > README.md <<EOF
# cfg_dev_environment

Gold-standard GitHub environment setup scripts and configuration templates.

## Overview

This repository contains the scripts and templates used to configure a
professional GitHub development environment on Windows with Git Bash.

## Structure

\`\`\`
scripts/      : Phase scripts (PS7 primary, bash fallback)
config/       : Tool configuration files (gitleaks, etc.)
claude-rules/ : Auto-loaded Claude rules (universal or extension-triggered)
claude-stacks/: Opt-in Claude rules (@-imported per repo)
templates/    : Project scaffold and VS Code templates
\`\`\`

## Usage

See IMPLEMENTATION_STEPS.md for the full setup sequence.
EOF
        git add README.md
    fi

    if git commit -S -m "chore: initial project scaffold

Gold-standard GitHub environment setup. Includes phase scripts (PS7 + bash
fallback), gitleaks configuration, git hooks, Claude rules, and project
scaffold templates."; then
        log_pass "Initial signed commit created"
    else
        abort "git commit failed. Check SSH signing configuration."
    fi
fi

# ==============================================================================
# Step 7: Push to GitHub
# ==============================================================================
log_section "Step 7: Push to GitHub"

if git push -u origin main 2>&1; then
    log_pass "Pushed to origin/main"
else
    log_fail "git push failed"
    log_info "Try: git push -u origin main"
    log_info "If the remote has commits (from --license flag): git pull --rebase origin main && git push"
    abort "Push failed. Resolve conflicts manually and push."
fi

# ==============================================================================
# Step 8: Apply branch protection
# ==============================================================================
log_section "Step 8: Apply branch protection on main"

log_info "Applying branch protection rules via gh API..."

PROTECTION_JSON='{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "required_linear_history": true
}'

if gh api \
    --method PUT \
    "repos/$GH_USER/$REPO_NAME/branches/main/protection" \
    --input - <<< "$PROTECTION_JSON" &>/dev/null; then
    log_pass "Branch protection applied to main"
else
    log_warn "Branch protection API call failed (may need free-tier workaround)"
    log_info "Manual: GitHub -> Settings -> Branches -> Add protection rule for 'main'"
    log_info "Enable: Require a pull request before merging, Require conversation resolution"
fi

# ==============================================================================
# Step 9: Apply repository topics
# ==============================================================================
log_section "Step 9: Apply repository topics"

TOPICS_JSON='{"names":["github-setup","developer-environment","windows","git-bash","powershell","devtools","scaffold"]}'

if gh api \
    --method PUT \
    "repos/$GH_USER/$REPO_NAME/topics" \
    --input - <<< "$TOPICS_JSON" &>/dev/null; then
    log_pass "Repository topics applied"
else
    log_warn "Failed to apply topics, apply manually on GitHub if desired"
fi

# ==============================================================================
# Summary
# ==============================================================================
log_section "Summary"

REPO_URL="https://github.com/$GH_USER/$REPO_NAME"

echo -e "\n${C_GREEN}[RESULT] Phase 12 completed successfully.${C_RESET}"
echo -e "\n${C_CYAN}  Repository URL  : $REPO_URL"
echo      "  Local directory : $LOCAL_DIR"
echo -e   "${C_RESET}"
echo    "  Manual verification steps:"
echo    "    1. Open $REPO_URL"
echo    "    2. Confirm the first commit has a green 'Verified' badge"
echo    "    3. Confirm: Settings -> Branches -> Branch protection rules active"
echo    "    4. Confirm the repo is private"
echo    ""
echo -e "${C_CYAN}  Setup complete! From now on, every new project starts with: /new-repo${C_RESET}\n"
exit 0
