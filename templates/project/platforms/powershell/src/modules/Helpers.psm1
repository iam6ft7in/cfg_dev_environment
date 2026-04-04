#Requires -Version 7.0
<#
.SYNOPSIS
    Helper functions for {{REPO_NAME}}
#>

function Write-StatusMessage {
    <#
    .SYNOPSIS
        Write a colored status message to the console.
    .DESCRIPTION
        Wraps Write-Host with consistent color coding:
        Success=Green, Error=Red, Warning=Yellow, Info=Cyan
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]${Message},

        [Parameter()]
        [ValidateSet('Success', 'Error', 'Warning', 'Info')]
        [string]${Type} = 'Info'
    )

    $ColorMap = @{
        Success = 'Green'
        Error   = 'Red'
        Warning = 'Yellow'
        Info    = 'Cyan'
    }

    Write-Host ${Message} -ForegroundColor ${ColorMap}[${Type}]
}

Export-ModuleMember -Function Write-StatusMessage
