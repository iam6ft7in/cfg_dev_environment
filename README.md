# cfg_dev_environment

Gold standard GitHub development environment setup for Windows 11. One-time
bootstrap of git, commit signing, hooks, Claude Code rules and skills, the
project directory layout, Windows Terminal profiles, and a reusable migration
script for moving existing projects into the standard.

---

## Start here

If you have just cloned this repo and want to set up your machine, follow
these steps in order. Each step has a single command. Do not run anything
out of order.

### 1. Preview every change before it happens

```powershell
pwsh -File scripts\preview.ps1
```

Or from Git Bash:

```bash
bash scripts/preview.sh
```

This script makes **no changes**. It walks the 12 phases and prints, for
each one, the tools it would install, the directories it would create, the
config files it would write or overwrite, the registry keys it would set,
and the Claude artifacts it would deploy. It tags each line with the
current state on your machine (`[EXISTS]`, `[WILL CREATE]`, `[INSTALLED]`,
`[WILL INSTALL]`, `[WILL OVERWRITE]`).

Read the output before continuing. If you see anything you do not want to
change, stop here and ask before proceeding.

### 2. Complete the manual Phase 0 prerequisites

Phase 0 is four manual steps: move the OneDrive AI folder, get your GitHub
noreply email, install PowerShell 7+, install Bitwarden Desktop. Full
detail in [IMPLEMENTATION_STEPS.md, Phase 0](IMPLEMENTATION_STEPS.md).

### 3. Run Phases 1 through 12 in strict order

```powershell
pwsh -File scripts\phase_01_prerequisites.ps1
pwsh -File scripts\phase_02_ssh_setup.ps1
pwsh -File scripts\phase_03_git_config.ps1
pwsh -File scripts\phase_04_directories.ps1
pwsh -File scripts\phase_05_gitignore.ps1
pwsh -File scripts\phase_06_hooks_and_scanning.ps1
pwsh -File scripts\phase_07_claude_rules.ps1
pwsh -File scripts\phase_07b_claude_skills_and_scripts.ps1
pwsh -File scripts\phase_08_scaffold_template.ps1
pwsh -File scripts\phase_09_cspell_dictionary.ps1
pwsh -File scripts\phase_10_windows_env.ps1
pwsh -File scripts\phase_11_e2e_test.ps1
pwsh -File scripts\phase_12_init_setup_repo.ps1
```

Every phase prints a pass/fail table and exits non-zero on failure. Do not
proceed to the next phase if the previous one failed; fix the issue first
and re-run that phase. Each phase is idempotent: re-running it on a
partially completed state is safe.

Bash mirrors live next to each `.ps1` (e.g. `scripts/phase_01_prerequisites.sh`)
for users who prefer Git Bash.

### 4. Done

After Phase 12 your machine has the full gold-standard environment plus
this repo cloned at `{projects_root}\{github_username}\public\cfg_dev_environment\`.

For ongoing tasks (creating a new repo, migrating an existing one,
auditing an old repo against the standard), see the Claude skills now
deployed at `~/.claude/skills/` (`/new-repo`, `/migrate-repo`,
`/apply-standard`, etc.).

---

## What this installs and changes on your machine

High-level summary. Run `scripts\preview.ps1` for the per-file inventory.

| Category | Examples | Reversible? |
|---|---|---|
| **Installed tools** | `git`, `gh`, VS Code, Windows Terminal, Oh My Posh, `delta`, `gitleaks`, Node.js, Python, `uv`, NASM, x64dbg, Perl, ShellCheck, BATS | Yes (`winget uninstall`) |
| **Bitwarden SSH key** | One Ed25519 key stored inside your Bitwarden vault | Yes (delete the vault entry) |
| **Global git config** | `~/.gitconfig`, `~/.gitconfig-client`, `~/.gitconfig-arduino`, `~/.gitmessage`, `~/.gitignore_global` | Existing files are backed up to `*.bak` first |
| **Git template hooks** | `~/.git-templates/hooks/pre-commit`, `~/.git-templates/hooks/commit-msg` | Yes (delete the directory) |
| **gitleaks** | `~/.gitleaks.toml`, weekly Windows Task Scheduler job | Yes (delete file, unregister task) |
| **Project directory tree** | `{projects_root}\{github_username}\{public,private,collaborative}`, `{projects_root}\client`, `{projects_root}\arduino\{upstream,custom}` | Yes (empty until you add repos) |
| **Claude Code config** | `~/.claude/{rules,skills,scripts,shortcuts,templates}/` | Yes (delete the directory) |
| **VS Code config** | User `settings.json`, `keybindings.json`, extensions list | Yes (revert via VS Code Settings Sync or manual edit) |
| **Windows Terminal profiles** | Three new profiles: `GitHub Personal`, `GitHub Client`, `GitHub Arduino` | Yes (remove the profiles from `settings.json`) |
| **Windows env vars (HKCU)** | `GIT_SSH`, `LANG`, `LC_ALL` | Yes (`reg delete` or System Properties UI) |
| **PowerShell profile** | Oh My Posh init line appended to `$PROFILE` | Yes (remove the line) |
| **Cspell dictionary** | `~/.cspell/custom_words.txt` | Yes (delete the file) |
| **Self-install** | This repo cloned to `{projects_root}\{github_username}\public\cfg_dev_environment\` (Phase 12 only) | Yes (delete the directory) |

Phase 3 prompts you for `projects_root` and your personal GitHub username
the first time it runs and persists both to `~/.claude/config.json`.
Every later phase reads from that config, so you can put your projects
anywhere you want (e.g. `C:\extCODE\`, not just `%USERPROFILE%\projects\`).

---

## Repository layout

| Directory | Contents |
|-----------|----------|
| `scripts/` | 26 setup scripts (phases 1–12 inc. 7b, PowerShell 7 + bash) plus `preview.ps1`/`.sh` and `migrate_to_github.ps1` |
| `templates/` | Project scaffold, platform-specific files, VS Code config |
| `claude-rules/` | Global Claude rule files, deployed to `~/.claude/rules/` (auto-load universal or extension-triggered) |
| `claude-stacks/` | Opt-in stack rule files, deployed to `~/.claude/stacks/` (do NOT auto-load; @-imported per repo) |
| `claude-skills/` | Skill directories deployed to `~/.claude/skills/` |
| `claude-scripts/` | Helper scripts the skills call, deployed to `~/.claude/scripts/` and `~/.claude/shortcuts/` by Phase 7b |
| `config/` | Source-of-truth dotfiles deployed to `~/`: gitconfig, gitleaks, gitignore_global, gitmessage, Oh My Posh theme, ssh_config, bashrc, bash_profile, git-templates/hooks, cspell custom words, bitwarden_env.example |

---

## Further reading

- [`IMPLEMENTATION_STEPS.md`](IMPLEMENTATION_STEPS.md): exhaustive run order with exit criteria for every phase. Use this when a phase fails and you need to look up what it was supposed to do.
- [`HOW_IT_WORKS.md`](HOW_IT_WORKS.md): architecture and rationale. Why two SSH binaries, why `[includeIf]` in gitconfig, what each Claude rule contributes, etc.
- [`DIARY.md`](DIARY.md): changelog and decision log.
