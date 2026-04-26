#Requires -Version 7.0
<#
.SYNOPSIS
    Read-only preview of every change the 12 phases would make.

.DESCRIPTION
    Script Name : preview.ps1
    Purpose     : Walks the 12 phases and reports, for each one, what it
                  would install, create, modify, or write on the current
                  machine. Makes NO changes and writes no files.

                  Use this before running phase_01..phase_12 to confirm you
                  understand what will change. Re-run any time to see the
                  remaining diff between current state and target state.

    Phase       : 0 (preview, runs before Phase 1)

    Status tags:
      [INSTALLED]      tool is on PATH at the right version
      [WILL INSTALL]   tool is missing or older than minimum
      [EXISTS]         file or directory already on disk
      [WILL CREATE]    file or directory will be created
      [WILL OVERWRITE] file exists and will be overwritten by a phase
                       (existing content is backed up to *.bak when the
                       phase supports it)

.NOTES
    Run with: pwsh -File scripts\preview.ps1
    Or:       bash  scripts/preview.sh
#>

Set-StrictMode -Version Latest
${ErrorActionPreference} = 'Stop'

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

function Write-Phase {
    param([string]${Title})
    Write-Host ""
    Write-Host "=== ${Title} ===" -ForegroundColor Cyan
}

function Write-Status {
    param([string]${Tag}, [string]${Item}, [string]${Note} = '')
    ${color} = switch (${Tag}) {
        'INSTALLED'      { 'Green'  }
        'EXISTS'         { 'Green'  }
        'WILL INSTALL'   { 'Yellow' }
        'WILL CREATE'    { 'Yellow' }
        'WILL OVERWRITE' { 'Magenta' }
        default           { 'White'  }
    }
    ${tagPad} = ${Tag}.PadRight(15)
    ${line}   = "  [${tagPad}] ${Item}"
    if (${Note}) { ${line} += "  ($Note)" }
    Write-Host ${line} -ForegroundColor ${color}
}

function Test-CommandOnPath {
    param([string]${Name})
    return [bool](Get-Command ${Name} -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  cfg_dev_environment, preview of all 12 phases"           -ForegroundColor Cyan
Write-Host "  Read-only. No changes will be made."                       -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Resolve a tentative projects_root and github_username for the inventory.
# Phase 3 will prompt for these; until then we use the existing values from
# ~/.claude/config.json or fall back to the defaults.
${ClaudeConfig} = Join-Path ${HOME} '.claude\config.json'
${ProjectsRoot}   = Join-Path ${HOME} 'projects'
${GithubUsername} = '<unset>'
${configKnown}    = $false
if (Test-Path ${ClaudeConfig}) {
    try {
        ${cfg} = Get-Content ${ClaudeConfig} -Raw -Encoding UTF8 | ConvertFrom-Json
        if (${cfg}.PSObject.Properties.Name -contains 'projects_root' `
                -and ${cfg}.projects_root) {
            ${ProjectsRoot} = ${cfg}.projects_root
        }
        if (${cfg}.PSObject.Properties.Name -contains 'github_username' `
                -and ${cfg}.github_username) {
            ${GithubUsername} = ${cfg}.github_username
            ${configKnown}    = $true
        }
    } catch { }
}

Write-Host ""
Write-Host "  projects_root   : ${ProjectsRoot}"   -ForegroundColor Gray
Write-Host "  github_username : ${GithubUsername}" -ForegroundColor Gray
if (-not ${configKnown}) {
    Write-Host "  (Phase 3 will prompt for both and persist them to ~/.claude/config.json)" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Phase 0: Manual prerequisites
# ---------------------------------------------------------------------------

Write-Phase 'Phase 0: manual prerequisites (you do these yourself)'

Write-Host '  - Move %USERPROFILE%\OneDrive\Documents\AI\ to %USERPROFILE%\OneDrive\AI\'
Write-Host '  - Get your GitHub noreply email (Settings, Emails)'
Write-Host '  - Confirm: pwsh --version >= 7.4'
Write-Host '  - Confirm: Bitwarden Desktop >= 2025.1.2 installed and logged in'

# ---------------------------------------------------------------------------
# Phase 1: tools
# ---------------------------------------------------------------------------

Write-Phase 'Phase 1: tools to install'

${tools} = @(
    @{ Name = 'git';        Cmd = 'git';        MinVersion = '2.42' }
    @{ Name = 'gh';         Cmd = 'gh';         MinVersion = '2.40' }
    @{ Name = 'ssh.exe';    Cmd = 'ssh';        MinVersion = '0.0'  }
    @{ Name = 'gitleaks';   Cmd = 'gitleaks';   MinVersion = '8.18' }
    @{ Name = 'nasm';       Cmd = 'nasm';       MinVersion = '2.16' }
    @{ Name = 'uv';         Cmd = 'uv';         MinVersion = '0.4'  }
    @{ Name = 'ruff';       Cmd = 'ruff';       MinVersion = '0.3'  }
    @{ Name = 'delta';      Cmd = 'delta';      MinVersion = '0.17' }
    @{ Name = 'x64dbg';     Cmd = 'x64dbg';     MinVersion = '0.0'  }
    @{ Name = 'oh-my-posh'; Cmd = 'oh-my-posh'; MinVersion = '23'   }
)

foreach (${t} in ${tools}) {
    ${name}    = ${t}.Name
    ${cmd}     = ${t}.Cmd
    ${minVer}  = ${t}.MinVersion
    if (Test-CommandOnPath ${cmd}) {
        Write-Status 'INSTALLED' ${name}
    } else {
        Write-Status 'WILL INSTALL' ${name} "min version ${minVer}"
    }
}
Write-Host '  Plus: JetBrains Mono Nerd Font (manual install)' -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Phase 2: SSH setup
# ---------------------------------------------------------------------------

Write-Phase 'Phase 2: SSH setup (Bitwarden-backed)'

${sshConfig}      = Join-Path ${HOME} '.ssh\config'
${allowedSigners} = Join-Path ${HOME} '.ssh\allowed_signers'

if (Test-Path ${sshConfig}) {
    Write-Status 'WILL OVERWRITE' '~/.ssh/config' 'host aliases for github-personal and github-client'
} else {
    Write-Status 'WILL CREATE' '~/.ssh/config'
}
if (Test-Path ${allowedSigners}) {
    Write-Status 'WILL OVERWRITE' '~/.ssh/allowed_signers'
} else {
    Write-Status 'WILL CREATE' '~/.ssh/allowed_signers'
}
Write-Host '  Plus: one Ed25519 key generated inside your Bitwarden vault' -ForegroundColor Gray
Write-Host '  Plus: Windows OpenSSH Authentication Agent service set to Disabled' -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Phase 3: git config files
# ---------------------------------------------------------------------------

Write-Phase 'Phase 3: git config files (prompts for projects_root and github_username)'

${gitFiles} = @(
    '~/.gitconfig'
    '~/.gitconfig-client'
    '~/.gitconfig-arduino'
    '~/.gitmessage'
)
foreach (${rel} in ${gitFiles}) {
    ${abs} = ${rel} -replace '^~', ${HOME}
    if (Test-Path ${abs}) {
        Write-Status 'WILL OVERWRITE' ${rel} 'existing content backed up to *.bak by .sh; .ps1 overwrites in place'
    } else {
        Write-Status 'WILL CREATE' ${rel}
    }
}
if (Test-Path ${ClaudeConfig}) {
    Write-Status 'WILL OVERWRITE' '~/.claude/config.json' 'projects_root + github_username keys updated'
} else {
    Write-Status 'WILL CREATE' '~/.claude/config.json'
}

# ---------------------------------------------------------------------------
# Phase 4: directory tree
# ---------------------------------------------------------------------------

Write-Phase 'Phase 4: directory tree'

${dirs} = @(
    "${ProjectsRoot}\${GithubUsername}\public"
    "${ProjectsRoot}\${GithubUsername}\private"
    "${ProjectsRoot}\${GithubUsername}\collaborative"
    "${ProjectsRoot}\client"
    "${ProjectsRoot}\arduino\upstream"
    "${ProjectsRoot}\arduino\custom"
    (Join-Path ${HOME} '.git-templates\hooks')
    (Join-Path ${HOME} '.claude\rules')
    (Join-Path ${HOME} '.claude\skills')
    (Join-Path ${HOME} '.claude\scripts')
    (Join-Path ${HOME} '.claude\shortcuts')
    (Join-Path ${HOME} '.claude\templates')
    (Join-Path ${HOME} '.cspell')
    (Join-Path ${HOME} '.oh-my-posh')
)
foreach (${d} in ${dirs}) {
    if (Test-Path ${d}) {
        Write-Status 'EXISTS' ${d}
    } else {
        Write-Status 'WILL CREATE' ${d}
    }
}

# ---------------------------------------------------------------------------
# Phase 5: ~/.gitignore_global
# ---------------------------------------------------------------------------

Write-Phase 'Phase 5: ~/.gitignore_global'

${gitignoreGlobal} = Join-Path ${HOME} '.gitignore_global'
if (Test-Path ${gitignoreGlobal}) {
    Write-Status 'WILL OVERWRITE' '~/.gitignore_global'
} else {
    Write-Status 'WILL CREATE' '~/.gitignore_global'
}

# ---------------------------------------------------------------------------
# Phase 6: hooks + gitleaks scan
# ---------------------------------------------------------------------------

Write-Phase 'Phase 6: git hooks and weekly gitleaks scan'

${hookFiles} = @(
    '~/.git-templates/hooks/pre-commit'
    '~/.git-templates/hooks/commit-msg'
    '~/.gitleaks.toml'
)
foreach (${rel} in ${hookFiles}) {
    ${abs} = ${rel} -replace '^~', ${HOME}
    if (Test-Path ${abs}) {
        Write-Status 'WILL OVERWRITE' ${rel}
    } else {
        Write-Status 'WILL CREATE' ${rel}
    }
}
${weeklyScript} = Join-Path ${HOME} '.git-templates\gitleaks-weekly-scan.ps1'
if (Test-Path ${weeklyScript}) {
    Write-Status 'WILL OVERWRITE' '~/.git-templates/gitleaks-weekly-scan.ps1'
} else {
    Write-Status 'WILL CREATE' '~/.git-templates/gitleaks-weekly-scan.ps1'
}
${task} = Get-ScheduledTask -TaskName 'GitLeaks Weekly Security Scan' -ErrorAction SilentlyContinue
if (${task}) {
    Write-Status 'WILL OVERWRITE' 'Task Scheduler: GitLeaks Weekly Security Scan'
} else {
    Write-Status 'WILL CREATE' 'Task Scheduler: GitLeaks Weekly Security Scan'
}
Write-Host '  Plus: git config init.templateDir = ~/.git-templates' -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Phase 7 + 7b + 8 + 9: Claude config
# ---------------------------------------------------------------------------

Write-Phase 'Phases 7, 7b, 8, 9: Claude rules, skills, scripts, templates, cspell dictionary'

${claudeTargets} = @(
    @{ Path = (Join-Path ${HOME} '.claude\rules');                  Note = 'rule files (universal + extension-triggered)' }
    @{ Path = (Join-Path ${HOME} '.claude\skills');                 Note = 'skill directories (~ 20 skills)' }
    @{ Path = (Join-Path ${HOME} '.claude\scripts');                Note = 'helper scripts (setup_project_board.ps1)' }
    @{ Path = (Join-Path ${HOME} '.claude\shortcuts');              Note = 'regenerate.ps1 + per-repo .lnk files' }
    @{ Path = (Join-Path ${HOME} '.claude\templates');              Note = 'project scaffold' }
    @{ Path = (Join-Path ${HOME} '.cspell\custom_words.txt');       Note = 'cspell dictionary' }
)
foreach (${c} in ${claudeTargets}) {
    if (Test-Path ${c}.Path) {
        Write-Status 'WILL OVERWRITE' ${c}.Path ${c}.Note
    } else {
        Write-Status 'WILL CREATE' ${c}.Path ${c}.Note
    }
}
Write-Host '  Phase 7b uses diff-before-copy: drifted files prompt per-file.' -ForegroundColor Gray
Write-Host '  User edits to deployed-only files (e.g. send-email/config.json) are preserved.' -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Phase 10: Windows env
# ---------------------------------------------------------------------------

Write-Phase 'Phase 10: Windows environment (registry + Terminal + PowerShell profile)'

${envVars} = @('GIT_SSH', 'LANG', 'LC_ALL')
foreach (${v} in ${envVars}) {
    ${val} = [System.Environment]::GetEnvironmentVariable(${v}, 'User')
    if (${val}) {
        Write-Status 'WILL OVERWRITE' "HKCU env var: ${v}" "currently: ${val}"
    } else {
        Write-Status 'WILL CREATE' "HKCU env var: ${v}"
    }
}

${ompTheme} = Join-Path ${HOME} '.oh-my-posh\theme.json'
if (Test-Path ${ompTheme}) {
    Write-Status 'WILL OVERWRITE' '~/.oh-my-posh/theme.json'
} else {
    Write-Status 'WILL CREATE' '~/.oh-my-posh/theme.json'
}

if (Test-Path ${PROFILE}) {
    Write-Status 'WILL OVERWRITE' "PowerShell profile: ${PROFILE}" 'Oh My Posh init line appended'
} else {
    Write-Status 'WILL CREATE' "PowerShell profile: ${PROFILE}"
}

Write-Host '  Plus: three Windows Terminal profiles added (GitHub Personal, Client, Arduino)' -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Phase 11: e2e test
# ---------------------------------------------------------------------------

Write-Phase 'Phase 11: end-to-end test (no permanent changes)'

${testDir} = Join-Path ${ProjectsRoot} "${GithubUsername}\_e2e_test_temp"
Write-Host "  Temporary test repo created and deleted at: ${testDir}"
Write-Host "  Creates a GitHub repo named test_e2e_delete_me, then removes it."
Write-Host "  Verifies signed commits and PR flow end-to-end."

# ---------------------------------------------------------------------------
# Phase 12: self-install
# ---------------------------------------------------------------------------

Write-Phase 'Phase 12: install cfg_dev_environment as a gold standard repo'

${selfInstall} = Join-Path ${ProjectsRoot} "${GithubUsername}\public\cfg_dev_environment"
if (Test-Path ${selfInstall}) {
    Write-Status 'EXISTS' ${selfInstall} 'Phase 12 will prompt overwrite/skip/abort'
} else {
    Write-Status 'WILL CREATE' ${selfInstall}
}
Write-Host '  Creates a private GitHub repo: cfg_dev_environment' -ForegroundColor Gray
Write-Host '  Pushes initial signed commit, applies branch protection ruleset.' -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Preview complete. No changes were made."                  -ForegroundColor Cyan
Write-Host "  To proceed, follow the Start Here section in README.md." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
