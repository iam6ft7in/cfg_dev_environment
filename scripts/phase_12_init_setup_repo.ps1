#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 12 - Initialize cfg_dev_environment as Gold Standard Repository

.DESCRIPTION
    Script Name : phase_12_init_setup_repo.ps1
    Purpose     : Initialize the SetupGitHub project as a proper GitHub repository
                  (cfg_dev_environment) following the gold standard structure.
    Phase       : 12
    Exit Criteria:
        - GitHub repo 'cfg_dev_environment' created under the authenticated account
        - Repo populated under {projects_root}/{github_username}/public/cfg_dev_environment/
        - Git initialized with remote set to git@github-personal:{user}/cfg_dev_environment.git
        - CLAUDE.md and AGENTS.md created
        - Chosen license file written
        - Initial signed commit pushed to origin main
        - Branch protection enabled (enforce admins, required signatures, no force push)
        - GitHub topics applied
        - Final status printed with repo URL, local path, and commit SHA

.NOTES
    Run from any location; $RepoRoot is derived from $PSScriptRoot.
    Requires: gh, git, SSH configured with github-personal host alias.
    Commit signing must already be configured (phase 05/06).
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
    Write-Host "`n[ABORTED] Phase 12 did not complete. Review errors above." -ForegroundColor Red
    exit 1
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$RepoRoot = Split-Path -Parent $PSScriptRoot

# Resolve install location from ~/.claude/config.json (Phase 3).
${ClaudeConfig} = Join-Path $HOME '.claude\config.json'
if (-not (Test-Path ${ClaudeConfig})) {
    Exit-WithError "~/.claude/config.json not found. Run Phase 3 first."
}
${cfg} = Get-Content ${ClaudeConfig} -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not ${cfg}.projects_root -or -not ${cfg}.github_username) {
    Exit-WithError "projects_root or github_username missing from ${ClaudeConfig}. Re-run Phase 3."
}
$LocalRepoPath = Join-Path ${cfg}.projects_root "$(${cfg}.github_username)\public\cfg_dev_environment"
$RepoName      = 'cfg_dev_environment'

# Track results
$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n========================================"    -ForegroundColor Cyan
Write-Host "  Phase 12 - Initialize cfg_dev_environment Repo"   -ForegroundColor Cyan
Write-Host "  Source (this project) : $RepoRoot"         -ForegroundColor Cyan
Write-Host "  Destination           : $LocalRepoPath"    -ForegroundColor Cyan
Write-Host "========================================`n"   -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Pre-check: Verify gh and git are available
# ---------------------------------------------------------------------------
foreach ($Tool in @('gh', 'git')) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        Exit-WithError "'$Tool' is not on PATH. Install it and try again."
    }
}

# ---------------------------------------------------------------------------
# Get authenticated GitHub username
# ---------------------------------------------------------------------------
Write-Section "Retrieve authenticated GitHub username"

try {
    $GitHubUser = (gh api user --jq .login).Trim()
    if ([string]::IsNullOrWhiteSpace($GitHubUser)) {
        Exit-WithError "Could not retrieve GitHub username. Run 'gh auth login' first."
    }
    Write-Pass "Authenticated as: $GitHubUser"
} catch {
    Exit-WithError "Failed to get GitHub username: $_"
}

# ---------------------------------------------------------------------------
# Step 1 - Check if local destination already exists
# ---------------------------------------------------------------------------
Write-Section "Step 1: Check for existing local destination"

if (Test-Path $LocalRepoPath -PathType Container) {
    Write-Warn "Destination already exists: $LocalRepoPath"
    $Choice = Read-Host "  Overwrite (o), Skip (s), or Abort (a)? [o/s/a]"
    switch ($Choice.Trim().ToLower()) {
        'o' {
            Write-Info "Overwriting existing directory..."
            Remove-Item -Path $LocalRepoPath -Recurse -Force
            Write-Pass "Removed existing directory."
        }
        's' {
            Write-Info "Skipping copy step - will continue with existing directory."
            $Results['LocalDir'] = 'SKIP'
        }
        default {
            Exit-WithError "Aborted by user."
        }
    }
} else {
    Write-Pass "Destination is clear: $LocalRepoPath"
}

# ---------------------------------------------------------------------------
# Step 2 - Prompt for license choice
# ---------------------------------------------------------------------------
Write-Section "Step 2: Choose a license"

Write-Host "`n  License options:" -ForegroundColor Cyan
Write-Host "    1) MIT"            -ForegroundColor White
Write-Host "    2) Apache-2.0"     -ForegroundColor White
Write-Host "    3) GPL-3.0"        -ForegroundColor White
Write-Host "    4) None"           -ForegroundColor White

$ValidChoices = @('1', '2', '3', '4', 'mit', 'apache-2.0', 'gpl-3.0', 'none')
$LicenseInput = ''
do {
    $LicenseInput = (Read-Host "`n  Enter choice (1/2/3/4 or name)").Trim().ToLower()
    if ($LicenseInput -notin $ValidChoices) {
        Write-Warn "Invalid choice '$LicenseInput'. Please enter 1, 2, 3, or 4."
    }
} while ($LicenseInput -notin $ValidChoices)

$LicenseKey = switch ($LicenseInput) {
    { $_ -in @('1', 'mit')        } { 'MIT'        }
    { $_ -in @('2', 'apache-2.0') } { 'Apache-2.0' }
    { $_ -in @('3', 'gpl-3.0')   } { 'GPL-3.0'    }
    { $_ -in @('4', 'none')       } { 'None'       }
}
Write-Pass "License selected: $LicenseKey"

# ---------------------------------------------------------------------------
# Step 3 - GitHub username already retrieved above
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Step 4 - Create GitHub repo
# ---------------------------------------------------------------------------
Write-Section "Step 4: Create GitHub repository '$RepoName'"

# Check if repo already exists
$ExistingRepo = gh repo view "$GitHubUser/$RepoName" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Warn "GitHub repo '$GitHubUser/$RepoName' already exists."
    $RepoChoice = Read-Host "  Use existing repo (u) or Abort (a)? [u/a]"
    if ($RepoChoice.Trim().ToLower() -ne 'u') {
        Exit-WithError "Aborted. Delete the existing GitHub repo first or choose to use it."
    }
    Write-Info "Using existing GitHub repo."
    $Results['CreateGitHubRepo'] = 'PASS (existing)'
} else {
    try {
        gh repo create $RepoName `
            --private `
            --description "Development environment setup scripts and gold standard configuration" 2>&1 | Out-Null
        Write-Pass "GitHub repo created: $GitHubUser/$RepoName"
        $Results['CreateGitHubRepo'] = 'PASS'
    } catch {
        Exit-WithError "Failed to create GitHub repo: $_"
    }
}

# ---------------------------------------------------------------------------
# Step 5 - Create local directory
# ---------------------------------------------------------------------------
Write-Section "Step 5: Create local directory"

if ($Results['LocalDir'] -ne 'SKIP') {
    try {
        New-Item -ItemType Directory -Path $LocalRepoPath -Force | Out-Null
        Write-Pass "Created: $LocalRepoPath"
        $Results['LocalDir'] = 'PASS'
    } catch {
        Exit-WithError "Failed to create local directory '$LocalRepoPath': $_"
    }
}

# ---------------------------------------------------------------------------
# Step 6 - Copy all project files to new location
# ---------------------------------------------------------------------------
Write-Section "Step 6: Copy project files to new location"

if ($Results['LocalDir'] -eq 'SKIP') {
    Write-Info "Skipping copy (user chose to use existing directory)."
    $Results['CopyFiles'] = 'SKIP'
} else {
    try {
        Copy-Item -Path "$RepoRoot\*" -Destination "$LocalRepoPath\" -Recurse -Force
        $CopiedCount = (Get-ChildItem -Path $LocalRepoPath -Recurse -File).Count
        Write-Pass "Copied $CopiedCount file(s) to $LocalRepoPath"
        $Results['CopyFiles'] = 'PASS'
    } catch {
        Exit-WithError "Failed to copy project files: $_"
    }
}

# ---------------------------------------------------------------------------
# Step 7 - Initialize git
# ---------------------------------------------------------------------------
Write-Section "Step 7: Initialize git in new location"

try {
    Push-Location $LocalRepoPath
    $InitOutput = git init 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git init failed: $($InitOutput -join ' ')" }
    Write-Pass "git init completed."
    Write-Info $InitOutput
    $Results['GitInit'] = 'PASS'
} catch {
    Pop-Location
    Exit-WithError "git init failed: $_"
}
# Stay in $LocalRepoPath for remaining steps

# ---------------------------------------------------------------------------
# Step 8 - Copy scaffold template files to repo root
# ---------------------------------------------------------------------------
Write-Section "Step 8: Apply gold standard scaffold template"

$TemplateProjectDir = Join-Path $LocalRepoPath 'templates\project'
if (Test-Path $TemplateProjectDir -PathType Container) {
    try {
        $TemplateFiles = Get-ChildItem -Path $TemplateProjectDir -File
        foreach ($TF in $TemplateFiles) {
            $Dest = Join-Path $LocalRepoPath $TF.Name
            if (-not (Test-Path $Dest)) {
                Copy-Item -Path $TF.FullName -Destination $Dest -Force
                Write-Pass "Scaffolded: $($TF.Name)"
            } else {
                Write-Info "Skipped (already exists): $($TF.Name)"
            }
        }
        $Results['ScaffoldTemplate'] = 'PASS'
    } catch {
        Write-Warn "Template scaffold step had errors: $_"
        $Results['ScaffoldTemplate'] = 'WARN'
    }
} else {
    Write-Warn "Template directory not found: $TemplateProjectDir"
    Write-Warn "Skipping scaffold step."
    $Results['ScaffoldTemplate'] = 'WARN (not found)'
}

# ---------------------------------------------------------------------------
# Step 9 - Create CLAUDE.md
# ---------------------------------------------------------------------------
Write-Section "Step 9: Create CLAUDE.md"

$ClaudeMdPath = Join-Path $LocalRepoPath 'CLAUDE.md'
$ClaudeMdContent = @'
# Claude Rules

@~/.claude/rules/core.md
@~/.claude/rules/shell.md
'@

try {
    [System.IO.File]::WriteAllText($ClaudeMdPath, $ClaudeMdContent, $Utf8NoBom)
    Write-Pass "Created: CLAUDE.md"
    $Results['ClaudeMd'] = 'PASS'
} catch {
    Write-Fail "Failed to write CLAUDE.md: $_"
    $Results['ClaudeMd'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 10 - Create AGENTS.md
# ---------------------------------------------------------------------------
Write-Section "Step 10: Create AGENTS.md"

$AgentsMdPath = Join-Path $LocalRepoPath 'AGENTS.md'
$AgentsMdContent = @'
# AI Agent Rules

This repository follows universal AI collaboration rules. All AI agents
(Claude, Copilot, GPT, etc.) must adhere to the following principles:

## Core Principles

- **Minimal footprint**: Make only the changes requested. Do not refactor
  or reorganize code unless explicitly asked.
- **No silent assumptions**: If requirements are unclear, ask before acting.
- **Preserve intent**: Maintain the style and conventions already present
  in the codebase.
- **Reversible actions**: Prefer changes that can be easily undone.
  Never force-push, delete branches, or remove files without confirmation.
- **Conventional commits**: All commit messages must follow the
  Conventional Commits specification (https://www.conventionalcommits.org/).
- **Signed commits**: All commits must be GPG-signed.

## Full Rule Set

See the complete rule files imported in CLAUDE.md:
- `~/.claude/rules/core.md`  : Universal rules for all projects
- `~/.claude/rules/shell.md` , Shell/PowerShell-specific rules
'@

try {
    [System.IO.File]::WriteAllText($AgentsMdPath, $AgentsMdContent, $Utf8NoBom)
    Write-Pass "Created: AGENTS.md"
    $Results['AgentsMd'] = 'PASS'
} catch {
    Write-Fail "Failed to write AGENTS.md: $_"
    $Results['AgentsMd'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 11 - Write license file
# ---------------------------------------------------------------------------
Write-Section "Step 11: Write license file ($LicenseKey)"

$Year = (Get-Date).Year
$LicenseContent = switch ($LicenseKey) {
    'MIT' { @"
MIT License

Copyright (c) $Year {your_name}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@ }

    'Apache-2.0' { @"
Copyright $Year {your_name}

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"@ }

    'GPL-3.0' { @"
Copyright (C) $Year {your_name}

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
"@ }

    'None' { @"
NOTICE

All rights reserved. Proprietary.

This software and its source code are the exclusive property of {your_name}.
Unauthorized copying, distribution, modification, or use of this software,
in whole or in part, is strictly prohibited without prior written permission.
"@ }
}

$LicenseFile = if ($LicenseKey -eq 'None') { 'NOTICE' } else { 'LICENSE' }
$LicensePath = Join-Path $LocalRepoPath $LicenseFile

try {
    [System.IO.File]::WriteAllText($LicensePath, $LicenseContent, $Utf8NoBom)
    Write-Pass "Created: $LicenseFile"
    $Results['License'] = 'PASS'
} catch {
    Write-Fail "Failed to write $LicenseFile : $_"
    $Results['License'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 12 - Set remote using SSH host alias
# ---------------------------------------------------------------------------
Write-Section "Step 12: Set git remote (SSH host alias)"

try {
    $RemoteUrl = "git@github-personal:$GitHubUser/$RepoName.git"
    # Remove existing origin if present (e.g., if git was re-initialized)
    $ExistingRemote = git remote 2>&1
    if ($ExistingRemote -contains 'origin') {
        git remote remove origin 2>&1 | Out-Null
    }
    git remote add origin $RemoteUrl 2>&1 | Out-Null
    Write-Pass "Remote set: $RemoteUrl"
    $Results['GitRemote'] = 'PASS'
} catch {
    Write-Fail "Failed to set git remote: $_"
    $Results['GitRemote'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 13 - Stage all files
# ---------------------------------------------------------------------------
Write-Section "Step 13: Stage all files"

try {
    git add . 2>&1 | Out-Null
    $Staged = git diff --cached --name-only 2>&1
    Write-Pass "Staged $($Staged.Count) file(s)."
    $Results['GitAdd'] = 'PASS'
} catch {
    Write-Fail "git add failed: $_"
    $Results['GitAdd'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 14 - Create first signed commit
# ---------------------------------------------------------------------------
Write-Section "Step 14: Create initial signed commit"

try {
    $CommitOutput = git commit -m "chore: initial project scaffold" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git commit failed: $($CommitOutput -join ' ')" }
    Write-Pass "Initial commit created."
    $CommitOutput | ForEach-Object { Write-Info $_ }
    $Results['InitialCommit'] = 'PASS'
} catch {
    Write-Fail "Initial commit failed: $_"
    $Results['InitialCommit'] = 'FAIL'
    Exit-WithError "Cannot push without a commit."
}

# ---------------------------------------------------------------------------
# Step 15 - Push to origin main
# ---------------------------------------------------------------------------
Write-Section "Step 15: Push to origin main"

try {
    # Ensure local branch is named 'main'
    $CurrentBranch = (git branch --show-current 2>&1).Trim()
    if ($CurrentBranch -ne 'main') {
        git branch -M main 2>&1 | Out-Null
        Write-Info "Renamed branch to 'main'."
    }

    $PushOutput = git push -u origin main 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git push failed: $($PushOutput -join ' ')" }
    Write-Pass "Pushed to origin main."
    $Results['GitPush'] = 'PASS'
} catch {
    Write-Fail "Push failed: $_"
    $Results['GitPush'] = 'FAIL'
    Exit-WithError "Push failed. Fix remote/SSH and retry from this step."
}

# Get first commit SHA
$CommitSHA = (git rev-parse HEAD 2>&1).Trim()

# ---------------------------------------------------------------------------
# Step 16 - Configure branch protection
# ---------------------------------------------------------------------------
Write-Section "Step 16: Configure branch protection"

try {
    gh api "repos/$GitHubUser/$RepoName/branches/main/protection" `
        --method PUT `
        --field required_status_checks=null `
        --field enforce_admins=true `
        --field required_pull_request_reviews=null `
        --field restrictions=null `
        --field required_signatures=true `
        --field allow_force_pushes=false `
        --field allow_deletions=false 2>&1 | Out-Null

    Write-Pass "Branch protection applied to main."
    Write-Info "  - Enforce admins     : true"
    Write-Info "  - Required signatures: true"
    Write-Info "  - Allow force pushes : false"
    Write-Info "  - Allow deletions    : false"
    $Results['BranchProtection'] = 'PASS'
} catch {
    Write-Warn "Branch protection could not be set: $_"
    Write-Warn "You may need admin access or a GitHub plan that supports branch protection."
    $Results['BranchProtection'] = 'WARN'
}

# ---------------------------------------------------------------------------
# Step 17 - Apply GitHub topics
# ---------------------------------------------------------------------------
Write-Section "Step 17: Apply GitHub topics"

try {
    gh repo edit $RepoName `
        --add-topic "setup" `
        --add-topic "github" `
        --add-topic "development-environment" `
        --add-topic "powershell" `
        --add-topic "gold-standard" 2>&1 | Out-Null
    Write-Pass "Topics applied: setup, github, development-environment, powershell, gold-standard"
    $Results['GitHubTopics'] = 'PASS'
} catch {
    Write-Warn "Could not apply GitHub topics: $_"
    $Results['GitHubTopics'] = 'WARN'
}

# ---------------------------------------------------------------------------
# Return to original location
# ---------------------------------------------------------------------------
Pop-Location

# ---------------------------------------------------------------------------
# Step 18 - Final status
# ---------------------------------------------------------------------------
Write-Section "Final Status"

$RepoURL  = "https://github.com/$GitHubUser/$RepoName"

Write-Host "`n  Repository URL  : $RepoURL"              -ForegroundColor Green
Write-Host "  Local path      : $LocalRepoPath"          -ForegroundColor Green
Write-Host "  First commit    : $CommitSHA"              -ForegroundColor Green
Write-Host "  License         : $LicenseKey"             -ForegroundColor Green
Write-Host "  Remote alias    : git@github-personal:$GitHubUser/$RepoName.git" -ForegroundColor Green

Write-Host "`n  Result table:" -ForegroundColor Cyan
$PassCount = 0; $WarnCount = 0; $FailCount = 0
foreach ($Key in $Results.Keys) {
    $Val = $Results[$Key]
    $Color = switch -Wildcard ($Val) {
        'PASS*' { $PassCount++; 'Green'  }
        'WARN*' { $WarnCount++; 'Yellow' }
        'SKIP'  { 'Gray'  }
        'FAIL'  { $FailCount++; 'Red'    }
        default { 'Gray' }
    }
    Write-Host ("    {0,-25} {1}" -f $Key, $Val) -ForegroundColor $Color
}

Write-Host "`n  Checks passed   : $PassCount" -ForegroundColor Green
Write-Host "  Warnings        : $WarnCount"   -ForegroundColor $(if ($WarnCount -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Failures        : $FailCount"   -ForegroundColor $(if ($FailCount -gt 0) { 'Red'    } else { 'Green' })

Write-Host "`n  Verification reminders:" -ForegroundColor Yellow
Write-Host "    1. Open $RepoURL in your browser."             -ForegroundColor Yellow
Write-Host "    2. Click the initial commit and look for the 'Verified' badge." -ForegroundColor Yellow
Write-Host "       If absent, GPG signing may not have taken effect."           -ForegroundColor Yellow
Write-Host "    3. Go to Settings > Branches and confirm protection rules."     -ForegroundColor Yellow
Write-Host "    4. Confirm the five topics appear on the repo home page."       -ForegroundColor Yellow

if ($FailCount -gt 0) {
    Write-Host "`n[RESULT] Phase 12 completed with errors. Review failures above." -ForegroundColor Red
    exit 1
} elseif ($WarnCount -gt 0) {
    Write-Host "`n[RESULT] Phase 12 completed with warnings." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n[RESULT] Phase 12 completed successfully. cfg_dev_environment is your first gold standard repo." -ForegroundColor Green
    exit 0
}
