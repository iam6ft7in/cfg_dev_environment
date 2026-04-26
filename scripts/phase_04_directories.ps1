#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 4: Project Directory Structure

.DESCRIPTION
    Script Name : phase_04_directories.ps1
    Purpose     : Prompt for the projects root directory, create the project
                  directory tree and supporting dot-directories (~/.git-templates,
                  ~/.claude, ~/.cspell, ~/.oh-my-posh), write the chosen root to
                  ~/.claude/config.json, and report whether each directory was
                  newly created or already existed.
    Phase       : 4 of 12
    Exit Criteria: All required directories exist on disk.

.NOTES
    Run with: pwsh -File scripts\phase_04_directories.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function Write-Info    { param([string]$Msg) Write-Host "  [INFO] $Msg"    -ForegroundColor Cyan    }
function Write-Pass    { param([string]$Msg) Write-Host "  [PASS] $Msg"    -ForegroundColor Green   }
function Write-Warn    { param([string]$Msg) Write-Host "  [WARN] $Msg"    -ForegroundColor Yellow  }
function Write-Fail    { param([string]$Msg) Write-Host "  [FAIL] $Msg"    -ForegroundColor Red     }
function Write-Section { param([string]$Msg) Write-Host "`n==> $Msg"       -ForegroundColor White   }

function Abort {
    param([string]$Msg)
    Write-Fail $Msg
    Write-Host "`nScript aborted. Fix the issue above and re-run Phase 4.`n" -ForegroundColor Red
    exit 1
}

# Ensure a directory exists; returns 'Created' or 'Exists'
function Ensure-Directory {
    param([string]$Path)
    if (Test-Path $Path) {
        return 'Exists'
    }
    try {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        return 'Created'
    } catch {
        throw "Failed to create directory '$Path': $_"
    }
}

# ---------------------------------------------------------------------------
# Section header
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 4, Project Directory Structure"  -ForegroundColor Cyan
Write-Host "  Repo root: $RepoRoot"                   -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$Results  = [ordered]@{}
$anyFail  = $false

# ---------------------------------------------------------------------------
# Prompt for projects root
# ---------------------------------------------------------------------------

$DefaultRoot = Join-Path $HOME 'projects'
Write-Host "Where should your GitHub repos live?" -ForegroundColor White
Write-Host "  Default: ${DefaultRoot}" -ForegroundColor DarkGray
${InputRoot} = Read-Host "Projects root (press Enter to accept default)"
${ProjectsRoot} = if ([string]::IsNullOrWhiteSpace(${InputRoot})) {
    $DefaultRoot
} else {
    ${InputRoot}.TrimEnd('\').TrimEnd('/')
}
Write-Info "Projects root set to: ${ProjectsRoot}"

# ---------------------------------------------------------------------------
# Directory definitions
# ---------------------------------------------------------------------------

$Directories = [ordered]@{
    # Project roots, derived from the user-chosen projects root
    "${ProjectsRoot}\personal"          = 'Personal GitHub projects'
    "${ProjectsRoot}\client"           = 'Client GitHub projects'
    "${ProjectsRoot}\arduino\upstream"  = 'Arduino/ArduPilot upstream forks'
    "${ProjectsRoot}\arduino\custom"    = 'Arduino/ArduPilot custom work'

    # Git template directory (used by Phase 6 hooks)
    "$HOME\.git-templates"                      = 'Git template root'
    "$HOME\.git-templates\hooks"                = 'Git template hooks (Phase 6)'

    # Claude configuration directories
    "$HOME\.claude"                             = 'Claude root config'
    "$HOME\.claude\rules"                       = 'Claude rule files (Phase 7)'
    "$HOME\.claude\skills"                      = 'Claude skill files (Phase 7b)'
    "$HOME\.claude\scripts"                     = 'Claude helper scripts (Phase 7b)'
    "$HOME\.claude\shortcuts"                   = 'Claude-launcher shortcuts (Phase 7b)'
    "$HOME\.claude\templates"                   = 'Claude project templates (Phase 8)'

    # CSpell custom dictionary directory
    "$HOME\.cspell"                             = 'CSpell custom dictionary (Phase 9)'

    # Oh My Posh theme directory
    "$HOME\.oh-my-posh"                         = 'Oh My Posh theme files (Phase 10)'
}

# ---------------------------------------------------------------------------
# Create directories
# ---------------------------------------------------------------------------

Write-Section "Creating directories"

$colW = 55
Write-Host ("{0,-$colW} {1,-10} {2}" -f 'Path', 'Status', 'Purpose') -ForegroundColor White
Write-Host ("{0,-$colW} {1,-10} {2}" -f ('-' * ($colW - 1)), '----------', '-------') -ForegroundColor White

foreach ($kv in $Directories.GetEnumerator()) {
    $dirPath = $kv.Key
    $purpose = $kv.Value
    try {
        $status = Ensure-Directory -Path $dirPath
        $color  = if ($status -eq 'Created') { 'Green' } else { 'Cyan' }
        Write-Host ("{0,-$colW} {1,-10} {2}" -f $dirPath, $status, $purpose) -ForegroundColor $color
        $Results[$dirPath] = $status
    } catch {
        Write-Host ("{0,-$colW} {1,-10} {2}" -f $dirPath, 'FAILED', $purpose) -ForegroundColor Red
        Write-Warn "  Error: $_"
        $Results[$dirPath] = 'FAILED'
        $anyFail = $true
    }
}

# ---------------------------------------------------------------------------
# Verification pass
# ---------------------------------------------------------------------------

Write-Section "Verification"

$verifyFail = $false
foreach ($dirPath in $Directories.Keys) {
    if (-not (Test-Path $dirPath)) {
        Write-Fail "Missing after creation attempt: $dirPath"
        $verifyFail = $true
    }
}

if (-not $verifyFail) {
    Write-Pass "All $($Directories.Count) directories verified on disk."
}

# ---------------------------------------------------------------------------
# Write ~/.claude/config.json
# ---------------------------------------------------------------------------

Write-Section "Writing ~/.claude/config.json"

${ClaudeConfigPath} = Join-Path $HOME '.claude\config.json'
try {
    # Preserve any existing keys; only set projects_root.
    ${Config} = if (Test-Path ${ClaudeConfigPath}) {
        Get-Content ${ClaudeConfigPath} -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        [PSCustomObject]@{}
    }
    ${Config} | Add-Member -MemberType NoteProperty -Name 'projects_root' `
                           -Value ${ProjectsRoot} -Force
    ${Config} | ConvertTo-Json -Depth 5 |
        Set-Content -Path ${ClaudeConfigPath} -Encoding UTF8
    Write-Pass "Config written: ${ClaudeConfigPath}"
    Write-Info "  projects_root = ${ProjectsRoot}"
} catch {
    Write-Warn "Could not write config.json: $_"
    Write-Warn "Skills and scripts will fall back to %USERPROFILE%\projects."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 4, Summary"                       -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$created = @($Results.Values | Where-Object { $_ -eq 'Created' }).Count
$existed = @($Results.Values | Where-Object { $_ -eq 'Exists'  }).Count
$failed  = @($Results.Values | Where-Object { $_ -eq 'FAILED'  }).Count

Write-Host "  Directories created : $created" -ForegroundColor Green
Write-Host "  Already existed     : $existed" -ForegroundColor Cyan
if ($failed -gt 0) {
    Write-Host "  Failed              : $failed" -ForegroundColor Red
}

Write-Host ""

if ($anyFail -or $verifyFail) {
    Write-Fail "One or more directories could not be created. Fix errors above and re-run Phase 4."
    exit 1
} else {
    Write-Pass "All directories are in place. Proceed to Phase 5 (global .gitignore)."
    exit 0
}
