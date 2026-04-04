#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 10 - Windows Environment Configuration

.DESCRIPTION
    Script Name : phase_10_windows_env.ps1
    Purpose     : Configure Windows environment variables, PATH, Windows Terminal,
                  Oh My Posh theme, and PowerShell profile.
    Phase       : 10
    Exit Criteria:
        - User env vars GIT_SSH, LANG, LC_ALL are set
        - All required tools verified on PATH (with pass/fail table)
        - Oh My Posh theme copied to ~/.oh-my-posh/theme.json
        - PowerShell profile updated with Oh My Posh init and ssh-agent block
        - Windows Terminal profiles updated (or fallback config written)
        - Summary of all changes printed

.NOTES
    Run from any location; $RepoRoot is derived from $PSScriptRoot.
    Some steps (system PATH, Windows Terminal settings) benefit from Administrator.
    User-scoped environment variable changes work without Administrator.
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
    Write-Host "`n[ABORTED] Phase 10 did not complete successfully." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$RepoRoot       = Split-Path -Parent $PSScriptRoot
$OhMyPoshSrc    = Join-Path $RepoRoot 'config\ohmyposh-theme.json'
$OhMyPoshDir    = Join-Path $HOME '.oh-my-posh'
$OhMyPoshDest   = Join-Path $OhMyPoshDir 'theme.json'
$ProfilePath    = $PROFILE   # Points to Current User, Current Host (pwsh)

# Windows Terminal settings locations
$WTSettingsPath1 = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$WTSettingsPath2 = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
$WTFallbackPath  = Join-Path $RepoRoot 'config\windows-terminal-profiles.json'

# Track results
$Results = [ordered]@{}
$ChangeLog = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Phase 10 - Windows Environment Setup"  -ForegroundColor Cyan
Write-Host "  Repo Root : $RepoRoot"                 -ForegroundColor Cyan
Write-Host "=======================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Check for Administrator
# ---------------------------------------------------------------------------
Write-Section "Step 1: Administrator check"

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if ($IsAdmin) {
    Write-Pass "Running as Administrator."
} else {
    Write-Warn "NOT running as Administrator. User-scoped env vars will be set."
    Write-Warn "System PATH changes and some Windows Terminal edits may require elevation."
    Write-Warn "Re-run as Administrator if any steps fail due to permissions."
}
$Results['AdminCheck'] = if ($IsAdmin) { 'PASS (Admin)' } else { 'WARN (User)' }

# ---------------------------------------------------------------------------
# Step 2 - Set user environment variables
# ---------------------------------------------------------------------------
Write-Section "Step 2: Set user environment variables"

$EnvVars = [ordered]@{
    'GIT_SSH' = 'C:\Windows\System32\OpenSSH\ssh.exe'
    'LANG'    = 'en_US.UTF-8'
    'LC_ALL'  = 'en_US.UTF-8'
}

foreach ($VarName in $EnvVars.Keys) {
    $DesiredValue = $EnvVars[$VarName]
    $CurrentValue = [System.Environment]::GetEnvironmentVariable($VarName, 'User')
    if ($CurrentValue -eq $DesiredValue) {
        Write-Info "$VarName already set to: $DesiredValue"
        $Results["EnvVar_$VarName"] = 'PASS (already set)'
    } else {
        try {
            [System.Environment]::SetEnvironmentVariable($VarName, $DesiredValue, 'User')
            # Also apply to current session
            [System.Environment]::SetEnvironmentVariable($VarName, $DesiredValue, 'Process')
            Write-Pass "Set $VarName = $DesiredValue"
            $Results["EnvVar_$VarName"] = 'PASS'
            $ChangeLog.Add("Set env var: $VarName = $DesiredValue")
        } catch {
            Write-Fail "Failed to set $VarName : $_"
            $Results["EnvVar_$VarName"] = 'FAIL'
        }
    }
}

# ---------------------------------------------------------------------------
# Step 3 - Verify required tools on PATH
# ---------------------------------------------------------------------------
Write-Section "Step 3: Verify required tools on PATH"

$RequiredTools = @(
    'git', 'gh', 'gitleaks', 'nasm', 'uv', 'ruff', 'pwsh', 'delta', 'oh-my-posh'
)
$OptionalTools = @('x64dbg')

# Additional common locations for x64dbg
$X64DbgPaths = @(
    'C:\Program Files\x64dbg\release\x64\x64dbg.exe',
    'C:\Tools\x64dbg\release\x64\x64dbg.exe',
    "$env:USERPROFILE\tools\x64dbg\release\x64\x64dbg.exe"
)

Write-Host "`n  Tool              Status    Path" -ForegroundColor Cyan
Write-Host "  ----------------  --------  ----" -ForegroundColor Cyan

foreach ($Tool in $RequiredTools) {
    $Cmd = Get-Command $Tool -ErrorAction SilentlyContinue
    if ($Cmd) {
        Write-Host ("  {0,-18}" -f $Tool) -ForegroundColor Cyan -NoNewline
        Write-Host ("{0,-10}" -f "FOUND") -ForegroundColor Green -NoNewline
        Write-Host $Cmd.Source
        $Results["Tool_$Tool"] = 'PASS'
    } else {
        Write-Host ("  {0,-18}" -f $Tool) -ForegroundColor Cyan -NoNewline
        Write-Host ("{0,-10}" -f "NOT FOUND") -ForegroundColor Red -NoNewline
        Write-Host "(not on PATH)"
        $Results["Tool_$Tool"] = 'FAIL'
    }
}

# x64dbg - optional, check common paths
$X64Found = $false
foreach ($X64Path in $X64DbgPaths) {
    if (Test-Path $X64Path -PathType Leaf) {
        Write-Host ("  {0,-18}" -f 'x64dbg') -ForegroundColor Cyan -NoNewline
        Write-Host ("{0,-10}" -f "FOUND") -ForegroundColor Green -NoNewline
        Write-Host $X64Path
        $X64Found = $true
        break
    }
}
if (-not $X64Found) {
    $X64Cmd = Get-Command 'x64dbg' -ErrorAction SilentlyContinue
    if ($X64Cmd) {
        Write-Host ("  {0,-18}" -f 'x64dbg') -ForegroundColor Cyan -NoNewline
        Write-Host ("{0,-10}" -f "FOUND") -ForegroundColor Green -NoNewline
        Write-Host $X64Cmd.Source
    } else {
        Write-Host ("  {0,-18}" -f 'x64dbg') -ForegroundColor Cyan -NoNewline
        Write-Host ("{0,-10}" -f "WARN") -ForegroundColor Yellow -NoNewline
        Write-Host "(optional - not found in common locations)"
    }
}

# ---------------------------------------------------------------------------
# Step 4 - Copy Oh My Posh theme
# ---------------------------------------------------------------------------
Write-Section "Step 4: Copy Oh My Posh theme"

if (-not (Test-Path $OhMyPoshSrc -PathType Leaf)) {
    Write-Warn "Oh My Posh theme source not found: $OhMyPoshSrc"
    Write-Warn "Skipping theme copy. Place ohmyposh-theme.json in $RepoRoot\config\ and re-run."
    $Results['OhMyPoshTheme'] = 'WARN (source missing)'
} else {
    try {
        if (-not (Test-Path $OhMyPoshDir -PathType Container)) {
            New-Item -ItemType Directory -Path $OhMyPoshDir -Force | Out-Null
            Write-Pass "Created: $OhMyPoshDir"
        }
        Copy-Item -Path $OhMyPoshSrc -Destination $OhMyPoshDest -Force
        Write-Pass "Theme copied to: $OhMyPoshDest"
        $Results['OhMyPoshTheme'] = 'PASS'
        $ChangeLog.Add("Copied Oh My Posh theme to: $OhMyPoshDest")
    } catch {
        Write-Fail "Failed to copy Oh My Posh theme: $_"
        $Results['OhMyPoshTheme'] = 'FAIL'
    }
}

# ---------------------------------------------------------------------------
# Step 5 - Configure PowerShell profile
# ---------------------------------------------------------------------------
Write-Section "Step 5: Configure PowerShell profile"

Write-Info "Profile path: $ProfilePath"

$OhMyPoshLine = "oh-my-posh init pwsh --config `"$HOME\.oh-my-posh\theme.json`" | Invoke-Expression"

$SSHAgentBlock = @'

# SSH keys are managed by the Bitwarden desktop app (SSH Agent feature).
# No ssh-add needed — Bitwarden serves keys via \\.\pipe\openssh-ssh-agent.
# Ensure Bitwarden is open and your vault is unlocked before git operations.
'@

# Read or create profile
$ProfileDir = Split-Path -Parent $ProfilePath
if (-not (Test-Path $ProfileDir -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
        Write-Pass "Created profile directory: $ProfileDir"
    } catch {
        Write-Fail "Cannot create profile directory: $_"
        $Results['PSProfile'] = 'FAIL'
    }
}

$ProfileContent = ''
if (Test-Path $ProfilePath -PathType Leaf) {
    $ProfileContent = Get-Content -Path $ProfilePath -Raw -Encoding UTF8
    Write-Info "Existing profile loaded ($($ProfileContent.Length) chars)."
} else {
    Write-Info "No existing profile found - will create new."
}

$ProfileChanged = $false

# Check/add Oh My Posh init line
if ($ProfileContent -match [regex]::Escape('oh-my-posh init pwsh')) {
    Write-Info "Oh My Posh init line already present in profile."
    $Results['PSProfile_OhMyPosh'] = 'PASS (already present)'
} else {
    $ProfileContent = $ProfileContent.TrimEnd() + "`n`n" + $OhMyPoshLine + "`n"
    Write-Pass "Added Oh My Posh init line to profile."
    $Results['PSProfile_OhMyPosh'] = 'PASS'
    $ChangeLog.Add("Added Oh My Posh init to PowerShell profile.")
    $ProfileChanged = $true
}

# Check/add SSH agent block
if ($ProfileContent -match 'Auto-load SSH keys') {
    Write-Info "SSH agent key-loading block already present in profile."
    $Results['PSProfile_SSH'] = 'PASS (already present)'
} else {
    $ProfileContent = $ProfileContent.TrimEnd() + "`n" + $SSHAgentBlock + "`n"
    Write-Pass "Added SSH agent key-loading block to profile."
    $Results['PSProfile_SSH'] = 'PASS'
    $ChangeLog.Add("Added SSH key auto-load block to PowerShell profile.")
    $ProfileChanged = $true
}

# Write profile if changed
if ($ProfileChanged) {
    try {
        $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($ProfilePath, $ProfileContent, $Utf8NoBom)
        Write-Pass "Profile written: $ProfilePath"
        $Results['PSProfile_Write'] = 'PASS'
    } catch {
        Write-Fail "Failed to write PowerShell profile: $_"
        $Results['PSProfile_Write'] = 'FAIL'
    }
} else {
    Write-Info "Profile unchanged (all content already present)."
    $Results['PSProfile_Write'] = 'PASS (no change needed)'
}

# ---------------------------------------------------------------------------
# Step 6 - Configure Windows Terminal
# ---------------------------------------------------------------------------
Write-Section "Step 6: Configure Windows Terminal"

# Locate settings.json
$WTSettingsPath = $null
foreach ($Candidate in @($WTSettingsPath1, $WTSettingsPath2)) {
    if (Test-Path $Candidate -PathType Leaf) {
        $WTSettingsPath = $Candidate
        break
    }
}

# Resolve projects root from ~/.claude/config.json (written by phase_04).
# Falls back to %USERPROFILE%\projects if the config does not exist.
${ClaudeConfig} = Join-Path $HOME '.claude\config.json'
${ProjectsRoot} = if (Test-Path ${ClaudeConfig}) {
    (Get-Content ${ClaudeConfig} -Raw -Encoding UTF8 | ConvertFrom-Json).projects_root
} else {
    Join-Path $HOME 'projects'
}
# Convert backslashes to forward slashes — Windows Terminal requires forward slashes.
${ProjectsRoot} = ${ProjectsRoot}.Replace('\', '/')

# Profile definitions
$NewProfiles = @(
    [ordered]@{
        name              = 'GitHub Personal'
        commandline       = 'pwsh.exe'
        startingDirectory = "${ProjectsRoot}/personal"
        background        = '#1A1A2E'
        tabColor          = '#56B4E9'
        fontFace          = 'JetBrainsMono Nerd Font'
        fontSize          = 14
        colorScheme       = 'One Half Dark'
        hidden            = $false
    }
    [ordered]@{
        name              = 'GitHub Client'
        commandline       = 'pwsh.exe'
        startingDirectory = "${ProjectsRoot}/client"
        background        = '#1A1A2E'
        tabColor          = '#E69F00'
        fontFace          = 'JetBrainsMono Nerd Font'
        fontSize          = 14
        colorScheme       = 'One Half Dark'
        hidden            = $false
    }
    [ordered]@{
        name              = 'GitHub Arduino'
        commandline       = 'pwsh.exe'
        startingDirectory = "${ProjectsRoot}/arduino"
        background        = '#1A1A2E'
        tabColor          = '#CC79A7'
        fontFace          = 'JetBrainsMono Nerd Font'
        fontSize          = 14
        colorScheme       = 'One Half Dark'
        hidden            = $false
    }
)

if ($WTSettingsPath) {
    Write-Pass "Found Windows Terminal settings: $WTSettingsPath"
    try {
        $WTRaw = Get-Content -Path $WTSettingsPath -Raw -Encoding UTF8
        $WTSettings = $WTRaw | ConvertFrom-Json

        # Ensure profiles.list exists
        if (-not $WTSettings.profiles) {
            $WTSettings | Add-Member -MemberType NoteProperty -Name 'profiles' -Value ([PSCustomObject]@{ list = @() }) -Force
        }
        if (-not $WTSettings.profiles.list) {
            $WTSettings.profiles | Add-Member -MemberType NoteProperty -Name 'list' -Value @() -Force
        }

        $ProfileList = [System.Collections.Generic.List[object]]$WTSettings.profiles.list

        foreach ($NewProfile in $NewProfiles) {
            $ExistingIdx = -1
            for ($i = 0; $i -lt $ProfileList.Count; $i++) {
                if ($ProfileList[$i].name -eq $NewProfile.name) {
                    $ExistingIdx = $i
                    break
                }
            }

            $ProfileObj = [PSCustomObject]$NewProfile

            if ($ExistingIdx -ge 0) {
                # Update existing profile
                $ProfileList[$ExistingIdx] = $ProfileObj
                Write-Info "Updated existing profile: $($NewProfile.name)"
            } else {
                # Add new profile
                $ProfileList.Add($ProfileObj)
                Write-Pass "Added profile: $($NewProfile.name)"
            }
            $ChangeLog.Add("Windows Terminal profile: $($NewProfile.name)")
        }

        $WTSettings.profiles.list = $ProfileList.ToArray()
        $WTJson = $WTSettings | ConvertTo-Json -Depth 20
        $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($WTSettingsPath, $WTJson, $Utf8NoBom)
        Write-Pass "Windows Terminal settings saved."
        $Results['WindowsTerminal'] = 'PASS'
    } catch {
        Write-Fail "Failed to update Windows Terminal settings: $_"
        $Results['WindowsTerminal'] = 'FAIL'
    }
} else {
    Write-Warn "Windows Terminal settings.json not found in standard locations."
    Write-Warn "Writing profile definitions to: $WTFallbackPath"
    Write-Info "Install Windows Terminal from the Microsoft Store and re-run, or"
    Write-Info "manually merge $WTFallbackPath into your Windows Terminal settings."

    try {
        $FallbackObj = [ordered]@{
            _instructions = "Merge these profiles into your Windows Terminal settings.json under profiles.list"
            profiles      = $NewProfiles
        }
        $FallbackJson = $FallbackObj | ConvertTo-Json -Depth 10
        $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($WTFallbackPath, $FallbackJson, $Utf8NoBom)
        Write-Pass "Fallback config written: $WTFallbackPath"
        $Results['WindowsTerminal'] = 'WARN (fallback written)'
    } catch {
        Write-Fail "Could not write fallback config: $_"
        $Results['WindowsTerminal'] = 'FAIL'
    }
}

# ---------------------------------------------------------------------------
# Step 7 - Summary of all changes
# ---------------------------------------------------------------------------
Write-Section "Summary of Environment Changes"

Write-Host "`n  Changes made this run:" -ForegroundColor Cyan
if ($ChangeLog.Count -eq 0) {
    Write-Info "  No changes were necessary (everything already configured)."
} else {
    foreach ($Change in $ChangeLog) {
        Write-Host "    - $Change" -ForegroundColor Green
    }
}

Write-Host "`n  Result table:" -ForegroundColor Cyan
$PassCount = 0; $WarnCount = 0; $FailCount = 0
foreach ($Key in $Results.Keys) {
    $Val = $Results[$Key]
    $Color = switch -Wildcard ($Val) {
        'PASS*' { $PassCount++; 'Green'  }
        'WARN*' { $WarnCount++; 'Yellow' }
        default { $FailCount++; 'Red'    }
    }
    Write-Host ("    {0,-35} {1}" -f $Key, $Val) -ForegroundColor $Color
}

Write-Host "`n  Checks passed  : $PassCount" -ForegroundColor Green
Write-Host "  Warnings       : $WarnCount"   -ForegroundColor $(if ($WarnCount -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Failures       : $FailCount"   -ForegroundColor $(if ($FailCount -gt 0) { 'Red'    } else { 'Green' })

Write-Host "`n  Next steps:" -ForegroundColor Yellow
Write-Host "    - Restart your PowerShell session to load the updated profile." -ForegroundColor Yellow
Write-Host "    - Verify Oh My Posh prompt appears after restart."               -ForegroundColor Yellow
Write-Host "    - Open Windows Terminal and confirm the three new profiles."     -ForegroundColor Yellow
Write-Host "    - Run 'ssh-add -l' to verify SSH keys are loaded."              -ForegroundColor Yellow

if ($FailCount -gt 0) {
    Write-Host "`n[RESULT] Phase 10 completed with errors. Review failures above." -ForegroundColor Red
    exit 1
} elseif ($WarnCount -gt 0) {
    Write-Host "`n[RESULT] Phase 10 completed with warnings." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n[RESULT] Phase 10 completed successfully." -ForegroundColor Green
    exit 0
}
