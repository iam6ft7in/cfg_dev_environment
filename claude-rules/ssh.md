---
description: SSH connectivity rules, how to use SSH on this machine, how repos document SSH use, and how to keep global SSH docs current
paths: ["**"]
---

# SSH Rules (Global)

## Never Assume SSH Configuration

Never assume how SSH is used for any project or repo. Before running any SSH
command or advising on SSH connectivity:

1. Check `~/.claude/memory/reference_ssh_windows.md`: which binary to use,
   Bitwarden bridge behavior, agent forwarding requirements.
2. Check `~/.claude/memory/reference_ssh_hosts.md`: which host aliases exist
   and which repos use them.
3. Check the repo's own SSH memory file (e.g., `memory/reference_ssh.md`) for
   repo-specific requirements.

---

## Always Use the Correct SSH Binary in Bash Tool

Claude Code's Bash tool does not source `~/.bashrc`. Always invoke:

```
/c/WINDOWS/System32/OpenSSH/ssh.exe
/c/WINDOWS/System32/OpenSSH/scp.exe
/c/WINDOWS/System32/OpenSSH/ssh-add.exe
```

Never use `/usr/bin/ssh.exe` (MSYS2) or bare `ssh` in the Bash tool.
See `reference_ssh_windows.md` for full explanation.

---

## Per-Repo SSH Documentation Protocol

Any repo that uses SSH connectivity **must** maintain a memory file at:
```
<project-memory-dir>/reference_ssh.md
```

This file must document:
- Which host aliases the repo connects to (from `~/.ssh/config`)
- What the connection is used for (git ops, remote test runner, deploy, etc.)
- Whether agent forwarding (`-A`) is required and why
- Any repo-specific SSH commands or patterns

### Template

```markdown
---
name: SSH connectivity for <repo-name>
description: Which SSH hosts this repo connects to and how
type: reference
---

## SSH Hosts Used

### `<alias>` (`<user>@<hostname>`)
- **Purpose:** <what this connection does>
- **Agent forwarding:** <yes/no>, reason
- **Common commands:**
  - `<example command>`

## Notes
<any repo-specific caveats>

## Global Reference
See `~/.claude/memory/reference_ssh_windows.md` for binary selection rules.
See `~/.claude/memory/reference_ssh_hosts.md` for full host alias definitions.
```

---

## Keeping Global Docs Current

When you add, change, or remove SSH connectivity for a repo:

1. Update the repo's `memory/reference_ssh.md`.
2. Update `~/.claude/memory/reference_ssh_hosts.md`: add/edit/remove the
   host alias entry, and update the "Repos using this host" field.
3. If a new host alias was added to `~/.ssh/config`, document it in
   `reference_ssh_hosts.md` immediately.
4. If the Windows SSH environment changes (new binary path, new bridge method,
   Bitwarden behavior change), update `reference_ssh_windows.md`.

---

## When a Repo Starts Using SSH for the First Time

1. Read `~/.claude/memory/reference_ssh_windows.md` and
   `~/.claude/memory/reference_ssh_hosts.md` to understand what already exists.
2. Determine if a new host alias in `~/.ssh/config` is needed or if an existing
   alias covers the use case.
3. Create `memory/reference_ssh.md` in the repo using the template above.
4. Update `~/.claude/memory/reference_ssh_hosts.md` with the new or updated
   host alias entry.
5. Add a pointer to `reference_ssh.md` in the repo's `memory/MEMORY.md`.
