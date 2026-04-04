Option Explicit
' Helper functions for {{REPO_NAME}}
' Platform: VBScript
' Note: This file is intended to be included via ExecuteFile or
' concatenated at build time — VBScript has no native module system.

' Log an informational message to the console.
' Uses WScript.Echo which outputs to stdout when run with cscript.exe.
Sub LogInfo(msg)
    WScript.Echo "[INFO] " & msg
End Sub

' Log an error message to stderr.
' StdErr is only available when run with cscript.exe (not wscript.exe).
Sub LogError(msg)
    WScript.StdErr.WriteLine "[ERROR] " & msg
End Sub
