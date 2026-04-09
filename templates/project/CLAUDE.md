# {{REPO_NAME}}

{{DESCRIPTION}}

<!-- Import global Claude rules -->
@~/.claude/rules/core.md

<!-- Import platform-specific rules — uncomment the relevant line -->
<!-- @~/.claude/rules/arduino.md -->
<!-- @~/.claude/rules/python.md -->
<!-- @~/.claude/rules/shell.md -->
<!-- @~/.claude/rules/assembly.md -->
<!-- @~/.claude/rules/vbscript.md -->

## PowerShell Execution
When running PowerShell scripts or commands in the Bash tool, always use
`pwsh.exe` (PowerShell 7.x), not `powershell.exe` (PowerShell 5.1).
This applies to every Bash tool invocation that calls PowerShell.

## Script and Command Language Preference
When generating scripts or suggesting commands to run manually, prefer
PowerShell (pwsh) over Git Bash or Python unless the task is a clearly
better fit for one of them — for example, POSIX text-processing pipelines
or direct use of a Python library. Both Git Bash and Python are installed
locally and are valid fallbacks when they make more sense.

<!-- Import project-specific rules -->
@.claude/rules/project.md

## Project Context
**Platform:** {{PLATFORM}}
**Description:** {{DESCRIPTION}}

## Project-Specific Notes
(Add any project-specific context, constraints, or reminders here)
