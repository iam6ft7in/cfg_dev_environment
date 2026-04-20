#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 08 - Copy Per-Project Scaffold Templates (diff-before-copy)

.DESCRIPTION
    Script Name : phase_08_scaffold_template.ps1
    Purpose     : Deploy the per-project scaffold from
                  $RepoRoot\templates\project\ to ~/.claude/templates/project/
                  while preserving any personalizations the user has made to
                  the deployed copy.

    For every file under the source tree, compare repo source against the
    deployed counterpart:
      - Missing on deployed side: CREATED (no drift risk).
      - Byte-identical: IN-SYNC, no action.
      - Differs: show unified diff and prompt per file with
        [o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit.
        Skipping preserves the deployed personalization.

    Deployed-only files (user customizations added under
    ~/.claude/templates/project/) are left alone and reported as KEPT.

    Non-interactive runs (piped stdin, scheduled tasks) skip every drifted
    file and warn on stderr. Re-run with -Force to overwrite every drifted
    file without prompting.

    Phase       : 08

.PARAMETER Force
    Overwrite every drifted file without prompting.

.NOTES
    Run with: pwsh -File scripts\phase_08_scaffold_template.ps1
    Force:    pwsh -File scripts\phase_08_scaffold_template.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]${Force}
)

Set-StrictMode -Version Latest
${ErrorActionPreference} = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Info    { param([string]${Msg}) Write-Host "  [INFO]  ${Msg}" -ForegroundColor Cyan   }
function Write-Pass    { param([string]${Msg}) Write-Host "  [PASS]  ${Msg}" -ForegroundColor Green  }
function Write-Warn    { param([string]${Msg}) Write-Host "  [WARN]  ${Msg}" -ForegroundColor Yellow }
function Write-Fail    { param([string]${Msg}) Write-Host "  [FAIL]  ${Msg}" -ForegroundColor Red    }
function Write-Section { param([string]${Msg}) Write-Host "`n=== ${Msg} ===" -ForegroundColor Cyan   }

function Exit-WithError {
    param([string]${Msg})
    Write-Fail ${Msg}
    Write-Host "`n[ABORTED] Phase 08 did not complete successfully." -ForegroundColor Red
    exit 1
}

function Show-FileDiff {
    param([string]${Src}, [string]${Dest})
    Write-Host "--- deployed: ${Dest}" -ForegroundColor DarkGray
    Write-Host "+++ repo:     ${Src}"  -ForegroundColor DarkGray
    & git --no-pager diff --no-index --color=auto -u -- ${Dest} ${Src}
}

function Read-FileAction {
    while ($true) {
        ${answer} = Read-Host "[o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit"
        ${trim}   = ${answer}.Trim()
        switch -CaseSensitive (${trim}) {
            ''  { return 'skip' }
            's' { return 'skip' }
            'S' { return 'skip' }
            'o' { return 'overwrite' }
            'O' { return 'overwrite' }
            'A' { return 'all-overwrite' }
            'N' { return 'all-skip' }
            'q' { return 'quit' }
            'Q' { return 'quit' }
            default { Write-Warn "Invalid choice: '${trim}'. Try again." }
        }
    }
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
${RepoRoot}       = Split-Path -Parent ${PSScriptRoot}
${SourceTemplDir} = Join-Path ${RepoRoot} 'templates\project'
${DestTemplDir}   = Join-Path ${HOME}     '.claude\templates\project'

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Phase 08 - Scaffold Templates"           -ForegroundColor Cyan
Write-Host "  Repo Root : ${RepoRoot}"                 -ForegroundColor Cyan
Write-Host "  Source    : ${SourceTemplDir}"           -ForegroundColor Cyan
Write-Host "  Dest      : ${DestTemplDir}"             -ForegroundColor Cyan
Write-Host "  Mode      : $(if (${Force}) { 'Force (overwrite all)' } else { 'Prompt on drift' })" -ForegroundColor Cyan
Write-Host "=======================================`n"  -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Verify source
# ---------------------------------------------------------------------------
Write-Section "Step 1: Verify source directory"

if (-not (Test-Path ${SourceTemplDir} -PathType Container)) {
    Exit-WithError "Source directory not found: ${SourceTemplDir}"
}
${SourceItems} = @(Get-ChildItem -Path ${SourceTemplDir} -Recurse -File -Force)
if (${SourceItems}.Count -eq 0) {
    Exit-WithError "Source directory is empty. Nothing to copy: ${SourceTemplDir}"
}
Write-Pass "Source contains $(${SourceItems}.Count) file(s)."

# ---------------------------------------------------------------------------
# Step 2 - Create destination
# ---------------------------------------------------------------------------
Write-Section "Step 2: Create destination directory"

if (Test-Path ${DestTemplDir} -PathType Container) {
    Write-Info "Exists: ${DestTemplDir}"
} else {
    try {
        New-Item -ItemType Directory -Path ${DestTemplDir} -Force | Out-Null
        Write-Pass "Created: ${DestTemplDir}"
    } catch {
        Exit-WithError "Failed to create destination directory '${DestTemplDir}': ${_}"
    }
}

# ---------------------------------------------------------------------------
# Step 3 - Per-file deploy decision
# ---------------------------------------------------------------------------
Write-Section "Step 3: Deploy scaffold (diff-before-copy)"

${Results} = [ordered]@{}
${autoOverwrite} = [bool]${Force}
${autoSkip}      = $false
${aborted}       = $false
${isTty}         = -not [Console]::IsInputRedirected

foreach (${f} in ${SourceItems}) {
    ${rel}   = [System.IO.Path]::GetRelativePath(${SourceTemplDir}, ${f}.FullName)
    ${label} = ${rel} -replace '\\','/'
    ${src}   = ${f}.FullName
    ${dest}  = Join-Path ${DestTemplDir} ${rel}

    if (${aborted}) {
        ${Results}[${label}] = 'SKIP (quit)'
        continue
    }

    ${destParent} = Split-Path -Parent ${dest}
    if (-not (Test-Path ${destParent} -PathType Container)) {
        New-Item -ItemType Directory -Path ${destParent} -Force | Out-Null
    }

    if (-not (Test-Path ${dest} -PathType Leaf)) {
        Copy-Item -Path ${src} -Destination ${dest} -Force
        Write-Pass "CREATED: ${label}"
        ${Results}[${label}] = 'CREATED'
        continue
    }

    ${srcHash}  = (Get-FileHash -Algorithm SHA256 -Path ${src}).Hash
    ${destHash} = (Get-FileHash -Algorithm SHA256 -Path ${dest}).Hash
    if (${srcHash} -eq ${destHash}) {
        Write-Info "IN-SYNC: ${label}"
        ${Results}[${label}] = 'IN-SYNC'
        continue
    }

    if (${autoOverwrite}) {
        Copy-Item -Path ${src} -Destination ${dest} -Force
        Write-Pass "OVERWRITE: ${label} (forced)"
        ${Results}[${label}] = 'OVERWRITE'
        continue
    }
    if (${autoSkip}) {
        Write-Info "SKIP: ${label} (batch-skip)"
        ${Results}[${label}] = 'SKIP'
        continue
    }
    if (-not ${isTty}) {
        Write-Warn "SKIP: ${label} (drift, stdin is not a TTY; -Force to overwrite)"
        ${Results}[${label}] = 'SKIP (non-TTY)'
        continue
    }

    Write-Host ""
    Write-Host "DRIFT: ${label}" -ForegroundColor Yellow
    Show-FileDiff -Src ${src} -Dest ${dest}
    ${action} = Read-FileAction

    switch (${action}) {
        'overwrite' {
            Copy-Item -Path ${src} -Destination ${dest} -Force
            Write-Pass "OVERWRITE: ${label}"
            ${Results}[${label}] = 'OVERWRITE'
        }
        'skip' {
            Write-Info "SKIP: ${label}"
            ${Results}[${label}] = 'SKIP'
        }
        'all-overwrite' {
            Copy-Item -Path ${src} -Destination ${dest} -Force
            Write-Pass "OVERWRITE: ${label} (All)"
            ${Results}[${label}] = 'OVERWRITE'
            ${autoOverwrite} = $true
        }
        'all-skip' {
            Write-Info "SKIP: ${label} (None)"
            ${Results}[${label}] = 'SKIP'
            ${autoSkip} = $true
        }
        'quit' {
            Write-Warn "QUIT: ${label} (user aborted; remaining files will be marked skipped)"
            ${Results}[${label}] = 'SKIP (quit)'
            ${aborted} = $true
        }
    }
}

# ---------------------------------------------------------------------------
# Step 4 - Report deployed-only files (KEPT)
# ---------------------------------------------------------------------------
Write-Section "Step 4: Deployed-only files (preserved)"

${srcSet} = @{}
foreach (${s} in ${SourceItems}) {
    ${rel} = [System.IO.Path]::GetRelativePath(${SourceTemplDir}, ${s}.FullName)
    ${srcSet}[${rel}] = $true
}

${keptCount} = 0
foreach (${d} in @(Get-ChildItem -Path ${DestTemplDir} -Recurse -File -Force)) {
    ${rel} = [System.IO.Path]::GetRelativePath(${DestTemplDir}, ${d}.FullName)
    if (-not ${srcSet}.ContainsKey(${rel})) {
        Write-Info "KEPT: $(${rel} -replace '\\','/')"
        ${keptCount}++
    }
}
if (${keptCount} -eq 0) {
    Write-Info "No deployed-only files."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Section "Summary"

${counts} = @{
    'IN-SYNC'        = 0
    'CREATED'        = 0
    'OVERWRITE'      = 0
    'SKIP'           = 0
    'SKIP (non-TTY)' = 0
    'SKIP (quit)'    = 0
}
foreach (${kv} in ${Results}.GetEnumerator()) {
    ${key} = ${kv}.Value
    if (${counts}.ContainsKey(${key})) {
        ${counts}[${key}]++
    }
}

Write-Host ""
Write-Host "  Files processed : $(${SourceItems}.Count)" -ForegroundColor Cyan
Write-Host "  In-sync         : $(${counts}['IN-SYNC'])"   -ForegroundColor Cyan
Write-Host "  Created         : $(${counts}['CREATED'])"   -ForegroundColor Green
Write-Host "  Overwritten     : $(${counts}['OVERWRITE'])" -ForegroundColor Green
${totalSkipped} = ${counts}['SKIP'] + ${counts}['SKIP (non-TTY)'] + ${counts}['SKIP (quit)']
Write-Host "  Skipped         : ${totalSkipped}" -ForegroundColor $(if (${totalSkipped} -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Kept (untracked): ${keptCount}" -ForegroundColor Cyan

if (${aborted}) {
    Write-Host "`n[RESULT] Phase 08 aborted by user. Re-run to continue." -ForegroundColor Yellow
    exit 2
}

Write-Host "`n[RESULT] Phase 08 completed. Drifted files were preserved unless overwritten." -ForegroundColor Green
exit 0
