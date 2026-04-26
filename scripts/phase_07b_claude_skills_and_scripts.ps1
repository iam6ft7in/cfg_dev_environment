#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 07b - Deploy Claude Skills and Helper Scripts (diff-before-copy)

.DESCRIPTION
    Script Name : phase_07b_claude_skills_and_scripts.ps1
    Purpose     : Deploy the three external assets the /new-repo,
                  /migrate-repo, and /apply-standard skills call out to:
                    1. claude-skills\*\*  -> ~/.claude/skills/*/*
                    2. claude-scripts\setup_project_board.ps1
                         -> ~/.claude/scripts/setup_project_board.ps1
                    3. claude-scripts\regenerate_shortcuts.ps1
                         -> ~\.claude\shortcuts\regenerate.ps1

    For every file involved, compare repo source against its deployed
    counterpart before writing:
      - Missing on deployed side: CREATED (no drift risk).
      - Byte-identical: IN-SYNC, no action.
      - Differs: show unified diff and prompt per file with
        [o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit.
        Skipping preserves the deployed personalization.

    Deployed-only files that have no source counterpart (user customizations
    added to a skill directory) are left alone and logged as KEPT.

    Non-interactive runs (piped stdin, scheduled tasks) skip every drifted
    file and warn on stderr. Re-run with -Force to overwrite every drifted
    file without prompting.

    Phase       : 07b (runs after Phase 07 rules, before Phase 08 templates)

.PARAMETER Force
    Overwrite every drifted file without prompting.

.NOTES
    Run with: pwsh -File scripts\phase_07b_claude_skills_and_scripts.ps1
    Force:    pwsh -File scripts\phase_07b_claude_skills_and_scripts.ps1 -Force
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
    Write-Host "`n[ABORTED] Phase 07b did not complete successfully." -ForegroundColor Red
    exit 1
}

# Same diff renderer as Phase 7; Phase 1 guarantees git on PATH.
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
${RepoRoot}          = Split-Path -Parent ${PSScriptRoot}
${SourceSkillsDir}   = Join-Path ${RepoRoot} 'claude-skills'
${SourceScriptsDir}  = Join-Path ${RepoRoot} 'claude-scripts'
${DestSkillsDir}     = Join-Path ${HOME}     '.claude\skills'
${DestScriptsDir}    = Join-Path ${HOME}     '.claude\scripts'
${ShortcutsDir}      = Join-Path ${HOME}     '.claude\shortcuts'

${BoardHelperSrc}  = Join-Path ${SourceScriptsDir} 'setup_project_board.ps1'
${BoardHelperDest} = Join-Path ${DestScriptsDir}   'setup_project_board.ps1'
${ShortcutsSrc}    = Join-Path ${SourceScriptsDir} 'regenerate_shortcuts.ps1'
${ShortcutsDest}   = Join-Path ${ShortcutsDir}     'regenerate.ps1'

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Phase 07b - Claude Skills and Helper Scripts" -ForegroundColor Cyan
Write-Host "  Repo Root      : ${RepoRoot}"             -ForegroundColor Cyan
Write-Host "  Skills source  : ${SourceSkillsDir}"      -ForegroundColor Cyan
Write-Host "  Skills dest    : ${DestSkillsDir}"        -ForegroundColor Cyan
Write-Host "  Scripts source : ${SourceScriptsDir}"     -ForegroundColor Cyan
Write-Host "  Scripts dest   : ${DestScriptsDir}"       -ForegroundColor Cyan
Write-Host "  Shortcuts dest : ${ShortcutsDir}"         -ForegroundColor Cyan
Write-Host "  Mode           : $(if (${Force}) { 'Force (overwrite all)' } else { 'Prompt on drift' })" -ForegroundColor Cyan
Write-Host "=======================================`n"  -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Verify sources
# ---------------------------------------------------------------------------
Write-Section "Step 1: Verify source directories"

if (-not (Test-Path ${SourceSkillsDir} -PathType Container)) {
    Exit-WithError "Source skills directory not found: ${SourceSkillsDir}"
}
Write-Pass "Source skills directory exists: ${SourceSkillsDir}"

if (-not (Test-Path ${SourceScriptsDir} -PathType Container)) {
    Exit-WithError "Source scripts directory not found: ${SourceScriptsDir}"
}
Write-Pass "Source scripts directory exists: ${SourceScriptsDir}"

${SkillDirs} = @(Get-ChildItem -Path ${SourceSkillsDir} -Directory | Sort-Object Name)
if (${SkillDirs}.Count -eq 0) {
    Exit-WithError "No skill subdirectories found under ${SourceSkillsDir}"
}
Write-Pass "Found $(${SkillDirs}.Count) skill(s) in source"

if (-not (Test-Path ${BoardHelperSrc} -PathType Leaf)) {
    Exit-WithError "Source helper missing: ${BoardHelperSrc}"
}
if (-not (Test-Path ${ShortcutsSrc} -PathType Leaf)) {
    Exit-WithError "Source helper missing: ${ShortcutsSrc}"
}
Write-Pass "Both helper scripts present in source"

# ---------------------------------------------------------------------------
# Step 2 - Create destination directories
# ---------------------------------------------------------------------------
Write-Section "Step 2: Create destination directories"

foreach (${dir} in @(${DestSkillsDir}, ${DestScriptsDir}, ${ShortcutsDir})) {
    if (Test-Path ${dir} -PathType Container) {
        Write-Info "Exists: ${dir}"
    } else {
        try {
            New-Item -ItemType Directory -Path ${dir} -Force | Out-Null
            Write-Pass "Created: ${dir}"
        } catch {
            Exit-WithError "Failed to create '${dir}': ${_}"
        }
    }
}

# ---------------------------------------------------------------------------
# Step 3 - Build the (source, dest, label) work list
# ---------------------------------------------------------------------------
Write-Section "Step 3: Enumerate source files"

# Skill files: walk each skill dir recursively; dest mirrors relative path
# under ~/.claude/skills/{skill}/. Labels use forward slashes for display
# parity with the bash variant and git output.
${pairs} = [System.Collections.Generic.List[object]]::new()

foreach (${skill} in ${SkillDirs}) {
    ${skillSrcRoot}  = ${skill}.FullName
    ${skillDestRoot} = Join-Path ${DestSkillsDir} ${skill}.Name

    ${skillFiles} = @(Get-ChildItem -Path ${skillSrcRoot} -Recurse -File -Force)
    if (${skillFiles}.Count -eq 0) {
        Write-Warn "Skipping $(${skill}.Name): source dir has no files"
        continue
    }

    # Require SKILL.md specifically; skills without one are malformed.
    ${hasSkillMd} = @(${skillFiles} | Where-Object {
        ${_}.Name -eq 'SKILL.md' -and ${_}.DirectoryName -eq ${skillSrcRoot}
    })
    if (${hasSkillMd}.Count -eq 0) {
        Write-Warn "Skipping $(${skill}.Name): no SKILL.md at skill root"
        continue
    }

    foreach (${f} in ${skillFiles}) {
        ${rel} = [System.IO.Path]::GetRelativePath(${skillSrcRoot}, ${f}.FullName)
        ${pairs}.Add([pscustomobject]@{
            Src   = ${f}.FullName
            Dest  = Join-Path ${skillDestRoot} ${rel}
            Label = "skills/$(${skill}.Name)/$(${rel} -replace '\\','/')"
        })
    }
}

# Helper scripts: two entries with a name remap for regenerate_shortcuts.
${pairs}.Add([pscustomobject]@{
    Src   = ${BoardHelperSrc}
    Dest  = ${BoardHelperDest}
    Label = 'scripts/setup_project_board.ps1'
})
${pairs}.Add([pscustomobject]@{
    Src   = ${ShortcutsSrc}
    Dest  = ${ShortcutsDest}
    Label = 'shortcuts/regenerate.ps1'
})

Write-Pass "$(${pairs}.Count) file(s) enumerated for deployment"

# ---------------------------------------------------------------------------
# Step 4 - Per-file deploy decision
# ---------------------------------------------------------------------------
Write-Section "Step 4: Deploy (diff-before-copy)"

${Results} = [ordered]@{}
${autoOverwrite} = [bool]${Force}
${autoSkip}      = $false
${aborted}       = $false
${isTty}         = -not [Console]::IsInputRedirected

foreach (${pair} in ${pairs}) {
    ${label} = ${pair}.Label
    ${src}   = ${pair}.Src
    ${dest}  = ${pair}.Dest

    if (${aborted}) {
        ${Results}[${label}] = 'SKIP (quit)'
        continue
    }

    # Make sure the dest's parent directory exists; a nested skill file
    # may need its skill dir created on first run.
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
# Step 5 - Report deployed-only files per skill (KEPT)
# ---------------------------------------------------------------------------
Write-Section "Step 5: Deployed-only files (preserved)"

${keptCount} = 0
foreach (${skill} in ${SkillDirs}) {
    ${skillDestRoot} = Join-Path ${DestSkillsDir} ${skill}.Name
    if (-not (Test-Path ${skillDestRoot} -PathType Container)) { continue }

    # Compute the set of relative paths present in source for this skill.
    ${skillSrcRoot}  = ${skill}.FullName
    ${srcSet} = @{}
    foreach (${f} in @(Get-ChildItem -Path ${skillSrcRoot} -Recurse -File -Force)) {
        ${rel} = [System.IO.Path]::GetRelativePath(${skillSrcRoot}, ${f}.FullName)
        ${srcSet}[${rel}] = $true
    }

    foreach (${d} in @(Get-ChildItem -Path ${skillDestRoot} -Recurse -File -Force)) {
        ${rel} = [System.IO.Path]::GetRelativePath(${skillDestRoot}, ${d}.FullName)
        if (-not ${srcSet}.ContainsKey(${rel})) {
            Write-Info "KEPT: skills/$(${skill}.Name)/$(${rel} -replace '\\','/')"
            ${keptCount}++
        }
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
Write-Host "  Files processed : $(${pairs}.Count)" -ForegroundColor Cyan
Write-Host "  In-sync         : $(${counts}['IN-SYNC'])"    -ForegroundColor Cyan
Write-Host "  Created         : $(${counts}['CREATED'])"    -ForegroundColor Green
Write-Host "  Overwritten     : $(${counts}['OVERWRITE'])"  -ForegroundColor Green
${totalSkipped} = ${counts}['SKIP'] + ${counts}['SKIP (non-TTY)'] + ${counts}['SKIP (quit)']
Write-Host "  Skipped         : ${totalSkipped}"            -ForegroundColor $(if (${totalSkipped} -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Kept (untracked): ${keptCount}"               -ForegroundColor Cyan

if (${aborted}) {
    Write-Host "`n[RESULT] Phase 07b aborted by user. Re-run to continue." -ForegroundColor Yellow
    exit 2
}

Write-Host "`n[RESULT] Phase 07b completed. Drifted files were preserved unless overwritten." -ForegroundColor Green
exit 0
