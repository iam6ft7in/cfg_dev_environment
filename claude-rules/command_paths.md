---
description: Rules for resolving command paths — what to do when a command is not found, and how to keep the index current
paths: ["**"]
---

# Command Path Rules (Global)

## Never Assume a Command Is on PATH

Before running any command in the Claude Code Bash tool or on a remote host,
check whether that command requires a non-default path:

1. Read `~/.claude/memory/reference_command_paths.md` for the index of known
   resolved paths on the local host and known remote hosts.
2. If the command is listed, use the documented path.
3. If the command is not listed, try it bare — if it fails with "command not
   found" (exit code 127), locate it and update the index before retrying.

## When "Command Not Found" Occurs

1. **Locate the command** using `which <command>` or `find` on the relevant host.
2. **Retry** using the resolved full path.
3. **Update `reference_command_paths.md`** immediately with the new entry.
4. **Update `MEMORY.md`** if the entry description needs refreshing.

Do not retry the same failing command blindly. Diagnose first, then fix the
index so the next session does not repeat the same lookup.

## MSYS2 Path Mangling (Windows ssh.exe → Remote Linux)

When running commands on a remote Linux host via
`/c/WINDOWS/System32/OpenSSH/ssh.exe`, MSYS2 converts POSIX paths in
arguments to Windows paths before the Windows binary receives them. The remote
Linux shell then gets a Windows-style path it cannot execute.

**Rule:** Pass bare command names (no path prefix) for commands that are in
the remote's standard PATH. Only pass full paths for commands that are NOT in
the remote's PATH.

Example:
```bash
# WRONG — MSYS2 converts /usr/bin/pkill to C:/Program Files/.../pkill
/c/WINDOWS/System32/OpenSSH/ssh.exe host "/usr/bin/pkill -f pytest"

# CORRECT — bare name, MSYS2 leaves it alone
/c/WINDOWS/System32/OpenSSH/ssh.exe host "pkill -f pytest"
```

## Per-Repo Command Path Files

Host-specific command paths belong in the **repo's own memory**, not the
global memory. The global `reference_command_paths.md` contains only paths
for the local Windows machine (Claude Code Bash tool itself).

When a repo uses commands on a remote host:
1. Create or update `memory/reference_command_paths.md` in that repo's memory.
2. Add a pointer to it in the repo's `memory/MEMORY.md`.
3. Include: non-standard command locations, venv paths, path mangling warnings.
4. Link back to `~/.claude/rules/command_paths.md` and the global file.

The global file (`~/.claude/memory/reference_command_paths.md`) is read at the
start of every session, so it should stay focused on universal local-machine
paths only.
