# cfg_dev_environment

Gold standard GitHub development environment setup for Windows 11, scripts,
templates, Claude rules, and skills for a fully automated, consistent workflow
across all personal and client projects.

## What's in here

| Directory | Contents |
|-----------|----------|
| `scripts/` | 26 setup scripts (phases 1–12 inc. 7b, PowerShell 7 + bash) plus `migrate_to_github.ps1` |
| `templates/` | Project scaffold, platform-specific files, VS Code config |
| `claude-rules/` | Global Claude rule files, deployed to `~/.claude/rules/` (auto-load universal or extension-triggered) |
| `claude-stacks/` | Opt-in stack rule files, deployed to `~/.claude/stacks/` (do NOT auto-load; @-imported per repo) |
| `claude-skills/` | Skill directories deployed to `~/.claude/skills/` |
| `claude-scripts/` | Helper scripts the skills call, deployed to `~/.claude/scripts/` and `{projects_root}\shortcuts\` by Phase 7b |
| `config/` | Source-of-truth for dotfiles deployed to `~/`: gitconfig, gitleaks, gitignore_global, gitmessage, Oh My Posh theme, ssh_config, bashrc, bash_profile, git-templates/hooks, cspell custom words, bitwarden_env.example |

## Usage

See `IMPLEMENTATION_STEPS.md` for the full setup walkthrough.

For ongoing use, see `HOW_IT_WORKS.md` and `DIARY.md`.
