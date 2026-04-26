#!/usr/bin/env bash
# ==============================================================================
# Phase 3: Git Configuration Files
#
# Script Name : phase_03_git_config.sh
# Purpose     : Prompt for noreply email, then write ~/.gitconfig,
#               ~/.gitconfig-client, ~/.gitconfig-arduino, ~/.gitmessage.
# Phase       : 3 of 12
# Exit Criteria: git config --list --global shows all expected settings.
#
# Run with: bash scripts/phase_03_git_config.sh
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
    echo -e "\n${C_RED}[ABORTED] Phase 3 did not complete successfully.${C_RESET}"
    exit 1
}

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 3, Git Configuration"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1: Prompt for noreply email
# ==============================================================================
log_section "Step 1: GitHub noreply email"

echo -e "${C_WHITE}Enter your GitHub noreply email address.${C_RESET}"
echo    "  Example: 12345678+yourusername@users.noreply.github.com"
echo    "  Find it at: github.com -> Settings -> Emails"
echo    "  (Enable 'Keep my email address private' first)"
echo ""
read -r -p "  Noreply email: " NOREPLY_EMAIL

if [ -z "$NOREPLY_EMAIL" ]; then
    abort "No email entered. Exiting."
fi

# Validate format loosely
if ! echo "$NOREPLY_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
    abort "Email '$NOREPLY_EMAIL' does not look valid. Exiting."
fi

log_pass "Using noreply email: $NOREPLY_EMAIL"

# ==============================================================================
# Step 1b: Prompt for git user name
# ==============================================================================
log_section "Step 1b: Git user name"

echo -e "${C_WHITE}Enter your full name as it should appear in git commits.${C_RESET}"
read -r -p "  Your name: " GIT_USER_NAME

if [ -z "${GIT_USER_NAME}" ]; then
    abort "No name entered. Exiting."
fi

log_pass "Using name: ${GIT_USER_NAME}"

# ==============================================================================
# Step 1c: Prompt for projects root and personal GitHub username
# ==============================================================================
log_section "Step 1c: Projects root and personal GitHub username"

CLAUDE_CONFIG="${HOME}/.claude/config.json"

# Read existing config (if any) to seed defaults. Use jq when available;
# otherwise a small grep/sed fallback (the values are simple JSON strings).
read_config_value() {
    local key="$1"
    [ -f "${CLAUDE_CONFIG}" ] || { echo ""; return; }
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg k "${key}" '.[$k] // empty' "${CLAUDE_CONFIG}" 2>/dev/null || true
    else
        grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "${CLAUDE_CONFIG}" \
            | sed -E "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/" \
            | head -n1
    fi
}

EXISTING_ROOT="$(read_config_value 'projects_root')"
EXISTING_USER="$(read_config_value 'github_username')"

DEFAULT_ROOT="${EXISTING_ROOT:-${HOME}/projects}"

echo -e "${C_WHITE}Where should your GitHub repos live?${C_RESET}"
echo    "  Default: ${DEFAULT_ROOT}"
read -r -p "  Projects root (Enter for default): " INPUT_ROOT
if [ -z "${INPUT_ROOT}" ]; then
    PROJECTS_ROOT="${DEFAULT_ROOT}"
else
    # Trim trailing slashes
    PROJECTS_ROOT="${INPUT_ROOT%/}"
    PROJECTS_ROOT="${PROJECTS_ROOT%\\}"
fi
log_pass "Projects root: ${PROJECTS_ROOT}"

echo -e "${C_WHITE}Personal GitHub username (used for ${PROJECTS_ROOT}/<username>/).${C_RESET}"
if [ -n "${EXISTING_USER}" ]; then
    echo "  Default: ${EXISTING_USER}"
fi
GITHUB_USERNAME=""
while [ -z "${GITHUB_USERNAME}" ]; do
    if [ -n "${EXISTING_USER}" ]; then
        read -r -p "  GitHub username (Enter for ${EXISTING_USER}): " INPUT_USER
        GITHUB_USERNAME="${INPUT_USER:-${EXISTING_USER}}"
    else
        read -r -p "  GitHub username: " GITHUB_USERNAME
    fi
done
log_pass "GitHub username: ${GITHUB_USERNAME}"

# Persist to ~/.claude/config.json so Phase 4 and later phases read instead
# of re-prompting.
mkdir -p "$(dirname "${CLAUDE_CONFIG}")"
if [ -f "${CLAUDE_CONFIG}" ] && command -v jq >/dev/null 2>&1; then
    tmp_cfg="$(mktemp)"
    jq --arg root "${PROJECTS_ROOT}" --arg user "${GITHUB_USERNAME}" \
       '. + {projects_root: $root, github_username: $user}' \
       "${CLAUDE_CONFIG}" > "${tmp_cfg}" && mv "${tmp_cfg}" "${CLAUDE_CONFIG}"
else
    cat > "${CLAUDE_CONFIG}" <<JSON
{
  "projects_root": "${PROJECTS_ROOT}",
  "github_username": "${GITHUB_USERNAME}"
}
JSON
fi
log_pass "Wrote: ${CLAUDE_CONFIG}"

# Paths
GITCONFIG="$HOME/.gitconfig"
GITCONFIG_CLIENT="$HOME/.gitconfig-client"
GITCONFIG_ARDUINO="$HOME/.gitconfig-arduino"
GITMESSAGE="$HOME/.gitmessage"
SSH_KEY="$HOME/.ssh/id_ed25519_github_personal"
PUB_KEY="$HOME/.ssh/id_ed25519_github_personal.pub"
ALLOWED_SIGNERS="$HOME/.ssh/allowed_signers"
GIT_TEMPLATES="$HOME/.git-templates"
GITIGNORE_GLOBAL="$HOME/.gitignore_global"

# ==============================================================================
# Step 2: Write ~/.gitconfig
# ==============================================================================
log_section "Step 2: Write ~/.gitconfig"

if [ -f "$GITCONFIG" ]; then
    log_warn "$GITCONFIG already exists, backing up to ${GITCONFIG}.bak"
    cp "$GITCONFIG" "${GITCONFIG}.bak"
fi

cat > "$GITCONFIG" <<EOF
[user]
    name       = ${GIT_USER_NAME}
    email      = $NOREPLY_EMAIL
    signingKey = $SSH_KEY

[commit]
    gpgSign = true
    template = $GITMESSAGE

[tag]
    gpgSign  = true
    forceSignAnnotated = true

[gpg]
    format = ssh

[gpg "ssh"]
    allowedSignersFile = $ALLOWED_SIGNERS

[core]
    autocrlf      = true
    eol           = crlf
    editor        = code --wait
    excludesFile  = $GITIGNORE_GLOBAL
    pager         = delta
    templateDir   = $GIT_TEMPLATES

[init]
    defaultBranch = main

[pull]
    rebase = true

[rebase]
    autoStash = true

[fetch]
    prune = true

[push]
    default       = current
    autoSetupRemote = true

[merge]
    conflictStyle = zdiff3
    tool          = vscode

[mergetool "vscode"]
    cmd = code --wait \$MERGED

[diff]
    tool       = vscode
    colorMoved = default

[difftool "vscode"]
    cmd = code --wait --diff \$LOCAL \$REMOTE

[delta]
    navigate    = true
    light       = false
    side-by-side = true
    line-numbers = true

[interactive]
    diffFilter = delta --color-only

[alias]
    st  = status -sb
    lg  = log --oneline --graph --decorate --all
    ca  = commit --amend --no-edit
    cp  = cherry-pick
    sw  = switch
    rb  = rebase
    pu  = push --set-upstream origin HEAD
    wip = "!git add -A && git commit -m 'wip: work in progress'"

[includeIf "gitdir:${PROJECTS_ROOT//\\//}/client/"]
    path = $GITCONFIG_CLIENT

[includeIf "gitdir:${PROJECTS_ROOT//\\//}/arduino/"]
    path = $GITCONFIG_ARDUINO
EOF

log_pass "~/.gitconfig written"

# ==============================================================================
# Step 3: Write ~/.gitconfig-client
# ==============================================================================
log_section "Step 3: Write ~/.gitconfig-client"

cat > "$GITCONFIG_CLIENT" <<EOF
# Client identity, placeholder until client GitHub account is created.
# Activated for all repos under ${PROJECTS_ROOT//\\//}/client/
[user]
    name       = ${GIT_USER_NAME} (client)
    email      = $NOREPLY_EMAIL
    signingKey = $SSH_KEY

[core]
    # Use UTC timestamps for client commits
    quotePath = false
EOF

log_pass "~/.gitconfig-client written"

# ==============================================================================
# Step 4: Write ~/.gitconfig-arduino
# ==============================================================================
log_section "Step 4: Write ~/.gitconfig-arduino"

cat > "$GITCONFIG_ARDUINO" <<EOF
# Arduino/ArduPilot identity override.
# Activated for all repos under ${PROJECTS_ROOT//\\//}/arduino/
[user]
    name       = ${GIT_USER_NAME}
    email      = $NOREPLY_EMAIL
    signingKey = $SSH_KEY

[core]
    # ArduPilot style, LF line endings
    autocrlf = input
    eol      = lf
EOF

log_pass "~/.gitconfig-arduino written"

# ==============================================================================
# Step 5: Write ~/.gitmessage
# ==============================================================================
log_section "Step 5: Write ~/.gitmessage"

cat > "$GITMESSAGE" <<'EOF'

# ---------------------------------------------------------------------------
# Conventional Commits template
# ---------------------------------------------------------------------------
# Format:  <type>(<scope>): <short summary>
#
# Types:
#   feat    : new feature
#   fix     : bug fix
#   docs    : documentation only
#   style   : formatting, whitespace (no logic change)
#   refactor, code change that neither fixes a bug nor adds a feature
#   perf    : performance improvement
#   test    : add or fix tests
#   build   : build system or external dependency change
#   ci      : CI configuration
#   chore   : maintenance tasks, tooling, config updates
#   revert  : revert a previous commit
#
# Scope (optional): affected module/component in parentheses
#   Example: feat(auth): add OAuth2 support
#
# Subject: imperative mood, no capital first letter, no period at end
#   Good : fix authentication timeout
#   Bad  : Fixed Authentication Timeout.
#
# Body (optional): explain WHY, not WHAT. Wrap at 72 chars.
#
# Footer (optional):
#   BREAKING CHANGE: <description>
#   Refs: #123
# ---------------------------------------------------------------------------
EOF

log_pass "~/.gitmessage written"

# ==============================================================================
# Step 6: Verify
# ==============================================================================
log_section "Step 6: Verify git config"

check_config() {
    local key="$1" expected="$2"
    local actual
    actual=$(git config --global "$key" 2>/dev/null || true)
    if [ "$actual" = "$expected" ]; then
        log_pass "$key = $actual"
    else
        log_warn "$key = '$actual' (expected '$expected')"
    fi
}

check_config "user.name"            "$GIT_USER_NAME"
check_config "user.email"           "$NOREPLY_EMAIL"
check_config "commit.gpgsign"       "true"
check_config "tag.gpgsign"          "true"
check_config "gpg.format"          "ssh"
check_config "pull.rebase"         "true"
check_config "init.defaultbranch"  "main"
check_config "core.autocrlf"       "true"

# ==============================================================================
# Summary
# ==============================================================================
echo -e "\n${C_GREEN}[RESULT] Phase 3 completed successfully.${C_RESET}"
echo -e "${C_CYAN}  Run: git config --list --global   to review all settings.${C_RESET}\n"
exit 0
