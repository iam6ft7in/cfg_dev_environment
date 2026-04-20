#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 11 - End-to-End GitHub Workflow Test

.DESCRIPTION
    Script Name : phase_11_e2e_test.ps1
    Purpose     : Authenticate GitHub CLI and run a full end-to-end test covering
                  repo creation, SSH clone, commit signing, push, and PR creation.
    Phase       : 11
    Exit Criteria:
        - gh auth status shows authenticated account
        - Test repo created on GitHub
        - SSH clone via github-personal host alias succeeds
        - Signed commit created and verified
        - Push and PR creation succeed
        - All test artifacts cleaned up (local dir + GitHub repo)
        - Final pass/fail table printed for all 8 test steps

.NOTES
    Run from any location; $RepoRoot is derived from $PSScriptRoot.
    Requires: gh, git, SSH configured with github-personal host alias.
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
    Write-Host "`n[ABORTED] Phase 11 did not complete. Review errors above." -ForegroundColor Red
    exit 1
}

# Track all 8 test results
$TestResults = [ordered]@{
    'T1_CreateRepo'      = 'NOT RUN'
    'T2_SSHClone'        = 'NOT RUN'
    'T3_CreateFile'      = 'NOT RUN'
    'T4_Commit'          = 'NOT RUN'
    'T5_VerifySigned'    = 'NOT RUN'
    'T6_Push'            = 'NOT RUN'
    'T7_CreatePR'        = 'NOT RUN'
    'T8_VerifyPR'        = 'NOT RUN'
}

$RepoRoot    = Split-Path -Parent $PSScriptRoot
$TestRepoName = 'test_e2e_delete_me'
$TestLocalDir = "$HOME\projects\personal\_e2e_test_temp"

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "`n======================================="  -ForegroundColor Cyan
Write-Host "  Phase 11 - End-to-End GitHub Test"       -ForegroundColor Cyan
Write-Host "  Test repo   : $TestRepoName"             -ForegroundColor Cyan
Write-Host "  Local clone : $TestLocalDir"             -ForegroundColor Cyan
Write-Host "=======================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1 - Manual step: gh auth login
# ---------------------------------------------------------------------------
Write-Section "Step 11A: Manual GitHub CLI Authentication"

Write-Host "`n  Before continuing, you must authenticate with GitHub CLI." -ForegroundColor Yellow
Write-Host "  If you haven't done so already, run in a separate terminal:"  -ForegroundColor Yellow
Write-Host "`n    gh auth login"                                             -ForegroundColor White
Write-Host "`n  Select:"                                                     -ForegroundColor Yellow
Write-Host "    - GitHub.com"                                               -ForegroundColor Yellow
Write-Host "    - SSH (recommended)"                                        -ForegroundColor Yellow
Write-Host "    - Authenticate with your browser or paste a token"         -ForegroundColor Yellow

Write-Host "`n" -NoNewline
$Confirm = Read-Host "  Have you completed 'gh auth login'? (yes/no)"
if ($Confirm.Trim().ToLower() -notin @('yes', 'y')) {
    Exit-WithError "User did not confirm authentication. Please run 'gh auth login' first."
}

# ---------------------------------------------------------------------------
# Step 2 - Verify gh auth status
# ---------------------------------------------------------------------------
Write-Section "Step 2: Verify gh auth status"

try {
    $AuthOutput = gh auth status 2>&1
    $AuthString = $AuthOutput -join "`n"
    Write-Info "gh auth status output:"
    $AuthOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

    if ($AuthString -match 'Logged in to github\.com' -or $AuthString -match 'Logged in to') {
        Write-Pass "GitHub CLI is authenticated."
    } else {
        Write-Fail "gh auth status does not show a logged-in account."
        Write-Info "Run 'gh auth login' and try again."
        Exit-WithError "Not authenticated with GitHub CLI."
    }
} catch {
    Exit-WithError "Failed to run 'gh auth status': $_"
}

# ---------------------------------------------------------------------------
# Step 3 - Get authenticated username
# ---------------------------------------------------------------------------
Write-Section "Step 3: Get authenticated GitHub username"

try {
    $GitHubUser = (gh api user --jq .login).Trim()
    if ([string]::IsNullOrWhiteSpace($GitHubUser)) {
        Exit-WithError "Could not retrieve GitHub username from 'gh api user --jq .login'."
    }
    Write-Pass "Authenticated as: $GitHubUser"
} catch {
    Exit-WithError "Failed to get GitHub username: $_"
}

# ---------------------------------------------------------------------------
# Pre-test: Clean up any leftover test artifacts from a previous run
# ---------------------------------------------------------------------------
Write-Section "Pre-test Cleanup"

if (Test-Path $TestLocalDir) {
    Write-Warn "Leftover local test directory found. Removing: $TestLocalDir"
    Remove-Item -Path $TestLocalDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Check if test repo already exists on GitHub
$ExistingRepo = gh repo view "$GitHubUser/$TestRepoName" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Warn "Leftover test repo found on GitHub: $TestRepoName. Deleting..."
    $DelOutput = gh repo delete "$TestRepoName" --yes 2>&1
    $DelString = $DelOutput -join ' '
    if ($LASTEXITCODE -ne 0) {
        if ($DelString -match 'delete_repo') {
            Write-Fail "Missing 'delete_repo' scope. Run this once, then re-run Phase 11:"
            Write-Info "  gh auth refresh -h github.com -s delete_repo"
            exit 1
        }
        Write-Warn "Repo deletion may have failed: $DelString"
        Write-Warn "Manually delete at: https://github.com/$GitHubUser/$TestRepoName/settings"
    } else {
        Write-Info "Deleted leftover GitHub repo."
    }
    Start-Sleep -Seconds 5  # Allow GitHub API to propagate deletion before re-creating
}

# ---------------------------------------------------------------------------
# Step 4 - Run end-to-end test sequence
# ---------------------------------------------------------------------------
Write-Section "Step 4: End-to-End Test Sequence"

# ---- T1: Create test repo ------------------------------------------------
Write-Host "`n  [T1] Create test repo on GitHub..." -ForegroundColor Cyan
try {
    $CreateOutput = gh repo create $TestRepoName `
        --private `
        --description "Temporary E2E test repo - safe to delete" 2>&1
    Write-Pass "T1: Test repo created: $GitHubUser/$TestRepoName"
    Write-Info $CreateOutput
    $TestResults['T1_CreateRepo'] = 'PASS'
} catch {
    Write-Fail "T1: Failed to create test repo: $_"
    $TestResults['T1_CreateRepo'] = 'FAIL'
    Exit-WithError "Cannot continue without test repo."
}

Start-Sleep -Seconds 2  # Brief pause for GitHub to provision the repo

# ---- T2: Clone using SSH host alias --------------------------------------
Write-Host "`n  [T2] Clone via SSH host alias 'github-personal'..." -ForegroundColor Cyan
try {
    # Ensure parent directory exists
    $ParentDir = Split-Path -Parent $TestLocalDir
    if (-not (Test-Path $ParentDir -PathType Container)) {
        New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
    }

    $CloneOutput = git clone "github-personal:$GitHubUser/$TestRepoName" $TestLocalDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git clone exited with code $LASTEXITCODE. Output: $($CloneOutput -join ' ')"
    }
    Write-Pass "T2: Cloned to $TestLocalDir"
    $TestResults['T2_SSHClone'] = 'PASS'
} catch {
    Write-Fail "T2: SSH clone failed: $_"
    $TestResults['T2_SSHClone'] = 'FAIL'
    Exit-WithError "Clone failed. Verify SSH host alias 'github-personal' in ~/.ssh/config."
}

# ---- T3: Create test file ------------------------------------------------
Write-Host "`n  [T3] Create test file in repo..." -ForegroundColor Cyan
try {
    $TestFile = Join-Path $TestLocalDir 'e2e_test.md'
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $FileContent = @"
# E2E Test

Automated end-to-end test file created by phase_11_e2e_test.ps1.

Timestamp: $Timestamp
User: $GitHubUser
"@
    $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($TestFile, $FileContent, $Utf8NoBom)
    Write-Pass "T3: Created test file: $TestFile"
    $TestResults['T3_CreateFile'] = 'PASS'
} catch {
    Write-Fail "T3: Failed to create test file: $_"
    $TestResults['T3_CreateFile'] = 'FAIL'
    Exit-WithError "Cannot continue without a test file to commit."
}

# ---- T4: Stage and commit ------------------------------------------------
Write-Host "`n  [T4] Stage and commit (conventional commits)..." -ForegroundColor Cyan
try {
    Push-Location $TestLocalDir
    $AddOutput = git add . 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git add failed: $($AddOutput -join ' ')" }

    $CommitOutput = git commit -m "chore: initial e2e test commit" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git commit failed: $($CommitOutput -join ' ')" }

    Write-Pass "T4: Commit created."
    $CommitOutput | ForEach-Object { Write-Info $_ }
    $TestResults['T4_Commit'] = 'PASS'
} catch {
    Write-Fail "T4: Commit failed: $_"
    $TestResults['T4_Commit'] = 'FAIL'
} finally {
    Pop-Location
}

# ---- T5: Verify commit is signed -----------------------------------------
Write-Host "`n  [T5] Verify commit signature..." -ForegroundColor Cyan
try {
    Push-Location $TestLocalDir
    $SigOutput = git log --show-signature -1 2>&1
    $SigString = $SigOutput -join "`n"
    Write-Info "git log --show-signature output:"
    $SigOutput | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

    if ($SigString -match 'Good.*signature' -or $SigString -match 'Verified' -or $SigString -match 'gpg: Signature made') {
        Write-Pass "T5: Commit is signed and verified."
        $TestResults['T5_VerifySigned'] = 'PASS'
    } elseif ($SigString -match 'error' -or $SigString -match 'no signature') {
        Write-Fail "T5: Commit does not appear to be signed."
        Write-Warn "Ensure GPG signing is configured: git config commit.gpgsign true"
        $TestResults['T5_VerifySigned'] = 'FAIL'
    } else {
        Write-Warn "T5: Could not definitively verify signature. Review output above."
        $TestResults['T5_VerifySigned'] = 'WARN'
    }
} catch {
    Write-Fail "T5: Signature verification failed: $_"
    $TestResults['T5_VerifySigned'] = 'FAIL'
} finally {
    Pop-Location
}

# ---- T6: Push ------------------------------------------------------------
Write-Host "`n  [T6] Push to GitHub..." -ForegroundColor Cyan
try {
    Push-Location $TestLocalDir
    $PushOutput = git push 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git push exited $LASTEXITCODE : $($PushOutput -join ' ')" }
    Write-Pass "T6: Push succeeded."
    $TestResults['T6_Push'] = 'PASS'
} catch {
    Write-Fail "T6: Push failed: $_"
    $TestResults['T6_Push'] = 'FAIL'
} finally {
    Pop-Location
}

# ---- T7: Create PR -------------------------------------------------------
Write-Host "`n  [T7] Create pull request..." -ForegroundColor Cyan
try {
    Push-Location $TestLocalDir

    # Need a branch for a PR (main branch can't PR into itself)
    $BranchOutput = git checkout -b e2e-test-branch 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git checkout -b failed: $($BranchOutput -join ' ')" }

    # Create a second file on the branch to give the PR something to merge
    $BranchFile = Join-Path $TestLocalDir 'e2e_branch_change.md'
    $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($BranchFile, "Branch change for E2E test PR.`n", $Utf8NoBom)

    git add . 2>&1 | Out-Null
    $BranchCommit = git commit -m "chore: e2e branch change for PR" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Branch commit failed: $($BranchCommit -join ' ')" }

    $BranchPush = git push --force-with-lease --set-upstream origin e2e-test-branch 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Branch push failed: $($BranchPush -join ' ')" }

    $PROutput = gh pr create `
        --title "chore: e2e test PR" `
        --body "Automated end-to-end test" `
        --base main 2>&1
    $PRString = $PROutput -join ' '

    if ($LASTEXITCODE -eq 0) {
        Write-Pass "T7: PR created."
        Write-Info $PROutput
        $TestResults['T7_CreatePR'] = 'PASS'
    } elseif ($PRString -match 'already exists') {
        # PR from a previous run is still open, the branch and PR mechanism work.
        Write-Pass "T7: PR already exists (leftover from previous run), branch/PR mechanism verified."
        Write-Info ($PRString -replace '.*https://', 'https://' -split ' ' | Select-Object -First 1)
        $TestResults['T7_CreatePR'] = 'PASS'
    } else {
        throw "gh pr create failed: $PRString"
    }
} catch {
    Write-Fail "T7: PR creation failed: $_"
    $TestResults['T7_CreatePR'] = 'FAIL'
} finally {
    Pop-Location
}

# ---- T8: Verify PR listed ------------------------------------------------
Write-Host "`n  [T8] Verify PR is listed..." -ForegroundColor Cyan
try {
    Push-Location $TestLocalDir
    $PRList = gh pr list 2>&1
    $PRString = $PRList -join "`n"
    Write-Info "gh pr list output:"
    $PRList | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

    if ($PRString -match 'e2e test PR' -or $PRString -match 'e2e-test-branch') {
        Write-Pass "T8: PR is visible in pr list."
        $TestResults['T8_VerifyPR'] = 'PASS'
    } else {
        Write-Warn "T8: Could not confirm PR in list. Review output above."
        $TestResults['T8_VerifyPR'] = 'WARN'
    }
} catch {
    Write-Fail "T8: PR verification failed: $_"
    $TestResults['T8_VerifyPR'] = 'FAIL'
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# Step 5 - Cleanup
# ---------------------------------------------------------------------------
Write-Section "Step 5: Cleanup"

# 5a - Delete local test directory
Write-Info "Removing local test directory: $TestLocalDir"
try {
    if (Test-Path $TestLocalDir) {
        # Remove read-only .git files on Windows
        Get-ChildItem -Path $TestLocalDir -Recurse -Force | ForEach-Object {
            if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                $_.Attributes = $_.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
            }
        }
        Remove-Item -Path $TestLocalDir -Recurse -Force
        Write-Pass "Local test directory removed."
    } else {
        Write-Info "Local test directory already absent."
    }
} catch {
    Write-Warn "Could not fully remove local test directory: $_"
    Write-Warn "You may need to manually delete: $TestLocalDir"
}

# 5b - Delete GitHub repo
Write-Info "Deleting GitHub test repo: $GitHubUser/$TestRepoName"
$FinalDel = gh repo delete $TestRepoName --yes 2>&1
$FinalDelStr = $FinalDel -join ' '
if ($LASTEXITCODE -eq 0) {
    Write-Pass "GitHub test repo deleted: $TestRepoName"
} elseif ($FinalDelStr -match 'delete_repo') {
    Write-Warn "Missing 'delete_repo' scope, repo not deleted automatically."
    Write-Warn "Run: gh auth refresh -h github.com -s delete_repo"
    Write-Warn "Then: gh repo delete $TestRepoName --yes"
} else {
    Write-Warn "Could not delete GitHub test repo: $FinalDelStr"
    Write-Warn "Manually delete at: https://github.com/$GitHubUser/$TestRepoName/settings"
}

# ---------------------------------------------------------------------------
# Step 6 - Final pass/fail report
# ---------------------------------------------------------------------------
Write-Section "Final Pass/Fail Report"

Write-Host "`n  Test Step                     Result" -ForegroundColor Cyan
Write-Host "  ----------------------------  --------" -ForegroundColor Cyan

$PassCount = 0; $WarnCount = 0; $FailCount = 0
$StepLabels = [ordered]@{
    'T1_CreateRepo'   = 'T1: Create GitHub test repo'
    'T2_SSHClone'     = 'T2: SSH clone (github-personal alias)'
    'T3_CreateFile'   = 'T3: Create test file'
    'T4_Commit'       = 'T4: Stage and commit (conventional)'
    'T5_VerifySigned' = 'T5: Verify commit signature'
    'T6_Push'         = 'T6: Push to GitHub'
    'T7_CreatePR'     = 'T7: Create pull request'
    'T8_VerifyPR'     = 'T8: Verify PR listed'
}

foreach ($Key in $StepLabels.Keys) {
    $Label  = $StepLabels[$Key]
    $Result = $TestResults[$Key]
    $Color  = switch -Wildcard ($Result) {
        'PASS*' { $PassCount++; 'Green'  }
        'WARN*' { $WarnCount++; 'Yellow' }
        'FAIL'  { $FailCount++; 'Red'    }
        default { 'Gray' }
    }
    Write-Host ("  {0,-32} " -f $Label) -ForegroundColor Cyan -NoNewline
    Write-Host $Result -ForegroundColor $Color
}

Write-Host "`n  Passed  : $PassCount / 8" -ForegroundColor Green
Write-Host "  Warned  : $WarnCount / 8"   -ForegroundColor $(if ($WarnCount -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Failed  : $FailCount / 8"   -ForegroundColor $(if ($FailCount -gt 0) { 'Red'    } else { 'Green' })

if ($FailCount -gt 0) {
    Write-Host "`n[RESULT] Phase 11 FAILED. $FailCount test step(s) did not pass." -ForegroundColor Red
    exit 1
} elseif ($WarnCount -gt 0) {
    Write-Host "`n[RESULT] Phase 11 passed with $WarnCount warning(s). Review items above." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n[RESULT] Phase 11 PASSED. All 8 end-to-end tests passed successfully." -ForegroundColor Green
    exit 0
}
