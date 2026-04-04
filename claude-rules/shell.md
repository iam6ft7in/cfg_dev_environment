---
description: Rules for bash, zsh, PowerShell 7+, and Perl scripts
paths: ["**/*.sh", "**/*.bash", "**/*.zsh", "**/*.ps1", "**/*.psm1", "**/*.psd1", "**/*.pl", "**/*.pm"]
---

# Shell Scripting Rules

## Universal Shell Rules
- Always use curly braces for variable interpolation: ${variable} not $variable
- This applies to: bash, zsh, PowerShell, Perl, Makefile
- Declare variables before use
- Use meaningful variable names (no single-letter variables except loop indices)

## bash / zsh
- Always start with: `#!/usr/bin/env bash` and `set -euo pipefail`
- -e: exit on error, -u: error on undefined variable, -o pipefail: pipe failures propagate
- Quote all variable expansions: "${variable}" not $variable
- Use [[ ]] for conditionals, not [ ]
- Declare arrays with: declare -a my_array=()
- Use $(command) not backticks for command substitution
- ShellCheck compliance required: run `shellcheck` before committing
- Function names: snake_case

## PowerShell 7+
- Target PS 7+, not 5.1 (use PS 7+ features freely)
- Add at top: `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
- Always use ${variable} curly braces, not $variable
- Use [CmdletBinding()] on all functions
- Function names: Verb-Noun PascalCase (follow PS conventions)
- Parameter names: PascalCase
- PSScriptAnalyzer compliance required
- Note PS 5.1 compatibility in comments when a script must run on 5.1

## Perl
- Always start with: `use strict;` and `use warnings;`
- UTF-8: add `use utf8;` for scripts handling Unicode
- Use ${variable} curly braces consistently
- Module names: PascalCase (e.g., ProjectName::Helpers)
- Function names: snake_case
- Test with Test::More

## Error Handling
- bash: `command || { log_error "message"; exit 1; }`
- PowerShell: use try/catch blocks; set $ErrorActionPreference = 'Stop'
- Perl: check return values; use `die` with descriptive messages
