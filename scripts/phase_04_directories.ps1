#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 4: Project Directory Structure

.DESCRIPTION
    Script Name : phase_04_directories.ps1
    Purpose     : Read projects_root and github_username from
                  ~/.claude/config.json (written by Phase 3), create the
                  project directory tree under that root and the supporting
                  dot-directories (~/.git-templates, ~/.claude, ~/.cspell,
                  ~/.oh-my-posh), and report whether each directory was newly
                  created or already existed. Aborts if Phase 3 has not run.
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
# Read projects_root and github_username from ~/.claude/config.json
# ---------------------------------------------------------------------------

${ClaudeConfigPath} = Join-Path $HOME '.claude\config.json'
if (-not (Test-Path ${ClaudeConfigPath})) {
    Abort "~/.claude/config.json not found. Run Phase 3 first; it prompts for projects_root and github_username and persists both to config."
}

${Config} = Get-Content ${ClaudeConfigPath} -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not (${Config}.PSObject.Properties.Name -contains 'projects_root') `
        -or [string]::IsNullOrWhiteSpace(${Config}.projects_root)) {
    Abort "projects_root missing from ${ClaudeConfigPath}. Re-run Phase 3."
}
if (-not (${Config}.PSObject.Properties.Name -contains 'github_username') `
        -or [string]::IsNullOrWhiteSpace(${Config}.github_username)) {
    Abort "github_username missing from ${ClaudeConfigPath}. Re-run Phase 3."
}

${ProjectsRoot}   = ${Config}.projects_root
${GithubUsername} = ${Config}.github_username

Write-Info "Projects root  : ${ProjectsRoot}"
Write-Info "GitHub username: ${GithubUsername}"

# ---------------------------------------------------------------------------
# Directory definitions
# ---------------------------------------------------------------------------

$Directories = [ordered]@{
    # Project roots, derived from the values stored by Phase 3
    "${ProjectsRoot}\${GithubUsername}\public"        = 'Personal public GitHub projects'
    "${ProjectsRoot}\${GithubUsername}\private"       = 'Personal private GitHub projects'
    "${ProjectsRoot}\${GithubUsername}\collaborative" = 'Personal collaborative GitHub projects'
    "${ProjectsRoot}\client"                          = 'Client GitHub projects'
    "${ProjectsRoot}\arduino\upstream"                = 'Arduino/ArduPilot upstream forks'
    "${ProjectsRoot}\arduino\custom"                  = 'Arduino/ArduPilot custom work'

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
