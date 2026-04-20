#!/usr/bin/env bash
# ==============================================================================
# Phase 6: Secret Scanning and Git Hooks
#
# Script Name : phase_06_hooks_and_scanning.sh
# Purpose     : Write pre-commit (gitleaks) and commit-msg (Conventional
#               Commits) hooks to ~/.git-templates/hooks/. Copy gitleaks.toml.
#               Set init.templateDir in git config.
#               NOTE: Windows Task Scheduler is not available in Git Bash.
#               Manual instructions are printed instead.
# Phase       : 6 of 12
# Exit Criteria: Both hook files exist and are executable. init.templateDir set.
#
# Run with: bash scripts/phase_06_hooks_and_scanning.sh
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
    echo -e "\n${C_RED}[ABORTED] Phase 6 did not complete successfully.${C_RESET}"
    exit 1
}

HOOKS_DIR="$HOME/.git-templates/hooks"
PRE_COMMIT="$HOOKS_DIR/pre-commit"
COMMIT_MSG="$HOOKS_DIR/commit-msg"
GITLEAKS_TOML="$HOME/.gitleaks.toml"
REPO_GITLEAKS_TOML="$REPO_ROOT/config/gitleaks.toml"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 6, Hooks and Secret Scanning"
echo      "  Hooks dir : $HOOKS_DIR"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1: Create hooks directory
# ==============================================================================
log_section "Step 1: Create hooks directory"

mkdir -p "$HOOKS_DIR"
log_pass "Directory exists: $HOOKS_DIR"

# ==============================================================================
# Step 2: Write pre-commit hook (gitleaks staged-file scan)
# ==============================================================================
log_section "Step 2: Write pre-commit hook (gitleaks)"

cat > "$PRE_COMMIT" <<'HOOK'
#!/usr/bin/env bash
# pre-commit: scan staged files for secrets using gitleaks
# Installed by phase_06_hooks_and_scanning.sh

set -euo pipefail

# Locate gitleaks
if ! command -v gitleaks &>/dev/null; then
    echo "[WARN] gitleaks not found on PATH, skipping secret scan."
    echo "       Install gitleaks to enable pre-commit secret scanning."
    exit 0
fi

# Determine toml config location
TOML_PATH="$HOME/.gitleaks.toml"
if [ -f ".gitleaks.toml" ]; then
    TOML_PATH=".gitleaks.toml"
fi

GITLEAKS_ARGS=(protect --staged --verbose)
if [ -f "$TOML_PATH" ]; then
    GITLEAKS_ARGS+=(--config "$TOML_PATH")
fi

echo "[pre-commit] Running gitleaks staged-file scan..."

if gitleaks "${GITLEAKS_ARGS[@]}"; then
    echo "[pre-commit] gitleaks: no secrets detected."
    exit 0
else
    echo ""
    echo "[pre-commit] gitleaks detected potential secrets in staged files."
    echo "             Review the findings above before committing."
    echo "             To skip this check (use with caution):"
    echo "               git commit --no-verify"
    exit 1
fi
HOOK

chmod +x "$PRE_COMMIT"
log_pass "pre-commit hook written and made executable: $PRE_COMMIT"

# ==============================================================================
# Step 3: Write commit-msg hook (Conventional Commits validation)
# ==============================================================================
log_section "Step 3: Write commit-msg hook (Conventional Commits)"

cat > "$COMMIT_MSG" <<'HOOK'
#!/usr/bin/env bash
# commit-msg: enforce Conventional Commits format
# Installed by phase_06_hooks_and_scanning.sh
#
# Valid format: <type>(<optional scope>): <summary>
# Types: feat fix docs style refactor perf test build ci chore revert

set -euo pipefail

MSG_FILE="$1"
MSG=$(cat "$MSG_FILE")

# Skip merge commits and fixup commits
if echo "$MSG" | grep -qE '^(Merge|Revert|fixup!|squash!)'; then
    exit 0
fi

# Skip empty messages (will be caught by git itself)
if [ -z "$(echo "$MSG" | sed '/^#/d' | tr -d '[:space:]')" ]; then
    exit 0
fi

# Allowed types
TYPES="feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"

# Pattern: type(scope)!: summary  OR  type!: summary  OR  type(scope): summary  OR  type: summary
PATTERN="^($TYPES)(\([a-zA-Z0-9_,. -]+\))?(!)?: .+"

first_line=$(echo "$MSG" | head -1)

if echo "$first_line" | grep -qE "$PATTERN"; then
    exit 0
else
    echo ""
    echo "  [FAIL] Commit message does not follow Conventional Commits format."
    echo ""
    echo "  Required format:"
    echo "    <type>(<scope>): <summary>"
    echo ""
    echo "  Valid types: feat fix docs style refactor perf test build ci chore revert"
    echo ""
    echo "  Examples:"
    echo "    feat(auth): add OAuth2 support"
    echo "    fix: correct off-by-one error in loop"
    echo "    chore: update dependencies"
    echo "    feat!: remove deprecated API (! = breaking change)"
    echo ""
    echo "  Your message:"
    echo "    $first_line"
    echo ""
    exit 1
fi
HOOK

chmod +x "$COMMIT_MSG"
log_pass "commit-msg hook written and made executable: $COMMIT_MSG"

# ==============================================================================
# Step 4: Write ~/.gitleaks.toml
# ==============================================================================
log_section "Step 4: Write ~/.gitleaks.toml"

# If the repo has a gitleaks.toml, copy it; otherwise write a default
if [ -f "$REPO_GITLEAKS_TOML" ]; then
    cp "$REPO_GITLEAKS_TOML" "$GITLEAKS_TOML"
    log_pass "Copied $REPO_GITLEAKS_TOML -> $GITLEAKS_TOML"
else
    log_info "No config/gitleaks.toml in repo, writing default ~/.gitleaks.toml"
    cat > "$GITLEAKS_TOML" <<'EOF'
# gitleaks configuration
# Managed by: phase_06_hooks_and_scanning.sh
# Reference : https://github.com/gitleaks/gitleaks

title = "Custom gitleaks config"

[extend]
useDefault = true

# ---------------------------------------------------------------------------
# Custom rules, ArduPilot / Arduino
# ---------------------------------------------------------------------------

[[rules]]
id          = "ardupilot-param-key"
description = "ArduPilot parameter key that looks like a secret"
regex       = '''(?i)PARAM_KEY\s*=\s*["'][A-Za-z0-9+/]{20,}["']'''
tags        = ["ardupilot", "key"]

# ---------------------------------------------------------------------------
# Allowlists, files that are permitted to contain patterns above
# ---------------------------------------------------------------------------

[allowlist]
description = "Global allowlist"
paths = [
    # Test fixtures
    '''tests?[/\\]fixtures?[/\\]''',
    # Documentation examples
    '''docs?[/\\]''',
    # This config file itself
    '''.gitleaks\.toml$''',
    # Windows environment variable example files
    '''.env\.example$''',
    '''.env\.template$''',
]
EOF
    log_pass "~/.gitleaks.toml written (default)"
fi

# ==============================================================================
# Step 5: Set init.templateDir
# ==============================================================================
log_section "Step 5: Set git init.templateDir"

git config --global init.templateDir "$HOME/.git-templates"
registered=$(git config --global init.templateDir 2>/dev/null || true)
log_pass "init.templateDir = $registered"

# ==============================================================================
# Step 6: Task Scheduler (manual instructions)
# ==============================================================================
log_section "Step 6: Weekly gitleaks scan, Task Scheduler (manual)"

echo -e "${C_YELLOW}  Windows Task Scheduler is not available from Git Bash.${C_RESET}"
echo    "  To set up a weekly full-repo scan (Sundays at 02:00 AM),"
echo    "  run the following in PowerShell 7+ (no admin required):"
echo ""
echo    '  $action  = New-ScheduledTaskAction -Execute "gitleaks.exe" \'
echo    '             -Argument "detect --source \"$HOME\projects\" --verbose" \'
echo    '             -WorkingDirectory "$HOME"'
echo    '  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am'
echo    '  $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable:$false'
echo    '  Register-ScheduledTask -TaskName "gitleaks-weekly-scan" \'
echo    '      -Action $action -Trigger $trigger -Settings $settings \'
echo    '      -Description "Weekly gitleaks secret scan" -Force'
echo ""
log_warn "Task Scheduler setup requires PowerShell, complete manually if needed."

# ==============================================================================
# Verify
# ==============================================================================
log_section "Verification"

verify_fail=0

for f in "$PRE_COMMIT" "$COMMIT_MSG"; do
    if [ -x "$f" ]; then
        log_pass "Executable: $f"
    else
        log_fail "Not executable or missing: $f"
        (( verify_fail++ )) || true
    fi
done

if [ -f "$GITLEAKS_TOML" ]; then
    log_pass "~/.gitleaks.toml exists"
else
    log_fail "~/.gitleaks.toml missing"
    (( verify_fail++ )) || true
fi

td=$(git config --global init.templateDir 2>/dev/null || true)
if [ -n "$td" ]; then
    log_pass "init.templateDir = $td"
else
    log_fail "init.templateDir not set"
    (( verify_fail++ )) || true
fi

# ==============================================================================
# Summary
# ==============================================================================
if [ "$verify_fail" -gt 0 ]; then
    echo -e "\n${C_RED}[RESULT] Phase 6 completed with $verify_fail error(s). Review above.${C_RESET}"
    exit 1
else
    echo -e "\n${C_GREEN}[RESULT] Phase 6 completed successfully.${C_RESET}"
    echo -e "${C_CYAN}  Test the hooks by running in any git repo:${C_RESET}"
    echo    "    git commit --allow-empty -m 'bad message'  # should be rejected"
    echo -e "    git commit --allow-empty -m 'chore: test hook'  # should pass\n"
    exit 0
fi
