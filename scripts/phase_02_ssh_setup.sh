#!/usr/bin/env bash
# ==============================================================================
# Phase 2 — SSH Key Setup via Bitwarden SSH Agent
#
# Script Name : phase_02_ssh_setup.sh
# Purpose     : Capture the public key created in the Bitwarden vault,
#               write ~/.ssh/config with host aliases, initialize
#               ~/.ssh/allowed_signers.
#
#               NOTE: On Windows (Git Bash / WSL running under Windows),
#               the Bitwarden desktop app provides the SSH agent via the
#               Windows named pipe \\.\pipe\openssh-ssh-agent. No manual
#               agent configuration is needed in bash; Bitwarden handles it.
#
#               If running in WSL2 and you want Bitwarden's agent inside WSL,
#               see: https://bitwarden.com/help/ssh-agent/
#               (requires npiperelay or socat bridge — out of scope here).
#
# Phase       : 2 of 12
# Exit Criteria: Public key saved to ~/.ssh/id_ed25519_github_personal.pub,
#                ~/.ssh/config has correct host aliases,
#                ~/.ssh/allowed_signers initialized.
#
# Run with: bash scripts/phase_02_ssh_setup.sh
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
    echo -e "\n${C_RED}[ABORTED] Phase 2 did not complete successfully.${C_RESET}"
    exit 1
}

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------
SSH_DIR="$HOME/.ssh"
PUB_KEY_PATH="$SSH_DIR/id_ed25519_github_personal.pub"
CONFIG_PATH="$SSH_DIR/config"
ALLOWED_SIGNERS_PATH="$SSH_DIR/allowed_signers"
CLIENT_HOLDER="$SSH_DIR/id_ed25519_github_client.placeholder"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 2 — SSH Setup (Bitwarden Agent)"
echo      "  Repo root: $REPO_ROOT"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 — Create ~/.ssh directory
# ==============================================================================
log_section "Step 1: Create ~/.ssh directory"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
log_pass "~/.ssh exists and is mode 700"

# ==============================================================================
# Step 2 — Manual: Create SSH key in Bitwarden
# ==============================================================================
log_section "Step 2: Create SSH key in Bitwarden (manual)"

echo -e "\n${C_CYAN}  ACTION REQUIRED — complete these steps in the Bitwarden desktop app"
echo    "  before pressing Enter to continue:"
echo    ""
echo    "  A. Open Bitwarden desktop."
echo    "  B. Go to: Settings -> Security -> SSH Agent"
echo    "     Turn on 'Enable SSH Agent'."
echo    "  C. In the left sidebar, click 'SSH Keys'."
echo    "  D. Click 'New SSH key'."
echo    "  E. Fill in:"
echo    "       Name    : GitHub Personal"
echo    "       Key type: Ed25519    <-- must be Ed25519"
echo    "  F. Click 'Save'."
echo    "  G. Click the copy icon next to the PUBLIC KEY"
echo    "     (the long string starting with ssh-ed25519 AAAA...)."
echo    ""
echo -e "  Keep the public key copied to your clipboard.${C_RESET}"
echo ""
read -r -p "  Press Enter when you have the public key copied to your clipboard..."

# ==============================================================================
# Step 3 — Capture public key
# ==============================================================================
log_section "Step 3: Save public key from Bitwarden"

log_info "Paste the public key you copied from Bitwarden (starts with: ssh-ed25519 AAAA...)"
echo ""

PUB_KEY_CONTENT=""
while true; do
    read -r -p "  Paste public key here: " PUB_KEY_CONTENT
    PUB_KEY_CONTENT="${PUB_KEY_CONTENT// /}"  # trim leading/trailing spaces
    if echo "$PUB_KEY_CONTENT" | grep -q '^ssh-ed25519 AAAA'; then
        break
    fi
    log_warn "That does not look like an Ed25519 public key."
    log_warn "Expected format: ssh-ed25519 AAAA... (optional comment)"
done

printf '%s\n' "$PUB_KEY_CONTENT" > "$PUB_KEY_PATH"
chmod 644 "$PUB_KEY_PATH"
log_pass "Public key saved: $PUB_KEY_PATH"

# ==============================================================================
# Step 4 — Create client key placeholder
# ==============================================================================
log_section "Step 4: Create client key placeholder"

cat > "$CLIENT_HOLDER" <<'EOF'
# CLIENT KEY PLACEHOLDER
# ======================
# This file marks where the client SSH key will be created.
#
# The actual key (id_ed25519_github_client.pub) will be saved here when
# you run the /activate-client skill. That skill will guide you through
# creating a second key in Bitwarden named "GitHub Client" and wiring it
# up to the client GitHub account.
#
# DO NOT delete this file — it documents the pending setup.
EOF
log_pass "Client placeholder written: $CLIENT_HOLDER"

# ==============================================================================
# Step 5 — Write ~/.ssh/config
# ==============================================================================
log_section "Step 5: Write ~/.ssh/config"

write_host_block() {
    local alias="$1" hostname="$2" identity_pub="$3"
    if grep -q "^Host ${alias}$" "$CONFIG_PATH" 2>/dev/null; then
        log_warn "Host alias '${alias}' already in $CONFIG_PATH — skipping"
    else
        cat >> "$CONFIG_PATH" <<EOF

Host ${alias}
    HostName      ${hostname}
    User          git
    IdentityFile  ${identity_pub}
    IdentitiesOnly yes
EOF
        log_pass "Added Host ${alias} -> ${hostname}"
    fi
}

# Ensure config exists with a header if new
if [ ! -f "$CONFIG_PATH" ]; then
    cat > "$CONFIG_PATH" <<'EOF'
# SSH Configuration — GitHub Host Aliases
# Generated by phase_02_ssh_setup.sh (Bitwarden SSH Agent)
#
# IdentityFile points to the PUBLIC key file (.pub) on disk.
# The private key lives in the Bitwarden vault, never on disk.
# IdentitiesOnly yes prevents other vault keys from being tried.
#
# Usage:
#   Personal repos : git clone git@github-personal:username/repo.git
#   Client repos  : git clone git@github-client:username/repo.git
EOF
fi

chmod 600 "$CONFIG_PATH"
write_host_block "github-personal" "github.com" "~/.ssh/id_ed25519_github_personal.pub"
write_host_block "github-client"  "github.com" "~/.ssh/id_ed25519_github_client.pub"
log_pass "~/.ssh/config written"

# ==============================================================================
# Step 6 — Write allowed_signers
# ==============================================================================
log_section "Step 6: Write ~/.ssh/allowed_signers"

KEY_TYPE=$(echo "$PUB_KEY_CONTENT" | awk '{print $1}')
KEY_MATERIAL=$(echo "$PUB_KEY_CONTENT" | awk '{print $2}')

if [ -f "$ALLOWED_SIGNERS_PATH" ]; then
    log_warn "$ALLOWED_SIGNERS_PATH already exists — appending if key not present"
    if grep -qF "$KEY_MATERIAL" "$ALLOWED_SIGNERS_PATH"; then
        log_info "Key already in allowed_signers — skipping"
    else
        echo "your.email@placeholder ${KEY_TYPE} ${KEY_MATERIAL}" >> "$ALLOWED_SIGNERS_PATH"
        log_pass "Key appended to allowed_signers"
    fi
else
    cat > "$ALLOWED_SIGNERS_PATH" <<EOF
# allowed_signers — SSH commit signature verification
# Updated by phase_02_ssh_setup.sh
#
# NOTE: The email below uses a placeholder. Phase 3 will replace it
# with your real GitHub noreply email.

your.email@placeholder ${KEY_TYPE} ${KEY_MATERIAL}
EOF
    chmod 644 "$ALLOWED_SIGNERS_PATH"
    log_pass "allowed_signers written: $ALLOWED_SIGNERS_PATH"
fi

# ==============================================================================
# Step 7 — Display public key with GitHub upload instructions
# ==============================================================================
log_section "Step 7: Public key — upload to GitHub"

echo -e "\n${C_WHITE}Your public key:${C_RESET}"
echo "------------------------------------------------------------"
cat "$PUB_KEY_PATH"
echo "------------------------------------------------------------"

echo -e "\n${C_CYAN}STEP 2B — Upload to GitHub (manual):${C_RESET}"
echo "  1. Copy the public key above."
echo "  2. Go to: https://github.com/settings/ssh/new"
echo "  3. Authentication key:"
echo "       Title   : {your_name} Personal — Authentication"
echo "       Key type: Authentication Key"
echo "       Key     : (paste above)"
echo "  4. Add a second key at the same URL:"
echo "       Title   : {your_name} Personal — Signing"
echo "       Key type: Signing Key"
echo "       Key     : (paste same key)"
echo ""
echo -e "${C_CYAN}STEP 2C — Test the connection (manual, after uploading):${C_RESET}"
echo "  Make sure Bitwarden is open and unlocked, then run:"
echo "      ssh -T github-personal"
echo "  Allow the Bitwarden authorization prompt."
echo "  Expected: Hi {github_username}! You've successfully authenticated..."

# ==============================================================================
# Summary
# ==============================================================================
echo -e "\n${C_GREEN}[RESULT] Phase 2 completed.${C_RESET}"
echo -e "${C_CYAN}         Complete the GitHub upload steps above before Phase 3.${C_RESET}\n"
exit 0
