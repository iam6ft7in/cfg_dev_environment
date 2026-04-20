# How This Repo Works

This document explains the structure and purpose of every component in this
repository, and how to use it, both for setting up a fresh Windows 11
development environment and for migrating existing projects into it.

For the step-by-step run instructions, see `IMPLEMENTATION_STEPS.md`.

---

## What This Repo Is

`cfg_dev_environment` is a self-contained toolkit for building a gold standard
GitHub development environment on Windows 11. It is designed to be run
once on a fresh machine. After all 12 phases complete, the machine has:

- All development tools installed and configured
- SSH keys in Bitwarden (never on disk)
- Signed git commits and tags globally enabled
- A project directory structure at `%USERPROFILE%\projects\`
- Global git hooks (Conventional Commits, gitleaks secret scanning)
- Global Claude rules and skills installed
- VS Code and Windows Terminal fully configured
- A reusable migration script for bringing existing projects into the
  new environment

---

## Folder Structure

```
cfg_dev_environment/
├── scripts/             : 27 scripts (13 PS7 + 13 bash + 1 migration)
├── templates/
│   ├── project/         : Scaffold files for every new repo
│   │   ├── platforms/   : Platform-specific starters (Python, PS, bash, etc.)
│   │   └── .github/     : Issue templates, PR template
│   └── vscode/          : VS Code settings, extensions, launch configs
├── claude-rules/        : 6 global Claude rule files
├── claude-skills/       : Claude skill directories (deployed to ~/.claude/skills/)
├── claude-scripts/      : Helper scripts the skills call (deployed by Phase 7b)
├── config/              : gitconfig templates, gitleaks, ssh_config, oh-my-posh
├── IMPLEMENTATION_STEPS.md : Authoritative run order with exit criteria
├── IMPLEMENTATION_STEPS.txt, Plain text copy of the above
└── HOW_IT_WORKS.md      : This file
```

---

## The 12 Phases

Each phase has a PowerShell 7 script (`phase_NN_*.ps1`) and a bash
equivalent (`phase_NN_*.sh`). Run in strict order. Each script prints a
pass/fail table and exits 1 if any check fails.

### Phase 0: Manual Prerequisites
No script. Four manual steps:
1. Move the OneDrive AI folder to the correct location
2. Retrieve your GitHub noreply email from GitHub Settings → Emails
3. Verify PowerShell 7+ is installed
4. Verify Bitwarden Desktop 2025.1.2+ is installed and logged in

### Phase 1: Install Prerequisites
Installs and verifies all required tools via winget or direct download:
git, GitHub CLI (gh), VS Code, Windows Terminal, Oh My Posh, delta,
gitleaks, Node.js, Python, uv, NASM, x64dbg, Perl, shellcheck, BATS.

### Phase 2: SSH Setup (Bitwarden)
Guides you through creating an Ed25519 SSH key inside Bitwarden's vault.
Writes `~/.ssh/config` with host aliases for `github-personal` and
`github-client`. The `IdentityFile` entries point to `.pub` files only,
Bitwarden presents the private key at runtime via the Windows named pipe.
Disables the Windows OpenSSH Authentication Agent service (it conflicts
with Bitwarden on the same pipe).
Writes `~/.ssh/allowed_signers` for commit signature verification.

**Why two binaries matter:**
- Auth (push/pull): `GIT_SSH` and `core.sshCommand` → Windows `ssh.exe`
- Signing (commits/tags): `gpg.ssh.program` → Windows `ssh-keygen.exe`
Git's bundled binaries use Unix `SSH_AUTH_SOCK` and cannot reach
Bitwarden's Windows named pipe. The Windows System32 binaries can.

### Phase 3: Git Config
Writes `~/.gitconfig` with:
- User identity (name + noreply email)
- SSH commit and tag signing (`gpg.format = ssh`)
- Signing key pointing to the `.pub` file
- `gpg.ssh.program` and `core.sshCommand` pointing to Windows binaries
- `autocrlf = input` (store LF, checkout LF on Windows)
- delta as the diff pager
- VS Code as the editor and merge tool
- Per-context include files for Client and Arduino identities
Writes `~/.gitmessage` commit message template.

### Phase 4: Directory Structure
Creates the project directory tree:
```
%USERPROFILE%\projects\
├── personal\
├── client\
└── arduino\
    ├── upstream\
    └── custom\
```

### Phase 5: Global gitignore
Writes `~/.gitignore_global` with patterns for Windows OS artifacts,
editor artifacts (.vs/, *.suo), Python, Node, secrets (.env), and
log/transcript files.

### Phase 6: Git Hooks and Secret Scanning
Installs two global git hooks to `~/.git-hooks/`:
- `commit-msg`: enforces Conventional Commits format (case-sensitive:
  `feat:` is valid, `FEAT:` is not)
- `pre-commit`: runs gitleaks against staged files and blocks the commit
  if secrets are detected

Configures git to use `~/.git-hooks/` globally.
Writes `~/.gitleaks.toml` with custom rules for Windows credential
patterns, ArduPilot SYSID values, and generic API keys.
Installs a weekly gitleaks scan as a Windows Task Scheduler task.

### Phase 7: Claude Rules
Deploys 9 rule files from `claude-rules/` to `~/.claude/rules/`:
- `core.md`: commit standards, branch standards, code standards, security
- `shell.md`: bash/zsh, PowerShell 7, Perl scripting standards
- `arduino.md`: ArduPilot/MAVLink conventions
- `python.md`: uv, ruff, pytest, src layout conventions
- `assembly.md`: NASM, x64 calling convention
- `vbscript.md`: Windows automation and Office macro conventions
- `command_paths.md`: PATH resolution, MSYS2 path mangling, per-repo command path files
- `powershell.md`: PS cmdlet limits, here-string gotchas, encoding hazards, executable selection
- `ssh.md`: SSH binary selection, per-repo SSH documentation protocol, host alias maintenance

On re-run, each file is compared to its deployed counterpart. Identical files
report `IN-SYNC` and are left alone. Drifted files trigger a per-file prompt
(`overwrite / skip / All / None / quit`) so hand-edits to the deployed copy
survive subsequent runs. Non-interactive runs skip every drifted file and
warn on stderr; pass `-Force` (PS) or `--force` (bash) to overwrite without
prompting.

### Phase 7b: Claude Skills and Helper Scripts
Deploys every file under `claude-skills/` to `~/.claude/skills/` (so the
`/new-repo`, `/migrate-repo`, `/apply-standard`, and other slash commands
become available) and the two helper scripts the skills shell out to:
- `claude-scripts/setup_project_board.ps1` → `~/.claude/scripts/setup_project_board.ps1`
  (creates and standardizes the GitHub Projects v2 board; called by
  `/new-repo` step 3m, `/migrate-repo` step 5, `/apply-standard` step 4s)
- `claude-scripts/regenerate_shortcuts.ps1` → `{projects_root}\shortcuts\regenerate.ps1`
  (rebuilds `.lnk` files under the shortcuts directory; called by the
  same three skills at the end of their runs)

The projects root is read from `~/.claude/config.json` (written by Phase 4).

On re-run, each file is compared to its deployed counterpart. Identical
files report `IN-SYNC`. Drifted files trigger a per-file prompt
(`overwrite / skip / All / None / quit`) so hand-edits survive subsequent
runs. Deployed-only files under a skill directory (user customizations)
are preserved and reported as `KEPT`, never deleted. Non-interactive runs
skip drifted files; pass `-Force` / `--force` to overwrite without
prompting.

### Phase 8: Project Scaffold Template
Deploys `templates/project/` to `~/.claude/templates/project/` so that the
`/new-repo` skill can stamp out a fully-formed repo structure.

Platform starters available:
- Python (uv + ruff + pytest, src/ layout, pyproject.toml)
- PowerShell (PSScriptAnalyzer config, module structure)
- bash (shellcheck config, BATS test layout)
- Perl (cpanfile, Test::More layout)
- VBScript (main script, helpers library)
- Assembly/NASM (main.asm, macros.inc, Makefile)
- Arduino/ArduPilot (base.param, vehicle.param, wiring diagram)

Uses the same diff-before-copy flow as Phase 7 and Phase 7b: identical
files report `IN-SYNC`, drifted files prompt per file, deployed-only
additions are reported as `KEPT` and preserved. `-Force` / `--force`
retains the old always-overwrite behavior.

### Phase 9: VS Code Configuration
Writes VS Code user settings (`settings.json`):
- Solarized Dark theme
- JetBrains Mono Nerd Font at 14px
- Ruler at 88 characters
- Format on save, trim trailing whitespace
- Per-language indent settings
Writes `extensions.json` with recommended extensions.
Copies launch configurations for Python, PowerShell, and NASM debugging.

### Phase 10: Windows Environment
Writes the PowerShell profile (`Microsoft.PowerShell_profile.ps1`) with:
- Oh My Posh prompt (minimal theme)
- Wong palette colors per context (sky blue personal / golden yellow
  client / purple arduino)
- A note that SSH keys are managed by Bitwarden (no ssh-add needed)
Sets system environment variables: `PYTHONDONTWRITEBYTECODE=1`,
`PYTHONUTF8=1`, `GIT_SSH` pointing to Windows `ssh.exe`.

### Phase 11: End-to-End Test
Creates a temporary test repo on GitHub and runs 8 automated tests:
- T1: git version check
- T2: SSH auth via `ssh -T git@github-personal`
- T3: Conventional Commits hook blocks invalid messages
- T4: gitleaks pre-commit hook blocks staged secrets
- T5: commit signing, verifies the `Verified` status in git log
- T6: push to remote
- T7: feature branch, PR creation via gh
- T8: delta pager is available
Cleans up the test repo at the end. Requires `delete_repo` scope on the
gh token (add with `gh auth refresh -h github.com -s delete_repo`).

### Phase 12: Initialize This Repo
Initializes `cfg_dev_environment` itself as a git repo (if not already done),
pushes to GitHub, and applies the branch ruleset and topics. This phase
is idempotent, re-running it is safe.

---

## Config Files

### `config/gitconfig.template`
The global gitconfig template showing all settings applied by Phase 3.
Includes context-include blocks for Client and Arduino git identities.

### `config/gitconfig-client.template` / `config/gitconfig-arduino.template`
Conditional include files for alternate identities. Used when working in
`%USERPROFILE%\projects\client\` or `%USERPROFILE%\projects\arduino\`.

### `config/gitleaks.toml`
The live gitleaks config copied to `~/.gitleaks.toml`. Custom rules:
- `windows-password-assignment`: flags `password = "literal"` patterns.
  Uses `secretGroup = 2` so the value (not the keyword) is checked against
  the allowlist. Allowlist patterns cover variable refs (`\$`), expressions
  (`\(`), and placeholder strings.
- `ardupilot-sysid`: flags non-default SYSID values outside param files.
- `windows-registry-credential`: flags HKEY paths containing "Password".
- `generic-api-key-var`: flags API key variable assignments.

### `config/ssh_config.template`
Template for `~/.ssh/config`. Key details:
- `IdentityFile` points to the `.pub` file (Bitwarden maps this to the
  private key in vault)
- No `AddKeysToAgent yes` (Bitwarden manages the agent, not ssh-add)
- Two host aliases: `github-personal` and `github-client`

### `config/ohmyposh-theme.json`
Oh My Posh minimal theme with Deuteranopia-safe Wong palette colors.

### `config/gitmessage.template`
Commit message template reminding of Conventional Commits format.

---

## Claude Rules (`claude-rules/`)

Six Markdown files installed to `~/.claude/rules/`. Claude Code loads these
globally for every project. They define standards for commits, branches,
code style, security, comments, and uncertainty handling per language.

The `core.md` rule is the most important, it defines:
- When to stop and ask vs. when to proceed with an assumption
- Code review format (Critical / Warning / Suggestion)
- Security rules (never commit secrets, flag potential leaks immediately)

---

## Claude Skills (`claude-skills/`)

Each subdirectory under `claude-skills/` is a Claude skill, a `SKILL.md`
file (sometimes with supporting assets like `aliases.json`) invoked via a
slash command. Phase 7b deploys them to `~/.claude/skills/`.

| Skill | Command | Purpose |
|---|---|---|
| new-repo | `/new-repo` | Scaffold a new repo from template, incl. Projects board |
| migrate-repo | `/migrate-repo` | Migrate an existing project into the gold standard |
| apply-standard | `/apply-standard` | Audit a repo and apply missing gold standard pieces |
| new-feature | `/new-feature` | Start a feature branch with a linked issue |
| pr-create | `/pr-create` | Create a PR with pre-flight checks and template |
| merge-complete | `/merge-complete` | Pull main, clean branches, close issue after merge |
| cleanup-branches | `/cleanup-branches` | Delete stale local branches |
| sync-upstream | `/sync-upstream` | Sync an ArduPilot fork with upstream |
| verify-backup | `/verify-backup` | Verify GitHub has all local commits |
| weekly-review | `/weekly-review` | Weekly repo health digest |
| check-notifications | `/check-notifications` | GitHub notifications digest |
| switch-theme | `/switch-theme` | Toggle VS Code / Terminal theme |
| activate-client | `/activate-client` | Switch to client GitHub identity |
| send-email | `/send-email` | Send SMTP notifications/alerts |
| session-save | `/session-save` | Write SESSION_STATE.md at end of session |
| session-resume | `/session-resume` | Read SESSION_STATE.md and re-orient |

### Helper scripts used by the skills (`claude-scripts/`)

A few skills shell out to scripts that must already be on disk. Phase 7b
deploys these alongside the SKILL.md files:

| Script | Destination | Called by |
|---|---|---|
| `setup_project_board.ps1` | `~/.claude/scripts/` | `/new-repo`, `/migrate-repo`, `/apply-standard` |
| `regenerate_shortcuts.ps1` | `{projects_root}\shortcuts\regenerate.ps1` | `/new-repo`, `/migrate-repo`, `/apply-standard` |

---

## The Migration Script (`scripts/migrate_to_github.ps1`)

Used to bring an existing project (not yet in git) into the gold standard
environment. Handles the full journey in one command.

### What it does
1. Validates 12 prerequisites (PS version, git, gh, auth, Bitwarden, etc.)
2. Analyzes scaffold gaps (lists which of 7 standard files are missing)
3. Detects gitignore candidates (.log, .pdf, .docx, dated transcripts, etc.)
4. Copies the project to `%USERPROFILE%\projects\personal\<repo-name>`
5. Initializes a git repo
6. Cleans stale OneDrive paths from `.claude/settings.local.json`
7. Generates a `.gitignore` for PowerShell projects
8. Adds all 7 missing scaffold files
9. Creates a private GitHub repo via `gh`
10. Sets the remote using the `github-personal` SSH alias
11. Makes an initial signed commit
12. Pushes to origin/main
13. Applies the branch ruleset (requires GitHub Pro for private repos)
14. Applies GitHub topics

### Modes
```powershell
# Check prerequisites only, no changes
pwsh -File scripts\migrate_to_github.ps1 -SourcePath "..." -RepoName "..." -Description "..." -Validate

# Preview all actions, no changes
pwsh -File scripts\migrate_to_github.ps1 -SourcePath "..." -RepoName "..." -Description "..." -WhatIf

# Execute migration
pwsh -File scripts\migrate_to_github.ps1 -SourcePath "..." -RepoName "..." -Description "..."
```

### Important: Topics array syntax
When calling with `pwsh -File`, do NOT use `@(...)` for the Topics array.
Pass bare comma-separated values:
```powershell
-Topics "powershell","windows","automation"
```

### Known limitations
- Designed for projects that are NOT already git repos. If the source has
  a `.git` directory it will migrate as-is (with a WARN, not a FAIL).
- The generated `.gitignore` is PowerShell-flavored. Edit it after
  migration if the project is a different platform.
- gitleaks will block the commit if real secrets are found in the source
  files. Fix the source before migrating, remove hardcoded credentials
  and replace with environment variable lookups before running this script.

---

## Running on a Fresh Machine

1. Clone this repo somewhere temporary (OneDrive is fine for this step):
   ```powershell
   git clone https://github.com/{github_username}/cfg_dev_environment.git
   cd cfg_dev_environment
   ```
2. Complete Phase 0 manually (see `IMPLEMENTATION_STEPS.md`)
3. Run phases 1-12 in order:
   ```powershell
   pwsh -File scripts\phase_01_prerequisites.ps1
   pwsh -File scripts\phase_02_ssh_setup.ps1
   # ... and so on through phase_12
   ```
4. After Phase 12 completes, clone the repo to its permanent location:
   ```powershell
   git clone git@github-personal:{github_username}/cfg_dev_environment.git %USERPROFILE%\projects\personal\cfg_dev_environment
   ```
5. Delete the temporary clone.

---

## Migrating a Future Project

```powershell
cd %USERPROFILE%\projects\personal\cfg_dev_environment

pwsh -File scripts\migrate_to_github.ps1 `
    -SourcePath "C:\path\to\existing\project" `
    -RepoName "my-project-name" `
    -Description "Short description for GitHub" `
    -Topics "powershell","windows","automation" `
    -Validate

# If all PASS, preview:
pwsh -File scripts\migrate_to_github.ps1 `
    -SourcePath "C:\path\to\existing\project" `
    -RepoName "my-project-name" `
    -Description "Short description for GitHub" `
    -Topics "powershell","windows","automation" `
    -WhatIf

# If preview looks right, execute:
pwsh -File scripts\migrate_to_github.ps1 `
    -SourcePath "C:\path\to\existing\project" `
    -RepoName "my-project-name" `
    -Description "Short description for GitHub" `
    -Topics "powershell","windows","automation"
```

After confirming the GitHub repo looks correct (Verified badge, topics,
ruleset), delete the source directory.
