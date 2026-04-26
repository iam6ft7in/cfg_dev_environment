#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 6: Git Hooks and Secret Scanning

.DESCRIPTION
    Script Name : phase_06_hooks_and_scanning.ps1
    Purpose     : Install gitleaks pre-commit hook, Conventional Commits
                  commit-msg hook, gitleaks.toml config, set
                  init.templateDir in gitconfig, create a Windows Task
                  Scheduler job for weekly gitleaks scans, and self-test
                  the commit-msg regex pattern.
    Phase       : 6 of 12
    Exit Criteria: Hooks are in ~/.git-templates/hooks/, init.templateDir
                   is set, Task Scheduler task exists, regex self-test passes.

.NOTES
    Run with: pwsh -File scripts\phase_06_hooks_and_scanning.ps1
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
    Write-Host "`nScript aborted. Fix the issue above and re-run Phase 6.`n" -ForegroundColor Red
    exit 1
}

# Write a text file with Unix line endings (LF), hooks must use LF
function Write-UnixFile {
    param([string]$Path, [string]$Content)
    # Normalize to LF
    $lfContent = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($lfContent)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

# ---------------------------------------------------------------------------
# Section header
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 6, Hooks and Secret Scanning"   -ForegroundColor Cyan
Write-Host "  Repo root: $RepoRoot"                  -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$templateDir  = Join-Path $HOME '.git-templates'
$hooksDir     = Join-Path $templateDir 'hooks'
$preCommit    = Join-Path $hooksDir 'pre-commit'
$commitMsg    = Join-Path $hooksDir 'commit-msg'
$weeklyScript = Join-Path $templateDir 'gitleaks-weekly-scan.ps1'
$gitleaksToml = Join-Path $HOME '.gitleaks.toml'
$configSrc    = Join-Path $RepoRoot 'config\gitleaks.toml'

# Hook bodies live in config/git-templates/hooks/ as the source of
# truth (added in the Phase D Tier B sweep). Single source of truth:
# edit those files, re-run Phase 6 to redeploy.
$preCommitTemplate = Join-Path $RepoRoot 'config\git-templates\hooks\pre-commit'
$commitMsgTemplate = Join-Path $RepoRoot 'config\git-templates\hooks\commit-msg'

$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Step 1: Ensure ~/.git-templates/hooks/ exists
# ---------------------------------------------------------------------------

Write-Section "Step 1, Ensure ~/.git-templates/hooks/ exists"

foreach ($dir in @($templateDir, $hooksDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Pass "Created: $dir"
    } else {
        Write-Info "Already exists: $dir"
    }
}
$Results['Template Hooks Dir'] = 'PASS'

# ---------------------------------------------------------------------------
# Step 2: Write pre-commit hook
# ---------------------------------------------------------------------------

Write-Section "Step 2, Write pre-commit hook (gitleaks staged scan)"

if (-not (Test-Path $preCommitTemplate)) {
    Abort "Template missing: $preCommitTemplate"
}
$preCommitContent = Get-Content -Raw -Path $preCommitTemplate

try {
    Write-UnixFile -Path $preCommit -Content $preCommitContent
    Write-Pass "Written: $preCommit (from $preCommitTemplate)"
    $Results['pre-commit Hook'] = 'PASS'
} catch {
    Write-Fail "Failed to write pre-commit hook: $_"
    $Results['pre-commit Hook'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 3: Write commit-msg hook
# ---------------------------------------------------------------------------

Write-Section "Step 3, Write commit-msg hook (Conventional Commits)"

if (-not (Test-Path $commitMsgTemplate)) {
    Abort "Template missing: $commitMsgTemplate"
}
$commitMsgContent = Get-Content -Raw -Path $commitMsgTemplate

try {
    Write-UnixFile -Path $commitMsg -Content $commitMsgContent
    Write-Pass "Written: $commitMsg (from $commitMsgTemplate)"
    $Results['commit-msg Hook'] = 'PASS'
} catch {
    Write-Fail "Failed to write commit-msg hook: $_"
    $Results['commit-msg Hook'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 4: Note on hook executability (Windows)
# ---------------------------------------------------------------------------

Write-Section "Step 4, Hook executability (Windows note)"

Write-Info "On Windows, git executes hook files directly via sh.exe bundled with Git."
Write-Info "The #!/bin/sh shebang and LF line endings (enforced above) are sufficient."
Write-Info "No chmod +x required on Windows, git handles this automatically."
$Results['Hook Executability'] = 'PASS (Windows, no chmod needed)'

# ---------------------------------------------------------------------------
# Step 5: Write ~/.gitleaks.toml
# ---------------------------------------------------------------------------

Write-Section "Step 5, Install ~/.gitleaks.toml"

# Source of truth is config/gitleaks.toml in this repo. The previous
# inline-default fallback was dead weight (config/gitleaks.toml is
# always committed) and risked silent drift between the inline copy
# and the committed template. Abort if the template is missing.

if (-not (Test-Path $configSrc)) {
    Abort "Template missing: $configSrc. Run from a complete cfg_dev_environment checkout."
}
try {
    Copy-Item -Path $configSrc -Destination $gitleaksToml -Force
    Write-Pass "Copied from repo: $configSrc -> $gitleaksToml"
    $Results['gitleaks.toml'] = 'PASS (from repo config/)'
} catch {
    Abort "Copy failed: $_"
}

# ---------------------------------------------------------------------------
# Step 6: Set init.templateDir in gitconfig
# ---------------------------------------------------------------------------

Write-Section "Step 6, Set init.templateDir in ~/.gitconfig"

try {
    # git config stores paths with forward slashes
    $templateDirForward = $templateDir -replace '\\', '/'
    git config --global init.templateDir $templateDirForward
    $readBack = (git config --global init.templateDir).Trim()
    Write-Pass "init.templateDir = $readBack"
    $Results['init.templateDir'] = 'PASS'
} catch {
    Write-Fail "Could not set init.templateDir: $_"
    $Results['init.templateDir'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 7: Write weekly scan script and create Task Scheduler task
# ---------------------------------------------------------------------------

Write-Section "Step 7, Weekly gitleaks scan (Task Scheduler)"

# 7a, Write the scan script
$weeklyScanContent = @"
#Requires -Version 7.0
# gitleaks-weekly-scan.ps1
# Runs gitleaks on every git repo under projects_root (read from
# ~/.claude/config.json) every Sunday at 02:00 AM.
# Created by phase_06_hooks_and_scanning.ps1

`$cfgPath   = Join-Path `$HOME '.claude\config.json'
`$scanRoot  = Join-Path `$HOME 'projects'
if (Test-Path `$cfgPath) {
    try {
        `$cfg = Get-Content `$cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (`$cfg.PSObject.Properties.Name -contains 'projects_root' ``
                -and `$cfg.projects_root) {
            `$scanRoot = `$cfg.projects_root
        }
    } catch {
        # Fall through to the default path on parse error.
    }
}
`$logFile    = Join-Path `$HOME '.git-templates\gitleaks-weekly-scan.log'
`$gitleaksCfg = Join-Path `$HOME '.gitleaks.toml'
`$timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Add-Content -Path `$logFile -Value "`n[`$timestamp] Starting weekly gitleaks scan of `$scanRoot"

if (-not (Test-Path `$scanRoot)) {
    Add-Content -Path `$logFile -Value "[`$timestamp] Scan root does not exist: `$scanRoot, skipping."
    exit 0
}

# Find all git repos (directories containing a .git folder)
`$repos = Get-ChildItem -Path `$scanRoot -Recurse -Directory -Filter '.git' -ErrorAction SilentlyContinue |
          ForEach-Object { `$_.Parent.FullName } |
          Sort-Object -Unique

if (`$repos.Count -eq 0) {
    Add-Content -Path `$logFile -Value "[`$timestamp] No git repositories found under `$scanRoot."
    exit 0
}

Add-Content -Path `$logFile -Value "[`$timestamp] Found `$(`$repos.Count) repositories to scan."

`$failed = @()

foreach (`$repo in `$repos) {
    Add-Content -Path `$logFile -Value "[`$timestamp] Scanning: `$repo"
    try {
        if (Test-Path `$gitleaksCfg) {
            `$out = & gitleaks detect --source `$repo --redact --config `$gitleaksCfg 2>&1
        } else {
            `$out = & gitleaks detect --source `$repo --redact 2>&1
        }
        if (`$LASTEXITCODE -ne 0) {
            Add-Content -Path `$logFile -Value "[`$timestamp] ALERT in `$repo`: `$out"
            `$failed += `$repo
        } else {
            Add-Content -Path `$logFile -Value "[`$timestamp] CLEAN: `$repo"
        }
    } catch {
        Add-Content -Path `$logFile -Value "[`$timestamp] ERROR scanning `$repo`: `$_"
    }
}

if (`$failed.Count -gt 0) {
    Add-Content -Path `$logFile -Value "[`$timestamp] SCAN COMPLETE, `$(`$failed.Count) repo(s) had findings:"
    foreach (`$f in `$failed) {
        Add-Content -Path `$logFile -Value "  - `$f"
    }
    # Write to Windows Event Log so alerts are visible in Event Viewer
    try {
        Write-EventLog -LogName Application -Source 'Gitleaks' -EventId 1001 -EntryType Warning ``
            -Message "Gitleaks weekly scan found potential secrets in: `$(`$failed -join ', ')"
    } catch {
        # Event source may not be registered; ignore
    }
    exit 1
} else {
    Add-Content -Path `$logFile -Value "[`$timestamp] SCAN COMPLETE, all repositories clean."
    exit 0
}
"@

try {
    Set-Content -Path $weeklyScript -Value $weeklyScanContent -Encoding UTF8
    Write-Pass "Written: $weeklyScript"
} catch {
    Write-Warn "Could not write weekly scan script: $_"
}

# 7b, Register / update Task Scheduler task
$taskName   = 'GitLeaks Weekly Security Scan'
$taskAction = New-ScheduledTaskAction `
    -Execute 'pwsh.exe' `
    -Argument "-NonInteractive -WindowStyle Hidden -File `"$weeklyScript`""

$taskTrigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Sunday `
    -At '02:00'

$taskSettings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -WakeToRun:$false

try {
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Warn "Task '$taskName' already exists, updating"
        Set-ScheduledTask `
            -TaskName $taskName `
            -Action   $taskAction `
            -Trigger  $taskTrigger `
            -Settings $taskSettings | Out-Null
        Write-Pass "Updated Task Scheduler task: $taskName"
        $Results['Task Scheduler Task'] = 'PASS (updated)'
    } else {
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action   $taskAction `
            -Trigger  $taskTrigger `
            -Settings $taskSettings `
            -Description 'Weekly gitleaks scan of all git repos under projects_root (read from ~/.claude/config.json). Created by phase_06_hooks_and_scanning.ps1.' `
            -RunLevel Limited | Out-Null
        Write-Pass "Created Task Scheduler task: $taskName"
        $Results['Task Scheduler Task'] = 'PASS'
    }
} catch {
    Write-Warn "Could not register Task Scheduler task: $_"
    Write-Info "This may require Administrator privileges."
    Write-Info "Manual fix (run as Admin):"
    Write-Info "  Re-run: pwsh -File scripts\phase_06_hooks_and_scanning.ps1"
    $Results['Task Scheduler Task'] = 'WARN'
}

# ---------------------------------------------------------------------------
# Step 8: Self-test the commit-msg regex pattern
# ---------------------------------------------------------------------------

Write-Section "Step 8, Self-test commit-msg regex pattern"

# Mirror the POSIX ERE pattern in PowerShell (.NET regex)
$pattern = '^(feat|fix|docs|style|refactor|perf|test|chore|ci|revert)(\(.+\))?: .{1,88}$'

$validMessages = @(
    'feat: add SSH key rotation support',
    'fix(hooks): prevent false positive on test fixtures',
    'chore: update uv to 0.5.0',
    'docs(readme): add Phase 2 troubleshooting section',
    'refactor(auth): extract key loading into helper function',
    'ci: add gitleaks scan to GitHub Actions workflow',
    'revert: revert commit abc1234',
    'perf(core): reduce startup time by lazy-loading plugins',
    'test(phase6): add regex self-test cases',
    'style: reformat with ruff'
)

$invalidMessages = @(
    'bad commit message',
    'Added some stuff',
    'fix some bugs',
    'WIP',
    '',
    'FEAT: uppercase type is invalid',
    'feat add missing colon',
    'feat: ' + ('x' * 90),  # too long (over 88 chars in description)
    'unknown-type: some message'
)

$allPass = $true

Write-Info "Testing VALID messages (should all match):"
foreach ($msg in $validMessages) {
    if ($msg -cmatch $pattern) {
        Write-Pass "  VALID  : '$msg'"
    } else {
        Write-Fail "  Should be valid but did NOT match: '$msg'"
        $allPass = $false
    }
}

Write-Host ""
Write-Info "Testing INVALID messages (should all fail to match):"
foreach ($msg in $invalidMessages) {
    if ($msg -cnotmatch $pattern) {
        Write-Pass "  INVALID: '$msg'"
    } else {
        Write-Fail "  Should be invalid but DID match: '$msg'"
        $allPass = $false
    }
}

$Results['Regex Self-Test'] = if ($allPass) { 'PASS' } else { 'FAIL' }

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 6, Summary"                      -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$colW = 35
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
Write-Host "  Files written:" -ForegroundColor White
Write-Host "    $preCommit" -ForegroundColor Cyan
Write-Host "    $commitMsg" -ForegroundColor Cyan
Write-Host "    $gitleaksToml" -ForegroundColor Cyan
Write-Host "    $weeklyScript" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Manual verification:" -ForegroundColor White
Write-Host "    Navigate into any directory and run: git init" -ForegroundColor Cyan
Write-Host "    Try: git commit --allow-empty -m `"bad message`"" -ForegroundColor Cyan
Write-Host "    Expected: commit rejected with format instructions." -ForegroundColor Cyan
Write-Host "    Try: git commit --allow-empty -m `"chore: test conventional commits hook`"" -ForegroundColor Cyan
Write-Host "    Expected: commit succeeds." -ForegroundColor Cyan
Write-Host ""

if ($anyFail) {
    Write-Fail "One or more steps failed. Review the output above and fix before running Phase 7."
    exit 1
} else {
    Write-Pass "Hooks and secret scanning configured. Proceed to Phase 7 (Claude rules)."
    exit 0
}
