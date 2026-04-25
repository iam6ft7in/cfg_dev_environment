#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 07 - Deploy Claude Rules and Stacks (diff-before-copy)

.DESCRIPTION
    Script Name : phase_07_claude_rules.ps1
    Purpose     : Deploy Claude rule and stack files from the repo to the
                  per-user Claude config directory, respecting any local
                  personalizations the user has made to the deployed copy.

    Two categories are deployed, in order:
      - rules  : $RepoRoot\claude-rules\   -> ~/.claude/rules\
                 Auto-loaded by Claude Code for universal rules or via
                 extension triggers.
      - stacks : $RepoRoot\claude-stacks\  -> ~/.claude/stacks\
                 Opt-in. Do NOT auto-load. Repos @-import them from
                 CLAUDE.md when needed.

    For each expected file in each category:
      - If the deployed copy does not exist: create it (no drift risk).
      - If the deployed copy is byte-identical to the repo source: no-op,
        report IN-SYNC.
      - If the deployed copy differs: show a unified diff and prompt the
        user per file: [o]verwrite / [s]kip (default) / [A]ll / [N]one /
        [q]uit. Skipping preserves the deployed personalization.

    Non-TTY runs (piped stdin, CI, scheduled tasks) skip every drifted file
    and warn on stderr. Re-run with -Force to override and overwrite every
    drifted file without prompting. An "All" / "None" choice applies to the
    remainder of the current category and carries over into the next.

    Phase       : 07
    Exit Criteria:
        - Every expected rule and stack file resolves to one of:
          IN-SYNC, CREATED, OVERWRITE, SKIP (user), SKIP (non-TTY).

.PARAMETER Force
    Overwrite every drifted file without prompting. Equivalent to answering
    "All" to every per-file prompt. The prior always-overwrite behavior.

.NOTES
    Run with: pwsh -File scripts\phase_07_claude_rules.ps1
    Force:    pwsh -File scripts\phase_07_claude_rules.ps1 -Force
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
    Write-Host "`n[ABORTED] Phase 07 did not complete successfully." -ForegroundColor Red
    exit 1
}

# Show a unified diff between two files using git, which Phase 1 guarantees
# is on PATH. --no-index lets us diff arbitrary paths outside any repo.
# --color=auto defers to git's detection so piped output stays plain.
function Show-RuleDiff {
    param([string]${Src}, [string]${Dest})
    Write-Host "--- deployed: ${Dest}" -ForegroundColor DarkGray
    Write-Host "+++ repo:     ${Src}"  -ForegroundColor DarkGray
    & git --no-pager diff --no-index --color=auto -u -- ${Dest} ${Src}
    # git exits 1 when files differ, 0 when identical. Either is fine here.
}

# Prompt returns one of: 'overwrite' | 'skip' | 'all-overwrite' |
# 'all-skip' | 'quit'. Invalid input re-prompts.
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
# Paths and categories
# ---------------------------------------------------------------------------
# Categories are deployed in the order listed. Each entry maps one repo
# source directory to one destination directory with its own expected-file
# roster. Adding a new category (e.g., claude-snippets) is a one-entry
# addition here; no other code change required.
${RepoRoot} = Split-Path -Parent ${PSScriptRoot}

${Categories} = @(
    [ordered]@{
        Name     = 'rules'
        Source   = Join-Path ${RepoRoot} 'claude-rules'
        Dest     = Join-Path ${HOME}     '.claude\rules'
        Expected = @(
            'core.md'
            'other.md'
            'arduino.md'
            'python.md'
            'shell.md'
            'assembly.md'
            'vbscript.md'
            'command_paths.md'
            'powershell.md'
            'ssh.md'
        )
    }
    [ordered]@{
        Name     = 'stacks'
        Source   = Join-Path ${RepoRoot} 'claude-stacks'
        Dest     = Join-Path ${HOME}     '.claude\stacks'
        Expected = @(
            'vmware.md'
        )
    }
)

# Results is keyed by "category:filename" so the summary can group them and
# no entry ever collides across categories.
${Results} = [ordered]@{}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Host "  Phase 07 - Deploy Claude Rules and Stacks"     -ForegroundColor Cyan
Write-Host "  Repo Root : ${RepoRoot}"                       -ForegroundColor Cyan
foreach (${cat} in ${Categories}) {
    Write-Host ("  {0,-8} : {1} -> {2}" -f ${cat}.Name, ${cat}.Source, ${cat}.Dest) -ForegroundColor Cyan
}
Write-Host "  Mode      : $(if (${Force}) { 'Force (overwrite all)' } else { 'Prompt on drift' })" -ForegroundColor Cyan
Write-Host "==============================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Verify source directories and expected files
# ---------------------------------------------------------------------------
Write-Section "Step 1: Verify source directories"

foreach (${cat} in ${Categories}) {
    ${name} = ${cat}.Name
    ${src}  = ${cat}.Source

    if (-not (Test-Path ${src} -PathType Container)) {
        Exit-WithError "Source directory for '${name}' not found: ${src}"
    }
    Write-Pass "Source directory exists (${name}): ${src}"

    ${missing} = @()
    foreach (${fname} in ${cat}.Expected) {
        ${srcPath} = Join-Path ${src} ${fname}
        if (Test-Path ${srcPath} -PathType Leaf) {
            Write-Pass "Found (${name}): ${fname}"
        } else {
            Write-Fail "Missing (${name}): ${fname}"
            ${missing} += ${fname}
        }
    }

    if (${missing}.Count -gt 0) {
        Exit-WithError "Missing expected files in source (${name}): $(${missing} -join ', ')"
    }
}

# ---------------------------------------------------------------------------
# Step 2 - Create destination directories
# ---------------------------------------------------------------------------
Write-Section "Step 2: Create destination directories"

foreach (${cat} in ${Categories}) {
    ${dest} = ${cat}.Dest
    if (Test-Path ${dest} -PathType Container) {
        Write-Info "Exists: ${dest}"
    } else {
        try {
            New-Item -ItemType Directory -Path ${dest} -Force | Out-Null
            Write-Pass "Created: ${dest}"
        } catch {
            Exit-WithError "Failed to create destination directory '${dest}': ${_}"
        }
    }
}

# ---------------------------------------------------------------------------
# Step 3 - Per-file deploy decision
# ---------------------------------------------------------------------------
Write-Section "Step 3: Deploy files (diff-before-copy)"

# Decisions that short-circuit subsequent prompts once the user picks an
# "All" or "None" option. Force starts in auto-overwrite mode. These flags
# persist across categories: if the user picks "All" during rules, stacks
# inherits that, which matches the user's evident intent.
${autoOverwrite} = [bool]${Force}
${autoSkip}      = $false
${aborted}       = $false

# Detect whether stdin is interactive. [Console]::IsInputRedirected returns
# true when stdin is a pipe or file, so "not redirected" is our TTY signal.
${isTty} = -not [Console]::IsInputRedirected

foreach (${cat} in ${Categories}) {
    ${catName} = ${cat}.Name
    ${src}     = ${cat}.Source
    ${dest}    = ${cat}.Dest

    Write-Host ""
    Write-Host "-- Category: ${catName}" -ForegroundColor White

    foreach (${fname} in ${cat}.Expected) {
        ${key}      = "${catName}:${fname}"
        ${srcFile}  = Join-Path ${src}  ${fname}
        ${destFile} = Join-Path ${dest} ${fname}

        if (${aborted}) {
            ${Results}[${key}] = 'SKIP (quit)'
            continue
        }

        # Brand-new file on the deployed side: always deploy, no drift risk.
        if (-not (Test-Path ${destFile} -PathType Leaf)) {
            Copy-Item -Path ${srcFile} -Destination ${destFile} -Force
            Write-Pass "CREATED: ${catName}/${fname}"
            ${Results}[${key}] = 'CREATED'
            continue
        }

        # SHA-256 hash compare is cheap and unambiguous; line-ending
        # differences are genuine drift worth surfacing, not false positives
        # to hide.
        ${srcHash}  = (Get-FileHash -Algorithm SHA256 -Path ${srcFile}).Hash
        ${destHash} = (Get-FileHash -Algorithm SHA256 -Path ${destFile}).Hash

        if (${srcHash} -eq ${destHash}) {
            Write-Info "IN-SYNC: ${catName}/${fname}"
            ${Results}[${key}] = 'IN-SYNC'
            continue
        }

        # Drift detected. Pick an action based on mode.
        if (${autoOverwrite}) {
            Copy-Item -Path ${srcFile} -Destination ${destFile} -Force
            Write-Pass "OVERWRITE: ${catName}/${fname} (forced)"
            ${Results}[${key}] = 'OVERWRITE'
            continue
        }
        if (${autoSkip}) {
            Write-Info "SKIP: ${catName}/${fname} (batch-skip)"
            ${Results}[${key}] = 'SKIP'
            continue
        }
        if (-not ${isTty}) {
            Write-Warn "SKIP: ${catName}/${fname} (drift detected, stdin is not a TTY; re-run with -Force to overwrite)"
            ${Results}[${key}] = 'SKIP (non-TTY)'
            continue
        }

        # Interactive: show the diff and prompt.
        Write-Host ""
        Write-Host "DRIFT: ${catName}/${fname}" -ForegroundColor Yellow
        Show-RuleDiff -Src ${srcFile} -Dest ${destFile}
        ${action} = Read-FileAction

        switch (${action}) {
            'overwrite' {
                Copy-Item -Path ${srcFile} -Destination ${destFile} -Force
                Write-Pass "OVERWRITE: ${catName}/${fname}"
                ${Results}[${key}] = 'OVERWRITE'
            }
            'skip' {
                Write-Info "SKIP: ${catName}/${fname}"
                ${Results}[${key}] = 'SKIP'
            }
            'all-overwrite' {
                Copy-Item -Path ${srcFile} -Destination ${destFile} -Force
                Write-Pass "OVERWRITE: ${catName}/${fname} (All)"
                ${Results}[${key}] = 'OVERWRITE'
                ${autoOverwrite} = $true
            }
            'all-skip' {
                Write-Info "SKIP: ${catName}/${fname} (None)"
                ${Results}[${key}] = 'SKIP'
                ${autoSkip} = $true
            }
            'quit' {
                Write-Warn "QUIT: ${catName}/${fname} (user aborted; remaining files will be marked skipped)"
                ${Results}[${key}] = 'SKIP (quit)'
                ${aborted} = $true
            }
        }
    }
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
Write-Host "  Per-file status:" -ForegroundColor White
foreach (${kv} in ${Results}.GetEnumerator()) {
    ${name}   = ${kv}.Key
    ${status} = ${kv}.Value
    ${color}  = switch -Wildcard (${status}) {
        'IN-SYNC'       { 'Cyan'   }
        'CREATED'       { 'Green'  }
        'OVERWRITE'     { 'Green'  }
        'SKIP*'         { 'Yellow' }
        default         { 'White'  }
    }
    Write-Host ("    {0,-28} {1}" -f ${name}, ${status}) -ForegroundColor ${color}
}

Write-Host ""
Write-Host "  In-sync     : $(${counts}['IN-SYNC'])"        -ForegroundColor Cyan
Write-Host "  Created     : $(${counts}['CREATED'])"        -ForegroundColor Green
Write-Host "  Overwritten : $(${counts}['OVERWRITE'])"      -ForegroundColor Green
${totalSkipped} = ${counts}['SKIP'] + ${counts}['SKIP (non-TTY)'] + ${counts}['SKIP (quit)']
Write-Host "  Skipped     : ${totalSkipped}"                -ForegroundColor $(if (${totalSkipped} -gt 0) { 'Yellow' } else { 'Green' })

if (${aborted}) {
    Write-Host "`n[RESULT] Phase 07 aborted by user. Re-run to continue." -ForegroundColor Yellow
    exit 2
}

Write-Host "`n[RESULT] Phase 07 completed. Drifted files were preserved unless overwritten." -ForegroundColor Green
exit 0
