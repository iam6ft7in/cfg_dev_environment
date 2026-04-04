#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 6 — Git Hooks and Secret Scanning

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

# Write a text file with Unix line endings (LF) — hooks must use LF
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
Write-Host "  Phase 6 — Hooks and Secret Scanning"   -ForegroundColor Cyan
Write-Host "  Repo root: $RepoRoot"                  -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$templateDir  = Join-Path $HOME '.git-templates'
$hooksDir     = Join-Path $templateDir 'hooks'
$preCommit    = Join-Path $hooksDir 'pre-commit'
$commitMsg    = Join-Path $hooksDir 'commit-msg'
$weeklyScript = Join-Path $templateDir 'gitleaks-weekly-scan.ps1'
$gitleaksToml = Join-Path $HOME '.gitleaks.toml'
$configSrc    = Join-Path $RepoRoot 'config\gitleaks.toml'

$Results = [ordered]@{}

# ---------------------------------------------------------------------------
# Step 1 — Ensure ~/.git-templates/hooks/ exists
# ---------------------------------------------------------------------------

Write-Section "Step 1 — Ensure ~/.git-templates/hooks/ exists"

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
# Step 2 — Write pre-commit hook
# ---------------------------------------------------------------------------

Write-Section "Step 2 — Write pre-commit hook (gitleaks staged scan)"

$preCommitContent = @'
#!/bin/sh
# pre-commit — gitleaks secret scan on staged files
# Installed by phase_06_hooks_and_scanning.ps1
#
# Runs gitleaks against staged changes before every commit.
# If secrets are detected, the commit is aborted.
# Set SKIP_GITLEAKS=1 to bypass (for test fixtures only — use sparingly).

if [ "${SKIP_GITLEAKS:-0}" = "1" ]; then
    echo "[pre-commit] WARNING: gitleaks scan skipped (SKIP_GITLEAKS=1)" >&2
    exit 0
fi

# Check if gitleaks is on PATH
if ! command -v gitleaks >/dev/null 2>&1; then
    echo "[pre-commit] WARNING: gitleaks is not installed — skipping secret scan." >&2
    echo "[pre-commit] Install gitleaks and re-run Phase 1 to enable scanning." >&2
    exit 0
fi

# Determine config path
GITLEAKS_CONFIG="$HOME/.gitleaks.toml"
if [ ! -f "$GITLEAKS_CONFIG" ]; then
    GITLEAKS_CONFIG=""
fi

# Run gitleaks on staged files
if [ -n "$GITLEAKS_CONFIG" ]; then
    gitleaks protect --staged --redact --config "$GITLEAKS_CONFIG" 2>&1
else
    gitleaks protect --staged --redact 2>&1
fi

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "" >&2
    echo "[pre-commit] BLOCKED: gitleaks detected potential secrets in staged files." >&2
    echo "[pre-commit] Review the output above. If this is a false positive:" >&2
    echo "[pre-commit]   1. Add an allowlist entry to ~/.gitleaks.toml" >&2
    echo "[pre-commit]   2. Or set SKIP_GITLEAKS=1 (only for test fixture commits)" >&2
    echo "" >&2
    exit 1
fi

exit 0
'@

try {
    Write-UnixFile -Path $preCommit -Content $preCommitContent
    Write-Pass "Written: $preCommit"
    $Results['pre-commit Hook'] = 'PASS'
} catch {
    Write-Fail "Failed to write pre-commit hook: $_"
    $Results['pre-commit Hook'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 3 — Write commit-msg hook
# ---------------------------------------------------------------------------

Write-Section "Step 3 — Write commit-msg hook (Conventional Commits)"

$commitMsgContent = @'
#!/bin/sh
# commit-msg — Conventional Commits format validation
# Installed by phase_06_hooks_and_scanning.ps1
#
# Validates the commit message against the Conventional Commits specification.
# Pattern: <type>(<optional scope>): <description>
#   - type     : feat|fix|docs|style|refactor|perf|test|chore|ci|revert
#   - scope    : optional, in parentheses
#   - description: 1-88 characters, lowercase preferred, no trailing period
#
# Merge commits, revert commits, and fixup commits bypass validation.

MSG_FILE="$1"
MSG=$(cat "$MSG_FILE")

# Skip validation for merge commits
if echo "$MSG" | grep -qE '^Merge '; then
    exit 0
fi

# Skip validation for revert auto-generated messages
if echo "$MSG" | grep -qE '^Revert "'; then
    exit 0
fi

# Skip fixup and squash commits (used during interactive rebase)
if echo "$MSG" | grep -qE '^(fixup|squash)!'; then
    exit 0
fi

# Skip empty messages or comment-only messages (git handles these separately)
STRIPPED=$(echo "$MSG" | sed '/^#/d' | sed '/^$/d')
if [ -z "$STRIPPED" ]; then
    exit 0
fi

# Conventional Commits pattern
# type(scope): description  — total subject line max 88 chars
CC_PATTERN='^(feat|fix|docs|style|refactor|perf|test|chore|ci|revert)(\(.+\))?: .{1,88}$'

# Extract subject line (first non-empty, non-comment line)
SUBJECT=$(echo "$MSG" | sed '/^#/d' | sed '/^[[:space:]]*$/d' | head -1)

if ! echo "$SUBJECT" | grep -qE "$CC_PATTERN"; then
    echo "" >&2
    echo "  COMMIT REJECTED — message does not follow Conventional Commits format." >&2
    echo "" >&2
    echo "  Your message:" >&2
    echo "    $SUBJECT" >&2
    echo "" >&2
    echo "  Required format:" >&2
    echo "    <type>(<scope>): <short description>" >&2
    echo "" >&2
    echo "  Valid types: feat, fix, docs, style, refactor, perf, test, chore, ci, revert" >&2
    echo "  Scope is optional. Description must be 1-88 characters." >&2
    echo "" >&2
    echo "  Examples:" >&2
    echo "    feat(auth): add SSH key rotation support" >&2
    echo "    fix(hooks): prevent false positive on test fixtures" >&2
    echo "    chore: update uv to 0.5.0" >&2
    echo "    docs(readme): add Phase 2 troubleshooting section" >&2
    echo "" >&2
    exit 1
fi

exit 0
'@

try {
    Write-UnixFile -Path $commitMsg -Content $commitMsgContent
    Write-Pass "Written: $commitMsg"
    $Results['commit-msg Hook'] = 'PASS'
} catch {
    Write-Fail "Failed to write commit-msg hook: $_"
    $Results['commit-msg Hook'] = 'FAIL'
}

# ---------------------------------------------------------------------------
# Step 4 — Note on hook executability (Windows)
# ---------------------------------------------------------------------------

Write-Section "Step 4 — Hook executability (Windows note)"

Write-Info "On Windows, git executes hook files directly via sh.exe bundled with Git."
Write-Info "The #!/bin/sh shebang and LF line endings (enforced above) are sufficient."
Write-Info "No chmod +x required on Windows — git handles this automatically."
$Results['Hook Executability'] = 'PASS (Windows — no chmod needed)'

# ---------------------------------------------------------------------------
# Step 5 — Write ~/.gitleaks.toml
# ---------------------------------------------------------------------------

Write-Section "Step 5 — Install ~/.gitleaks.toml"

$gitleaksTomlContent = @'
# ~/.gitleaks.toml — Custom gitleaks configuration
# Generated by phase_06_hooks_and_scanning.ps1
#
# Extends the default gitleaks ruleset with project-specific allowlists.
# Reference: https://github.com/gitleaks/gitleaks/tree/master#configuration

title = "Custom Gitleaks Config"

[extend]
# Use the built-in default rules as the base
useDefault = true

# ---------------------------------------------------------------------------
# Global allowlist — patterns that are NEVER secrets regardless of context
# ---------------------------------------------------------------------------
[allowlist]
description = "Global allowlist for known safe patterns"

# ArduPilot / MAVLink parameter strings that look like keys but are not
regexes = [
    # MAVLink parameter names (all caps, underscores, numbers)
    '''[A-Z][A-Z0-9_]{2,15}''',
    # C preprocessor hex constants (e.g. 0xDEADBEEF)
    '''0x[0-9A-Fa-f]{4,16}''',
    # NASM assembly hex immediates (e.g. 0FFFFh, 0xABCD)
    '''[0-9][0-9A-Fa-f]*h\b''',
]

paths = [
    # Test fixture directories
    '''test[s]?/fixtures/''',
    '''test[s]?/data/''',
    # Documentation examples
    '''docs?/examples?/''',
    # This config file itself
    '''\.gitleaks\.toml''',
    # Phase setup scripts (contain example patterns in comments)
    '''scripts/phase_0[0-9]_''',
]

# ---------------------------------------------------------------------------
# Additional custom rules
# ---------------------------------------------------------------------------

# Detect Windows credential manager exports
[[rules]]
id          = "windows-credential-export"
description = "Windows Credential Manager exported credential"
regex       = '''(?i)(target|username|password|credential).{0,30}[:=].{0,100}'''
tags        = ["windows", "credential"]
severity    = "HIGH"

[rules.allowlist]
regexes = [
    # Allow documentation comments
    '''^\s*#''',
    # Allow gitconfig format lines
    '''^\s+\w+\s*=\s*\w+''',
]

# Detect SSH private key material accidentally staged
[[rules]]
id          = "ssh-private-key-content"
description = "SSH private key content (not just BEGIN PRIVATE KEY header)"
regex       = '''-----BEGIN (OPENSSH|RSA|DSA|EC|PGP) PRIVATE KEY-----'''
tags        = ["ssh", "key", "private"]
severity    = "CRITICAL"

# Detect .env-style variable assignments containing secrets
[[rules]]
id          = "env-variable-secret"
description = "Environment variable assignment with a probable secret value"
regex       = '''(?i)(api_?key|api_?secret|auth_?token|access_?token|secret_?key|private_?key|client_?secret)\s*[=:]\s*['"]?[A-Za-z0-9+/=_\-]{16,}['"]?'''
tags        = ["env", "secret", "token"]
severity    = "HIGH"

[rules.allowlist]
regexes = [
    # Allow .env.example files — they contain placeholders
    '''\.env\.example''',
    # Allow lines that are clearly placeholder values
    '''(?i)(your[-_]?|example[-_]?|replace[-_]?|placeholder|<.*>|CHANGEME)''',
]
'@

# Prefer copying from repo config/ if it exists; otherwise write inline
if (Test-Path $configSrc) {
    try {
        Copy-Item -Path $configSrc -Destination $gitleaksToml -Force
        Write-Pass "Copied from repo: $configSrc -> $gitleaksToml"
        $Results['gitleaks.toml'] = 'PASS (from repo config/)'
    } catch {
        Write-Warn "Copy failed: $_. Writing inline default instead."
        Set-Content -Path $gitleaksToml -Value $gitleaksTomlContent -Encoding UTF8
        Write-Pass "Written inline: $gitleaksToml"
        $Results['gitleaks.toml'] = 'PASS (inline default)'
    }
} else {
    Write-Info "config\gitleaks.toml not found in repo root — writing inline default"
    Set-Content -Path $gitleaksToml -Value $gitleaksTomlContent -Encoding UTF8
    Write-Pass "Written: $gitleaksToml"
    $Results['gitleaks.toml'] = 'PASS (inline default)'
}

# ---------------------------------------------------------------------------
# Step 6 — Set init.templateDir in gitconfig
# ---------------------------------------------------------------------------

Write-Section "Step 6 — Set init.templateDir in ~/.gitconfig"

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
# Step 7 — Write weekly scan script and create Task Scheduler task
# ---------------------------------------------------------------------------

Write-Section "Step 7 — Weekly gitleaks scan (Task Scheduler)"

# 7a — Write the scan script
$weeklyScanContent = @"
#Requires -Version 7.0
# gitleaks-weekly-scan.ps1
# Runs gitleaks on all git repos under ~/projects/ every Sunday at 02:00 AM.
# Created by phase_06_hooks_and_scanning.ps1

`$scanRoot   = Join-Path `$HOME 'projects'
`$logFile    = Join-Path `$HOME '.git-templates\gitleaks-weekly-scan.log'
`$gitleaksCfg = Join-Path `$HOME '.gitleaks.toml'
`$timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Add-Content -Path `$logFile -Value "`n[`$timestamp] Starting weekly gitleaks scan of `$scanRoot"

if (-not (Test-Path `$scanRoot)) {
    Add-Content -Path `$logFile -Value "[`$timestamp] Scan root does not exist: `$scanRoot — skipping."
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
    Add-Content -Path `$logFile -Value "[`$timestamp] SCAN COMPLETE — `$(`$failed.Count) repo(s) had findings:"
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
    Add-Content -Path `$logFile -Value "[`$timestamp] SCAN COMPLETE — all repositories clean."
    exit 0
}
"@

try {
    Set-Content -Path $weeklyScript -Value $weeklyScanContent -Encoding UTF8
    Write-Pass "Written: $weeklyScript"
} catch {
    Write-Warn "Could not write weekly scan script: $_"
}

# 7b — Register / update Task Scheduler task
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
        Write-Warn "Task '$taskName' already exists — updating"
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
            -Description 'Weekly gitleaks scan of all git repos under ~/projects/. Created by phase_06_hooks_and_scanning.ps1.' `
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
# Step 8 — Self-test the commit-msg regex pattern
# ---------------------------------------------------------------------------

Write-Section "Step 8 — Self-test commit-msg regex pattern"

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
Write-Host "  Phase 6 — Summary"                      -ForegroundColor Cyan
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
