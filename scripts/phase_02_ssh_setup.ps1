#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 2 — SSH Key Setup via Bitwarden SSH Agent

.DESCRIPTION
    Script Name : phase_02_ssh_setup.ps1
    Purpose     : Disable the Windows OpenSSH Authentication Agent service
                  (Bitwarden replaces it), capture the public key you create
                  in the Bitwarden vault, write ~/.ssh/config with host aliases
                  that hint the correct key per account, initialize
                  ~/.ssh/allowed_signers, and set the GIT_SSH environment
                  variable to the Windows OpenSSH client (required for
                  Bitwarden's named-pipe agent to work with git).
    Phase       : 2 of 12
    Exit Criteria: Windows OpenSSH Agent service is disabled, public key is
                   saved to ~/.ssh/id_ed25519_github_personal.pub,
                   ~/.ssh/config has both host aliases, GIT_SSH points to
                   Windows OpenSSH, public key is uploaded to GitHub and
                   connection test passes.

.NOTES
    Run with: pwsh -File scripts\phase_02_ssh_setup.ps1
    Prerequisite: Bitwarden desktop app version 2025.1.2 or newer is installed
                  and the SSH Agent feature is enabled in Bitwarden settings.
    After this script: upload the public key to GitHub (Steps 2B/2C).
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
    Write-Host "`nScript aborted. Fix the issue above and re-run Phase 2.`n" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Section header
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 2 — SSH Setup (Bitwarden Agent)"  -ForegroundColor Cyan
Write-Host "  Repo root: $RepoRoot"                   -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$sshDir         = Join-Path $HOME '.ssh'
$personalKeyPub = Join-Path $sshDir 'id_ed25519_github_personal.pub'
$clientHolder  = Join-Path $sshDir 'id_ed25519_github_client.placeholder'
$sshConfig      = Join-Path $sshDir 'config'
$allowedSigners = Join-Path $sshDir 'allowed_signers'

# Ensure ~/.ssh exists with correct permissions
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Write-Info "Created $sshDir"
}

$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Step 1 — Verify Bitwarden desktop is installed
# ---------------------------------------------------------------------------

Write-Section "Step 1 — Verify Bitwarden desktop is installed"

$bwPaths = @(
    "$env:LOCALAPPDATA\Programs\Bitwarden\Bitwarden.exe",
    "$env:ProgramFiles\Bitwarden\Bitwarden.exe",
    "${env:ProgramFiles(x86)}\Bitwarden\Bitwarden.exe"
)

$bwFound = $false
foreach ($p in $bwPaths) {
    if (Test-Path $p) {
        Write-Pass "Bitwarden desktop found: $p"
        $bwFound = $true
        break
    }
}

if (-not $bwFound) {
    # Also check if it shows up in start menu / winget list
    $wgCheck = winget list --id Bitwarden.Bitwarden 2>&1
    if ($LASTEXITCODE -eq 0 -and $wgCheck -match 'Bitwarden') {
        Write-Pass "Bitwarden desktop confirmed via winget"
        $bwFound = $true
    }
}

if (-not $bwFound) {
    Abort "Bitwarden desktop app not found. Install it first (winget install Bitwarden.Bitwarden), then re-run this script."
}

$Results['Bitwarden Installed'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 2 — Disable Windows OpenSSH Authentication Agent service
#           Bitwarden replaces it by exposing its own agent on the same
#           named pipe (\\.\pipe\openssh-ssh-agent). Both cannot coexist.
# ---------------------------------------------------------------------------

Write-Section "Step 2 — Disable Windows OpenSSH Authentication Agent service"

try {
    $svc = Get-Service -Name 'ssh-agent' -ErrorAction Stop

    if ($svc.StartType -eq 'Disabled' -and $svc.Status -ne 'Running') {
        Write-Pass "ssh-agent service is already disabled and stopped"
    } else {
        # Stop if running
        if ($svc.Status -eq 'Running') {
            Stop-Service -Name 'ssh-agent' -Force
            Write-Info "Stopped ssh-agent service"
        }
        # Disable startup
        Set-Service -Name 'ssh-agent' -StartupType Disabled
        Write-Pass "ssh-agent service set to Disabled (Bitwarden will take over this role)"
    }
    $Results['OpenSSH Agent Disabled'] = 'PASS'
} catch {
    Write-Warn "Could not modify ssh-agent service: $_"
    Write-Info "This step may require Administrator privileges."
    Write-Info "Manual fix (run PowerShell as Admin):"
    Write-Info "  Stop-Service ssh-agent -Force"
    Write-Info "  Set-Service  ssh-agent -StartupType Disabled"
    $Results['OpenSSH Agent Disabled'] = 'WARN'
}

# ---------------------------------------------------------------------------
# Step 3 — Manual: Enable Bitwarden SSH Agent and create SSH key in vault
# ---------------------------------------------------------------------------

Write-Section "Step 3 — Create SSH key in Bitwarden (manual)"

Write-Host @"

  ACTION REQUIRED — complete these steps in the Bitwarden desktop app
  before pressing Enter to continue:

  A. Open Bitwarden desktop.
  B. Go to: Settings -> Security -> SSH Agent
     Turn on "Enable SSH Agent".
     (If prompted, approve the Windows security dialog.)
  C. In the left sidebar, click "SSH Keys".
  D. Click "New SSH key".
  E. Fill in:
       Name    : GitHub Personal
       Key type: Ed25519    <-- must be Ed25519
  F. Click "Save".
  G. The key row now shows a fingerprint. Click the copy icon next to
     the PUBLIC KEY (the long string starting with ssh-ed25519 AAAA...).

  Keep the public key copied to your clipboard — the next step will ask
  you to paste it.

"@ -ForegroundColor Cyan

Read-Host "  Press Enter when you have the public key copied to your clipboard"

# ---------------------------------------------------------------------------
# Step 4 — Capture public key
# ---------------------------------------------------------------------------

Write-Section "Step 4 — Save public key from Bitwarden"

Write-Info "Paste the public key you just copied from Bitwarden."
Write-Info "It starts with: ssh-ed25519 AAAA..."
Write-Host ""

$publicKeyContent = ''
do {
    $publicKeyContent = (Read-Host "  Paste public key here").Trim()
    if ($publicKeyContent -notmatch '^ssh-ed25519\s+AAAA') {
        Write-Warn "That does not look like an Ed25519 public key."
        Write-Warn "Expected format: ssh-ed25519 AAAA... (optional comment)"
        Write-Warn "Try copying the key again from Bitwarden and paste it below."
        $publicKeyContent = ''
    }
} while ([string]::IsNullOrWhiteSpace($publicKeyContent))

Set-Content -Path $personalKeyPub -Value $publicKeyContent -Encoding UTF8 -NoNewline
Write-Pass "Public key saved: $personalKeyPub"
$Results['Public Key Saved'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 5 — Create client key placeholder
# ---------------------------------------------------------------------------

Write-Section "Step 5 — Create client key placeholder"

$placeholderContent = @"
# CLIENT KEY PLACEHOLDER
# ======================
# This file marks where the client SSH key will be created.
#
# The actual key (id_ed25519_github_client.pub) will be saved here when
# you run the /activate-client skill. That skill will guide you through
# creating a second key in Bitwarden named "GitHub Client" and wiring it
# up to the client GitHub account.
#
# DO NOT delete this file — it documents the pending setup.
"@

Set-Content -Path $clientHolder -Value $placeholderContent -Encoding UTF8
Write-Pass "Created client placeholder: $clientHolder"
$Results['Client Placeholder'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 6 — Write ~/.ssh/config
#
# IdentityFile points to the PUBLIC key file (.pub).
# OpenSSH uses this as a hint to ask the agent for the matching private key.
# The private key never leaves the Bitwarden vault.
# IdentitiesOnly yes ensures only the hinted key is offered (prevents
# wrong-account errors when multiple keys are in the vault).
# ---------------------------------------------------------------------------

Write-Section "Step 6 — Write ~/.ssh/config"

$sshConfigContent = @"
# SSH Configuration — GitHub Host Aliases
# Generated by phase_02_ssh_setup.ps1 (Bitwarden SSH Agent)
#
# How this works:
#   IdentityFile points to the PUBLIC key file on disk (.pub).
#   The private key is stored in the Bitwarden vault, never on disk.
#   When SSH connects, Bitwarden's agent is asked for the key that
#   matches the public key hint. IdentitiesOnly yes prevents other
#   vault keys from being tried for this host alias.
#
# Usage:
#   Personal repos : git clone git@github-personal:username/repo.git
#   Client repos  : git clone git@github-client:username/repo.git

Host github-personal
    HostName      github.com
    User          git
    IdentityFile  ~/.ssh/id_ed25519_github_personal.pub
    IdentitiesOnly yes

Host github-client
    HostName      github.com
    User          git
    IdentityFile  ~/.ssh/id_ed25519_github_client.pub
    IdentitiesOnly yes
"@

Set-Content -Path $sshConfig -Value $sshConfigContent -Encoding UTF8
Write-Pass "Written: $sshConfig"
$Results['SSH Config Written'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 7 — Write ~/.ssh/allowed_signers
# ---------------------------------------------------------------------------

Write-Section "Step 7 — Initialize ~/.ssh/allowed_signers"

$keyParts    = $publicKeyContent -split '\s+'
$keyType     = $keyParts[0]
$keyMaterial = $keyParts[1]

$allowedSignersContent = @"
# allowed_signers — SSH commit signature verification
# Updated by phase_02_ssh_setup.ps1
#
# NOTE: The email below uses a placeholder. Phase 3 will replace it
# with your real GitHub noreply email ({noreply_id}+{github_username}@users.noreply.github.com).
# After Phase 3, verify signatures with: git log --show-signature

your.email@placeholder $keyType $keyMaterial
"@

Set-Content -Path $allowedSigners -Value $allowedSignersContent -Encoding UTF8
Write-Pass "Written: $allowedSigners"
Write-Info "(Placeholder email will be replaced with your noreply address in Phase 3)"
$Results['allowed_signers'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 8 — Set GIT_SSH to Windows OpenSSH
#
# Git must use C:\Windows\System32\OpenSSH\ssh.exe, not Git's bundled ssh.
# Only the Windows OpenSSH client can connect to Bitwarden's named-pipe
# agent (\\.\pipe\openssh-ssh-agent). Git's bundled ssh.exe cannot.
# ---------------------------------------------------------------------------

Write-Section "Step 8 — Set GIT_SSH environment variable"

$opensshExe = 'C:\Windows\System32\OpenSSH\ssh.exe'
if (-not (Test-Path $opensshExe)) {
    $sshInPath = Get-Command ssh -ErrorAction SilentlyContinue
    if ($sshInPath) {
        $opensshExe = $sshInPath.Source
        Write-Info "Windows OpenSSH not at default path; using: $opensshExe"
    } else {
        Write-Warn "ssh.exe not found. GIT_SSH will be set to the standard path."
        Write-Info "Ensure OpenSSH Client is installed (Phase 1 should have done this)."
    }
}

[System.Environment]::SetEnvironmentVariable('GIT_SSH', $opensshExe, 'User')
$env:GIT_SSH = $opensshExe
Write-Pass "GIT_SSH set to: $opensshExe (User scope)"
$Results['GIT_SSH Variable'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 9 — Display public key for GitHub upload
# ---------------------------------------------------------------------------

Write-Section "Step 9 — Public key for GitHub upload"

Write-Host ""
Write-Host "  *** YOUR PUBLIC KEY — COPY EVERYTHING BELOW THIS LINE ***" -ForegroundColor Yellow
Write-Host ""
Write-Host "  $publicKeyContent" -ForegroundColor Green
Write-Host ""
Write-Host "  *** END OF PUBLIC KEY ***" -ForegroundColor Yellow
Write-Host ""

# ---------------------------------------------------------------------------
# Step 10 — Print manual instructions for Steps 2B and 2C
# ---------------------------------------------------------------------------

Write-Section "Step 10 — Manual steps: Upload key and test connection (2B & 2C)"

Write-Host @"

  STEP 2B — Upload your public key to GitHub (Manual):
  ─────────────────────────────────────────────────────
  1. Copy the public key printed above.
  2. Open your browser and go to:
       https://github.com/settings/ssh/new
  3. Add it as an AUTHENTICATION key:
       Title : {your_name} Personal — Authentication
       Type  : Authentication Key
       Key   : (paste the public key)
       Click "Add SSH key"
  4. Go to https://github.com/settings/ssh/new again.
  5. Add it as a SIGNING key:
       Title : {your_name} Personal — Signing
       Type  : Signing Key
       Key   : (paste the same public key)
       Click "Add SSH key"

  STEP 2C — Test the SSH connection (Manual, after uploading):
  ─────────────────────────────────────────────────────────────
  Make sure the Bitwarden desktop app is open and your vault is unlocked,
  then open a new PowerShell 7+ window and run:

      ssh -T github-personal

  Bitwarden will show an authorization prompt — click Allow (or set the
  key's authorization to "Remember until vault is locked" to reduce prompts).

  Expected response:
      Hi {github_username}! You've successfully authenticated, but GitHub
      does not provide shell access.

  If you see that message: Phase 2 is complete. Proceed to Phase 3.

"@ -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Phase 2 — Summary"                     -ForegroundColor Cyan
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
    Write-Fail "One or more steps failed. Review the output above and fix before running Phase 3."
    exit 1
} else {
    Write-Pass "SSH setup complete. Upload the public key to GitHub, test the connection, then run Phase 3."
    exit 0
}
