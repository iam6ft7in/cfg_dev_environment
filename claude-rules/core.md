---
description: Core rules applied to all projects, commits, security, branching, general Claude behavior
---

# Core Rules (Global)

## Commit Standards
- Conventional Commits format required: type(scope): description
- Types: feat, fix, docs, style, refactor, perf, test, chore, ci, revert
- Scope: optional, in snake_case
- Description: imperative mood, max 88 characters, no trailing period
- SSH signing on all commits and tags (commit.gpgsign=true is set globally)
- Never amend published commits, create new commits instead

## Branch Standards
- Never commit directly to main
- Use branch prefixes: feature/, fix/, docs/, chore/, refactor/, test/
- Branch names in snake_case: feature/add_altitude_hold
- Squash and merge via PR only (no direct merges)
- Delete branches after merging

## Code Standards
- Maximum line length: 88 characters
- American English in all documentation, comments, and commit messages
- Always use curly brace variable syntax where supported:
  - bash/zsh: ${variable}
  - PowerShell: ${variable}
  - Perl: ${variable}
  - Makefile: ${variable}
- Python, VBScript, Assembly: not applicable (different syntax)

## Security Rules
- NEVER commit secrets, credentials, API keys, tokens, passwords, or private keys
- Use .env files for secrets, .env is gitignored, .env.example is committed
- If you detect a potential secret in code, flag it immediately as Critical
- All repos are private by default
- Explicit license choice required at repo creation, never add a license silently

## File Handling
- Always read a file before editing it
- Do not create files unless absolutely necessary
- Prefer editing existing files over creating new ones
- Never use sed/awk when Edit tool is available
- Never use grep when Grep tool is available
- No authorization is required to read any file or subfolder under `~/.claude`

## Repository Conventions
- Repo names: snake_case with type prefix (e.g., python_telemetry_parser)
- Keep repos private by default
- Explicit license choice required, never add a default silently

## Comment Style
- Teaching style: explain WHY the code works this way, not just WHAT it does
- Comments should answer "why was this done this way?"
- Include context about alternatives considered when relevant
- Avoid restating what the code clearly shows

## Writing Style
- No em dashes (—) anywhere: code, comments, documentation, commit messages,
  PR and issue bodies, markdown tables, or chat responses. Use commas,
  parentheses, colons, or periods instead.
- Hyphens (-) for compound words are fine. En dashes (–) for numeric ranges
  are allowed but rare. The ban is specifically on the em dash (—, U+2014).
- Reason: em dashes read as AI-generated and clutter prose that other
  punctuation handles cleanly.

## Uncertainty Handling
- HIGH-IMPACT decisions (architecture changes, destructive operations, security implications,
  deleting files, changing APIs): STOP and ask explicitly before proceeding
- LOW-IMPACT decisions (variable names, comment wording, minor formatting,
  choosing between equivalent approaches): state the assumption made, then proceed
- When in doubt about impact level: treat as high-impact and ask

## Code Review Format
When reviewing code or responding to review requests, use this format:
- **Critical:** [issue], Must fix before merge. [explanation of why]
- **Warning:** [issue], Should fix. [explanation]. Can skip if [condition].
- **Suggestion:** [improvement], Optional. [rationale for improvement].
Each comment explains WHY it matters, not just what to change.
