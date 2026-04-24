# GitHub Setup, Implementation Steps
**Date:** 2026-04-01

This document lists every step you personally need to take, either manually
(browser, file system, or command you run yourself) or by starting a script
(you launch it, the script does the work). Steps are in strict sequence.
Do not proceed to the next phase until the exit criteria for the current
phase are met.

---

## PHASE 0, Manual Prerequisites
**Type:** Manual (you do these yourself, no script)
**Must complete before:** Phase 1

### Step 0.1, Move the OneDrive AI Folder
Move the folder:
  FROM: %USERPROFILE%\OneDrive\Documents\AI\
  TO:   %USERPROFILE%\OneDrive\AI\

How: Open File Explorer, cut the AI folder from Documents, paste it one
level up into OneDrive directly.

Verify: The folder now exists at %USERPROFILE%\OneDrive\AI\ and the
original location %USERPROFILE%\OneDrive\Documents\AI\ is gone.

IMPORTANT: Confirm there are no Git repositories inside this folder
before moving. (There should be none, clean slate confirmed.)

### Step 0.2, Get Your GitHub Noreply Email Address
1. Open a browser and go to github.com
2. Log in to your personal GitHub account
3. Go to: Settings -> Emails
4. Enable "Keep my email address private"
5. Copy the noreply address shown, it looks like:
   {numbers}+{username}@users.noreply.github.com
6. Save this address somewhere handy, it is needed in Phase 3

### Step 0.3, Verify PowerShell 7+ Is Installed
Open a terminal and run:
   pwsh --version

If it shows version 7.4 or higher: proceed.
If not installed: run this command in any terminal:
   winget install Microsoft.PowerShell

### Step 0.4, Verify Bitwarden Desktop Is Installed (version 2025.1.2+)
Bitwarden's SSH Agent feature replaces the Windows OpenSSH Authentication
Agent. It stores private keys in your vault and presents them to SSH and git
via the same Windows named pipe that the built-in agent would use.

Check your installed version:
   winget list --id Bitwarden.Bitwarden

If not installed or below 2025.1.2:
   winget install Bitwarden.Bitwarden

After installing, open Bitwarden desktop and log in before running Phase 2.

EXIT CRITERIA: AI folder is at new location, noreply email is in hand,
pwsh --version returns 7.4+, Bitwarden desktop is installed and logged in.

---

## PHASE 1, Verify and Install Prerequisites
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_01_prerequisites.ps1
**Bash fallback:** scripts\phase_01_prerequisites.sh

### What the script does:
Checks whether each required tool is installed at the minimum version.
Installs any missing tools automatically via winget or direct download.
Prints a pass/fail table at the end.

### How to start it:
Open PowerShell 7+ and run:
   pwsh -File scripts\phase_01_prerequisites.ps1

### Tools it installs if missing:
- Git (2.42+)
- GitHub CLI / gh (2.40+)
- Windows OpenSSH (built into Windows 11, verifies it is active)
- gitleaks (8.18+)
- NASM assembler (2.16+)
- uv, Python environment manager (0.4+)
- ruff, Python linter/formatter (0.3+)
- delta, enhanced git diff pager (0.17+)
- x64dbg, Assembly debugger (latest)
- Oh My Posh, terminal prompt engine (23+)
- JetBrains Mono Nerd Font

EXIT CRITERIA: Script prints all tools as PASS. No FAIL entries remain.

---

## PHASE 2, SSH Key Setup via Bitwarden SSH Agent
**Type:** Script + Manual (interleaved)
**Script file:** scripts\phase_02_ssh_setup.ps1

### How SSH works with Bitwarden:
Private keys are stored in your Bitwarden vault and never written to disk.
Bitwarden's desktop app acts as the SSH agent, exposing keys on the same
Windows named pipe (\\.\pipe\openssh-ssh-agent) that the built-in agent
would use. Git is directed to use the Windows OpenSSH client (ssh.exe),
which knows how to talk to that pipe. Only a public key file (.pub) is
saved to ~/.ssh/, it serves as a hint so SSH knows which vault key to
request for each GitHub host alias.

### Step 2A, Run the script:
   pwsh -File scripts\phase_02_ssh_setup.ps1

The script will (pausing for your manual actions where needed):
1. Verify Bitwarden desktop is installed
2. Disable the Windows OpenSSH Authentication Agent service
   (Bitwarden replaces it, both cannot run at the same time)
3. Pause and guide you to:
   - Enable SSH Agent in Bitwarden: Settings -> Security -> SSH Agent
   - Create a new key: SSH Keys -> New SSH key
       Name: GitHub Personal    Key type: Ed25519
   - Copy the public key to your clipboard
4. Prompt you to paste the public key, saves it to
   ~/.ssh/id_ed25519_github_personal.pub
5. Write ~/.ssh/config with host aliases for github-personal and
   github-client (client key is a placeholder, activated later)
6. Initialize ~/.ssh/allowed_signers
7. Set GIT_SSH to C:\Windows\System32\OpenSSH\ssh.exe (required so git
   uses the Windows SSH client that can reach Bitwarden's agent)
8. Display the public key again and print GitHub upload instructions

### Step 2B, Upload your public key to GitHub (Manual):
The script will print your public key. Copy it, then:

1. Go to github.com -> Settings -> SSH and GPG keys
2. Click "New SSH key"
3. Title: "{your_name} Personal, Authentication"
4. Key type: Authentication Key
5. Paste the public key
6. Click "Add SSH key"

7. Click "New SSH key" again
8. Title: "{your_name} Personal, Signing"
9. Key type: Signing Key
10. Paste the same public key
11. Click "Add SSH key"

### Step 2C, Test the connection (Manual):
Make sure Bitwarden desktop is open and your vault is unlocked.
Open a new PowerShell 7+ terminal and run:
   ssh -T github-personal

Bitwarden will show an authorization prompt, click Allow.
(Optional: set the key's authorization to "Remember until vault is locked"
in Bitwarden to reduce future prompts.)

Expected response:
   Hi {github_username}! You've successfully authenticated, but GitHub
   does not provide shell access.

EXIT CRITERIA: SSH test returns the success message above.

---

## PHASE 3, Git Configuration Files
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_03_git_config.ps1

### Before running: Have your noreply email ready (from Step 0.2)

### How to start it:
   pwsh -File scripts\phase_03_git_config.ps1

The script will prompt you to enter your GitHub noreply email address,
then create:
- ~/.gitconfig, global Git configuration with all settings
- ~/.gitconfig-client, client identity placeholder (UTC timestamps)
- ~/.gitconfig-arduino, arduino identity override
- ~/.gitmessage, Conventional Commits reminder template

### Verify after the script completes:
   git config --list --global

Confirm you see: user.name, user.email, commit.gpgsign=true,
tag.gpgsign=true, pull.rebase=true, and init.defaultBranch=main.

EXIT CRITERIA: git config --list --global shows all expected values.

---

## PHASE 4, Project Directory Structure
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_04_directories.ps1

### How to start it:
   pwsh -File scripts\phase_04_directories.ps1

The script creates:
- %USERPROFILE%\projects\iam6ft7in\
- %USERPROFILE%\projects\client\
- %USERPROFILE%\projects\arduino\upstream\
- %USERPROFILE%\projects\arduino\custom\

EXIT CRITERIA: All four directories exist.

---

## PHASE 5, Global .gitignore
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_05_gitignore.ps1

### How to start it:
   pwsh -File scripts\phase_05_gitignore.ps1

The script creates ~/.gitignore_global covering Windows OS files,
VS Code artifacts, temp files, .env files, and Python build artifacts.
Registers it in ~/.gitconfig via core.excludesFile.

EXIT CRITERIA: git config --global core.excludesFile returns a valid path.

---

## PHASE 6, Secret Scanning and Git Hooks
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_06_hooks_and_scanning.ps1

### How to start it:
   pwsh -File scripts\phase_06_hooks_and_scanning.ps1

The script:
- Creates ~/.git-templates/hooks/pre-commit (gitleaks staged-file scan)
- Creates ~/.git-templates/hooks/commit-msg (Conventional Commits validation)
- Creates ~/.gitleaks.toml with custom ArduPilot and Windows rules
- Sets init.templateDir in ~/.gitconfig
- Creates a Windows Task Scheduler task for weekly full repo scan
  (Sundays at 02:00 AM)

### Verify the commit-msg hook works (Manual):
Navigate into any test directory, run git init, and try:
   git commit --allow-empty -m "bad commit message"

You should see a rejection with instructions on correct format.

Then try:
   git commit --allow-empty -m "chore: test conventional commits hook"

This should succeed.

EXIT CRITERIA: Bad commit message is rejected. Valid message is accepted.
Task Scheduler task is visible in Task Scheduler.

---

## PHASE 7, Global Claude Rules Files
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_07_claude_rules.ps1

### How to start it:
   pwsh -File scripts\phase_07_claude_rules.ps1

### What it does:
Deploys 9 rule files to `~/.claude/rules/`:
- `core.md`: universal rules for all projects
- `shell.md`: bash/zsh, PowerShell 7, Perl scripting standards
- `arduino.md`: ArduPilot/Arduino rules
- `python.md`: uv, ruff, pytest, src/ layout
- `assembly.md`: NASM x86/x64 rules
- `vbscript.md`: VBScript/Office automation rules
- `command_paths.md`: PATH resolution and MSYS2 path mangling
- `powershell.md`: PS cmdlet limits, here-string gotchas, encoding hazards
- `ssh.md`: SSH binary selection and per-repo documentation protocol

### Behavior on re-run (diff-before-copy):
First run creates every file from the repo source. On subsequent runs:
- Files byte-identical to the repo source are reported `IN-SYNC` and skipped.
- Files that differ from the repo source (for example, because you edited
  the deployed copy) trigger a per-file prompt:
  `[o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit`.
  Press Enter (or `s`) to preserve your personalization.
- Non-interactive runs (piped stdin, scheduled task) skip every drifted
  file and warn on stderr.

### Force mode:
To bypass the prompt and overwrite every drifted file (the prior behavior):
   pwsh -File scripts\phase_07_claude_rules.ps1 -Force

EXIT CRITERIA: All 9 .md files exist under ~/.claude/rules/. Every file is
reported as one of IN-SYNC, CREATED, OVERWRITE, or SKIP.

---

## PHASE 7b, Claude Skills and Helper Scripts
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_07b_claude_skills_and_scripts.ps1
**Bash fallback:** scripts\phase_07b_claude_skills_and_scripts.sh

### How to start it:
   pwsh -File scripts\phase_07b_claude_skills_and_scripts.ps1

### What the script does:
Walks every file under claude-skills/ and under claude-scripts/ and
deploys each one against its counterpart in either ~/.claude/skills/,
~/.claude/scripts/, or {projects_root}\shortcuts\ (for the shortcut
regenerator). Path mapping:
- claude-skills/{skill}/*
    -> ~/.claude/skills/{skill}/*
- claude-scripts\setup_project_board.ps1
    -> ~/.claude/scripts/setup_project_board.ps1
- claude-scripts\regenerate_shortcuts.ps1
    -> {projects_root}\shortcuts\regenerate.ps1

The projects root is read from ~/.claude/config.json (written by Phase 4);
falls back to %USERPROFILE%\projects if the config is missing.

### Behavior on re-run (diff-before-copy):
Each file is compared to its deployed counterpart:
- IN-SYNC files are left alone.
- Drifted files trigger a per-file prompt
  `[o]verwrite / [s]kip (default) / [A]ll / [N]one / [q]uit`.
- Non-interactive runs skip drifted files and warn on stderr.
- Deployed-only files (user customizations added to a skill dir) are
  preserved and reported as KEPT, never deleted.

Force mode:
   pwsh -File scripts\phase_07b_claude_skills_and_scripts.ps1 -Force

EXIT CRITERIA: Every SKILL.md in claude-skills/ has a deployed copy,
setup_project_board.ps1 exists in ~/.claude/scripts/, and regenerate.ps1
exists in {projects_root}\shortcuts\. Each file resolves to one of
IN-SYNC, CREATED, OVERWRITE, or SKIP.

---

## PHASE 8, Per-Project Scaffold Template
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_08_scaffold_template.ps1
**Bash fallback:** scripts\phase_08_scaffold_template.sh

### How to start it:
   pwsh -File scripts\phase_08_scaffold_template.ps1

### What the script does:
Deploys ~/.claude/templates/project/ from templates/project/ so
/new-repo has something to stamp out. The tree contains:
- AGENTS.md, CLAUDE.md, README.md skeleton
- .gitignore, .gitattributes, .editorconfig templates
- SECURITY.md, CONTRIBUTING.md, CHANGELOG.md templates
- .github/pull_request_template.md
- .github/ISSUE_TEMPLATE/ (bug_report, feature_request, task)
- .code-workspace template
- .claude/rules/project.md starter
- Platform-specific sub-templates (python, powershell, bash, perl,
  vbscript, asm, arduino)

### Behavior on re-run (diff-before-copy):
Same pattern as Phase 7 and Phase 7b. Every file under the source tree is
compared to its deployed counterpart. Identical files report IN-SYNC,
drifted files trigger a per-file prompt, new files are CREATED, and
deployed-only files (personalizations) are preserved and reported as KEPT.
Non-interactive runs skip drifted files. Pass -Force (PS) or --force
(bash) to overwrite every drifted file without prompting.

EXIT CRITERIA: ~/.claude/templates/project/ exists. Every source file
resolves to one of IN-SYNC, CREATED, OVERWRITE, or SKIP.

---

## PHASE 9, VS Code Configuration Templates
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_09_vscode_config.ps1

### How to start it:
   pwsh -File scripts\phase_09_vscode_config.ps1

The script:
- Writes VS Code user settings (Solarized Dark theme, JetBrains Mono
  Nerd Font, onFocusChange auto-save, minimap off, ruler at 88)
- Creates ~/.claude/templates/vscode/ with extension lists and
  launch.json debug templates for Python, PowerShell, and NASM Assembly
- Creates the global CSpell custom dictionary at ~/.cspell/custom-words.txt

### After the script: verify VS Code manually (Manual):
Open VS Code. Confirm:
- Theme is Solarized Dark
- Font is JetBrains Mono Nerd Font (monospace, clear glyphs)
- A ruler line is visible at 88 characters

EXIT CRITERIA: VS Code opens with correct theme, font, and ruler.

---

## PHASE 10, Windows Environment Configuration
**Type:** Script (you start it, script does the work)
**Script file:** scripts\phase_10_windows_env.ps1

### How to start it (run as Administrator):
Right-click PowerShell 7+ -> Run as Administrator, then:
   pwsh -File scripts\phase_10_windows_env.ps1

The script:
- Sets GIT_SSH environment variable to Windows OpenSSH
- Sets LANG and LC_ALL to en_US.UTF-8
- Verifies all required tools are on PATH
- Writes Windows Terminal settings.json with three profiles:
    personal  (sky blue    #56B4E9)
    client   (golden yellow #E69F00), placeholder
    arduino   (purple      #CC79A7)
  Each profile opens at its corresponding project root directory
- Configures Oh My Posh theme at ~/.oh-my-posh/theme.json
- Adds Oh My Posh initialization to your PowerShell profile ($PROFILE)
- Verifies the Task Scheduler gitleaks task from Phase 6 is present

### After the script: verify manually (Manual):
1. Close and reopen Windows Terminal
2. Open the "personal" profile
3. Confirm: blue accent color is visible
4. Confirm: Oh My Posh prompt is visible with directory shown
5. Navigate into any Git repo and confirm Git branch + status appear
   in the prompt

EXIT CRITERIA: Windows Terminal opens personal profile with correct color.
Oh My Posh shows Git branch and status when inside a repo.

---

## PHASE 11, GitHub CLI Authentication and End-to-End Test
**Type:** Manual then Script

### Step 11A, Authenticate GitHub CLI (Manual):
Open PowerShell 7+ (personal profile in Windows Terminal) and run:
   gh auth login

Follow the prompts:
- GitHub.com (not Enterprise)
- SSH protocol
- Select your existing key: id_ed25519_github_personal
- Authenticate via browser when prompted

Then verify:
   gh auth status

You should see your username and "Logged in to github.com".

### Step 11B, Run end-to-end test (Script):
   pwsh -File scripts\phase_11_e2e_test.ps1

The script:
- Creates a temporary private test repo called test_e2e_delete_me
- Clones it using the SSH host alias
- Makes a signed commit with a valid Conventional Commits message
- Verifies the commit signature (git log --show-signature)
- Creates a test PR via gh pr create
- Deletes the test repo and local directory
- Reports pass/fail for each step

EXIT CRITERIA: All end-to-end test steps pass. Signed commit is verified.
Test repo is cleaned up.

---

## PHASE 12, Initialize cfg_dev_environment as First Gold Standard Repo
**Type:** Script then Manual
**Script file:** scripts\phase_12_init_setup_repo.ps1

### Step 12A, Run the initialization script:
   pwsh -File scripts\phase_12_init_setup_repo.ps1

The script:
- Creates the repo on GitHub: personal_cfg_dev_environment (private)
- Creates local directory at ~/projects/iam6ft7in/cfg_dev_environment/
- Copies all scaffold template files (from Phase 8)
- Copies all setup scripts organized by phase into scripts/
- Copies all configuration file templates
- Creates the first signed commit: "chore: initial project scaffold"
- Pushes to GitHub
- Configures branch protection on main

### Step 12B, Choose a license (Manual, prompted by script):
The script will pause and ask you to choose a license:
- MIT
- Apache-2.0
- GPL-3.0
- None (proprietary)
Choose explicitly, there is no default.

### Step 12C, Verify on GitHub (Manual):
1. Open github.com and navigate to your new cfg_dev_environment repo
2. Confirm: the first commit has a green "Verified" badge
3. Confirm: branch protection is active on main
   (go to Settings -> Branches -> Branch protection rules)
4. Confirm: the repo is private

EXIT CRITERIA: Repo is live on GitHub, first commit shows Verified badge,
branch protection is active, repo is private.

---

## IMPLEMENTATION COMPLETE

Once Phase 12 is done you have a fully configured, gold standard GitHub
environment. From this point forward, every new project starts with:
   /new-repo

---

## Quick Reference, Script Commands

| Phase | Command |
|-------|---------|
| 1 | pwsh -File scripts\phase_01_prerequisites.ps1 |
| 2 | pwsh -File scripts\phase_02_ssh_setup.ps1 |
| 3 | pwsh -File scripts\phase_03_git_config.ps1 |
| 4 | pwsh -File scripts\phase_04_directories.ps1 |
| 5 | pwsh -File scripts\phase_05_gitignore.ps1 |
| 6 | pwsh -File scripts\phase_06_hooks_and_scanning.ps1 |
| 7 | pwsh -File scripts\phase_07_claude_rules.ps1 |
| 7b | pwsh -File scripts\phase_07b_claude_skills_and_scripts.ps1 |
| 8 | pwsh -File scripts\phase_08_scaffold_template.ps1 |
| 9 | pwsh -File scripts\phase_09_vscode_config.ps1 |
| 10 | pwsh -File scripts\phase_10_windows_env.ps1 (as Admin) |
| 11A | gh auth login (manual) |
| 11B | pwsh -File scripts\phase_11_e2e_test.ps1 |
| 12 | pwsh -File scripts\phase_12_init_setup_repo.ps1 |

---

## Notes

- Do not skip phases, each phase depends on the previous one.
- Phase 10 requires Administrator privileges.
- If any script fails, read the error output carefully before retrying.
  Do not re-run a script blindly after a failure.
- The Bash fallback scripts (.sh) are available for each phase if
  PowerShell is unavailable. Run them from Git Bash.
- The client identity is a placeholder. When the client GitHub account
  is created, run: /activate-client
