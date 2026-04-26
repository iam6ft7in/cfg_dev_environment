#!/usr/bin/env bash
# ==============================================================================
# preview.sh, read-only preview of every change the 12 phases would make.
#
# Walks the 12 phases and reports, for each one, what it would install,
# create, modify, or write on the current machine. Makes NO changes.
#
# Status tags:
#   [INSTALLED]      tool is on PATH at the right version
#   [WILL INSTALL]   tool is missing or older than minimum
#   [EXISTS]         file or directory already on disk
#   [WILL CREATE]    file or directory will be created
#   [WILL OVERWRITE] file exists and will be overwritten by a phase
#                    (existing content is backed up to *.bak when the
#                    phase supports it)
#
# Run with: bash scripts/preview.sh
# Mirror of scripts/preview.ps1.
# ==============================================================================

set -euo pipefail

if [ -t 1 ]; then
    C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
    C_MAG='\033[0;35m';  C_GRAY='\033[0;90m';  C_RESET='\033[0m'
else
    C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_MAG=''; C_GRAY=''; C_RESET=''
fi

phase()   { printf '\n%b=== %s ===%b\n' "${C_CYAN}" "$1" "${C_RESET}"; }
note()    { printf '%b  %s%b\n' "${C_GRAY}" "$1" "${C_RESET}"; }

status() {
    # status TAG ITEM [NOTE]
    local tag="$1" item="$2" note="${3:-}" color
    case "${tag}" in
        INSTALLED|EXISTS)        color="${C_GREEN}" ;;
        'WILL INSTALL'|'WILL CREATE') color="${C_YELLOW}" ;;
        'WILL OVERWRITE')        color="${C_MAG}"   ;;
        *)                       color="${C_RESET}" ;;
    esac
    local pad
    pad=$(printf '%-15s' "${tag}")
    if [ -n "${note}" ]; then
        printf '%b  [%s] %s  (%s)%b\n' "${color}" "${pad}" "${item}" "${note}" "${C_RESET}"
    else
        printf '%b  [%s] %s%b\n' "${color}" "${pad}" "${item}" "${C_RESET}"
    fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
printf '\n%b==========================================================\n' "${C_CYAN}"
printf '  cfg_dev_environment, preview of all 12 phases\n'
printf '  Read-only. No changes will be made.\n'
printf '==========================================================%b\n' "${C_RESET}"

# Resolve a tentative projects_root and github_username from existing config.
CLAUDE_CONFIG="${HOME}/.claude/config.json"
PROJECTS_ROOT="${HOME}/projects"
GITHUB_USERNAME='<unset>'
config_known=0
if [ -f "${CLAUDE_CONFIG}" ]; then
    if command -v jq >/dev/null 2>&1; then
        cfg_root=$(jq -r '.projects_root   // empty' "${CLAUDE_CONFIG}" 2>/dev/null || true)
        cfg_user=$(jq -r '.github_username // empty' "${CLAUDE_CONFIG}" 2>/dev/null || true)
    else
        cfg_root=$(grep -oE '"projects_root"[[:space:]]*:[[:space:]]*"[^"]+"' "${CLAUDE_CONFIG}" \
                   | sed -E 's/.*"projects_root"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
                   | head -n1 || true)
        cfg_user=$(grep -oE '"github_username"[[:space:]]*:[[:space:]]*"[^"]+"' "${CLAUDE_CONFIG}" \
                   | sed -E 's/.*"github_username"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
                   | head -n1 || true)
    fi
    if [ -n "${cfg_root:-}" ]; then PROJECTS_ROOT="${cfg_root//\\\\/\\}"; fi
    if [ -n "${cfg_user:-}" ]; then GITHUB_USERNAME="${cfg_user}"; config_known=1; fi
fi

printf '\n  projects_root   : %s\n'   "${PROJECTS_ROOT}"
printf '  github_username : %s\n' "${GITHUB_USERNAME}"
if [ "${config_known}" -eq 0 ]; then
    note '(Phase 3 will prompt for both and persist them to ~/.claude/config.json)'
fi

# ------------------------------------------------------------------------------
# Phase 0
# ------------------------------------------------------------------------------
phase 'Phase 0: manual prerequisites (you do these yourself)'
echo '  - Move %USERPROFILE%\OneDrive\Documents\AI\ to %USERPROFILE%\OneDrive\AI\'
echo '  - Get your GitHub noreply email (Settings, Emails)'
echo '  - Confirm: pwsh --version >= 7.4'
echo '  - Confirm: Bitwarden Desktop >= 2025.1.2 installed and logged in'

# ------------------------------------------------------------------------------
# Phase 1: tools
# ------------------------------------------------------------------------------
phase 'Phase 1: tools to install'

check_tool() {
    local name="$1" cmd="$2" minver="$3"
    if have_cmd "${cmd}"; then
        status 'INSTALLED' "${name}"
    else
        status 'WILL INSTALL' "${name}" "min version ${minver}"
    fi
}

check_tool 'git'        'git'        '2.42'
check_tool 'gh'         'gh'         '2.40'
check_tool 'ssh.exe'    'ssh'        '0.0'
check_tool 'gitleaks'   'gitleaks'   '8.18'
check_tool 'nasm'       'nasm'       '2.16'
check_tool 'uv'         'uv'         '0.4'
check_tool 'ruff'       'ruff'       '0.3'
check_tool 'delta'      'delta'      '0.17'
check_tool 'x64dbg'     'x64dbg'     '0.0'
check_tool 'oh-my-posh' 'oh-my-posh' '23'
note 'Plus: JetBrains Mono Nerd Font (manual install)'

# ------------------------------------------------------------------------------
# Phase 2: SSH
# ------------------------------------------------------------------------------
phase 'Phase 2: SSH setup (Bitwarden-backed)'

check_file_overwrite() {
    local rel="$1" abs="$2" extra="${3:-}"
    if [ -e "${abs}" ]; then
        status 'WILL OVERWRITE' "${rel}" "${extra}"
    else
        status 'WILL CREATE' "${rel}"
    fi
}

check_file_overwrite '~/.ssh/config'          "${HOME}/.ssh/config" 'host aliases for github-personal and github-client'
check_file_overwrite '~/.ssh/allowed_signers' "${HOME}/.ssh/allowed_signers"
note 'Plus: one Ed25519 key generated inside your Bitwarden vault'
note 'Plus: Windows OpenSSH Authentication Agent service set to Disabled'

# ------------------------------------------------------------------------------
# Phase 3: gitconfig family
# ------------------------------------------------------------------------------
phase 'Phase 3: git config files (prompts for projects_root and github_username)'

git_files=('~/.gitconfig' '~/.gitconfig-client' '~/.gitconfig-arduino' '~/.gitmessage')
for rel in "${git_files[@]}"; do
    abs="${rel/#\~/${HOME}}"
    if [ -e "${abs}" ]; then
        status 'WILL OVERWRITE' "${rel}" 'existing content backed up to *.bak by .sh; .ps1 overwrites in place'
    else
        status 'WILL CREATE' "${rel}"
    fi
done
if [ -e "${CLAUDE_CONFIG}" ]; then
    status 'WILL OVERWRITE' '~/.claude/config.json' 'projects_root + github_username keys updated'
else
    status 'WILL CREATE' '~/.claude/config.json'
fi

# ------------------------------------------------------------------------------
# Phase 4: directory tree
# ------------------------------------------------------------------------------
phase 'Phase 4: directory tree'

dirs=(
    "${PROJECTS_ROOT}/${GITHUB_USERNAME}/public"
    "${PROJECTS_ROOT}/${GITHUB_USERNAME}/private"
    "${PROJECTS_ROOT}/${GITHUB_USERNAME}/collaborative"
    "${PROJECTS_ROOT}/client"
    "${PROJECTS_ROOT}/arduino/upstream"
    "${PROJECTS_ROOT}/arduino/custom"
    "${HOME}/.git-templates/hooks"
    "${HOME}/.claude/rules"
    "${HOME}/.claude/skills"
    "${HOME}/.claude/scripts"
    "${HOME}/.claude/shortcuts"
    "${HOME}/.claude/templates"
    "${HOME}/.cspell"
    "${HOME}/.oh-my-posh"
)
for d in "${dirs[@]}"; do
    if [ -d "${d}" ]; then
        status 'EXISTS' "${d}"
    else
        status 'WILL CREATE' "${d}"
    fi
done

# ------------------------------------------------------------------------------
# Phase 5: gitignore_global
# ------------------------------------------------------------------------------
phase 'Phase 5: ~/.gitignore_global'
check_file_overwrite '~/.gitignore_global' "${HOME}/.gitignore_global"

# ------------------------------------------------------------------------------
# Phase 6: hooks + gitleaks scan
# ------------------------------------------------------------------------------
phase 'Phase 6: git hooks and weekly gitleaks scan'

check_file_overwrite '~/.git-templates/hooks/pre-commit'     "${HOME}/.git-templates/hooks/pre-commit"
check_file_overwrite '~/.git-templates/hooks/commit-msg'     "${HOME}/.git-templates/hooks/commit-msg"
check_file_overwrite '~/.gitleaks.toml'                      "${HOME}/.gitleaks.toml"
check_file_overwrite '~/.git-templates/gitleaks-weekly-scan.ps1' "${HOME}/.git-templates/gitleaks-weekly-scan.ps1"
note 'Task Scheduler entry registered by .ps1 variant only (PowerShell required).'
note 'Plus: git config init.templateDir = ~/.git-templates'

# ------------------------------------------------------------------------------
# Phases 7, 7b, 8, 9: Claude config
# ------------------------------------------------------------------------------
phase 'Phases 7, 7b, 8, 9: Claude rules, skills, scripts, templates, cspell dictionary'

claude_paths=(
    "${HOME}/.claude/rules|rule files (universal + extension-triggered)"
    "${HOME}/.claude/skills|skill directories (~ 20 skills)"
    "${HOME}/.claude/scripts|helper scripts (setup_project_board.ps1)"
    "${HOME}/.claude/shortcuts|regenerate.ps1 + per-repo .lnk files"
    "${HOME}/.claude/templates|project scaffold"
    "${HOME}/.cspell/custom_words.txt|cspell dictionary"
)
for entry in "${claude_paths[@]}"; do
    p="${entry%%|*}"
    n="${entry#*|}"
    if [ -e "${p}" ]; then
        status 'WILL OVERWRITE' "${p}" "${n}"
    else
        status 'WILL CREATE' "${p}" "${n}"
    fi
done
note 'Phase 7b uses diff-before-copy: drifted files prompt per-file.'
note 'User edits to deployed-only files (e.g. send-email/config.json) are preserved.'

# ------------------------------------------------------------------------------
# Phase 10: Windows env (informational from bash; .ps1 does the actual writes)
# ------------------------------------------------------------------------------
phase 'Phase 10: Windows environment (registry + Terminal + PowerShell profile)'

note 'Sets HKCU env vars: GIT_SSH, LANG, LC_ALL'
check_file_overwrite '~/.oh-my-posh/theme.json' "${HOME}/.oh-my-posh/theme.json"
note 'Appends Oh My Posh init to PowerShell profile (run .ps1 variant for the actual edit).'
note 'Plus: three Windows Terminal profiles added (GitHub Personal, Client, Arduino)'

# ------------------------------------------------------------------------------
# Phase 11: e2e test
# ------------------------------------------------------------------------------
phase 'Phase 11: end-to-end test (no permanent changes)'

echo "  Temporary test repo created and deleted at: ${PROJECTS_ROOT}/${GITHUB_USERNAME}/_e2e_test_temp"
echo '  Creates a GitHub repo named test_e2e_delete_me, then removes it.'
echo '  Verifies signed commits and PR flow end-to-end.'

# ------------------------------------------------------------------------------
# Phase 12: self-install
# ------------------------------------------------------------------------------
phase 'Phase 12: install cfg_dev_environment as a gold standard repo'

self_install="${PROJECTS_ROOT}/${GITHUB_USERNAME}/public/cfg_dev_environment"
if [ -d "${self_install}" ]; then
    status 'EXISTS' "${self_install}" 'Phase 12 will prompt overwrite/skip/abort'
else
    status 'WILL CREATE' "${self_install}"
fi
note 'Creates a private GitHub repo: cfg_dev_environment'
note 'Pushes initial signed commit, applies branch protection ruleset.'

# ------------------------------------------------------------------------------
# Footer
# ------------------------------------------------------------------------------
printf '\n%b==========================================================\n' "${C_CYAN}"
printf '  Preview complete. No changes were made.\n'
printf '  To proceed, follow the Start Here section in README.md.\n'
printf '==========================================================%b\n\n' "${C_RESET}"
