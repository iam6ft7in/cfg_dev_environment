#!/usr/bin/env bash
# ==============================================================================
# Phase 10: Windows Environment Configuration
#
# Script Name : phase_10_windows_env.sh
# Purpose     : Set Windows environment variables via reg.exe, write Oh My Posh
#               theme, configure PowerShell profile.
#               Windows Terminal settings require manual update, JSON is printed.
# Phase       : 10 of 12
# Exit Criteria: GIT_SSH, LANG, LC_ALL set in user registry. Oh My Posh theme
#                written. PowerShell profile updated.
#
# Run with: bash scripts/phase_10_windows_env.sh
# NOTE: reg.exe calls modify the Windows user environment permanently.
#       No administrator rights required for HKCU keys.
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

OMP_THEME="$HOME/.oh-my-posh/theme.json"
OMP_DIR="$HOME/.oh-my-posh"

# Windows paths (for reg.exe and PowerShell)
WIN_SSH_PATH="C:\\Windows\\System32\\OpenSSH\\ssh.exe"
WIN_OMP_THEME=$(cygpath -w "$OMP_THEME" 2>/dev/null || echo "%USERPROFILE%\\.oh-my-posh\\theme.json")

# Read projects_root and github_username from ~/.claude/config.json (Phase 3).
# Used to seed the Windows Terminal profile startingDirectory values printed
# at Step 5. Falls back to %USERPROFILE%\projects if config is missing.
CLAUDE_CONFIG="${HOME}/.claude/config.json"
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
PROJECTS_ROOT="$(read_config_value 'projects_root')"
GITHUB_USERNAME="$(read_config_value 'github_username')"
if [ -z "${PROJECTS_ROOT}" ]; then
    PROJECTS_ROOT='%USERPROFILE%\projects'
fi
# Convert to Windows-style path with double-backslash escapes for the
# JSON values printed to the user.
WIN_PROJECTS_ROOT="$(echo "${PROJECTS_ROOT}" | sed -e 's|/|\\\\|g' -e 's|\\\([^\\]\)|\\\\\1|g')"
# Personal subtree uses {projects_root}/{github_username}/. If username is
# missing, fall back to the parent directory so the profile still opens
# something sensible.
if [ -n "${GITHUB_USERNAME}" ]; then
    WIN_PERSONAL_DIR="${WIN_PROJECTS_ROOT}\\\\${GITHUB_USERNAME}"
else
    WIN_PERSONAL_DIR="${WIN_PROJECTS_ROOT}"
fi

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 10, Windows Environment Setup"
echo      "  Repo root: $REPO_ROOT"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1: Set environment variables via reg.exe
# ==============================================================================
log_section "Step 1: Set Windows user environment variables (reg.exe)"

set_env_var() {
    local name="$1" value="$2"
    if reg add "HKCU\\Environment" /v "$name" /t REG_SZ /d "$value" /f &>/dev/null; then
        log_pass "Set $name = $value"
    else
        log_fail "Failed to set $name via reg.exe"
    fi
}

# GIT_SSH, point to Windows OpenSSH (avoids Git Bash ssh conflicts)
set_env_var "GIT_SSH" "$WIN_SSH_PATH"

# Locale
set_env_var "LANG"   "en_US.UTF-8"
set_env_var "LC_ALL" "en_US.UTF-8"

log_info "Environment variables will take effect in new sessions."
log_info "To apply immediately in this shell:"
log_info "  export GIT_SSH='$WIN_SSH_PATH'"
log_info "  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8"

# Apply to current session too
export GIT_SSH="$WIN_SSH_PATH"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ==============================================================================
# Step 2: Verify required tools on PATH
# ==============================================================================
log_section "Step 2: Verify tools on PATH"

TOOLS=(git gh ssh gitleaks delta oh-my-posh)

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        ver_raw=$($tool --version 2>&1 | head -1 || true)
        log_pass "$tool found: $ver_raw"
    else
        log_warn "$tool not found on PATH"
    fi
done

# ==============================================================================
# Step 3: Write Oh My Posh theme
# ==============================================================================
log_section "Step 3: Write Oh My Posh theme"

mkdir -p "$OMP_DIR"

if [ -f "$OMP_THEME" ]; then
    log_warn "$OMP_THEME already exists, backing up to ${OMP_THEME}.bak"
    cp "$OMP_THEME" "${OMP_THEME}.bak"
fi

cat > "$OMP_THEME" <<'EOF'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 2,
  "final_space": true,
  "console_title_template": "{{ .Shell }}, {{ .Folder }}",
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "os",
          "style": "diamond",
          "foreground": "#ffffff",
          "background": "#0077c2",
          "leading_diamond": "\ue0b6",
          "trailing_diamond": "\ue0b0",
          "template": " \uf17a "
        },
        {
          "type": "path",
          "style": "powerline",
          "powerline_symbol": "\ue0b0",
          "foreground": "#ffffff",
          "background": "#005f87",
          "properties": {
            "style": "agnoster_short",
            "max_depth": 4
          },
          "template": " \uf07c {{ .Path }} "
        },
        {
          "type": "git",
          "style": "powerline",
          "powerline_symbol": "\ue0b0",
          "foreground": "#193549",
          "background": "#56B4E9",
          "foreground_templates": [
            "{{ if or (.Working.Changed) (.Staging.Changed) }}#193549{{ end }}",
            "{{ if and (gt .Ahead 0) (gt .Behind 0) }}#ffffff{{ end }}",
            "{{ if gt .Ahead 0 }}#193549{{ end }}"
          ],
          "background_templates": [
            "{{ if or (.Working.Changed) (.Staging.Changed) }}#E69F00{{ end }}",
            "{{ if and (gt .Ahead 0) (gt .Behind 0) }}#CC79A7{{ end }}",
            "{{ if gt .Ahead 0 }}#56B4E9{{ end }}"
          ],
          "properties": {
            "branch_icon": "\ue725 ",
            "fetch_status": true,
            "fetch_upstream_icon": true
          },
          "template": " {{ .HEAD }}{{ if .Working.Changed }} \uf044 {{ .Working.String }}{{ end }}{{ if .Staging.Changed }} \uf046 {{ .Staging.String }}{{ end }} "
        },
        {
          "type": "python",
          "style": "powerline",
          "powerline_symbol": "\ue0b0",
          "foreground": "#100e23",
          "background": "#906cff",
          "template": " \ue235 {{ .Venv }}{{ .Full }} ",
          "properties": {
            "display_mode": "context",
            "home_enabled": false
          }
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "text",
          "style": "plain",
          "foreground": "#56B4E9",
          "template": "\u276f "
        }
      ]
    }
  ]
}
EOF

log_pass "Oh My Posh theme written: $OMP_THEME"

# ==============================================================================
# Step 4: Configure PowerShell profile
# ==============================================================================
log_section "Step 4: Configure PowerShell profile"

# Find PowerShell profile path
PS_PROFILE=""
if command -v pwsh &>/dev/null; then
    PS_PROFILE=$(pwsh -NoProfile -Command '$PROFILE' 2>/dev/null || true)
fi

if [ -z "$PS_PROFILE" ]; then
    # Fallback to standard location
    PS_PROFILE="$HOME/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
    log_warn "Could not query \$PROFILE from pwsh, using default: $PS_PROFILE"
fi

# Convert to Unix path for bash operations
PS_PROFILE_UNIX=$(cygpath "$PS_PROFILE" 2>/dev/null || echo "$PS_PROFILE")

mkdir -p "$(dirname "$PS_PROFILE_UNIX")"

OMP_INIT_LINE="oh-my-posh init pwsh --config \"\$HOME/.oh-my-posh/theme.json\" | Invoke-Expression"
OMP_COMMENT="# Oh My Posh, initialised by phase_10_windows_env.sh"

if [ -f "$PS_PROFILE_UNIX" ] && grep -qF "oh-my-posh init pwsh" "$PS_PROFILE_UNIX"; then
    log_warn "Oh My Posh init already in PowerShell profile, skipping"
else
    {
        echo ""
        echo "$OMP_COMMENT"
        echo "$OMP_INIT_LINE"
    } >> "$PS_PROFILE_UNIX"
    log_pass "Oh My Posh init appended to PowerShell profile: $PS_PROFILE"
fi

# ==============================================================================
# Step 5: Windows Terminal settings (manual, print JSON)
# ==============================================================================
log_section "Step 5: Windows Terminal settings (manual)"

echo -e "${C_YELLOW}  Windows Terminal settings.json must be updated manually.${C_RESET}"
echo    "  Open Windows Terminal -> Settings -> Open JSON file"
echo    "  Add the following profiles to the 'list' array inside 'profiles':"
echo ""
cat <<JSON
{
    "name": "personal",
    "commandline": "C:\\\\Program Files\\\\Git\\\\bin\\\\bash.exe -i -l",
    "startingDirectory": "${WIN_PERSONAL_DIR}",
    "colorScheme": "Campbell",
    "tabColor": "#56B4E9",
    "icon": "\ud83d\udc64",
    "font": {
        "face": "JetBrainsMono Nerd Font",
        "size": 13
    }
},
{
    "name": "client",
    "commandline": "C:\\\\Program Files\\\\Git\\\\bin\\\\bash.exe -i -l",
    "startingDirectory": "${WIN_PROJECTS_ROOT}\\\\client",
    "colorScheme": "Campbell",
    "tabColor": "#E69F00",
    "icon": "\ud83d\udd27",
    "font": {
        "face": "JetBrainsMono Nerd Font",
        "size": 13
    }
},
{
    "name": "arduino",
    "commandline": "C:\\\\Program Files\\\\Git\\\\bin\\\\bash.exe -i -l",
    "startingDirectory": "${WIN_PROJECTS_ROOT}\\\\arduino",
    "colorScheme": "Campbell",
    "tabColor": "#CC79A7",
    "icon": "\ud83e\udd16",
    "font": {
        "face": "JetBrainsMono Nerd Font",
        "size": 13
    }
}
JSON
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo -e "\n${C_GREEN}[RESULT] Phase 10 completed.${C_RESET}"
echo -e "${C_CYAN}  Manual steps remaining:${C_RESET}"
echo    "    1. Add the Windows Terminal profile JSON shown above"
echo    "    2. Restart Windows Terminal to pick up new environment variables"
echo    "    3. Open the 'personal' profile and verify Oh My Posh prompt appears"
echo -e "    4. Navigate to a git repo and confirm branch/status in prompt\n"
exit 0
