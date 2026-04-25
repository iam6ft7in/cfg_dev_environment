---
description: Placeholder for repos whose platform is undecided; defer to globals
---

# Other Platform Rules

This rule file exists so the `new-repo` skill (Step 1b option 9) can
pick the `other` platform when the eventual stack is not yet known.
It carries no platform-specific guidance; rely on the universal rules
(`core.md`, `docs.md`, `command_paths.md`, `shell.md`,
`powershell.md`, `ssh.md`) until a real platform is chosen.

## When to migrate off `other`

Replace this import with a specific platform's rules file (e.g.,
`@~/.claude/rules/python.md`) once:

- The build, test, and run tooling for the project is decided
- A matching platform overlay exists at
  `~/.claude/templates/project/platforms/{platform}/`
- A matching rules file exists at `~/.claude/rules/{platform}.md`

If the chosen stack has neither, contribute both back to
`cfg_dev_environment` first, then update this repo's `CLAUDE.md` to
import the new rules file.

## What to avoid while undecided

- Adding tooling-specific scaffolding (lockfiles, lint configs,
  entry-point modules) until the platform is chosen, that scaffolding
  becomes legacy the moment a different stack is picked.
- Committing build artifacts, `.venv/`, `node_modules/`, etc. The
  base scaffold's `.gitignore` already covers most cases.
