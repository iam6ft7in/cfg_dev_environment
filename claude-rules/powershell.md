# PowerShell Rules (Global)

## Known Cmdlet Parameter Limits

Some cmdlets have hard character limits that are not surfaced in help text.
Validate at the point of definition, parameter validation errors are terminating
even without `$ErrorActionPreference = 'Stop'`.

| Cmdlet | Parameter | Max chars |
|--------|-----------|-----------|
| `Set-LocalUser` / `New-LocalUser` | `-Description` | 48 |

## Idempotency Check Order for Rename/Transform Operations

Always check whether the **target state already exists** before checking whether
the source exists. Checking source first causes a false early-return on re-runs
after a partial operation where the source is already gone.

```powershell
# Wrong, returns "nothing to do" if source is gone, even if target needs updating
${source} = Get-LocalUser 'Administrator' -ErrorAction SilentlyContinue
if (-not ${source}) { return 'SKIP: source gone' }
${target} = Get-LocalUser 'janeway'       -ErrorAction SilentlyContinue
if (${target}) { ... update ... }

# Correct, always services the target account regardless of source state
${target} = Get-LocalUser 'janeway'       -ErrorAction SilentlyContinue
${source} = Get-LocalUser 'Administrator' -ErrorAction SilentlyContinue
if (${target})                          { ... update target ... }
elseif (${source})                      { ... rename source → target ... }
else                                    { return 'SKIP: nothing to act on' }
```

## Here-Strings Embedding Remote/Guest Scripts

### Line Continuation, Use Double Backtick

A single trailing backtick inside a double-quoted here-string (`@"..."@`) is an
unrecognized escape sequence. PowerShell **silently drops the backtick**. The
generated script has no line continuation and fails to parse.

Use ```` `` ```` (two backticks) to produce one literal backtick in the output:

```powershell
# Wrong, backtick is dropped; generated script fails to parse
${content} = @"
Set-Something -Param1 'value' `
    -Param2 'other'
"@

# Correct
${content} = @"
Set-Something -Param1 'value' ``
    -Param2 'other'
"@
```

### Non-ASCII Characters, Keep Embedded Scripts ASCII-Only

Never embed non-ASCII characters in **string literals** inside scripts that will
be executed by `powershell.exe` (PS 5.1).

PS 5.1 reads files using the system ANSI code page (CP1252 on US Windows) when no
UTF-8 BOM is present. UTF-8 multi-byte sequences for characters such as `—`
(em dash, bytes E2 80 94) include byte `0x94`, which CP1252 maps to `"` (right
curly quotation mark). PS 5.1 treats this as a string terminator, producing a
cascade of parse errors from that line onward, and the error is reported at a
later line, making the root cause non-obvious.

| Location | Non-ASCII safe? |
|----------|----------------|
| Comment lines (`#`) | Yes, comments are not parsed as string literals |
| Double-quoted string literals | **No**, use ASCII only or use `pwsh` |
| Single-quoted string literals | **No**, same encoding risk |
| Script executed by `pwsh` (PS 7) | Yes, PS 7 reads UTF-8 correctly |

When a non-ASCII character is needed in a string value, construct it at runtime:
```powershell
# Em dash without embedding a non-ASCII literal
${dash} = [char]0x2014
${msg}  = "Renamed${dash}description updated"
```

## Passing Secrets in Embedded Scripts

Never interpolate passwords directly into here-string content. Characters such as
`'`, `` ` ``, and `$` in the password value break the string literal syntax of
the generated script. Base64 encoding is safe for any password content, it
produces only `A-Z`, `a-z`, `0-9`, `+`, `/`, `=`.

```powershell
# Host side, encode before embedding
${b64Pass} = [Convert]::ToBase64String(
    [System.Text.Encoding]::Unicode.GetBytes(${plainPass})
)

# In the here-string, survives any password content
${content} = @"
`${pass} = ConvertTo-SecureString ``
    ([System.Text.Encoding]::Unicode.GetString(
        [Convert]::FromBase64String('${b64Pass}')
    )) -AsPlainText -Force
"@
```

## Remote and Guest Script Error Capture

Scripts executed remotely (via vmrun, Invoke-Command, SSH, etc.) where the
caller cannot see stdout or stderr **must** write diagnostic output to a
retrievable file. An exit code alone is not enough to diagnose failures.

```powershell
# Guest/remote script pattern
`$ErrorActionPreference = 'Stop'
`${result} = 'C:\Windows\Temp\script-result.txt'
try {
    # ... work ...
    Set-Content `${result} 'OK: operation description'
} catch {
    Set-Content `${result} "FAIL: `$(`$_.Exception.Message)"
    exit 1
}
```

Host-side retrieval (vmrun example):
```powershell
& vmrun copyFileFromGuestToHost ${vmx} 'C:\Windows\Temp\script-result.txt' ${local}
if (Test-Path ${local}) { Get-Content ${local} }
```

## PowerShell Executable Selection

| Executable | Version | File Encoding | Use When |
|------------|---------|---------------|----------|
| `powershell.exe` | 5.1 | System ANSI (CP1252 on US Windows) | Script runs before PS 7 is installed; content must be ASCII-only |
| `pwsh.exe` | 7+ | UTF-8 without BOM | PS 7 confirmed installed; supports full Unicode |

Never use `powershell` to execute a script that contains non-ASCII characters
unless the file is written with a UTF-8 BOM (`-Encoding utf8BOM` in PS 7).
When in doubt, keep embedded scripts ASCII-only regardless of which executable
is used.
