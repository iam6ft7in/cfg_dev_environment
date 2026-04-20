#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 07b - Deploy Claude Skills and Helper Scripts

.DESCRIPTION
    Script Name : phase_07b_claude_skills_and_scripts.ps1
    Purpose     : Deploy the three external assets the /new-repo,
                  /migrate-repo, and /apply-standard skills call out to:
                    1. claude-skills\*\SKILL.md  -> ~/.claude/skills/*/SKILL.md
                    2. claude-scripts\setup_project_board.ps1
                         -> ~/.claude/scripts/setup_project_board.ps1
                    3. claude-scripts\regenerate_shortcuts.ps1
                         -> {projects_root}\shortcuts\regenerate.ps1

    Phase       : 07b (runs after Phase 07 Claude rules, before Phase 08)
    Exit Criteria:
        - Every SKILL.md in claude-skills\ has a copy at the matching path
          under ~/.claude/skills/
        - setup_project_board.ps1 is present in ~/.claude/scripts/
        - regenerate.ps1 is present in {projects_root}\shortcuts\

    Projects root resolution: reads ~/.claude/config.json (key:
    projects_root), which Phase 04 writes. Falls back to
    %USERPROFILE%\projects and warns if the config is missing.

.NOTES
    Run with: pwsh -File scripts\phase_07b_claude_skills_and_scripts.ps1
    Idempotent - safe to re-run after adding new skills.
#>

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

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
${RepoRoot}          = Split-Path -Parent ${PSScriptRoot}
${SourceSkillsDir}   = Join-Path ${RepoRoot} 'claude-skills'
${SourceScriptsDir}  = Join-Path ${RepoRoot} 'claude-scripts'
${DestSkillsDir}     = Join-Path ${HOME}     '.claude\skills'
${DestScriptsDir}    = Join-Path ${HOME}     '.claude\scripts'
${ConfigPath}        = Join-Path ${HOME}     '.claude\config.json'

# Resolve projects root via ~/.claude/config.json (set by Phase 04). The skills
# read the same key, so using it here keeps the shortcuts directory consistent
# with the rest of the environment.
${DefaultRoot} = Join-Path ${HOME} 'projects'
if (Test-Path ${ConfigPath}) {
    try {
        ${cfg} = Get-Content ${ConfigPath} -Raw -Encoding UTF8 | ConvertFrom-Json
        if (${cfg}.PSObject.Properties.Name -contains 'projects_root' `
                -and ${cfg}.projects_root) {
            ${ProjectsRoot} = ${cfg}.projects_root
        } else {
            Write-Warn "~/.claude/config.json exists but has no projects_root key. Falling back to ${DefaultRoot}."
            ${ProjectsRoot} = ${DefaultRoot}
        }
    } catch {
        Write-Warn "Could not parse ~/.claude/config.json (${_}). Falling back to ${DefaultRoot}."
        ${ProjectsRoot} = ${DefaultRoot}
    }
} else {
    Write-Warn "~/.claude/config.json not found - run Phase 04 first. Falling back to ${DefaultRoot}."
    ${ProjectsRoot} = ${DefaultRoot}
}
${ShortcutsDir} = Join-Path ${ProjectsRoot} 'shortcuts'

# Named helper scripts. Source filenames differ from destination filenames
# for regenerate_shortcuts.ps1 because the skills reference the destination
# as regenerate.ps1 (short, lives in its own shortcuts/ dir - the disambiguating
# prefix is only needed in the repo where it sits next to other scripts).
${BoardHelperSrc}  = Join-Path ${SourceScriptsDir} 'setup_project_board.ps1'
${BoardHelperDest} = Join-Path ${DestScriptsDir}   'setup_project_board.ps1'
${ShortcutsSrc}    = Join-Path ${SourceScriptsDir} 'regenerate_shortcuts.ps1'
${ShortcutsDest}   = Join-Path ${ShortcutsDir}     'regenerate.ps1'

${Results} = [ordered]@{}

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
Write-Host "=======================================`n"  -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Verify source trees
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

${SkillDirs} = Get-ChildItem -Path ${SourceSkillsDir} -Directory | Sort-Object Name
if (${SkillDirs}.Count -eq 0) {
    Exit-WithError "No skill subdirectories found under ${SourceSkillsDir}"
}
Write-Pass "Found $(${SkillDirs}.Count) skill(s) in source"

if (-not (Test-Path ${BoardHelperSrc} -PathType Leaf)) {
    Exit-WithError "Source helper missing: ${BoardHelperSrc}"
}
Write-Pass "Found: $(Split-Path -Leaf ${BoardHelperSrc})"

if (-not (Test-Path ${ShortcutsSrc} -PathType Leaf)) {
    Exit-WithError "Source helper missing: ${ShortcutsSrc}"
}
Write-Pass "Found: $(Split-Path -Leaf ${ShortcutsSrc})"

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
# Step 3 - Copy every skill
# ---------------------------------------------------------------------------
Write-Section "Step 3: Copy skill files"

# Each skill is a directory holding SKILL.md (and occasionally other assets
# like aliases.json for send-email). Copy the entire directory recursively so
# supporting files come along for the ride.
${CopiedSkills} = 0
${SkillFailures} = 0
foreach (${skill} in ${SkillDirs}) {
    ${src}        = ${skill}.FullName
    ${destSkill}  = Join-Path ${DestSkillsDir} ${skill}.Name
    ${skillMdSrc} = Join-Path ${src} 'SKILL.md'

    if (-not (Test-Path ${skillMdSrc} -PathType Leaf)) {
        Write-Warn "Skipping $(${skill}.Name): no SKILL.md in source dir"
        ${Results}["Skill_$(${skill}.Name)"] = 'SKIP'
        continue
    }

    try {
        if (Test-Path ${destSkill}) {
            Remove-Item -Path ${destSkill} -Recurse -Force
        }
        Copy-Item -Path ${src} -Destination ${destSkill} -Recurse -Force
        Write-Pass "Copied: $(${skill}.Name)"
        Write-Info "     -> ${destSkill}"
        ${Results}["Skill_$(${skill}.Name)"] = 'PASS'
        ${CopiedSkills}++
    } catch {
        Write-Fail "Failed to copy skill '$(${skill}.Name)': ${_}"
        ${Results}["Skill_$(${skill}.Name)"] = 'FAIL'
        ${SkillFailures}++
    }
}

# ---------------------------------------------------------------------------
# Step 4 - Copy helper scripts
# ---------------------------------------------------------------------------
Write-Section "Step 4: Copy helper scripts"

function Copy-Helper {
    param(
        [Parameter(Mandatory)][string]${Src},
        [Parameter(Mandatory)][string]${Dest},
        [Parameter(Mandatory)][string]${Label}
    )
    try {
        Copy-Item -Path ${Src} -Destination ${Dest} -Force
        Write-Pass "Copied: ${Label}"
        Write-Info "     -> ${Dest}"
        return 'PASS'
    } catch {
        Write-Fail "Failed to copy ${Label}: ${_}"
        return 'FAIL'
    }
}

${Results}['BoardHelper']     = Copy-Helper -Src ${BoardHelperSrc}  -Dest ${BoardHelperDest}  -Label 'setup_project_board.ps1'
${Results}['ShortcutsHelper'] = Copy-Helper -Src ${ShortcutsSrc}    -Dest ${ShortcutsDest}    -Label 'regenerate.ps1 (shortcuts)'

# ---------------------------------------------------------------------------
# Step 5 - Verification pass
# ---------------------------------------------------------------------------
Write-Section "Step 5: Verify deployed files"

${verifyFail} = $false

foreach (${skill} in ${SkillDirs}) {
    ${expected} = Join-Path ${DestSkillsDir} (Join-Path ${skill}.Name 'SKILL.md')
    if (Test-Path ${expected} -PathType Leaf) {
        Write-Pass "SKILL.md present: $(${skill}.Name)"
    } else {
        # A skill dir without a SKILL.md in source was intentionally skipped
        # above and should not fail verification.
        ${srcSkillMd} = Join-Path ${skill}.FullName 'SKILL.md'
        if (Test-Path ${srcSkillMd}) {
            Write-Fail "Missing after copy: ${expected}"
            ${verifyFail} = $true
        }
    }
}

foreach (${pair} in @(
    @{ Path = ${BoardHelperDest}; Label = 'setup_project_board.ps1' },
    @{ Path = ${ShortcutsDest};   Label = 'regenerate.ps1'          }
)) {
    if (Test-Path ${pair}.Path -PathType Leaf) {
        Write-Pass "$(${pair}.Label) present at $(${pair}.Path)"
    } else {
        Write-Fail "Missing after copy: $(${pair}.Path)"
        ${verifyFail} = $true
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Section "Summary"

${PassCount} = @(${Results}.Values | Where-Object { ${_} -eq 'PASS' }).Count
${FailCount} = @(${Results}.Values | Where-Object { ${_} -eq 'FAIL' }).Count
${SkipCount} = @(${Results}.Values | Where-Object { ${_} -eq 'SKIP' }).Count

Write-Host "`n  Skills copied       : ${CopiedSkills} / $(${SkillDirs}.Count)" -ForegroundColor Cyan
Write-Host "  Skills skipped      : ${SkipCount}"                              -ForegroundColor Cyan
Write-Host "  Helper scripts      : 2 (board + shortcuts)"                     -ForegroundColor Cyan
Write-Host "  Checks passed       : ${PassCount}"                              -ForegroundColor Green
${failColor} = if (${FailCount} -gt 0) { 'Red' } else { 'Green' }
Write-Host "  Checks failed       : ${FailCount}"                              -ForegroundColor ${failColor}

if (${FailCount} -gt 0 -or ${verifyFail} -or ${SkillFailures} -gt 0) {
    Write-Host "`n[RESULT] Phase 07b completed with errors. Review failures above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[RESULT] Phase 07b completed successfully. Skills and helper scripts deployed." -ForegroundColor Green
    exit 0
}
