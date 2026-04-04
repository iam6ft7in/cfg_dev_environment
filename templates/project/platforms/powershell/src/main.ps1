#Requires -Version 7.0
<#
.SYNOPSIS
    {{DESCRIPTION}}

.DESCRIPTION
    Entry point for {{REPO_NAME}}.
    Platform: PowerShell 7+
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import modules
$ModulePath = Join-Path -Path ${PSScriptRoot} -ChildPath 'modules'
if (Test-Path -Path ${ModulePath}) {
    Get-ChildItem -Path ${ModulePath} -Filter '*.psm1' | ForEach-Object {
        Import-Module -Name ${_.FullName} -Force
    }
}

# Main logic
function Main {
    Write-Host "{{REPO_NAME}} starting..." -ForegroundColor Cyan
}

Main
