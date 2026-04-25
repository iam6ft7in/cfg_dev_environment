#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 09 - VS Code Configuration

.DESCRIPTION
    Script Name : phase_09_vscode_config.ps1
    Purpose     : Install VS Code user settings, copy vscode templates to
                  ~/.claude/templates/vscode/, create CSpell custom dictionary.
    Phase       : 09
    Exit Criteria:
        - VS Code settings.json exists with all required keys applied
        - ~/.claude/templates/vscode/ contains copied vscode templates
        - ~/.cspell/custom-words.txt exists with domain-specific words
        - User reminded to verify theme, font, and ruler in VS Code

.NOTES
    Run from any location; $RepoRoot is derived from $PSScriptRoot.
    Does NOT restart VS Code; user must reload the window to see changes.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Info    { param([string]$Msg) Write-Host "  [INFO]  $Msg" -ForegroundColor Cyan    }
function Write-Pass    { param([string]$Msg) Write-Host "  [PASS]  $Msg" -ForegroundColor Green   }
function Write-Warn    { param([string]$Msg) Write-Host "  [WARN]  $Msg" -ForegroundColor Yellow  }
function Write-Fail    { param([string]$Msg) Write-Host "  [FAIL]  $Msg" -ForegroundColor Red     }
function Write-Section { param([string]$Msg) Write-Host "`n=== $Msg ===" -ForegroundColor Cyan    }

function Exit-WithError {
    param([string]$Msg)
    Write-Fail $Msg
    Write-Host "`n[ABORTED] Phase 09 did not complete successfully." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$RepoRoot           = Split-Path -Parent $PSScriptRoot
$VSCodeSettingsPath = "$env:APPDATA\Code\User\settings.json"
$VSCodeTemplSrc     = Join-Path $RepoRoot 'templates\vscode'
$VSCodeTemplDest    = Join-Path $HOME '.claude\templates\vscode'
$CSpellDir          = Join-Path $HOME '.cspell'
$CSpellFile         = Join-Path $CSpellDir 'custom-words.txt'
# CSpell words live in config/cspell-custom-words.txt (added in the
# Phase D Tier B sweep) so the dictionary is editable without
# touching this script.
$CSpellWordsSrc     = Join-Path $RepoRoot 'config\cspell-custom-words.txt'

# Track results
$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Phase 09 - VS Code Configuration"      -ForegroundColor Cyan
Write-Host "  Repo Root      : $RepoRoot"             -ForegroundColor Cyan
Write-Host "  VS Code Config : $VSCodeSettingsPath"   -ForegroundColor Cyan
Write-Host "=======================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Desired VS Code settings (applied only for keys not already present)
# ---------------------------------------------------------------------------
$DesiredSettings = [ordered]@{
    'workbench.colorTheme'                        = 'Solarized Dark'
    'editor.fontFamily'                           = "'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace"
    'editor.fontSize'                             = 14
    'editor.fontLigatures'                        = $true
    'files.autoSave'                              = 'onFocusChange'
    'editor.minimap.enabled'                      = $false
    'editor.rulers'                               = @(88)
    'editor.wordWrapColumn'                       = 88
    'gitlens.codeLens.enabled'                    = $false
    'gitlens.currentLine.enabled'                 = $false
    'gitlens.blame.format'                        = '${author}, ${date}'
    'git.autofetch'                               = $true
    'git.pruneOnFetch'                            = $true
    'python.defaultInterpreterPath'               = '${workspaceFolder}/.venv/Scripts/python.exe'
    'python.terminal.activateEnvironment'         = $true
    'cSpell.language'                             = 'en-US'
    'cSpell.userWords'                            = @()
    'editor.formatOnSave'                         = $true
    '[python]'                                    = [ordered]@{
        'editor.defaultFormatter' = 'charliermarsh.ruff'
        'editor.formatOnSave'     = $true
    }
    '[powershell]'                                = [ordered]@{
        'editor.defaultFormatter' = 'ms-vscode.powershell'
    }
    'terminal.integrated.defaultProfile.windows'  = 'PowerShell'
    'terminal.integrated.fontFamily'              = "'JetBrainsMono Nerd Font', monospace"
}

# ---------------------------------------------------------------------------
# Step 1 - Find (or create) VS Code settings.json
# ---------------------------------------------------------------------------
Write-Section "Step 1: Locate VS Code settings.json"

Write-Info "Settings path: $VSCodeSettingsPath"
$VSCodeUserDir = Split-Path -Parent $VSCodeSettingsPath

if (-not (Test-Path $VSCodeUserDir -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $VSCodeUserDir -Force | Out-Null
        Write-Pass "Created VS Code User directory: $VSCodeUserDir"
    } catch {
        Exit-WithError "Cannot create VS Code User directory '$VSCodeUserDir': $_"
    }
}

if (Test-Path $VSCodeSettingsPath -PathType Leaf) {
    Write-Pass "settings.json already exists - will merge."
    $Results['LocateSettings'] = 'PASS (existing)'
} else {
    Write-Info "settings.json not found - will create new file."
    $Results['LocateSettings'] = 'PASS (new)'
}

# ---------------------------------------------------------------------------
# Step 2 & 3 - Read existing settings and merge desired keys
# ---------------------------------------------------------------------------
Write-Section "Step 2 & 3: Read and merge VS Code settings"

# Load existing settings (or start with empty object)
if (Test-Path $VSCodeSettingsPath -PathType Leaf) {
    try {
        $RawJson = Get-Content -Path $VSCodeSettingsPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($RawJson)) {
            $ExistingSettings = [ordered]@{}
            Write-Info "Existing settings.json is empty; starting fresh."
        } else {
            $ExistingSettings = $RawJson | ConvertFrom-Json -AsHashtable
            Write-Pass "Loaded $($ExistingSettings.Count) existing key(s)."
        }
    } catch {
        Write-Warn "Could not parse existing settings.json (invalid JSON?). Backing up and starting fresh."
        $BackupPath = "$VSCodeSettingsPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $VSCodeSettingsPath -Destination $BackupPath -Force
        Write-Info "Backup written to: $BackupPath"
        $ExistingSettings = [ordered]@{}
    }
} else {
    $ExistingSettings = [ordered]@{}
}

# Merge: apply desired keys only if NOT already present in existing settings
$AppliedKeys  = @()
$SkippedKeys  = @()

foreach ($Key in $DesiredSettings.Keys) {
    if ($ExistingSettings.Contains($Key)) {
        $SkippedKeys += $Key
        Write-Info "Skip (already set): $Key"
    } else {
        $ExistingSettings[$Key] = $DesiredSettings[$Key]
        $AppliedKeys += $Key
        Write-Pass "Applied: $Key"
    }
}

# Write merged settings back
try {
    $MergedJson = $ExistingSettings | ConvertTo-Json -Depth 10
    $Utf8NoBom  = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($VSCodeSettingsPath, $MergedJson, $Utf8NoBom)
    Write-Pass "settings.json written: $VSCodeSettingsPath"
    $Results['MergeSettings'] = 'PASS'
} catch {
    Write-Fail "Failed to write settings.json: $_"
    $Results['MergeSettings'] = 'FAIL'
    Exit-WithError "Cannot write VS Code settings."
}

Write-Info "Keys applied  : $($AppliedKeys.Count)"
Write-Info "Keys skipped  : $($SkippedKeys.Count) (already present)"

# ---------------------------------------------------------------------------
# Step 4 - Copy vscode templates
# ---------------------------------------------------------------------------
Write-Section "Step 4: Copy vscode templates to ~/.claude/templates/vscode/"

if (-not (Test-Path $VSCodeTemplSrc -PathType Container)) {
    Write-Warn "VS Code template source not found: $VSCodeTemplSrc - skipping."
    $Results['CopyVSCodeTemplates'] = 'WARN (source missing)'
} else {
    try {
        if (-not (Test-Path $VSCodeTemplDest -PathType Container)) {
            New-Item -ItemType Directory -Path $VSCodeTemplDest -Force | Out-Null
        }
        Copy-Item -Path "$VSCodeTemplSrc\*" -Destination $VSCodeTemplDest -Recurse -Force
        $CopiedVSCode = (Get-ChildItem -Path $VSCodeTemplDest -Recurse -File).Count
        Write-Pass "Copied $CopiedVSCode file(s) to $VSCodeTemplDest"
        $Results['CopyVSCodeTemplates'] = 'PASS'
    } catch {
        Write-Fail "Failed to copy vscode templates: $_"
        $Results['CopyVSCodeTemplates'] = 'FAIL'
    }
}

# ---------------------------------------------------------------------------
# Step 5 - Write CSpell custom words dictionary
# ---------------------------------------------------------------------------
Write-Section "Step 5: Write ~/.cspell/custom-words.txt"

if (-not (Test-Path $CSpellWordsSrc)) {
    Exit-WithError "Template missing: $CSpellWordsSrc"
}

# Read words from the committed template (one per line, trimmed,
# blanks dropped). This is the single source of truth; edit
# config/cspell-custom-words.txt to change the dictionary.
$CSpellWords = Get-Content -Path $CSpellWordsSrc |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' }

try {
    if (-not (Test-Path $CSpellDir -PathType Container)) {
        New-Item -ItemType Directory -Path $CSpellDir -Force | Out-Null
        Write-Pass "Created: $CSpellDir"
    }
    $CSpellContent = $CSpellWords -join "`n"
    $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($CSpellFile, $CSpellContent + "`n", $Utf8NoBom)
    Write-Pass "CSpell dictionary written: $CSpellFile"
    Write-Info "$($CSpellWords.Count) words in dictionary (from $CSpellWordsSrc)."
    $Results['CSpellDict'] = 'PASS'
} catch {
    Write-Fail "Failed to write CSpell dictionary: $_"
    $Results['CSpellDict'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 6 - Confirm settings path and written content
# ---------------------------------------------------------------------------
Write-Section "Step 6: Confirm VS Code settings"

Write-Info "VS Code settings path : $VSCodeSettingsPath"
if (Test-Path $VSCodeSettingsPath -PathType Leaf) {
    $FileSizeKB = [math]::Round((Get-Item $VSCodeSettingsPath).Length / 1KB, 1)
    Write-Pass "settings.json exists and is ${FileSizeKB} KB."
} else {
    Write-Fail "settings.json not found after write attempt!"
}

# ---------------------------------------------------------------------------
# Step 7 - Remind user to verify in VS Code
# ---------------------------------------------------------------------------
Write-Section "Step 7: Manual Verification Reminders"

Write-Host "`n  Please open VS Code and verify the following:" -ForegroundColor Yellow
Write-Host "    1. Theme  : Workbench > Color Theme should show 'Solarized Dark'"      -ForegroundColor Yellow
Write-Host "    2. Font   : Editor font should be 'JetBrainsMono Nerd Font', size 14"  -ForegroundColor Yellow
Write-Host "    3. Ruler  : A vertical line should appear at column 88"                -ForegroundColor Yellow
Write-Host "    4. CSpell : Extension should pick up ~/.cspell/custom-words.txt"       -ForegroundColor Yellow
Write-Host "    Tip: Ctrl+Shift+P > 'Open User Settings (JSON)' to inspect settings."  -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Section "Summary"

$PassCount = @($Results.Values | Where-Object { $_ -like 'PASS*' }).Count
$WarnCount = @($Results.Values | Where-Object { $_ -like 'WARN*' }).Count
$FailCount = @($Results.Values | Where-Object { $_ -eq 'FAIL' }).Count

foreach ($Key in $Results.Keys) {
    $Color = switch -Wildcard ($Results[$Key]) {
        'PASS*' { 'Green'  }
        'WARN*' { 'Yellow' }
        default { 'Red'    }
    }
    Write-Host "  $($Key.PadRight(25)) $($Results[$Key])" -ForegroundColor $Color
}

Write-Host "`n  VS Code settings : $VSCodeSettingsPath"  -ForegroundColor Cyan
Write-Host "  CSpell words     : $($CSpellWords.Count)" -ForegroundColor Cyan
Write-Host "  Keys applied     : $($AppliedKeys.Count)" -ForegroundColor Cyan
Write-Host "  Keys skipped     : $($SkippedKeys.Count)" -ForegroundColor Cyan

if ($FailCount -gt 0) {
    Write-Host "`n[RESULT] Phase 09 completed with errors. Review failures above." -ForegroundColor Red
    exit 1
} elseif ($WarnCount -gt 0) {
    Write-Host "`n[RESULT] Phase 09 completed with warnings. Verify items marked WARN manually." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n[RESULT] Phase 09 completed successfully. VS Code configuration is in place." -ForegroundColor Green
    exit 0
}
