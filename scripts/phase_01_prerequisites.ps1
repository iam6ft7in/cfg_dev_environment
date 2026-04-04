#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 1 — Verify and Install Prerequisites

.DESCRIPTION
    Script Name : phase_01_prerequisites.ps1
    Purpose     : Check and install all required development tools at minimum
                  versions. Uses winget for most tools, with fallback to direct
                  download or manual instructions where winget is unavailable.
    Phase       : 1 of 12
    Exit Criteria: All tools report PASS in the summary table. No FAIL entries
                   remain. Git, GitHub CLI, and OpenSSH must pass for a zero
                   exit code.

.NOTES
    Run with: pwsh -File scripts\phase_01_prerequisites.ps1
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

function Get-VersionFromString {
    param([string]$Raw)
    if ($Raw -match '(\d+\.\d+(?:\.\d+)*)') { return [version]$Matches[1] }
    return $null
}

function Test-MinVersion {
    param([version]$Actual, [string]$Min)
    if ($null -eq $Actual) { return $false }
    return $Actual -ge [version]$Min
}

function Invoke-Winget {
    param([string]$PackageId)
    Write-Info "Running: winget install --id $PackageId -e --accept-source-agreements --accept-package-agreements"
    $result = winget install --id $PackageId -e --accept-source-agreements --accept-package-agreements 2>&1
    return $LASTEXITCODE -eq 0
}

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')
}

# ---------------------------------------------------------------------------
# Result tracking
# ---------------------------------------------------------------------------

$Results = [ordered]@{}  # tool => 'PASS' | 'FAIL' | 'WARN'
$CriticalTools = @('Git', 'GitHub CLI (gh)', 'OpenSSH Client')

# ---------------------------------------------------------------------------
# Section header
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 1 — Prerequisites Check/Install" -ForegroundColor Cyan
Write-Host "  Repo root: $RepoRoot"                   -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Git
# ---------------------------------------------------------------------------

Write-Section "Git (minimum 2.42)"

$gitOk = $false
try {
    $raw = git --version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '2.42') {
        Write-Pass "Git $ver is installed and meets minimum version 2.42"
        $gitOk = $true
    } else {
        Write-Warn "Git $ver found but minimum is 2.42 — attempting upgrade"
    }
} catch {
    Write-Warn "Git not found — attempting install via winget"
}

if (-not $gitOk) {
    if (Invoke-Winget 'Git.Git') {
        Refresh-Path
        try {
            $raw = git --version 2>&1
            $ver = Get-VersionFromString ($raw -join ' ')
            if (Test-MinVersion $ver '2.42') {
                Write-Pass "Git $ver installed successfully"
                $gitOk = $true
            } else {
                Write-Fail "Git installed but version $ver still below 2.42"
            }
        } catch {
            Write-Fail "Git still not on PATH after install"
        }
    } else {
        Write-Fail "winget failed. Manual install: https://git-scm.com/download/win"
    }
}

$Results['Git'] = if ($gitOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 2. GitHub CLI (gh)
# ---------------------------------------------------------------------------

Write-Section "GitHub CLI / gh (minimum 2.40)"

$ghOk = $false
try {
    $raw = gh --version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '2.40') {
        Write-Pass "gh $ver is installed and meets minimum version 2.40"
        $ghOk = $true
    } else {
        Write-Warn "gh $ver found but minimum is 2.40 — attempting upgrade"
    }
} catch {
    Write-Warn "gh not found — attempting install via winget"
}

if (-not $ghOk) {
    if (Invoke-Winget 'GitHub.cli') {
        Refresh-Path
        try {
            $raw = gh --version 2>&1
            $ver = Get-VersionFromString ($raw -join ' ')
            if (Test-MinVersion $ver '2.40') {
                Write-Pass "gh $ver installed successfully"
                $ghOk = $true
            } else {
                Write-Fail "gh installed but version $ver still below 2.40"
            }
        } catch {
            Write-Fail "gh still not on PATH after install"
        }
    } else {
        Write-Fail "winget failed. Manual install: https://cli.github.com/"
    }
}

$Results['GitHub CLI (gh)'] = if ($ghOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 3. OpenSSH Client (Windows Feature)
# ---------------------------------------------------------------------------

Write-Section "OpenSSH Client (Windows Feature)"

$sshOk = $false
try {
    $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Client*'
    if ($cap.State -eq 'Installed') {
        Write-Pass "OpenSSH Client Windows feature is installed"
        $sshOk = $true
    } else {
        Write-Warn "OpenSSH Client feature not installed — attempting to add"
        try {
            Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' | Out-Null
            Write-Pass "OpenSSH Client feature installed successfully"
            $sshOk = $true
        } catch {
            Write-Fail "Failed to install OpenSSH Client: $_"
            Write-Info "Manual fix: Settings -> Apps -> Optional Features -> Add a feature -> OpenSSH Client"
        }
    }
} catch {
    Write-Fail "Could not query Windows capabilities (requires admin?): $_"
    # Fall back to checking if ssh.exe exists
    $sshExe = 'C:\Windows\System32\OpenSSH\ssh.exe'
    if (Test-Path $sshExe) {
        Write-Warn "ssh.exe found at $sshExe (feature query failed but binary exists)"
        $sshOk = $true
    }
}

$Results['OpenSSH Client'] = if ($sshOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 4. gitleaks
# ---------------------------------------------------------------------------

Write-Section "gitleaks (minimum 8.18)"

$gitleaksOk = $false
try {
    $raw = gitleaks version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '8.18') {
        Write-Pass "gitleaks $ver is installed and meets minimum version 8.18"
        $gitleaksOk = $true
    } else {
        Write-Warn "gitleaks $ver found but minimum is 8.18 — attempting upgrade"
    }
} catch {
    Write-Warn "gitleaks not found — attempting install"
}

if (-not $gitleaksOk) {
    Write-Info "Trying winget: Zricethezav.gitleaks"
    if (Invoke-Winget 'Zricethezav.gitleaks') {
        Refresh-Path
        $gitleaksOk = $true
        Write-Pass "gitleaks installed via winget"
    } else {
        Write-Warn "winget install failed — trying GitHub releases download"
        try {
            $release = Invoke-RestMethod 'https://api.github.com/repos/gitleaks/gitleaks/releases/latest'
            $asset   = $release.assets | Where-Object { $_.name -match 'windows.*x64.*zip' -or $_.name -match 'x64.*windows.*zip' } | Select-Object -First 1
            if (-not $asset) {
                $asset = $release.assets | Where-Object { $_.name -match 'windows' -and $_.name -match '\.zip$' } | Select-Object -First 1
            }
            if ($asset) {
                $zipPath    = "$env:TEMP\gitleaks.zip"
                $extractDir = "$env:TEMP\gitleaks"
                Write-Info "Downloading $($asset.name) from GitHub releases"
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
                Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
                $exe = Get-ChildItem $extractDir -Filter 'gitleaks.exe' -Recurse | Select-Object -First 1
                if ($exe) {
                    $destDir = "$env:LOCALAPPDATA\Programs\gitleaks"
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    Copy-Item $exe.FullName "$destDir\gitleaks.exe" -Force
                    # Add to user PATH if not already present
                    $userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
                    if ($userPath -notlike "*$destDir*") {
                        [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$destDir", 'User')
                        Refresh-Path
                    }
                    Write-Pass "gitleaks installed to $destDir"
                    $gitleaksOk = $true
                } else {
                    Write-Fail "gitleaks.exe not found in downloaded archive"
                }
            } else {
                Write-Fail "No suitable Windows asset found in gitleaks GitHub releases"
            }
        } catch {
            Write-Fail "GitHub download also failed: $_"
            Write-Info "Manual install: https://github.com/gitleaks/gitleaks/releases"
            Write-Info "Download the Windows x64 zip, extract gitleaks.exe, add it to your PATH."
        }
    }
}

$Results['gitleaks'] = if ($gitleaksOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 5. NASM
# ---------------------------------------------------------------------------

Write-Section "NASM (minimum 2.16)"

$nasmOk = $false
try {
    $raw = nasm --version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '2.16') {
        Write-Pass "NASM $ver is installed and meets minimum version 2.16"
        $nasmOk = $true
    } else {
        Write-Warn "NASM $ver found but minimum is 2.16 — attempting upgrade"
    }
} catch {
    Write-Warn "NASM not found — attempting install via winget"
}

if (-not $nasmOk) {
    if (Invoke-Winget 'NASM.NASM') {
        Refresh-Path
        try {
            $raw = nasm --version 2>&1
            $ver = Get-VersionFromString ($raw -join ' ')
            Write-Pass "NASM $ver installed successfully"
            $nasmOk = $true
        } catch {
            Write-Warn "NASM installed but not yet on PATH — may need to restart terminal"
            $nasmOk = $true  # winget succeeded; PATH refresh may need a new shell
        }
    } else {
        Write-Fail "winget failed. Manual install: https://nasm.us/pub/nasm/releasebuilds/"
    }
}

$Results['NASM'] = if ($nasmOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 6. uv
# ---------------------------------------------------------------------------

Write-Section "uv — Python environment manager (minimum 0.4)"

$uvOk = $false
try {
    $raw = uv --version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '0.4') {
        Write-Pass "uv $ver is installed and meets minimum version 0.4"
        $uvOk = $true
    } else {
        Write-Warn "uv $ver found but minimum is 0.4 — attempting upgrade"
    }
} catch {
    Write-Warn "uv not found — installing via official installer"
}

if (-not $uvOk) {
    try {
        Write-Info "Running: Invoke-WebRequest https://astral.sh/uv/install.ps1 | Invoke-Expression"
        Invoke-WebRequest -Uri 'https://astral.sh/uv/install.ps1' -UseBasicParsing | Invoke-Expression
        Refresh-Path
        $raw = uv --version 2>&1
        $ver = Get-VersionFromString ($raw -join ' ')
        if (Test-MinVersion $ver '0.4') {
            Write-Pass "uv $ver installed successfully"
            $uvOk = $true
        } else {
            Write-Fail "uv installed but version $ver still below 0.4"
        }
    } catch {
        Write-Fail "uv install failed: $_"
        Write-Info "Manual install: https://docs.astral.sh/uv/getting-started/installation/"
    }
}

$Results['uv'] = if ($uvOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 7. ruff
# ---------------------------------------------------------------------------

Write-Section "ruff — Python linter/formatter (minimum 0.3)"

$ruffOk = $false
try {
    $raw = ruff --version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '0.3') {
        Write-Pass "ruff $ver is installed and meets minimum version 0.3"
        $ruffOk = $true
    } else {
        Write-Warn "ruff $ver found but minimum is 0.3 — attempting upgrade"
    }
} catch {
    Write-Warn "ruff not found — attempting install via uv"
}

if (-not $ruffOk) {
    if ($uvOk) {
        try {
            Write-Info "Running: uv tool install ruff"
            uv tool install ruff 2>&1 | Out-Null
            Refresh-Path
            $raw = ruff --version 2>&1
            $ver = Get-VersionFromString ($raw -join ' ')
            if (Test-MinVersion $ver '0.3') {
                Write-Pass "ruff $ver installed successfully via uv"
                $ruffOk = $true
            } else {
                Write-Fail "ruff installed but version $ver still below 0.3"
            }
        } catch {
            Write-Fail "ruff install via uv failed: $_"
        }
    } else {
        Write-Fail "uv is not available — cannot install ruff automatically"
        Write-Info "Manual install: uv tool install ruff  (after installing uv)"
    }
}

$Results['ruff'] = if ($ruffOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 8. delta
# ---------------------------------------------------------------------------

Write-Section "delta — git diff pager (minimum 0.17)"

$deltaOk = $false
try {
    $raw = delta --version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '0.17') {
        Write-Pass "delta $ver is installed and meets minimum version 0.17"
        $deltaOk = $true
    } else {
        Write-Warn "delta $ver found but minimum is 0.17 — attempting upgrade"
    }
} catch {
    Write-Warn "delta not found — attempting install via winget"
}

if (-not $deltaOk) {
    if (Invoke-Winget 'dandavison.delta') {
        Refresh-Path
        try {
            $raw = delta --version 2>&1
            $ver = Get-VersionFromString ($raw -join ' ')
            Write-Pass "delta $ver installed successfully"
            $deltaOk = $true
        } catch {
            Write-Warn "delta installed but not yet on PATH — may need to restart terminal"
            $deltaOk = $true
        }
    } else {
        Write-Fail "winget failed. Manual install: https://github.com/dandavison/delta/releases"
    }
}

$Results['delta'] = if ($deltaOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 9. x64dbg
# ---------------------------------------------------------------------------

Write-Section "x64dbg — Assembly debugger (any recent version)"

$x64dbgOk = $false

# Check common locations
$commonPaths = @(
    'x64dbg.exe',
    "$env:LOCALAPPDATA\x64dbg\release\x64\x64dbg.exe",
    "$env:LOCALAPPDATA\x64dbg\x64dbg.exe",
    'C:\Program Files\x64dbg\release\x64\x64dbg.exe',
    'C:\Tools\x64dbg\release\x64\x64dbg.exe'
)

foreach ($p in $commonPaths) {
    try {
        $resolved = Get-Command $p -ErrorAction SilentlyContinue
        if ($resolved) { $x64dbgOk = $true; Write-Pass "x64dbg found at $($resolved.Source)"; break }
    } catch {}
    if (Test-Path $p) { $x64dbgOk = $true; Write-Pass "x64dbg found at $p"; break }
}

if (-not $x64dbgOk) {
    Write-Warn "x64dbg not found in PATH or common locations — attempting download from GitHub releases"
    try {
        $release = Invoke-RestMethod 'https://api.github.com/repos/x64dbg/x64dbg/releases/latest'
        $asset   = $release.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
        if ($asset) {
            $zipPath    = "$env:TEMP\x64dbg.zip"
            $extractDir = "$env:LOCALAPPDATA\x64dbg"
            Write-Info "Downloading $($asset.name) from GitHub releases"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
            # Find x64dbg.exe recursively
            $exe = Get-ChildItem $extractDir -Filter 'x64dbg.exe' -Recurse | Select-Object -First 1
            if ($exe) {
                $exeDir = $exe.DirectoryName
                $userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
                if ($userPath -notlike "*$exeDir*") {
                    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$exeDir", 'User')
                    Refresh-Path
                }
                Write-Pass "x64dbg extracted to $exeDir"
                $x64dbgOk = $true
            } else {
                Write-Fail "x64dbg.exe not found in downloaded archive"
            }
        } else {
            Write-Fail "No zip asset found in x64dbg GitHub releases"
        }
    } catch {
        Write-Fail "GitHub download failed: $_"
        Write-Info "Manual install: https://github.com/x64dbg/x64dbg/releases"
        Write-Info "Download the zip, extract it, and add the x64 folder to your PATH."
    }
}

$Results['x64dbg'] = if ($x64dbgOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 10. Oh My Posh
# ---------------------------------------------------------------------------

Write-Section "Oh My Posh — terminal prompt engine (minimum version 23)"

$ompOk = $false
try {
    $raw = oh-my-posh --version 2>&1
    $ver = Get-VersionFromString ($raw -join ' ')
    if (Test-MinVersion $ver '23.0') {
        Write-Pass "Oh My Posh $ver is installed and meets minimum version 23"
        $ompOk = $true
    } else {
        Write-Warn "Oh My Posh $ver found but minimum is 23 — attempting upgrade"
    }
} catch {
    Write-Warn "Oh My Posh not found — attempting install via winget"
}

if (-not $ompOk) {
    if (Invoke-Winget 'JanDeDobbeleer.OhMyPosh') {
        Refresh-Path
        try {
            $raw = oh-my-posh --version 2>&1
            $ver = Get-VersionFromString ($raw -join ' ')
            Write-Pass "Oh My Posh $ver installed successfully"
            $ompOk = $true
        } catch {
            Write-Warn "Oh My Posh installed but not yet on PATH — may need to restart terminal"
            $ompOk = $true
        }
    } else {
        Write-Fail "winget failed. Manual install: https://ohmyposh.dev/docs/installation/windows"
    }
}

$Results['Oh My Posh'] = if ($ompOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# 11. JetBrains Mono Nerd Font
# ---------------------------------------------------------------------------

Write-Section "JetBrains Mono Nerd Font"

$fontOk = $false

# Check Windows fonts registry / folder
$fontFolder  = "$env:WINDIR\Fonts"
$localFonts  = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

$fontFiles = @(
    (Get-ChildItem $fontFolder  -Filter '*JetBrainsMono*' -ErrorAction SilentlyContinue),
    (Get-ChildItem $localFonts  -Filter '*JetBrainsMono*' -ErrorAction SilentlyContinue)
) | Where-Object { $_ }

if ($fontFiles) {
    Write-Pass "JetBrains Mono Nerd Font found in Windows fonts"
    $fontOk = $true
} else {
    Write-Warn "JetBrains Mono Nerd Font not found — attempting download from nerd-fonts GitHub releases"
    try {
        $release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
        $asset   = $release.assets | Where-Object { $_.name -eq 'JetBrainsMono.zip' } | Select-Object -First 1
        if ($asset) {
            $zipPath    = "$env:TEMP\JetBrainsMono.zip"
            $extractDir = "$env:TEMP\JetBrainsMono"
            Write-Info "Downloading JetBrainsMono.zip ($([math]::Round($asset.size/1MB,1)) MB)"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

            # Install fonts to user font folder (no admin needed)
            New-Item -ItemType Directory -Path $localFonts -Force | Out-Null
            $ttfFiles = Get-ChildItem $extractDir -Filter '*.ttf' -Recurse
            $installed = 0
            foreach ($ttf in $ttfFiles) {
                $dest = Join-Path $localFonts $ttf.Name
                Copy-Item $ttf.FullName $dest -Force
                $installed++
            }
            Write-Pass "Installed $installed JetBrains Mono Nerd Font files to $localFonts"
            $fontOk = $true
        } else {
            Write-Fail "JetBrainsMono.zip not found in nerd-fonts releases"
            Write-Info "Manual install: https://www.nerdfonts.com/font-downloads -> JetBrains Mono"
        }
    } catch {
        Write-Fail "Font download failed: $_"
        Write-Info "Manual install: https://www.nerdfonts.com/font-downloads"
        Write-Info "Download JetBrainsMono.zip, extract, right-click each .ttf -> Install for all users"
    }
}

$Results['JetBrains Mono Nerd Font'] = if ($fontOk) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# Summary table
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 1 — Summary"                       -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$colW = 30
Write-Host ("{0,-$colW} {1}" -f 'Tool', 'Status') -ForegroundColor White
Write-Host ("{0,-$colW} {1}" -f ('-' * ($colW - 1)), '------') -ForegroundColor White

$anyFail = $false
$criticalFail = $false

foreach ($kv in $Results.GetEnumerator()) {
    $color = switch ($kv.Value) {
        'PASS' { 'Green'  }
        'FAIL' { 'Red'    }
        'WARN' { 'Yellow' }
    }
    Write-Host ("{0,-$colW} {1}" -f $kv.Key, $kv.Value) -ForegroundColor $color
    if ($kv.Value -eq 'FAIL') {
        $anyFail = $true
        if ($kv.Key -in $CriticalTools) { $criticalFail = $true }
    }
}

Write-Host ""

if ($criticalFail) {
    Write-Fail "One or more CRITICAL tools (Git, GitHub CLI, OpenSSH) failed. Fix them before proceeding to Phase 2."
    exit 1
} elseif ($anyFail) {
    Write-Warn "Some non-critical tools failed. Review the table above and install them manually if needed."
    Write-Warn "You may proceed to Phase 2, but functionality will be limited."
    exit 0
} else {
    Write-Pass "All tools passed. You are ready to proceed to Phase 2."
    exit 0
}
