#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 3: Git Configuration Files

.DESCRIPTION
    Script Name : phase_03_git_config.ps1
    Purpose     : Write ~/.gitconfig (global), ~/.gitconfig-client,
                  ~/.gitconfig-arduino, and ~/.gitmessage. Prompts for the
                  GitHub noreply email, reads the personal SSH public key for
                  signing, and updates ~/.ssh/allowed_signers with the real
                  noreply address.
    Phase       : 3 of 12
    Exit Criteria: git config --list --global shows user.name, user.email,
                   commit.gpgsign=true, tag.gpgsign=true, pull.rebase=true,
                   and init.defaultBranch=main.

.NOTES
    Run with: pwsh -File scripts\phase_03_git_config.ps1
    Prerequisites: Phase 2 must be complete (SSH key must exist).
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
    Write-Host "`nScript aborted. Fix the issue above and re-run Phase 3.`n" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Section header
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 3, Git Configuration Files"      -ForegroundColor Cyan
Write-Host "  Repo root: $RepoRoot"                   -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$sshDir         = Join-Path $HOME '.ssh'
$personalKeyPub = Join-Path $sshDir 'id_ed25519_github_personal.pub'
$allowedSigners = Join-Path $sshDir 'allowed_signers'
$gitconfig      = Join-Path $HOME '.gitconfig'
$gitconfigPega  = Join-Path $HOME '.gitconfig-client'
$gitconfigArdu  = Join-Path $HOME '.gitconfig-arduino'
$gitmessage     = Join-Path $HOME '.gitmessage'

$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Step 1: Prompt for noreply email
# ---------------------------------------------------------------------------

Write-Section "Step 1, GitHub noreply email address"

Write-Info "Your noreply email looks like: 123456+username@users.noreply.github.com"
Write-Info "Find it at: GitHub -> Settings -> Emails (enable 'Keep my email address private')"
Write-Host ""

$noReplyEmail = ''
do {
    $noReplyEmail = Read-Host "  Enter your GitHub noreply email address"
    $noReplyEmail = $noReplyEmail.Trim()

    # Step 2: Validate
    if ($noReplyEmail -notmatch '@users\.noreply\.github\.com$') {
        Write-Warn "That does not look like a GitHub noreply address."
        Write-Warn "Expected format: 123456+username@users.noreply.github.com"
        $noReplyEmail = ''
    }
} while ([string]::IsNullOrWhiteSpace($noReplyEmail))

Write-Pass "noreply email accepted: $noReplyEmail"
$Results['Email Validated'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 2: Prompt for git user name
# ---------------------------------------------------------------------------

Write-Section "Step 2, Git user name"

Write-Info "Enter your full name as it should appear in git commits."
${gitUserName} = ''
do {
    ${gitUserName} = (Read-Host "  Enter your name").Trim()
} while ([string]::IsNullOrWhiteSpace(${gitUserName}))

Write-Pass "Name accepted: ${gitUserName}"
$Results['Name Validated'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 3: Read personal SSH public key
# ---------------------------------------------------------------------------

Write-Section "Step 3, Read personal SSH public key"

if (-not (Test-Path $personalKeyPub)) {
    Abort "Personal SSH public key not found: $personalKeyPub`nRun Phase 2 first."
}

$pubKeyRaw   = (Get-Content $personalKeyPub -Raw).Trim()
$keyParts    = $pubKeyRaw -split '\s+'
$keyType     = $keyParts[0]
$keyMaterial = $keyParts[1]

if ([string]::IsNullOrWhiteSpace($keyMaterial)) {
    Abort "Public key file appears malformed: $personalKeyPub"
}

Write-Pass "Public key read: $keyType $($keyMaterial.Substring(0, 20))..."
$Results['Public Key Read'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 4: Write ~/.gitconfig
# ---------------------------------------------------------------------------

Write-Section "Step 4, Write ~/.gitconfig"

# Use forward-slash home path for gitconfig (git uses POSIX-style paths internally)
$homeForward = $HOME -replace '\\', '/'

$gitconfigContent = @"
# ~/.gitconfig, Global Git Configuration
# Generated by phase_03_git_config.ps1
# Do not edit manually; re-run the script to regenerate.

[user]
    name        = $gitUserName
    email       = $noReplyEmail
    signingkey  = ~/.ssh/id_ed25519_github_personal.pub

[gpg]
    format      = ssh

[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers
    # Use Windows OpenSSH ssh-keygen so signing calls reach Bitwarden's
    # named-pipe agent. Git's bundled ssh-keygen uses Unix SSH_AUTH_SOCK
    # and cannot see the Windows agent.
    program            = C:/Windows/System32/OpenSSH/ssh-keygen.exe

[commit]
    gpgsign     = true
    template    = ~/.gitmessage

[tag]
    gpgsign     = true

[core]
    # Force git to use Windows OpenSSH client. Required for Bitwarden SSH agent:
    # only Windows ssh.exe can connect to Bitwarden's named pipe on Windows.
    sshCommand      = C:/Windows/System32/OpenSSH/ssh.exe
    autocrlf        = input
    editor          = code --wait
    excludesFile    = ~/.gitignore_global
    whitespace      = trailing-space,space-before-tab
    precomposeunicode = true

[push]
    autoSetupRemote = true
    followTags      = true

[pull]
    rebase          = true

[fetch]
    prune           = true
    pruneTags       = true

[init]
    defaultBranch   = main
    templateDir     = ~/.git-templates

[rerere]
    enabled         = true
    autoupdate      = true

[maintenance]
    auto            = true
    strategy        = incremental

[stash]
    showPatch               = true
    showIncludeUntracked    = true

[log]
    decorate        = full

[format]
    pretty          = %C(auto)%h %d %s %C(dim)(%ar by %an)

[pager]
    log             = delta
    diff            = delta
    show            = delta

[delta]
    navigate        = true
    side-by-side    = false
    line-numbers    = true
    syntax-theme    = Solarized (dark)

[merge]
    conflictstyle   = zdiff3
    tool            = vscode

[mergetool "vscode"]
    cmd             = code --wait `$MERGED

[diff]
    algorithm       = histogram
    colorMoved      = default
    tool            = vscode

[difftool "vscode"]
    cmd             = code --wait --diff `$LOCAL `$REMOTE

[i18n]
    commitEncoding  = UTF-8
    logOutputEncoding = UTF-8

[help]
    autocorrect     = prompt

[branch]
    sort            = -committerdate

[tag]
    sort            = version:refname

[alias]
    st  = status -sb
    lg  = log --oneline --graph --decorate
    lga = log --oneline --graph --decorate --all
    co  = checkout
    sw  = switch
    rb  = rebase
    fp  = fetch --prune --prune-tags
    wip = "!git add -A && git commit -m 'chore: wip'"
    undo = reset HEAD~1 --mixed
    pushf = push --force-with-lease

[includeIf "gitdir:~/projects/client/"]
    path = ~/.gitconfig-client

[includeIf "gitdir:~/projects/arduino/"]
    path = ~/.gitconfig-arduino
"@

Set-Content -Path $gitconfig -Value $gitconfigContent -Encoding UTF8
Write-Pass "Written: $gitconfig"
$Results['~/.gitconfig'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 5: Write ~/.gitconfig-client
# ---------------------------------------------------------------------------

Write-Section "Step 5, Write ~/.gitconfig-client"

$gitconfigPegaContent = @"
# ~/.gitconfig-client, Client Identity Override
# Generated by phase_03_git_config.ps1
#
# This file is included automatically for repos under ~/projects/client/
# via the [includeIf "gitdir:~/projects/client/"] directive in ~/.gitconfig.
#
# TO ACTIVATE: Run the /activate-client skill after creating the client
# GitHub account. That skill will:
#   1. Generate ~/.ssh/id_ed25519_github_client
#   2. Replace UPDATE_WITH_CLIENT_NOREPLY_EMAIL with the real address
#   3. Add the signing key to ~/.ssh/allowed_signers
#   4. Upload the public key to the client GitHub account
#
# UTC TIMESTAMPS:
#   The pre-commit hook at ~/.git-templates/hooks/pre-commit sets
#   GIT_COMMITTER_DATE to UTC for consistency across environments.
#   This is handled automatically by Phase 6 hooks.

[user]
    name        = $gitUserName
    email       = UPDATE_WITH_CLIENT_NOREPLY_EMAIL
    signingkey  = ~/.ssh/id_ed25519_github_client.pub

[gpg]
    format      = ssh

[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers
"@

Set-Content -Path $gitconfigPega -Value $gitconfigPegaContent -Encoding UTF8
Write-Pass "Written: $gitconfigPega"
$Results['~/.gitconfig-client'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 6: Write ~/.gitconfig-arduino
# ---------------------------------------------------------------------------

Write-Section "Step 6, Write ~/.gitconfig-arduino"

$gitconfigArduContent = @"
# ~/.gitconfig-arduino, Arduino/ArduPilot Identity Override
# Generated by phase_03_git_config.ps1
#
# This file is included automatically for repos under ~/projects/arduino/
# via the [includeIf "gitdir:~/projects/arduino/"] directive in ~/.gitconfig.
#
# Uses the personal identity and signing key (same GitHub account as personal).

[user]
    name        = $gitUserName
    email       = $noReplyEmail
    signingkey  = ~/.ssh/id_ed25519_github_personal

[gpg]
    format      = ssh

[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers
"@

Set-Content -Path $gitconfigArdu -Value $gitconfigArduContent -Encoding UTF8
Write-Pass "Written: $gitconfigArdu"
$Results['~/.gitconfig-arduino'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 7: Write ~/.gitmessage
# ---------------------------------------------------------------------------

Write-Section "Step 7, Write ~/.gitmessage"

$gitmessageContent = @"
# Conventional Commits, commit message template
# ─────────────────────────────────────────────
# Format:  <type>(<scope>): <short description>
#
# Types (required):
#   feat     : new feature
#   fix      : bug fix
#   docs     : documentation changes only
#   style    : formatting, missing semi-colons, etc. (no logic change)
#   refactor , code change that is neither a fix nor a feature
#   perf     : performance improvement
#   test     : adding or updating tests
#   chore    : build process, dependency updates, tooling
#   ci       : CI/CD configuration changes
#   revert   : reverts a previous commit
#
# Scope (optional): component, module, or file affected, e.g. (auth), (api)
#
# Short description rules:
#   - Lowercase, no period at the end
#   - Imperative mood: "add feature" not "added feature"
#   - Maximum 88 characters total (type + scope + description)
#
# Body (optional, blank line after subject):
#   - Explain WHY, not WHAT (the diff shows what)
#   - Wrap at 72 characters
#
# Footer (optional):
#   BREAKING CHANGE: <description>
#   Closes #<issue-number>
#   Co-authored-by: Name <email>
#
# Examples:
#   feat(auth): add SSH key rotation support
#   fix(hooks): prevent gitleaks false positive on test fixtures
#   chore: update uv to 0.5.0
#   docs(readme): add Phase 2 troubleshooting section
#
# ─────────────────────────────────────────────


"@

Set-Content -Path $gitmessage -Value $gitmessageContent -Encoding UTF8
Write-Pass "Written: $gitmessage"
$Results['~/.gitmessage'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 8: Update ~/.ssh/allowed_signers with real noreply email
# ---------------------------------------------------------------------------

Write-Section "Step 8, Update ~/.ssh/allowed_signers with noreply email"

$allowedSignersContent = @"
# allowed_signers, SSH commit signature verification
# Updated by phase_03_git_config.ps1
#
# To verify a commit signature:
#   git log --show-signature
#
# To verify a specific commit:
#   git verify-commit <hash>
$noReplyEmail $keyType $keyMaterial
"@

Set-Content -Path $allowedSigners -Value $allowedSignersContent -Encoding UTF8
Write-Pass "Updated: $allowedSigners (using $noReplyEmail)"
$Results['allowed_signers Updated'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 9: Verify: git config --list --global
# ---------------------------------------------------------------------------

Write-Section "Step 9, Verify git config --list --global"

try {
    $configOutput = git config --list --global 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "git config --list returned non-zero: $LASTEXITCODE"
        $Results['git config --list'] = 'WARN'
    } else {
        Write-Host ""
        Write-Host "  --- git config --list --global output ---" -ForegroundColor White
        foreach ($line in ($configOutput -split "`n")) {
            if ($line.Trim()) {
                Write-Host "  $line" -ForegroundColor Cyan
            }
        }
        Write-Host "  --- end of git config output ---" -ForegroundColor White
        Write-Host ""

        # Check key values
        $checks = @{
            'user.name'            = $gitUserName
            'commit.gpgsign'       = 'true'
            'tag.gpgsign'          = 'true'
            'pull.rebase'          = 'true'
            'init.defaultbranch'   = 'main'
        }

        $verifyOk = $true
        foreach ($ck in $checks.GetEnumerator()) {
            $found = $configOutput | Where-Object { $_ -match "^$($ck.Key)=$($ck.Value)$" }
            if ($found) {
                Write-Pass "Verified: $($ck.Key) = $($ck.Value)"
            } else {
                Write-Warn "Not found or wrong value: $($ck.Key) = $($ck.Value)"
                $verifyOk = $false
            }
        }

        $Results['git config --list'] = if ($verifyOk) { 'PASS' } else { 'WARN' }
    }
} catch {
    Write-Warn "Could not run git config --list: $_"
    $Results['git config --list'] = 'WARN'
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 3, Summary"                       -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$colW = 30
Write-Host ("{0,-$colW} {1}" -f 'Step', 'Status') -ForegroundColor White
Write-Host ("{0,-$colW} {1}" -f ('-' * ($colW - 1)), '------') -ForegroundColor White

$anyFail = $false
foreach ($kv in $Results.GetEnumerator()) {
    $color = switch -Wildcard ($kv.Value) {
        'PASS*' { 'Green'  }
        'FAIL'  { 'Red'    }
        'WARN'  { 'Yellow' }
        default { 'White'  }
    }
    Write-Host ("{0,-$colW} {1}" -f $kv.Key, $kv.Value) -ForegroundColor $color
    if ($kv.Value -eq 'FAIL') { $anyFail = $true }
}

Write-Host ""
if ($anyFail) {
    Write-Fail "One or more steps failed. Review the output above and fix before running Phase 4."
    exit 1
} else {
    Write-Pass "Git configuration complete. Proceed to Phase 4 (directory structure)."
    exit 0
}
