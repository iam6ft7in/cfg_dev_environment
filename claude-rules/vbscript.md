---
description: VBScript rules for Windows automation and Office macros
paths: ["**/*.vbs", "**/*.vba", "**/*.bas"]
---

# VBScript Rules

## Required Declarations
- ALWAYS start every .vbs file with `Option Explicit`
- This prevents typo-induced bugs by requiring all variables to be declared
- Declare variables with: `Dim myVariable`

## Comment Requirements
- File header comment required in every .vbs file:
  ```
  ' Script: name.vbs
  ' Purpose: one-line description
  ' Dependencies: list COM objects used (e.g., WScript.Shell, Excel.Application)
  ' Office version: e.g., Microsoft 365 / Excel 16.0
  ' Author: {your_name}
  ' Date: YYYY-MM-DD
  ```
- Document every COM object: note the ProgID and what it provides

## COM Object Documentation
- Every COM object instantiation must have a comment:
  `Set objShell = CreateObject("WScript.Shell")  ' Windows shell — run commands, read registry`
- Document required Office versions in docs/dependencies.md
- Use early binding (CreateObject) and document the object's capabilities

## Error Handling
- Use `On Error Resume Next` sparingly — only when you explicitly handle the error
- Always check `Err.Number` after risky operations
- Use `On Error GoTo 0` to re-enable error propagation after handling

## Runtime Considerations
- Run with cscript.exe for console output (WScript.Echo goes to stdout)
- Run with wscript.exe for GUI (WScript.Echo shows a dialog)
- WScript.StdErr only available under cscript.exe
- Note in script header which host is required

## Security
- Never hardcode credentials in VBScript
- Avoid using Shell to run commands with user-supplied input (command injection risk)
