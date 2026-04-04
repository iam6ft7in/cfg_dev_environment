# VBScript Dependencies

## Runtime Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| Windows Script Host | 5.8+ | Built into Windows |
| VBScript | 5.8 | Built into Windows |

## COM Object Dependencies

| Object | Used In | Purpose |
|--------|---------|---------|
| WScript.Shell | helpers.vbs | Shell command execution |

## Office Dependencies (if applicable)

| Application | Version | Notes |
|-------------|---------|-------|
| (none yet) | | |

## Known Compatibility Issues

- Run with `cscript.exe` (not `wscript.exe`) for console output
- `WScript.StdErr` only available under cscript.exe
