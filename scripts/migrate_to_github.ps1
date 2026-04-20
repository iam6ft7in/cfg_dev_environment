#Requires -Version 7.0
<#
.SYNOPSIS
    Migrate an existing project into the gold standard GitHub dev environment.

.DESCRIPTION
    Script Name : migrate_to_github.ps1
    Purpose     : Copies an existing project to the personal projects root
                  (read from ~/.claude/config.json, falls back to
                  %USERPROFILE%\projects\personal), initializes git, adds missing
                  scaffold files, creates a private GitHub repo under the
                  github-personal SSH alias, makes an initial signed commit,
                  pushes, and applies a branch protection ruleset.

                  Designed to be reusable for any project migration.

    -WhatIf     : Preview every action without making any changes.
    -Validate   : Run all prerequisite checks and exit — no migration.

.PARAMETER SourcePath
    Full path to the existing project directory.
    Example: %USERPROFILE%\OneDrive\AI\Projects\MyProject

.PARAMETER RepoName
    GitHub repo name and local directory name. Lowercase, snake_case or hyphen.
    Example: my_project

.PARAMETER Description
    Short description for the GitHub repo.

.PARAMETER Topics
    Array of GitHub topics (max 20, lowercase, no spaces).
    Example: @("powershell","hyper-v","infrastructure")

.PARAMETER TargetRoot
    Parent directory for the migrated repo. Defaults to the personal projects root
    from ~/.claude/config.json, or %USERPROFILE%\projects\personal if not configured.

.PARAMETER GitHubAlias
    SSH config host alias to use for the remote. Default: github-personal

.PARAMETER WhatIf
    Preview all actions without making any changes.

.PARAMETER Validate
    Run prerequisite checks and show what would be added/skipped, then exit.

.EXAMPLE
    # Dry run
    pwsh -File scripts\migrate_to_github.ps1 `
        -SourcePath "%USERPROFILE%\OneDrive\AI\Projects\MyProject" `
        -RepoName "my_project" `
        -Description "Short description of the project" `
        -Topics "powershell","automation" `
        -WhatIf

    # Actual migration
    pwsh -File scripts\migrate_to_github.ps1 `
        -SourcePath "%USERPROFILE%\OneDrive\AI\Projects\MyProject" `
        -RepoName "my_project" `
        -Description "Short description of the project" `
        -Topics "powershell","automation"

.NOTES
    Prerequisites: Phases 1-12 complete, gh authenticated, Bitwarden vault unlocked.
    Pass -Topics as bare comma-separated strings, not @(...), when using pwsh -File.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]${SourcePath},

    [Parameter(Mandatory)]
    [string]${RepoName},

    [Parameter(Mandatory)]
    [string]${Description},

    [string[]]${Topics} = @(),

    [string]${TargetRoot} = '',

    [string]${GitHubAlias} = 'github-personal',

    [switch]${WhatIf},

    [switch]${Validate}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function Write-Info    { param([string]${Msg}) Write-Host "  [INFO]   ${Msg}" -ForegroundColor Cyan    }
function Write-Pass    { param([string]${Msg}) Write-Host "  [PASS]   ${Msg}" -ForegroundColor Green   }
function Write-Warn    { param([string]${Msg}) Write-Host "  [WARN]   ${Msg}" -ForegroundColor Yellow  }
function Write-Fail    { param([string]${Msg}) Write-Host "  [FAIL]   ${Msg}" -ForegroundColor Red     }
function Write-Section { param([string]${Msg}) Write-Host "`n==> ${Msg}"      -ForegroundColor White   }
function Write-WhatIf  { param([string]${Msg}) Write-Host "  [WHATIF] ${Msg}" -ForegroundColor Magenta }
function Write-Skip    { param([string]${Msg}) Write-Host "  [SKIP]   ${Msg}" -ForegroundColor DarkGray }

function Abort {
    param([string]${Msg})
    Write-Fail ${Msg}
    Write-Host "`nMigration aborted. Fix the issue above and re-run.`n" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

# Resolve TargetRoot from ~/.claude/config.json when not supplied explicitly.
# This keeps the script portable — no hardcoded username in the default.
if ([string]::IsNullOrEmpty(${TargetRoot})) {
    ${ClaudeConfig} = Join-Path $HOME '.claude\config.json'
    if (Test-Path ${ClaudeConfig}) {
        ${ProjectsRoot} = (Get-Content ${ClaudeConfig} -Raw -Encoding UTF8 |
                           ConvertFrom-Json).projects_root
        ${TargetRoot} = Join-Path ${ProjectsRoot} 'personal'
    } else {
        ${TargetRoot} = Join-Path $HOME 'projects\personal'
    }
}

${TargetPath} = Join-Path ${TargetRoot} ${RepoName}
${ModeLabel}  = if (${WhatIf}) { ' [DRY RUN — no changes will be made]' } elseif (${Validate}) { ' [VALIDATE ONLY]' } else { '' }

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  migrate_to_github.ps1${ModeLabel}"           -ForegroundColor Cyan
Write-Host "  Source : ${SourcePath}"                       -ForegroundColor Cyan
Write-Host "  Target : ${TargetPath}"                       -ForegroundColor Cyan
Write-Host "  Repo   : ${RepoName}"                         -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

${ValidationResults} = [ordered]@{}

# ===========================================================================
# SECTION 1 — Prerequisites and Validation
# ===========================================================================

Write-Section "Section 1: Prerequisite and pre-flight checks"

# --- 1.1 PowerShell version -------------------------------------------------
${psVer} = $PSVersionTable.PSVersion
if (${psVer}.Major -ge 7) {
    Write-Pass "PowerShell ${psVer}"
    ${ValidationResults}['PowerShell 7+'] = 'PASS'
} else {
    Write-Fail "PowerShell ${psVer} (7+ required)"
    ${ValidationResults}['PowerShell 7+'] = 'FAIL'
}

# --- 1.2 git on PATH --------------------------------------------------------
try {
    ${gitVer} = (git --version 2>&1) -join ''
    Write-Pass "git found: ${gitVer}"
    ${ValidationResults}['git on PATH'] = 'PASS'
} catch {
    Write-Fail "git not found on PATH"
    ${ValidationResults}['git on PATH'] = 'FAIL'
}

# --- 1.3 gh on PATH ---------------------------------------------------------
try {
    ${ghVer} = (gh --version 2>&1 | Select-Object -First 1) -join ''
    Write-Pass "gh found: ${ghVer}"
    ${ValidationResults}['gh on PATH'] = 'PASS'
} catch {
    Write-Fail "gh not found on PATH"
    ${ValidationResults}['gh on PATH'] = 'FAIL'
}

# --- 1.4 gh auth status -----------------------------------------------------
try {
    ${authOutput} = gh auth status 2>&1
    ${authStr}    = ${authOutput} -join ' '
    if (${authStr} -match 'Logged in') {
        ${githubUser} = (gh api user --jq '.login' 2>&1).Trim()
        Write-Pass "gh authenticated as: ${githubUser}"
        ${ValidationResults}['gh authenticated'] = 'PASS'
    } else {
        Write-Fail "gh is not authenticated. Run: gh auth login"
        ${ValidationResults}['gh authenticated'] = 'FAIL'
        ${githubUser} = 'UNKNOWN'
    }
} catch {
    Write-Fail "gh auth check failed: $_"
    ${ValidationResults}['gh authenticated'] = 'FAIL'
    ${githubUser} = 'UNKNOWN'
}

# --- 1.5 delete_repo scope --------------------------------------------------
try {
    ${scopeOutput} = gh auth status 2>&1 | Where-Object { $_ -match 'Token scopes' }
    if (${scopeOutput} -match 'delete_repo') {
        Write-Pass "gh has delete_repo scope"
        ${ValidationResults}['gh delete_repo scope'] = 'PASS'
    } else {
        Write-Warn "gh is missing delete_repo scope (non-blocking, but cleanup on failure will need it)"
        Write-Info "  To add: gh auth refresh -h github.com -s delete_repo"
        ${ValidationResults}['gh delete_repo scope'] = 'WARN'
    }
} catch {
    Write-Warn "Could not verify gh token scopes: $_"
    ${ValidationResults}['gh delete_repo scope'] = 'WARN'
}

# --- 1.6 Source directory exists --------------------------------------------
if (Test-Path ${SourcePath} -PathType Container) {
    Write-Pass "Source directory exists: ${SourcePath}"
    ${ValidationResults}['Source exists'] = 'PASS'
} else {
    Write-Fail "Source directory not found: ${SourcePath}"
    ${ValidationResults}['Source exists'] = 'FAIL'
}

# --- 1.7 Source is NOT already a git repo -----------------------------------
${sourceGitDir} = Join-Path ${SourcePath} '.git'
if (-not (Test-Path ${sourceGitDir})) {
    Write-Pass "Source is not a git repository (clean for migration)"
    ${ValidationResults}['Source not git'] = 'PASS'
} else {
    Write-Warn "Source already has a .git directory — will migrate as-is (remote will be added/updated)"
    ${ValidationResults}['Source not git'] = 'WARN'
}

# --- 1.8 Target directory does NOT already exist ----------------------------
if (-not (Test-Path ${TargetPath})) {
    Write-Pass "Target path is free: ${TargetPath}"
    ${ValidationResults}['Target free'] = 'PASS'
} else {
    Write-Warn "Target already exists: ${TargetPath}"
    Write-Info "  If a previous migration partially ran, remove it first:"
    Write-Info "  Remove-Item -Recurse -Force '${TargetPath}'"
    ${ValidationResults}['Target free'] = 'WARN'
}

# --- 1.9 GitHub repo does NOT already exist ---------------------------------
if (${githubUser} -ne 'UNKNOWN') {
    ${repoCheck} = gh repo view "${githubUser}/${RepoName}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Pass "GitHub repo ${githubUser}/${RepoName} does not exist yet"
        ${ValidationResults}['GitHub repo free'] = 'PASS'
    } else {
        Write-Warn "GitHub repo ${githubUser}/${RepoName} already exists"
        Write-Info "  If intentional, the script will skip creation and use the existing repo."
        ${ValidationResults}['GitHub repo free'] = 'WARN'
    }
} else {
    Write-Warn "Cannot check GitHub repo — gh not authenticated"
    ${ValidationResults}['GitHub repo free'] = 'WARN'
}

# --- 1.10 Git signing configured --------------------------------------------
try {
    ${signingKey} = git config --global user.signingkey 2>&1
    ${gpgFormat}  = git config --global gpg.format    2>&1
    if (${signingKey} -and ${gpgFormat} -eq 'ssh') {
        Write-Pass "Git signing configured: ${gpgFormat} / ${signingKey}"
        ${ValidationResults}['Git signing'] = 'PASS'
    } else {
        Write-Warn "Git signing may not be fully configured (run Phase 3)"
        ${ValidationResults}['Git signing'] = 'WARN'
    }
} catch {
    Write-Warn "Could not verify git signing config: $_"
    ${ValidationResults}['Git signing'] = 'WARN'
}

# --- 1.11 SSH agent has keys (Bitwarden check) ------------------------------
try {
    ${agentKeys} = & 'C:\Windows\System32\OpenSSH\ssh-add.exe' -L 2>&1
    if (${agentKeys} -match 'ssh-ed25519') {
        Write-Pass "SSH agent is serving keys (Bitwarden appears unlocked)"
        ${ValidationResults}['SSH agent / Bitwarden'] = 'PASS'
    } else {
        Write-Warn "No SSH keys found in agent. Is Bitwarden open and vault unlocked?"
        ${ValidationResults}['SSH agent / Bitwarden'] = 'WARN'
    }
} catch {
    Write-Warn "Could not query SSH agent: $_"
    ${ValidationResults}['SSH agent / Bitwarden'] = 'WARN'
}

# --- 1.12 Target parent directory exists ------------------------------------
if (Test-Path ${TargetRoot} -PathType Container) {
    Write-Pass "Target parent exists: ${TargetRoot}"
    ${ValidationResults}['Target root exists'] = 'PASS'
} else {
    Write-Fail "Target root missing: ${TargetRoot} (run Phase 4)"
    ${ValidationResults}['Target root exists'] = 'FAIL'
}

# --- 1.13 Scan for scaffold files: show what would be added or skipped ------
Write-Section "Section 1b: Scaffold file gap analysis"

${ScaffoldFiles} = [ordered]@{
    '.gitignore'                         = 'Generated (PowerShell platform)'
    '.gitattributes'                     = 'Standard text normalization'
    '.editorconfig'                      = '88-char ruler, spaces, UTF-8'
    'CONTRIBUTING.md'                    = 'Contribution guidelines template'
    'CHANGELOG.md'                       = 'Keep-a-changelog template'
    'SECURITY.md'                        = 'Security policy template'
    '.github/pull_request_template.md'   = 'PR template'
}

${FilesToAdd}  = [System.Collections.Generic.List[string]]::new()
${FilesToSkip} = [System.Collections.Generic.List[string]]::new()

foreach (${file} in ${ScaffoldFiles}.Keys) {
    ${full} = Join-Path ${SourcePath} ${file}
    if (Test-Path ${full}) {
        Write-Skip "${file} (already exists — will not overwrite)"
        ${FilesToSkip}.Add(${file})
    } else {
        Write-Info "${file} → will add: $(${ScaffoldFiles}[${file}])"
        ${FilesToAdd}.Add(${file})
    }
}

# --- 1.14 Detect files that should be gitignored ---------------------------
Write-Section "Section 1c: Gitignore candidate detection"

${GitignoreCandidates} = @()
${allSourceFiles} = Get-ChildItem ${SourcePath} -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

foreach (${f} in ${allSourceFiles}) {
    ${ext}  = ${f}.Extension.ToLower()
    ${name} = ${f}.Name.ToLower()
    if (${ext} -in @('.log', '.pdf', '.docx', '.xlsx') -or
        ${name} -match '^old_.*\.bat$' -or
        ${name} -match '^\d{4}-\d{2}-\d{2}-\d{6}-.*\.txt$') {
        Write-Info "Will gitignore candidate: $(${f}.Name) (${ext})"
        ${GitignoreCandidates} += ${f}.Name
    }
}

if (${GitignoreCandidates}.Count -eq 0) {
    Write-Info "No obvious gitignore candidates detected."
}

# --- Validation summary -----------------------------------------------------
Write-Section "Validation Summary"

${colW}  = 35
${fails} = 0
${warns} = 0
Write-Host ("{0,-${colW}} {1}" -f 'Check', 'Result') -ForegroundColor White
Write-Host ("{0,-${colW}} {1}" -f ('-' * (${colW}-1)), '------') -ForegroundColor White

foreach (${kv} in ${ValidationResults}.GetEnumerator()) {
    ${color} = switch (${kv}.Value) {
        'PASS' { 'Green'  }
        'WARN' { 'Yellow' }
        'FAIL' { 'Red'    }
        default { 'White' }
    }
    Write-Host ("{0,-${colW}} {1}" -f ${kv}.Key, ${kv}.Value) -ForegroundColor ${color}
    if (${kv}.Value -eq 'FAIL') { ${fails}++ }
    if (${kv}.Value -eq 'WARN') { ${warns}++ }
}

Write-Host ""
Write-Host "  Files to add   : $(${FilesToAdd}.Count)"  -ForegroundColor Cyan
Write-Host "  Files to skip  : $(${FilesToSkip}.Count)" -ForegroundColor Cyan
Write-Host "  Gitignore hits : $(${GitignoreCandidates}.Count)" -ForegroundColor Cyan

if (${fails} -gt 0) {
    Abort "Validation failed with ${fails} error(s). Fix the items above before migrating."
}
if (${warns} -gt 0) {
    Write-Warn "${warns} warning(s). Review above before proceeding."
}

# ---------------------------------------------------------------------------
# Exit points for -Validate and -WhatIf
# ---------------------------------------------------------------------------

if (${Validate}) {
    Write-Host "`n[VALIDATE] All checks complete. Re-run without -Validate to migrate.`n" -ForegroundColor Green
    exit 0
}

if (${WhatIf}) {
    Write-Section "WhatIf Preview — actions that WOULD run"
    Write-WhatIf "Copy '${SourcePath}' -> '${TargetPath}'"
    Write-WhatIf "cd '${TargetPath}'"
    Write-WhatIf "git init --initial-branch=main"
    Write-WhatIf "Clean stale paths from .claude/settings.local.json (if present)"
    foreach (${f} in ${FilesToAdd}) {
        Write-WhatIf "Add scaffold: ${f}"
    }
    Write-WhatIf "gh repo create ${RepoName} --private --description '...'"
    Write-WhatIf "git remote add origin git@${GitHubAlias}:${githubUser}/${RepoName}.git"
    Write-WhatIf "git add ."
    Write-WhatIf "git commit -m 'chore: migrate ${RepoName} to gold standard github environment'"
    Write-WhatIf "git push --set-upstream origin main"
    Write-WhatIf "Apply branch ruleset (deletion, force-push, signatures)"
    if (${Topics}.Count -gt 0) {
        Write-WhatIf "Apply topics: $(${Topics} -join ', ')"
    }
    Write-Host "`n[WHATIF] No changes made. Remove -WhatIf to execute.`n" -ForegroundColor Magenta
    exit 0
}

# ===========================================================================
# SECTION 2 — Copy source to target
# ===========================================================================

Write-Section "Section 2: Copy project to target location"

New-Item -ItemType Directory -Path ${TargetPath} -Force | Out-Null
Write-Info "Created: ${TargetPath}"

# Copy all files except any stale .git directory
Get-ChildItem ${SourcePath} -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
    Copy-Item $_.FullName -Destination ${TargetPath} -Recurse -Force
}
Write-Pass "Copied: ${SourcePath} -> ${TargetPath}"

# ===========================================================================
# SECTION 3 — Initialize git
# ===========================================================================

Write-Section "Section 3: Initialize git repository"

Push-Location ${TargetPath}
try {
    if (-not (Test-Path (Join-Path ${TargetPath} '.git'))) {
        git init --initial-branch=main 2>&1 | Out-Null
        Write-Pass "git init (branch: main)"
    } else {
        Write-Info "git already initialized (source had .git) — skipping init"
    }
} catch {
    Abort "git init failed: $_"
} finally {
    Pop-Location
}

# ===========================================================================
# SECTION 4 — Clean stale paths in .claude/settings.local.json
# ===========================================================================

Write-Section "Section 4: Clean .claude/settings.local.json"

${settingsPath} = Join-Path ${TargetPath} '.claude\settings.local.json'
if (Test-Path ${settingsPath}) {
    try {
        ${settingsRaw}  = Get-Content ${settingsPath} -Raw -Encoding UTF8
        ${settingsJson} = ${settingsRaw} | ConvertFrom-Json -AsHashtable

        if (${settingsJson}.ContainsKey('permissions') -and
            ${settingsJson}['permissions'].ContainsKey('allow')) {

            ${original} = ${settingsJson}['permissions']['allow']

            # Remove any Bash() entries that contain the OLD OneDrive source path
            # (stale mkdir / setup commands from when the project lived in OneDrive)
            ${cleaned} = ${original} | Where-Object {
                $_ -notmatch [regex]::Escape(${SourcePath}) -and
                $_ -notmatch [regex]::Escape('OneDrive\\Documents\\AI\\Projects') -and
                $_ -notmatch 'mkdir'
            }

            # Wrap in @() so .Count works even when Where-Object returns $null or
            # a single non-array item (PowerShell unwraps single-element results)
            if (@(${cleaned}).Count -lt @(${original}).Count) {
                ${removed} = @(${original}).Count - @(${cleaned}).Count
                ${settingsJson}['permissions']['allow'] = ${cleaned}
                ${settingsJson} | ConvertTo-Json -Depth 10 |
                    Set-Content ${settingsPath} -Encoding UTF8
                Write-Pass "Cleaned ${removed} stale path permission(s) from settings.local.json"
            } else {
                Write-Info "settings.local.json: no stale paths found"
            }
        } else {
            Write-Info "settings.local.json: no permissions.allow block found"
        }
    } catch {
        Write-Warn "Could not parse settings.local.json: $_ (leaving unchanged)"
    }
} else {
    Write-Info "No .claude/settings.local.json found — skipping"
}

# ===========================================================================
# SECTION 5 — Generate .gitignore
# ===========================================================================

Write-Section "Section 5: Generate .gitignore"

${gitignorePath} = Join-Path ${TargetPath} '.gitignore'
if (Test-Path ${gitignorePath}) {
    Write-Skip ".gitignore already exists — not overwriting"
} else {
    ${gitignoreContent} = @"
# =============================================================================
# .gitignore — PowerShell Project
# Generated by migrate_to_github.ps1
# =============================================================================

# --- Runtime logs and execution transcripts ---
*.log
# Dated transcript format: 2026-04-01-125249-Script-Name.txt
????-??-??-??????-*.txt

# --- Generated documentation (built from scripts, not committed source) ---
*.pdf
*.docx
*.xlsx

# --- Archived/old batch files (machine-local, not source code) ---
OLD_*.bat

# --- Windows OS artifacts ---
Thumbs.db
ehthumbs.db
Desktop.ini
`$RECYCLE.BIN/
*.lnk

# --- Editor artifacts ---
.vs/
*.suo
*.user

# --- Secrets and credentials ---
.env
.env.local
*.env.local
secrets.*
*.key
*.pem
"@

    Set-Content -Path ${gitignorePath} -Value ${gitignoreContent} -Encoding UTF8
    Write-Pass "Generated: .gitignore"
}

# ===========================================================================
# SECTION 6 — Add missing scaffold files
# ===========================================================================

Write-Section "Section 6: Add missing scaffold files"

# Helper: write a file only if it doesn't exist
function Add-ScaffoldFile {
    param([string]${RelPath}, [string]${Content})
    ${full} = Join-Path ${TargetPath} ${RelPath}
    ${dir}  = Split-Path ${full} -Parent
    if (Test-Path ${full}) {
        Write-Skip "${RelPath} (already exists)"
        return
    }
    if (-not (Test-Path ${dir})) {
        New-Item -ItemType Directory -Path ${dir} -Force | Out-Null
    }
    Set-Content -Path ${full} -Value ${Content} -Encoding UTF8
    Write-Pass "Added: ${RelPath}"
}

Add-ScaffoldFile '.gitattributes' @"
# .gitattributes — Normalize line endings to LF in the repository.
# Windows checkouts remain LF (autocrlf=input in .gitconfig).
* text=auto eol=lf

# Binary files — do not attempt line ending conversion
*.pdf  binary
*.docx binary
*.xlsx binary
*.png  binary
*.jpg  binary
*.ico  binary
*.zip  binary
*.exe  binary
*.dll  binary
"@

Add-ScaffoldFile '.editorconfig' @"
# .editorconfig — Editor configuration for consistent formatting.
# See https://editorconfig.org

root = true

[*]
charset             = utf-8
end_of_line         = lf
insert_final_newline  = true
trim_trailing_whitespace = true
indent_style        = space
indent_size         = 4
max_line_length     = 88

[*.md]
trim_trailing_whitespace = false
max_line_length     = off

[*.{yml,yaml,json}]
indent_size         = 2

[Makefile]
indent_style        = tab
"@

Add-ScaffoldFile 'CONTRIBUTING.md' @"
# Contributing

This is a personal project. External contributions are not expected, but
issues and suggestions are welcome.

## Making Changes

Branches follow the convention:
  feature/short-description
  fix/short-description
  chore/short-description
  docs/short-description

## Commit Messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org/):

    type(scope): short description

    Types: feat fix docs style refactor perf test chore ci revert
    Max subject line length: 88 characters
    Use imperative mood: "add support" not "adds support"

## Pull Requests

Use the PR template. Squash and merge.
"@

Add-ScaffoldFile 'CHANGELOG.md' @"
# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]
"@

Add-ScaffoldFile 'SECURITY.md' @"
# Security Policy

## Reporting a Vulnerability

This is a personal project. If you discover a security issue, please open
a GitHub issue with the label **security**.

Do not include credential material or exploit details in public issues.
"@

Add-ScaffoldFile '.github/pull_request_template.md' @"
## Summary

<!-- What does this PR do and why? -->

## Changes

-

## Test plan

- [ ] Tested locally
- [ ] No secrets or credentials introduced
- [ ] Commit messages follow Conventional Commits

## Related issues

<!-- Closes #N -->
"@

# ===========================================================================
# SECTION 7 — Create GitHub repo
# ===========================================================================

Write-Section "Section 7: Create GitHub repository"

${repoExists} = gh repo view "${githubUser}/${RepoName}" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Info "GitHub repo ${githubUser}/${RepoName} already exists — skipping creation"
} else {
    ${createOutput} = gh repo create ${RepoName} `
        --private `
        --description ${Description} 2>&1
    if ($LASTEXITCODE -ne 0) {
        Abort "gh repo create failed: $(${createOutput} -join ' ')"
    }
    Write-Pass "Created: https://github.com/${githubUser}/${RepoName} (private)"
}

# ===========================================================================
# SECTION 8 — Set git remote
# ===========================================================================

Write-Section "Section 8: Configure git remote"

Push-Location ${TargetPath}
try {
    ${remoteUrl}  = "git@${GitHubAlias}:${githubUser}/${RepoName}.git"
    ${existing}   = git remote 2>&1
    if (${existing} -contains 'origin') {
        ${currentUrl} = (git remote get-url origin 2>&1).Trim()
        if (${currentUrl} -ne ${remoteUrl}) {
            git remote set-url origin ${remoteUrl} 2>&1 | Out-Null
            Write-Pass "Updated remote origin -> ${remoteUrl}"
        } else {
            Write-Info "Remote origin already correct: ${remoteUrl}"
        }
    } else {
        git remote add origin ${remoteUrl} 2>&1 | Out-Null
        Write-Pass "Added remote origin: ${remoteUrl}"
    }
} catch {
    Abort "Failed to configure remote: $_"
} finally {
    Pop-Location
}

# ===========================================================================
# SECTION 9 — Stage and commit
# ===========================================================================

Write-Section "Section 9: Stage and commit"

Push-Location ${TargetPath}
try {
    git add . 2>&1 | Out-Null
    ${staged} = (git diff --cached --name-only 2>&1)
    Write-Info "Staged $(${staged}.Count) file(s)"

    ${commitMsg} = "chore: migrate ${RepoName} to gold standard github environment"
    ${commitOut} = git commit -m ${commitMsg} 2>&1
    if ($LASTEXITCODE -ne 0) {
        Abort "git commit failed: $(${commitOut} -join ' ')"
    }
    ${sha} = (git rev-parse HEAD 2>&1).Trim()
    Write-Pass "Commit: ${sha}"
    Write-Info "  '${commitMsg}'"
} catch {
    Abort "Commit failed: $_"
} finally {
    Pop-Location
}

# ===========================================================================
# SECTION 10 — Push
# ===========================================================================

Write-Section "Section 10: Push to GitHub"

Push-Location ${TargetPath}
try {
    ${pushOut} = git push --set-upstream origin main 2>&1
    if ($LASTEXITCODE -ne 0) {
        Abort "git push failed: $(${pushOut} -join ' ')"
    }
    Write-Pass "Pushed to origin/main"
} catch {
    Abort "Push failed: $_"
} finally {
    Pop-Location
}

# ===========================================================================
# SECTION 11 — Branch ruleset
# ===========================================================================

Write-Section "Section 11: Apply branch ruleset"

try {
    ${rulesetJson} = '{"name":"main-protection","target":"branch","enforcement":"active","conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[]}},"rules":[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"required_signatures"}]}'
    ${tmpFile} = [System.IO.Path]::GetTempFileName()
    Set-Content -Path ${tmpFile} -Value ${rulesetJson} -Encoding UTF8

    ${ruleOut} = gh api "repos/${githubUser}/${RepoName}/rulesets" `
        --method POST --input ${tmpFile} 2>&1
    Remove-Item ${tmpFile} -Force

    if ($LASTEXITCODE -ne 0) {
        ${ruleStr} = ${ruleOut} -join ' '
        if (${ruleStr} -match '403' -or ${ruleStr} -match 'Upgrade') {
            Write-Warn "Branch rulesets require a public repo or paid plan."
            Write-Info "  To enable on a private repo: upgrade to GitHub Pro."
            Write-Info "  To make public: gh repo edit ${githubUser}/${RepoName} --visibility public --accept-visibility-change-consequences"
        } else {
            Write-Warn "Ruleset creation failed: ${ruleStr}"
        }
    } else {
        Write-Pass "Branch ruleset applied (deletion, force-push, required signatures)"
    }
} catch {
    Write-Warn "Could not apply branch ruleset: $_"
}

# ===========================================================================
# SECTION 12 — Apply GitHub topics
# ===========================================================================

Write-Section "Section 12: Apply GitHub topics"

if (${Topics}.Count -gt 0) {
    try {
        ${topicArgs} = ${Topics} | ForEach-Object { "--add-topic", $_ }
        ${topicOut}  = gh repo edit "${githubUser}/${RepoName}" @topicArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Could not apply topics: $(${topicOut} -join ' ')"
        } else {
            Write-Pass "Topics applied: $(${Topics} -join ', ')"
        }
    } catch {
        Write-Warn "Topic application failed: $_"
    }
} else {
    Write-Info "No topics specified — skipping"
}

# ===========================================================================
# SECTION 13 — Final summary
# ===========================================================================

Write-Host "`n=============================================" -ForegroundColor Green
Write-Host "  Migration Complete"                          -ForegroundColor Green
Write-Host "============================================="  -ForegroundColor Green
Write-Host ""
Write-Host "  Repo URL    : https://github.com/${githubUser}/${RepoName}" -ForegroundColor White
Write-Host "  Local path  : ${TargetPath}"                                -ForegroundColor White
Write-Host "  Remote      : git@${GitHubAlias}:${githubUser}/${RepoName}.git" -ForegroundColor White
Write-Host ""
Write-Host "  Verification reminders:" -ForegroundColor Yellow
Write-Host "    1. Open https://github.com/${githubUser}/${RepoName} in your browser." -ForegroundColor Yellow
Write-Host "    2. Click the initial commit and confirm the 'Verified' badge."         -ForegroundColor Yellow
Write-Host "    3. Go to Settings -> Rules -> Rulesets and confirm main-protection."   -ForegroundColor Yellow
Write-Host "    4. Review the generated .gitignore — adjust if any files were"         -ForegroundColor Yellow
Write-Host "       incorrectly excluded or included."                                  -ForegroundColor Yellow
Write-Host "    5. The source directory still exists — delete it once you have"        -ForegroundColor Yellow
Write-Host "       confirmed the GitHub repo looks correct."                           -ForegroundColor Yellow
Write-Host ""
Write-Host "[RESULT] ${RepoName} migrated successfully.`n" -ForegroundColor Green
