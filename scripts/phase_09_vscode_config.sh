#!/usr/bin/env bash
# ==============================================================================
# Phase 9 — VS Code Configuration Templates
#
# Script Name : phase_09_vscode_config.sh
# Purpose     : Write VS Code user settings (merge via Python/node if available,
#               otherwise print instructions). Copy templates/vscode/ to
#               ~/.claude/templates/vscode/. Write ~/.cspell/custom-words.txt.
# Phase       : 9 of 12
# Exit Criteria: VS Code settings written, vscode templates copied,
#                cspell dictionary exists.
#
# Run with: bash scripts/phase_09_vscode_config.sh
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

# ------------------------------------------------------------------------------
# Paths — Windows Git Bash paths for VS Code AppData
# ------------------------------------------------------------------------------
APPDATA_CODE="$HOME/AppData/Roaming/Code/User"
VSCODE_SETTINGS="$APPDATA_CODE/settings.json"
CSPELL_DIR="$HOME/.cspell"
CSPELL_DICT="$CSPELL_DIR/custom-words.txt"
VSCODE_TMPL_SRC="$REPO_ROOT/templates/vscode"
VSCODE_TMPL_DEST="$HOME/.claude/templates/vscode"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 9 — VS Code Configuration"
echo      "  Settings : $VSCODE_SETTINGS"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1 — VS Code settings.json
# ==============================================================================
log_section "Step 1: VS Code user settings"

# The desired settings block as a JSON string
DESIRED_SETTINGS='{
    "workbench.colorTheme": "Solarized Dark",
    "editor.fontFamily": "JetBrainsMono Nerd Font, JetBrains Mono, Consolas, monospace",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "editor.lineHeight": 1.5,
    "editor.rulers": [88],
    "editor.minimap.enabled": false,
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "ms-python.black-formatter",
    "files.autoSave": "onFocusChange",
    "files.eol": "\r\n",
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.detectIndentation": false,
    "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font",
    "terminal.integrated.fontSize": 13,
    "git.enableSmartCommit": false,
    "git.confirmSync": false,
    "git.autofetch": true,
    "editor.inlineSuggest.enabled": true,
    "cSpell.customDictionaries": {
        "custom-words": {
            "name": "custom-words",
            "path": "${userHome}/.cspell/custom-words.txt",
            "addWords": true
        }
    },
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff",
        "editor.formatOnSave": true
    }
}'

mkdir -p "$APPDATA_CODE"

# Try Python merge first, then node, then write directly
settings_written=false

if command -v python3 &>/dev/null || command -v python &>/dev/null; then
    PYTHON_CMD=$(command -v python3 2>/dev/null || command -v python)
    log_info "Using $PYTHON_CMD to merge VS Code settings"

    # Write desired settings to a temp file
    DESIRED_TMP=$(mktemp /tmp/vscode_desired_XXXXXX.json)
    printf '%s' "$DESIRED_SETTINGS" > "$DESIRED_TMP"

    MERGE_SCRIPT=$(cat <<'PYEOF'
import json, sys, os

desired_file = sys.argv[1]
settings_file = sys.argv[2]

with open(desired_file, 'r', encoding='utf-8') as f:
    desired = json.load(f)

existing = {}
if os.path.isfile(settings_file):
    try:
        with open(settings_file, 'r', encoding='utf-8') as f:
            content = f.read().strip()
            if content:
                existing = json.loads(content)
    except Exception:
        existing = {}

existing.update(desired)

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(existing, f, indent=4, ensure_ascii=False)
    f.write('\n')

print("OK")
PYEOF
)
    result=$($PYTHON_CMD -c "$MERGE_SCRIPT" "$DESIRED_TMP" "$VSCODE_SETTINGS" 2>&1) || true
    rm -f "$DESIRED_TMP"

    if [ "$result" = "OK" ]; then
        log_pass "VS Code settings merged via Python: $VSCODE_SETTINGS"
        settings_written=true
    else
        log_warn "Python merge failed: $result — trying node"
    fi
fi

if [ "$settings_written" = false ] && command -v node &>/dev/null; then
    log_info "Using node to merge VS Code settings"

    DESIRED_TMP=$(mktemp /tmp/vscode_desired_XXXXXX.json)
    printf '%s' "$DESIRED_SETTINGS" > "$DESIRED_TMP"

    node - "$DESIRED_TMP" "$VSCODE_SETTINGS" <<'JSEOF'
const fs = require('fs');
const [,, desiredFile, settingsFile] = process.argv;
const desired = JSON.parse(fs.readFileSync(desiredFile, 'utf8'));
let existing = {};
if (fs.existsSync(settingsFile)) {
    try { existing = JSON.parse(fs.readFileSync(settingsFile, 'utf8')); }
    catch(e) { existing = {}; }
}
Object.assign(existing, desired);
fs.writeFileSync(settingsFile, JSON.stringify(existing, null, 4) + '\n', 'utf8');
console.log('OK');
JSEOF
    rm -f "$DESIRED_TMP"
    log_pass "VS Code settings merged via node: $VSCODE_SETTINGS"
    settings_written=true
fi

if [ "$settings_written" = false ]; then
    log_warn "Neither Python nor node available — printing settings to apply manually."
    echo ""
    echo -e "${C_WHITE}Add the following to your VS Code settings.json${C_RESET}"
    echo -e "${C_WHITE}  File: $VSCODE_SETTINGS${C_RESET}"
    echo    "  Open in VS Code: Ctrl+Shift+P -> 'Open User Settings (JSON)'"
    echo ""
    echo "$DESIRED_SETTINGS"
    echo ""
    log_warn "VS Code settings NOT written automatically."
fi

# ==============================================================================
# Step 2 — Copy templates/vscode/ to ~/.claude/templates/vscode/
# ==============================================================================
log_section "Step 2: Copy VS Code templates"

if [ -d "$VSCODE_TMPL_SRC" ]; then
    mkdir -p "$VSCODE_TMPL_DEST"
    source_count=$(find "$VSCODE_TMPL_SRC" -type f | wc -l)

    if [ "$source_count" -gt 0 ]; then
        cp -r "$VSCODE_TMPL_SRC/." "$VSCODE_TMPL_DEST/"
        dest_count=$(find "$VSCODE_TMPL_DEST" -type f | wc -l)
        log_pass "Copied $source_count file(s) to $VSCODE_TMPL_DEST"
        if [ "$dest_count" -lt "$source_count" ]; then
            log_warn "Destination has $dest_count files, expected $source_count"
        fi
    else
        log_warn "Source vscode templates directory is empty: $VSCODE_TMPL_SRC"
    fi
else
    log_warn "No templates/vscode/ directory found in repo: $VSCODE_TMPL_SRC"
    log_info "This is optional — skipping."
fi

# ==============================================================================
# Step 3 — Write ~/.cspell/custom-words.txt
# ==============================================================================
log_section "Step 3: Write ~/.cspell/custom-words.txt"

mkdir -p "$CSPELL_DIR"

if [ -f "$CSPELL_DICT" ]; then
    log_warn "$CSPELL_DICT already exists — skipping (preserve existing custom words)"
else
    cat > "$CSPELL_DICT" <<'EOF'
# CSpell custom dictionary
# Add project-specific words below, one per line.
# Managed initially by: phase_09_vscode_config.sh

ardupilot
ArduPilot
ArduCopter
ArduPlane
ArduRover
mavlink
MAVLink
gitleaks
gitconfig
noreply
nasm
NASM
uv
ruff
client
cspell
CSpell
endregion
autocrlf
gpgsign
templatedir
excludesfile
autostash
difftool
mergetool
zdiff
colorMoved
onFocusChange
EOF
    log_pass "~/.cspell/custom-words.txt written"
fi

# ==============================================================================
# Summary
# ==============================================================================
echo -e "\n${C_GREEN}[RESULT] Phase 9 completed.${C_RESET}"
echo -e "${C_CYAN}  After installing VS Code confirm:${C_RESET}"
echo    "    - Theme: Solarized Dark"
echo    "    - Font: JetBrains Mono Nerd Font"
echo -e "    - Ruler visible at 88 characters\n"
exit 0
