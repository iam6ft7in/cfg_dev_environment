#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 08 - Copy Per-Project Scaffold Templates

.DESCRIPTION
    Script Name : phase_08_scaffold_template.ps1
    Purpose     : Copy per-project scaffold templates from $RepoRoot\templates\project\
                  to ~/.claude/templates\project\
    Phase       : 08
    Exit Criteria:
        - $RepoRoot\templates\project\ exists and is non-empty
        - ~/.claude/templates\project\ exists and contains all copied items
        - File count and top-level listing are reported

.NOTES
    Run from any location; $RepoRoot is derived from $PSScriptRoot.
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
    Write-Host "`n[ABORTED] Phase 08 did not complete successfully." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$RepoRoot        = Split-Path -Parent $PSScriptRoot
$SourceTemplDir  = Join-Path $RepoRoot 'templates\project'
$DestTemplDir    = Join-Path $HOME '.claude\templates\project'

# Track results
$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Phase 08 - Scaffold Templates"          -ForegroundColor Cyan
Write-Host "  Repo Root : $RepoRoot"                  -ForegroundColor Cyan
Write-Host "  Source    : $SourceTemplDir"            -ForegroundColor Cyan
Write-Host "  Dest      : $DestTemplDir"              -ForegroundColor Cyan
Write-Host "=======================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Verify source directory exists and is non-empty
# ---------------------------------------------------------------------------
Write-Section "Step 1: Verify source directory"

if (-not (Test-Path $SourceTemplDir -PathType Container)) {
    Exit-WithError "Source directory not found: $SourceTemplDir"
}
Write-Pass "Source directory exists: $SourceTemplDir"

$SourceItems = Get-ChildItem -Path $SourceTemplDir -Recurse -File
if ($SourceItems.Count -eq 0) {
    Exit-WithError "Source directory is empty. Nothing to copy: $SourceTemplDir"
}
Write-Pass "Source contains $($SourceItems.Count) file(s)."
$Results['VerifySource'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 2 - Create destination directory if needed
# ---------------------------------------------------------------------------
Write-Section "Step 2: Create destination directory"

if (Test-Path $DestTemplDir -PathType Container) {
    Write-Info "Destination already exists: $DestTemplDir"
} else {
    try {
        New-Item -ItemType Directory -Path $DestTemplDir -Force | Out-Null
        Write-Pass "Created: $DestTemplDir"
    } catch {
        Exit-WithError "Failed to create destination directory '$DestTemplDir': $_"
    }
}
$Results['CreateDestDir'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 3 - Copy entire templates\project\ directory recursively
# ---------------------------------------------------------------------------
Write-Section "Step 3: Copy template directory (recurse)"

try {
    Copy-Item -Path "$SourceTemplDir\*" -Destination $DestTemplDir -Recurse -Force
    Write-Pass "Copy-Item completed without errors."
    $Results['CopyTemplates'] = 'PASS'
} catch {
    Write-Fail "Copy failed: $_"
    $Results['CopyTemplates'] = 'FAIL'
    Exit-WithError "Failed to copy templates to '$DestTemplDir'."
}

# ---------------------------------------------------------------------------
# Step 4 - Report count of files copied
# ---------------------------------------------------------------------------
Write-Section "Step 4: File count verification"

$DestFiles = Get-ChildItem -Path $DestTemplDir -Recurse -File
$SourceCount = $SourceItems.Count
$DestCount   = $DestFiles.Count

Write-Info "Source file count : $SourceCount"
Write-Info "Dest file count   : $DestCount"

if ($DestCount -ge $SourceCount) {
    Write-Pass "All $SourceCount source file(s) accounted for in destination."
    $Results['FileCount'] = 'PASS'
} else {
    Write-Warn "Destination has fewer files ($DestCount) than source ($SourceCount). Some files may not have copied."
    $Results['FileCount'] = 'WARN'
}

# ---------------------------------------------------------------------------
# Step 5 - List top-level files/dirs in destination
# ---------------------------------------------------------------------------
Write-Section "Step 5: Top-level contents of $DestTemplDir"

$TopLevel = Get-ChildItem -Path $DestTemplDir | Sort-Object Name
if ($TopLevel.Count -eq 0) {
    Write-Warn "Destination appears empty after copy - something went wrong."
} else {
    foreach ($Item in $TopLevel) {
        $TypeTag = if ($Item.PSIsContainer) { '[DIR] ' } else { '[FILE]' }
        Write-Info "$TypeTag $($Item.Name)"
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Section "Summary"

$PassCount = @($Results.Values | Where-Object { $_ -eq 'PASS' }).Count
$WarnCount = @($Results.Values | Where-Object { $_ -eq 'WARN' }).Count
$FailCount = @($Results.Values | Where-Object { $_ -eq 'FAIL' }).Count

Write-Host "`n  Source files    : $SourceCount"       -ForegroundColor Cyan
Write-Host "  Dest files      : $DestCount"           -ForegroundColor Cyan
Write-Host "  Checks passed   : $PassCount"           -ForegroundColor Green
Write-Host "  Warnings        : $WarnCount"           -ForegroundColor $(if ($WarnCount -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Checks failed   : $FailCount"           -ForegroundColor $(if ($FailCount -gt 0) { 'Red' } else { 'Green' })

if ($FailCount -gt 0) {
    Write-Host "`n[RESULT] Phase 08 completed with errors. Review failures above." -ForegroundColor Red
    exit 1
} elseif ($WarnCount -gt 0) {
    Write-Host "`n[RESULT] Phase 08 completed with warnings. Verify destination manually." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n[RESULT] Phase 08 completed successfully. Scaffold templates are in place." -ForegroundColor Green
    exit 0
}
