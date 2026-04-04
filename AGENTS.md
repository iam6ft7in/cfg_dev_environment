# AI Agent Rules

This repository follows universal AI collaboration rules. All AI agents
(Claude, Copilot, GPT, etc.) must adhere to the following principles:

## Core Principles

- **Minimal footprint**: Make only the changes requested. Do not refactor
  or reorganize code unless explicitly asked.
- **No silent assumptions**: If requirements are unclear, ask before acting.
- **Preserve intent**: Maintain the style and conventions already present
  in the codebase.
- **Reversible actions**: Prefer changes that can be easily undone.
  Never force-push, delete branches, or remove files without confirmation.
- **Conventional commits**: All commit messages must follow the
  Conventional Commits specification (https://www.conventionalcommits.org/).
- **Signed commits**: All commits must be GPG-signed.

## Full Rule Set

See the complete rule files imported in CLAUDE.md:
- `~/.claude/rules/core.md`   — Universal rules for all projects
- `~/.claude/rules/shell.md`  — Shell/PowerShell-specific rules