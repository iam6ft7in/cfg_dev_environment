#!/usr/bin/env bash
# ==============================================================================
# Phase 5: Global .gitignore
#
# Script Name : phase_05_gitignore.sh
# Purpose     : Write ~/.gitignore_global and register it in ~/.gitconfig.
# Phase       : 5 of 12
# Exit Criteria: git config --global core.excludesFile returns a valid path.
#
# Run with: bash scripts/phase_05_gitignore.sh
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

GITIGNORE_GLOBAL="$HOME/.gitignore_global"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}========================================"
echo      "  Phase 5, Global .gitignore"
echo      "  File: $GITIGNORE_GLOBAL"
echo -e   "========================================${C_RESET}\n"

# ==============================================================================
# Step 1: Write ~/.gitignore_global
# ==============================================================================
log_section "Step 1: Write ~/.gitignore_global"

if [ -f "$GITIGNORE_GLOBAL" ]; then
    log_warn "$GITIGNORE_GLOBAL already exists, backing up to ${GITIGNORE_GLOBAL}.bak"
    cp "$GITIGNORE_GLOBAL" "${GITIGNORE_GLOBAL}.bak"
fi

cat > "$GITIGNORE_GLOBAL" <<'EOF'
# ===========================================================================
# Global .gitignore, applies to all repositories
# Managed by: phase_05_gitignore.sh
# ===========================================================================

# ---------------------------------------------------------------------------
# Windows OS files
# ---------------------------------------------------------------------------
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
ehthumbs_vista.db
Desktop.ini
$RECYCLE.BIN/
*.lnk
*.url

# Windows image file caches
*.stackdump

# Folder config files
[Dd]esktop.ini

# Recycle Bin used on file shares
$RECYCLE.BIN/

# Windows Installer files
*.cab
*.msi
*.msix
*.msm
*.msp

# Windows shortcuts
*.lnk

# ---------------------------------------------------------------------------
# VS Code
# ---------------------------------------------------------------------------
.vscode/
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
!.vscode/*.code-snippets
.history/
*.vsix

# ---------------------------------------------------------------------------
# Temporary files
# ---------------------------------------------------------------------------
*.tmp
*.temp
*.swp
*.swo
*~
*.bak
*.orig
*.log
*.pid
*.seed
*.pid.lock

# Build output directories (generic)
[Bb]in/
[Oo]bj/
[Oo]ut/
[Dd]ist/
[Bb]uild/
*.o
*.obj
*.exe
*.dll
*.so
*.dylib
*.lib
*.a
*.pdb

# ---------------------------------------------------------------------------
# Environment and secrets
# ---------------------------------------------------------------------------
.env
.env.*
!.env.example
!.env.template
.envrc
*.pem
*.key
*.p12
*.pfx
*.cer
*.crt
secrets.json
secrets.yaml
secrets.yml
credentials.json
credentials.yaml
credentials.yml
config.local.*

# ---------------------------------------------------------------------------
# Python artifacts
# ---------------------------------------------------------------------------
__pycache__/
*.py[cod]
*$py.class
*.pyo
*.pyd
.Python

# Virtual environments
.venv/
venv/
env/
ENV/
.env/

# Distribution / packaging
*.egg
*.egg-info/
dist/
build/
eggs/
parts/
var/
sdist/
develop-eggs/
.installed.cfg
lib/
lib64/
wheels/

# PyInstaller
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# mypy / pyright / ruff cache
.mypy_cache/
.dmypy.json
dmypy.json
.pyright/
.ruff_cache/

# Jupyter notebooks checkpoints
.ipynb_checkpoints/

# ---------------------------------------------------------------------------
# Node / npm (present in some toolchains)
# ---------------------------------------------------------------------------
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.yarn/cache
.pnp.*

# ---------------------------------------------------------------------------
# macOS (if collaborating cross-platform)
# ---------------------------------------------------------------------------
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes
EOF

log_pass "~/.gitignore_global written"

# ==============================================================================
# Step 2: Register in ~/.gitconfig
# ==============================================================================
log_section "Step 2: Register core.excludesFile in git config"

git config --global core.excludesFile "$GITIGNORE_GLOBAL"
log_pass "core.excludesFile = $GITIGNORE_GLOBAL"

# ==============================================================================
# Step 3: Verify
# ==============================================================================
log_section "Step 3: Verify"

registered=$(git config --global core.excludesFile 2>/dev/null || true)
if [ "$registered" = "$GITIGNORE_GLOBAL" ]; then
    log_pass "Verified: core.excludesFile = $registered"
else
    log_fail "core.excludesFile not set correctly. Got: '$registered'"
    exit 1
fi

if [ -f "$GITIGNORE_GLOBAL" ]; then
    line_count=$(wc -l < "$GITIGNORE_GLOBAL")
    log_pass "File exists with $line_count lines"
else
    log_fail "File does not exist: $GITIGNORE_GLOBAL"
    exit 1
fi

# ==============================================================================
# Summary
# ==============================================================================
echo -e "\n${C_GREEN}[RESULT] Phase 5 completed successfully.${C_RESET}"
echo -e "${C_CYAN}  Global gitignore: $GITIGNORE_GLOBAL${C_RESET}\n"
exit 0
