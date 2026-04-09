# Claude Rules

## Session Management
When the user says "resume" or references a previous session, read all project
files in the current directory to rebuild context — especially any context
handoff files, README, and design docs. Do not assume a specific file like
CONTEXT.md exists; discover what is actually present first.

## Communication Style
When asking clarifying questions, consolidate them into a single numbered
list rather than asking sequentially one at a time. Limit to 5-10 questions
per batch.

## Windows Scripting
When working with PowerShell or batch files on Windows, be careful with:
UTF-8 encoding (avoid em dashes and other special chars), unescaped
parentheses in batch files, here-string syntax differences between terminal
and scripts, and progress bar characters.

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

@~/.claude/rules/core.md
@~/.claude/rules/shell.md