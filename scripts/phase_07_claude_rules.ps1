#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 07 - Copy Claude Rules

.DESCRIPTION
    Script Name : phase_07_claude_rules.ps1
    Purpose     : Copy Claude rules from $RepoRoot\claude-rules\ to ~/.claude/rules\
    Phase       : 07
    Exit Criteria:
        - All expected .md rule files exist in $RepoRoot\claude-rules\
        - ~/.claude/rules\ exists and contains all copied files
        - Each file copy is confirmed and reported

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
    Write-Host "`n[ABORTED] Phase 07 did not complete successfully." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$RepoRoot        = Split-Path -Parent $PSScriptRoot
$SourceRulesDir  = Join-Path $RepoRoot 'claude-rules'
$DestRulesDir    = Join-Path $HOME '.claude\rules'

$ExpectedFiles = @(
    'core.md'
    'arduino.md'
    'python.md'
    'shell.md'
    'assembly.md'
    'vbscript.md'
    'command_paths.md'
    'powershell.md'
    'ssh.md'
)

# Track results for summary
$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Phase 07 - Copy Claude Rules"          -ForegroundColor Cyan
Write-Host "  Repo Root : $RepoRoot"                 -ForegroundColor Cyan
Write-Host "  Source    : $SourceRulesDir"           -ForegroundColor Cyan
Write-Host "  Dest      : $DestRulesDir"             -ForegroundColor Cyan
Write-Host "=======================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Verify source directory and expected files
# ---------------------------------------------------------------------------
Write-Section "Step 1: Verify source directory"

if (-not (Test-Path $SourceRulesDir -PathType Container)) {
    Exit-WithError "Source directory not found: $SourceRulesDir"
}
Write-Pass "Source directory exists: $SourceRulesDir"

$MissingFiles = @()
foreach ($FileName in $ExpectedFiles) {
    $FilePath = Join-Path $SourceRulesDir $FileName
    if (Test-Path $FilePath -PathType Leaf) {
        Write-Pass "Found: $FileName"
        $Results["Verify_$FileName"] = 'PASS'
    } else {
        Write-Fail "Missing: $FileName"
        $Results["Verify_$FileName"] = 'FAIL'
        $MissingFiles += $FileName
    }
}

if ($MissingFiles.Count -gt 0) {
    Exit-WithError "Missing expected rule files: $($MissingFiles -join ', '). Cannot continue."
}

# ---------------------------------------------------------------------------
# Step 2 - Create destination directory
# ---------------------------------------------------------------------------
Write-Section "Step 2: Create destination directory"

if (Test-Path $DestRulesDir -PathType Container) {
    Write-Info "Destination already exists: $DestRulesDir"
} else {
    try {
        New-Item -ItemType Directory -Path $DestRulesDir -Force | Out-Null
        Write-Pass "Created: $DestRulesDir"
    } catch {
        Exit-WithError "Failed to create destination directory '$DestRulesDir': $_"
    }
}
$Results['CreateDestDir'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 3 & 4 - Copy each file and report source/destination
# ---------------------------------------------------------------------------
Write-Section "Step 3 & 4: Copy rule files"

$CopiedCount = 0
foreach ($FileName in $ExpectedFiles) {
    $Src  = Join-Path $SourceRulesDir $FileName
    $Dest = Join-Path $DestRulesDir   $FileName
    try {
        Copy-Item -Path $Src -Destination $Dest -Force
        Write-Pass "Copied: $Src"
        Write-Info "     -> $Dest"
        $Results["Copy_$FileName"] = 'PASS'
        $CopiedCount++
    } catch {
        Write-Fail "Failed to copy '$FileName': $_"
        $Results["Copy_$FileName"] = 'FAIL'
    }
}

# ---------------------------------------------------------------------------
# Step 5 - List all files now in destination
# ---------------------------------------------------------------------------
Write-Section "Step 5: Files now in $DestRulesDir"

$DestFiles = Get-ChildItem -Path $DestRulesDir -File | Sort-Object Name
if ($DestFiles.Count -eq 0) {
    Write-Warn "No files found in destination directory."
} else {
    foreach ($F in $DestFiles) {
        $SizeKB = [math]::Round($F.Length / 1KB, 1)
        Write-Info "$($F.Name)  ($SizeKB KB)  Last modified: $($F.LastWriteTime)"
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Section "Summary"

$PassCount = @($Results.Values | Where-Object { $_ -eq 'PASS' }).Count
$FailCount = @($Results.Values | Where-Object { $_ -eq 'FAIL' }).Count

Write-Host "`n  Files expected  : $($ExpectedFiles.Count)"   -ForegroundColor Cyan
Write-Host "  Files copied    : $CopiedCount"               -ForegroundColor Cyan
Write-Host "  Files in dest   : $($DestFiles.Count)"        -ForegroundColor Cyan
Write-Host "  Checks passed   : $PassCount"                 -ForegroundColor Green
Write-Host "  Checks failed   : $FailCount"                 -ForegroundColor $(if ($FailCount -gt 0) { 'Red' } else { 'Green' })

if ($FailCount -gt 0) {
    Write-Host "`n[RESULT] Phase 07 completed with errors. Review failures above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[RESULT] Phase 07 completed successfully. All Claude rules are in place." -ForegroundColor Green
    exit 0
}
